class_name ServicoJogador
extends Node
## Dados do jogador e save local (autoload "Jogador"). É o único lugar que
## muda o estado do jogador: as telas leem cópias e pedem mudanças por
## comandos, que validam, mudam, salvam e avisam (sinal `mudou`). Cada
## comando devolve {ok: bool, erro: String, ...}: na Parte 3 os comandos que
## valem algo (ouro, itens, timers) viram chamadas a Edge Functions com a
## mesma assinatura, e o servidor passa a ser o dono do estado.
##
## Modelo (dicionário com "versao"; ver docs/DADOS_JOGADOR.md):
##   cavaleiro, casa, cavalos, cavalo_ativo, inventario {ouro, gemas,
##   materiais, itens}, equipamento {espaco: id}, visual {espaco: id},
##   vila {predios}, timers [{id, tipo, alvo, inicio_em, termina_em}],
##   pve, tutorial, criado_em, proximo_id.
## Timers sempre como horário de término (ServicoTempo).

signal mudou(secao: String)

const VERSAO := 7
const ESPACOS_REGRA := ["elmo", "peitoral", "escudo", "lanca"]

@export var caminho_save := "user://jogador.json"

var estado: Dictionary = {}

func _ready() -> void:
	if not carregar():
		estado = novo_estado()

# ------------------------------------------------------------------ leitura

func tem_personagem() -> bool:
	return estado.get("cavaleiro", {}).get("nome", "") != ""

func cavaleiro() -> Dictionary:
	return estado["cavaleiro"].duplicate(true)

func casa() -> Dictionary:
	return estado["casa"].duplicate(true)

func cavalo_ativo() -> Dictionary:
	for c: Dictionary in estado["cavalos"]:
		if c["id"] == estado["cavalo_ativo"]:
			return c.duplicate(true)
	return {}

func cavalo(id: String) -> Dictionary:
	for c: Dictionary in estado["cavalos"]:
		if c["id"] == id:
			return c.duplicate(true)
	return {}

## Fôlego atual do cavalo (0 ao máximo dos dados). Guardado como valor +
## horário; recupera com o tempo, mais rápido com o estábulo melhor, sem
## precisar de nada rodando (vale com o jogo fechado).
func folego_cavalo(id := "") -> int:
	var c := cavalo_ativo() if id == "" else cavalo(id)
	if c.is_empty():
		return 0
	var f: Dictionary = Balanceamento.carregar("treino")["folego_cavalo"]
	var maximo := int(f["maximo"])
	var base := int(c.get("folego", maximo))
	var desde := maxi(ServicoTempo.agora() - int(c.get("folego_em", ServicoTempo.agora())), 0)
	return mini(maximo, base + desde * _recuperacao_por_hora() / 3600)

## Cavalo cansado: fôlego abaixo do limite. Corre mesmo assim, com
## penalidade de velocidade (GDD: nunca existe energia que impede de jogar).
func cavalo_cansado(id := "") -> bool:
	return folego_cavalo(id) < int(Balanceamento.carregar("treino")["folego_cavalo"]["cansado_abaixo_de"])

## Horário em que o cavalo estará com o fôlego cheio.
func descansado_em(id := "") -> int:
	var f: Dictionary = Balanceamento.carregar("treino")["folego_cavalo"]
	var falta := int(f["maximo"]) - folego_cavalo(id)
	return ServicoTempo.agora() + (falta * 3600 + _recuperacao_por_hora() - 1) / maxi(_recuperacao_por_hora(), 1)

func _recuperacao_por_hora() -> int:
	var f: Dictionary = Balanceamento.carregar("treino")["folego_cavalo"]
	var bonus := int(f["bonus_recupera_por_nivel_estabulo_pct"]) * maxi(predio_nivel("estabulo") - 1, 0)
	bonus += bonus_companheiros("folego_recupera_pct")
	return int(f["recupera_por_hora"]) * (100 + bonus) / 100

func cavalo_treinando(id: String) -> bool:
	for t: Dictionary in estado["timers"]:
		if t["tipo"] == "treino_cavalo" and t.get("cavalo", "") == id:
			return true
	return false

func cavalos() -> Array:
	return estado["cavalos"].duplicate(true)

func ouro() -> int:
	return int(estado["inventario"]["ouro"])

func itens() -> Array:
	return estado["inventario"]["itens"].duplicate(true)

func item(id: String) -> Dictionary:
	for it: Dictionary in estado["inventario"]["itens"]:
		if it["id"] == id:
			return it.duplicate(true)
	return {}

## Peça equipada num espaço ({} se vazio).
func equipado(espaco: String) -> Dictionary:
	return item(estado["equipamento"].get(espaco, ""))

## Variante de arte de cada espaço, já com o guarda-roupa (visual) aplicado
## e com o estágio de dano da peça equipada (sufixo _d1, _d2, _d3).
func visual_das_pecas() -> Dictionary:
	var modelos: Dictionary = Balanceamento.carregar("itens")["modelos"]
	var saida := {}
	for espaco: String in estado["equipamento"]:
		var id: String = estado["visual"].get(espaco, estado["equipamento"][espaco])
		var it := item(id)
		if not it.is_empty():
			var e := estagio_dano(estado["equipamento"][espaco])
			saida[espaco] = str(modelos[it["modelo"]]["visual"]) + ("_d%d" % e if e > 0 else "")
	return saida

## Estágio de dano da peça (0 inteira, 1 riscada, 2 amassada, 3 rachada),
## pela porcentagem de durabilidade (limites em desgaste.json).
func estagio_dano(id: String) -> int:
	var it := item(id)
	if it.is_empty():
		return 0
	var maximo := int(Balanceamento.carregar("itens")["modelos"][it["modelo"]]["durabilidade_max"])
	if maximo <= 0:
		return 0
	var pct := int(it["durabilidade"]) * 100 / maximo
	var e := 0
	for limite in Balanceamento.carregar("desgaste")["estagios_pct"]:
		if pct < int(limite):
			e += 1
	return e

## Lado do jogador para a regra da justa: {cavaleiro, cavalo, equipamento,
## habilidades}. Peça quebrada (durabilidade 0) vai com durabilidade 0 e a
## regra ignora os bônus dela. Os atributos do cavaleiro já levam o bônus de
## conjunto (2 peças), sem passar do teto.
func lado_para_justa() -> Dictionary:
	var modelos: Dictionary = Balanceamento.carregar("itens")["modelos"]
	var equip := {}
	for espaco: String in ESPACOS_REGRA:
		var it := equipado(espaco)
		if it.is_empty():
			continue
		var p := status_do_item(it["id"])
		p["durabilidade"] = int(it["durabilidade"])
		equip[espaco] = p
	var cav := cavalo_ativo()
	var atr_cavalo: Dictionary = cav.get("atributos", {}).duplicate()
	if cavalo_cansado():
		var pen := int(Balanceamento.carregar("treino")["folego_cavalo"]["penalidade_velocidade_cansado_pct"])
		atr_cavalo["velocidade"] = int(atr_cavalo.get("velocidade", 0)) * (100 - pen) / 100
	var cav_atr: Dictionary = estado["cavaleiro"]["atributos"].duplicate()
	var bonus: Dictionary = efeito_conjuntos()["atributos"]
	var teto := int(Balanceamento.carregar("treino")["teto_atributo"])
	for k: String in bonus:
		if cav_atr.has(k):
			cav_atr[k] = mini(int(cav_atr[k]) + int(bonus[k]), teto)
	return {
		"cavaleiro": cav_atr,
		"cavalo": atr_cavalo,
		"equipamento": equip,
		"habilidades": habilidades_em_uso(),
	}

# -------------------------------------------------------------- habilidades
# GDD Habilidades especiais e Conjuntos (3.16): ofensivas (ativas, botão que
# carrega) e defensivas (passivas, disparam no impacto); 1 espaço no começo,
# o segundo numa liga alta (ou no nível, enquanto não há liga); no máximo uma
# por grupo. As de conjunto só valem com o conjunto completo equipado.

## Efeito dos conjuntos equipados (RegraConjuntos): {atributos, habilidades, contagem, total}.
func efeito_conjuntos() -> Dictionary:
	var modelos_eq: Array = []
	for esp: String in estado["equipamento"]:
		var it := item(estado["equipamento"][esp])
		if not it.is_empty():
			modelos_eq.append(it["modelo"])
	return RegraConjuntos.efeito(modelos_eq, Balanceamento.carregar("itens"))

## Habilidades que o cavaleiro pode equipar agora: as de base e as dos
## conjuntos completos equipados.
func habilidades_conhecidas() -> Array:
	var r: Array = (Balanceamento.carregar("progressao")["habilidades"]["base"] as Array).duplicate()
	for h: String in efeito_conjuntos()["habilidades"]:
		if not r.has(h):
			r.append(h)
	return r

func espacos_habilidade() -> int:
	var cfg: Dictionary = Balanceamento.carregar("progressao")["habilidades"]
	var n := int(cfg["espacos_iniciais"])
	var ligas: Array = Balanceamento.carregar("economia")["ligas"]["nomes"]
	var melhor := str(estado.get("liga", {}).get("melhor", ""))
	var por_liga := melhor != "" and ligas.find(melhor) >= ligas.find(cfg["segundo_espaco_liga"])
	if por_liga or int(estado["cavaleiro"]["nivel"]) >= int(cfg["segundo_espaco_nivel"]):
		n += 1
	return n

## Habilidades escolhidas (como estão salvas).
func habilidades_escolhidas() -> Array:
	return (estado["cavaleiro"].get("habilidades", []) as Array).duplicate()

## As que valem na justa: as escolhidas que ainda são conhecidas (a de um
## conjunto sai se o conjunto for desfeito), até o número de espaços.
func habilidades_em_uso() -> Array:
	var conhecidas := habilidades_conhecidas()
	var r: Array = []
	for h: String in habilidades_escolhidas():
		if conhecidas.has(h) and r.size() < espacos_habilidade():
			r.append(h)
	return r

## Troca as habilidades escolhidas: até o número de espaços, conhecidas,
## sem repetir e no máximo uma por grupo (ofensiva, defensiva).
func equipar_habilidades(lista: Array) -> Dictionary:
	if lista.size() > espacos_habilidade():
		return _erro("sem_espaco_habilidade")
	var conhecidas := habilidades_conhecidas()
	var defs: Dictionary = Balanceamento.carregar("impacto")["habilidades"]
	var grupos := {}
	for h: String in lista:
		if not conhecidas.has(h) or not defs.has(h):
			return _erro("habilidade_desconhecida")
		var g := str(defs[h]["grupo"])
		if grupos.has(g):
			return _erro("uma_por_grupo")
		grupos[g] = true
	estado["cavaleiro"]["habilidades"] = lista.duplicate()
	return _concluir("cavaleiro")

# ----------------------------------------------------------------- comandos

## Começa do zero (estado inicial dos dados) e salva.
func novo_jogo() -> Dictionary:
	estado = novo_estado()
	return _concluir("tudo")

## Criação de personagem (2.2). Campos: nome, nome_casa, corpo, rosto,
## cabelo, pele, cor_principal, cor_secundaria, pelagem.
func criar_personagem(d: Dictionary) -> Dictionary:
	for k in ["nome", "nome_casa", "corpo", "rosto", "cabelo", "pele", "cor_principal", "cor_secundaria", "pelagem"]:
		if not d.has(k) or str(d[k]) == "":
			return _erro("falta_" + k)
	for k in ["nome", "nome_casa"]:
		var e := ServicoNomes.validar(str(d[k]))
		if e != "":
			return _erro(e)
	var cav: Dictionary = estado["cavaleiro"]
	cav["nome"] = ServicoNomes.limpar(d["nome"])
	cav["corpo"] = d["corpo"]
	cav["rosto"] = d["rosto"]
	cav["cabelo"] = d["cabelo"]
	cav["pele"] = d["pele"]
	cav["cor_cabelo"] = d.get("cor_cabelo", "castanho")
	estado["casa"]["nome"] = ServicoNomes.limpar(d["nome_casa"])
	estado["casa"]["cores"]["principal"] = d["cor_principal"]
	estado["casa"]["cores"]["secundaria"] = d["cor_secundaria"]
	for c: Dictionary in estado["cavalos"]:
		if c["id"] == estado["cavalo_ativo"]:
			c["pelagem"] = d["pelagem"]
	return _concluir("cavaleiro")

## Brasão da casa (2.3): o dicionário do editor de brasão.
func definir_brasao(brasao: Dictionary) -> Dictionary:
	estado["casa"]["brasao"] = brasao.duplicate(true)
	return _concluir("casa")

## Equipa uma peça do inventário no espaço dela.
func equipar(id: String) -> Dictionary:
	var it := item(id)
	if it.is_empty():
		return _erro("item_inexistente")
	var modelo: Dictionary = Balanceamento.carregar("itens")["modelos"].get(it["modelo"], {})
	if modelo.is_empty():
		return _erro("modelo_inexistente")
	estado["equipamento"][modelo["espaco"]] = id
	return _concluir("equipamento")

## Guarda-roupa: aparência de `id_visual` no espaço (vazio = a da peça equipada).
func definir_visual(espaco: String, id_visual: String) -> Dictionary:
	if id_visual == "":
		estado["visual"].erase(espaco)
	else:
		var it := item(id_visual)
		if it.is_empty():
			return _erro("item_inexistente")
		if Balanceamento.carregar("itens")["modelos"][it["modelo"]]["espaco"] != espaco:
			return _erro("espaco_errado")
		estado["visual"][espaco] = id_visual
	return _concluir("equipamento")

# --------------------------------------------------------------------- vila

## Nível do prédio (0 = ainda não liberado). Prédio liberado pelo nível do
## cavaleiro e ainda sem registro começa no nível 1.
func predio_nivel(nome: String) -> int:
	if estado["vila"]["predios"].has(nome):
		return int(estado["vila"]["predios"][nome]["nivel"])
	return 1 if predio_liberado(nome) else 0

func predio_liberado(nome: String) -> bool:
	var p: Dictionary = Balanceamento.carregar("vila")["predios"].get(nome, {})
	return not p.is_empty() and int(estado["cavaleiro"]["nivel"]) >= int(p["libera_nivel"])

## Teto de nível: a casa senhorial vai até o máximo dela; os outros, até o
## nível da casa senhorial (GDD: ela define o teto dos outros prédios).
func teto_predio(nome: String) -> int:
	var p: Dictionary = Balanceamento.carregar("vila")["predios"][nome]
	if nome == "casa_senhorial":
		return int(p["nivel_max"])
	return mini(int(p["nivel_max"]), predio_nivel("casa_senhorial"))

## Timer em andamento (ou já pronto, esperando concluir) de um prédio; {} se
## não tem. `tipo` filtra ("melhoria", "treino_cavaleiro"...).
func timer_do_predio(nome: String, tipo := "") -> Dictionary:
	for t: Dictionary in estado["timers"]:
		if t["alvo"] == nome and (tipo == "" or t["tipo"] == tipo):
			return t.duplicate()
	return {}

## Timers de um prédio (todas as vagas).
func timers_do_predio(nome: String) -> Array:
	return estado["timers"].filter(func(t): return t["alvo"] == nome).map(func(t): return t.duplicate())

func timers() -> Array:
	return estado["timers"].duplicate(true)

## Se dá para melhorar e quanto custa: {ok, erro, ouro, segundos}.
func pode_melhorar(nome: String) -> Dictionary:
	var vila := Balanceamento.carregar("vila")
	if not vila["predios"].has(nome):
		return _erro("predio_inexistente")
	if not predio_liberado(nome):
		return _erro("predio_bloqueado")
	if not timer_do_predio(nome, "melhoria").is_empty():
		return _erro("predio_ocupado")
	var nivel := predio_nivel(nome)
	if nivel >= teto_predio(nome):
		return _erro("predio_no_teto" if nome != "casa_senhorial" and nivel < int(vila["predios"][nome]["nivel_max"]) else "predio_no_maximo")
	var m: Dictionary = vila["predios"][nome]["melhoria"][nivel - 1]
	if ouro() < int(m["ouro"]):
		return {"ok": false, "erro": "ouro_insuficiente", "ouro": int(m["ouro"]), "segundos": int(m["segundos"])}
	return {"ok": true, "erro": "", "ouro": int(m["ouro"]), "segundos": int(m["segundos"])}

## Começa a melhoria: cobra o ouro e cria o timer (horário de término).
func melhorar_predio(nome: String) -> Dictionary:
	var p := pode_melhorar(nome)
	if not p["ok"]:
		return p
	estado["inventario"]["ouro"] = ouro() - int(p["ouro"])
	var agora := ServicoTempo.agora()
	estado["timers"].append({"id": _novo_id(estado, "t"), "tipo": "melhoria", "alvo": nome,
		"inicio_em": agora, "termina_em": agora + duracao_timer(int(p["segundos"])), "nivel_novo": predio_nivel(nome) + 1})
	_garantir_predio(nome)
	_evento("predio")
	var r := _concluir("vila")
	r["ouro"] = p["ouro"]
	return r

## Conclui um timer que já terminou (aplica o efeito e tira da lista).
func concluir_timer(id: String) -> Dictionary:
	for i in estado["timers"].size():
		var t: Dictionary = estado["timers"][i]
		if t["id"] != id:
			continue
		if not ServicoTempo.pronto(int(t["termina_em"])):
			return _erro("timer_nao_terminou")
		var tr_cfg := Balanceamento.carregar("treino")
		var extra := {}
		match t["tipo"]:
			"melhoria":
				_garantir_predio(t["alvo"])
				estado["vila"]["predios"][t["alvo"]]["nivel"] = int(t["nivel_novo"])
			"treino_cavaleiro":
				var a: Dictionary = estado["cavaleiro"]["atributos"]
				a[t["atributo"]] = mini(int(a[t["atributo"]]) + int(tr_cfg["ganho_pontos"]), int(tr_cfg["teto_atributo"]))
			"conserto":
				var maximo := int(Balanceamento.carregar("itens")["modelos"][item(t["item"])["modelo"]]["durabilidade_max"])
				for it: Dictionary in estado["inventario"]["itens"]:
					if it["id"] == t["item"]:
						it["durabilidade"] = maximo
			"treino_cavalo":
				for c: Dictionary in estado["cavalos"]:
					if c["id"] == t["cavalo"]:
						var ac: Dictionary = c["atributos"]
						ac[t["atributo"]] = mini(int(ac[t["atributo"]]) + int(tr_cfg["ganho_pontos"]), int(tr_cfg["teto_atributo"]))
			"forja":
				extra = _entregar_forja(t["modelo"])
			"fundicao":
				var mats: Dictionary = estado["inventario"]["materiais"]
				mats[t["produto"]] = int(mats.get(t["produto"], 0)) + int(t["quantidade"])
				extra = {"produto": t["produto"], "quantidade": int(t["quantidade"])}
		estado["timers"].remove_at(i)
		var res := _concluir("vila")
		res.merge(extra, true)
		return res
	return _erro("timer_inexistente")

# ------------------------------------------------------- treino e cavalos

## Vagas de treino de um prédio (campo de treino ou estábulo).
func vagas_treino(predio: String) -> int:
	var v: Dictionary = Balanceamento.carregar("treino")["vagas"]
	return int(v["base"]) + (1 if predio_nivel(predio) >= int(v["extra_no_nivel_do_predio"]) else 0)

func treinos_em(predio: String) -> Array:
	return timers_do_predio(predio).filter(func(t): return str(t["tipo"]).begins_with("treino_"))

## Duração e custo do treino pelo nível do cavaleiro (curva dos dados).
func duracao_treino() -> int:
	return _da_curva(Balanceamento.carregar("treino")["duracao_por_nivel"])

func custo_treino() -> int:
	return _da_curva(Balanceamento.carregar("treino")["custo_ouro_por_nivel"])

func _da_curva(curva: Array) -> int:
	var nivel := int(estado["cavaleiro"]["nivel"])
	var v := int(curva[0][1])
	for par: Array in curva:
		if nivel >= int(par[0]):
			v = int(par[1])
	return v

## Treina um atributo do cavaleiro (ocupa uma vaga do campo de treino, não o
## cavaleiro: ele continua disputando).
func treinar_cavaleiro(atributo: String) -> Dictionary:
	var cfg := Balanceamento.carregar("treino")
	if not cfg["atributos_cavaleiro"].has(atributo):
		return _erro("atributo_invalido")
	if not predio_liberado("campo_treino"):
		return _erro("predio_bloqueado")
	if treinos_em("campo_treino").size() >= vagas_treino("campo_treino"):
		return _erro("sem_vaga")
	if int(estado["cavaleiro"]["atributos"][atributo]) >= int(cfg["teto_atributo"]):
		return _erro("atributo_no_teto")
	return _iniciar_treino("campo_treino", {"tipo": "treino_cavaleiro", "atributo": atributo})

## Treina um atributo de um cavalo (ocupa uma vaga do estábulo; cavalo em
## treino não corre, então o cavalo ativo não pode treinar).
func treinar_cavalo(id: String, atributo: String) -> Dictionary:
	var cfg := Balanceamento.carregar("treino")
	var c := cavalo(id)
	if c.is_empty():
		return _erro("cavalo_inexistente")
	if not cfg["atributos_cavalo"].has(atributo):
		return _erro("atributo_invalido")
	if id == estado["cavalo_ativo"]:
		return _erro("cavalo_ativo_em_uso")
	if cavalo_treinando(id):
		return _erro("cavalo_ja_treinando")
	if treinos_em("estabulo").size() >= vagas_treino("estabulo"):
		return _erro("sem_vaga")
	if int(c["atributos"][atributo]) >= int(cfg["teto_atributo"]):
		return _erro("atributo_no_teto")
	return _iniciar_treino("estabulo", {"tipo": "treino_cavalo", "cavalo": id, "atributo": atributo})

func _iniciar_treino(predio: String, extra: Dictionary) -> Dictionary:
	var custo := custo_treino()
	if ouro() < custo:
		return _erro("ouro_insuficiente")
	estado["inventario"]["ouro"] = ouro() - custo
	var agora := ServicoTempo.agora()
	var t := {"id": _novo_id(estado, "t"), "alvo": predio, "inicio_em": agora, "termina_em": agora + duracao_timer(duracao_treino())}
	t.merge(extra)
	estado["timers"].append(t)
	_evento("treino")
	return _concluir("treino")

## Escolhe o cavalo da justa (não pode estar treinando).
func usar_cavalo(id: String) -> Dictionary:
	if cavalo(id).is_empty():
		return _erro("cavalo_inexistente")
	if cavalo_treinando(id):
		return _erro("cavalo_ja_treinando")
	estado["cavalo_ativo"] = id
	return _concluir("cavalos")

## Novo cavalo no estábulo (recompensa ou compra; na Parte 3 vem do servidor).
func adicionar_cavalo(pelagem: String, atributos: Dictionary) -> Dictionary:
	var f: Dictionary = Balanceamento.carregar("treino")["folego_cavalo"]
	var id := _novo_id(estado, "c")
	estado["cavalos"].append({"id": id, "nome": "", "pelagem": pelagem, "atributos": atributos.duplicate(),
		"folego": int(f["maximo"]), "folego_em": ServicoTempo.agora()})
	var r := _concluir("cavalos")
	r["id"] = id
	return r

## Depois de uma justa: gasta o fôlego do cavalo que correu e passa o
## desgaste das peças (durabilidade final calculada pela regra, em
## resultado.equipamento_final) para o inventário. Recompensas: 2.10.
func registrar_justa(resultado: Dictionary) -> Dictionary:
	var fim: Dictionary = resultado.get("equipamento_final", {})
	for espaco: String in fim:
		var id: String = estado["equipamento"].get(espaco, "")
		for it: Dictionary in estado["inventario"]["itens"]:
			if it["id"] == id and fim[espaco].has("durabilidade"):
				it["durabilidade"] = clampi(int(fim[espaco]["durabilidade"]), 0, int(it["durabilidade"]))
	var f: Dictionary = Balanceamento.carregar("treino")["folego_cavalo"]
	for c: Dictionary in estado["cavalos"]:
		if c["id"] == estado["cavalo_ativo"] and resultado.get("gasta_folego", true):
			c["folego"] = maxi(folego_cavalo(c["id"]) - int(f["gasto_por_justa"]), 0)
			c["folego_em"] = ServicoTempo.agora()
	_evento("justa")
	return _concluir("cavalos")

# ------------------------------------------------------------------ conserto

func item_em_conserto(id: String) -> Dictionary:
	for t: Dictionary in estado["timers"]:
		if t["tipo"] == "conserto" and t.get("item", "") == id:
			return t.duplicate()
	return {}

## Custo do conserto: ouro e material proporcionais ao dano (quebrada custa
## mais) e tempo pelo nível do cavaleiro. {ouro, material, quantidade, segundos, dano}.
func custo_conserto(id: String) -> Dictionary:
	var it := item(id)
	var c: Dictionary = Balanceamento.carregar("desgaste")["conserto"]
	if it.is_empty():
		return {}
	var maximo := int(Balanceamento.carregar("itens")["modelos"][it["modelo"]]["durabilidade_max"])
	var dano := maxi(maximo - int(it["durabilidade"]), 0)
	var ouro_c := dano * int(c["ouro_por_ponto_milesimos"]) / 1000
	var qtd := (dano + int(c["pontos_por_material"]) - 1) / int(c["pontos_por_material"])
	if int(it["durabilidade"]) == 0 and maximo > 0:
		ouro_c = ouro_c * int(c["quebrada_custo_pct"]) / 100
		qtd = qtd * int(c["quebrada_custo_pct"]) / 100
	return {"ouro": ouro_c, "material": c["material"], "quantidade": qtd, "segundos": _da_curva(c["segundos_por_nivel"]), "dano": dano}

func pode_consertar(id: String) -> Dictionary:
	var custo := custo_conserto(id)
	if custo.is_empty():
		return _erro("item_inexistente")
	if int(custo["dano"]) == 0:
		return _erro("item_inteiro")
	if not predio_liberado("armeiro"):
		return _erro("predio_bloqueado")
	if not item_em_conserto(id).is_empty():
		return _erro("ja_em_conserto")
	var v: Dictionary = Balanceamento.carregar("desgaste")["conserto"]["vagas"]
	var vagas := int(v["base"]) + (1 if predio_nivel("armeiro") >= int(v["extra_no_nivel_do_predio"]) else 0)
	if timers_do_predio("armeiro").filter(func(t): return t["tipo"] == "conserto").size() >= vagas:
		return _erro("sem_vaga")
	if ouro() < int(custo["ouro"]):
		return _erro("ouro_insuficiente")
	if int(estado["inventario"]["materiais"].get(custo["material"], 0)) < int(custo["quantidade"]):
		return _erro("material_insuficiente")
	var r := custo.duplicate()
	r["ok"] = true
	r["erro"] = ""
	return r

## Manda a peça para o armeiro: cobra e cria o timer (horário de término).
func consertar(id: String) -> Dictionary:
	var p := pode_consertar(id)
	if not p["ok"]:
		return p
	estado["inventario"]["ouro"] = ouro() - int(p["ouro"])
	var mats: Dictionary = estado["inventario"]["materiais"]
	mats[p["material"]] = int(mats.get(p["material"], 0)) - int(p["quantidade"])
	var agora := ServicoTempo.agora()
	estado["timers"].append({"id": _novo_id(estado, "t"), "tipo": "conserto", "alvo": "armeiro", "item": id,
		"inicio_em": agora, "termina_em": agora + duracao_timer(int(p["segundos"]))})
	return _concluir("inventario")

# ---------------------------------------------------------------- progresso

## Ganha ouro e XP; sobe de nível pela tabela de progressao.json.
## Devolve os níveis ganhos (vazio se nenhum).
func _ganhar(ouro_ganho: int, xp_ganho: int) -> Array[int]:
	estado["inventario"]["ouro"] = ouro() + maxi(ouro_ganho, 0)
	var cav: Dictionary = estado["cavaleiro"]
	cav["xp"] = int(cav["xp"]) + maxi(xp_ganho, 0)
	var tabela: Array = Balanceamento.carregar("progressao")["xp_por_nivel"]
	var novos: Array[int] = []
	while int(cav["nivel"]) < tabela.size() and int(cav["xp"]) >= int(tabela[int(cav["nivel"])]):
		cav["nivel"] = int(cav["nivel"]) + 1
		novos.append(int(cav["nivel"]))
	return novos

## XP que falta para o próximo nível (0 no nível máximo).
func xp_para_proximo() -> int:
	var tabela: Array = Balanceamento.carregar("progressao")["xp_por_nivel"]
	var n := int(estado["cavaleiro"]["nivel"])
	return 0 if n >= tabela.size() else maxi(int(tabela[n]) - int(estado["cavaleiro"]["xp"]), 0)

# --------------------------------------------------------------------- forja
# GDD Forja (3.15). Armeiro: cria peça de um conjunto cujo projeto o jogador
# tem (receita pela raridade, fila de forja com timer, pequena variação de
# status) e melhora de +1 a +10 (até +5 garantido; depois pode falhar, sem
# destruir a peça; teto pelo nível do armeiro). Ferreiro: funde sucata em
# lingote de ferro e ferro em aço (fila do forno). Sorteios pela regra pura
# RegraForja com a semente do save; na Parte 3 viram Edge Function.

func cfg_forja() -> Dictionary:
	return Balanceamento.carregar("economia")["forja"]

func materiais() -> Dictionary:
	return (estado["inventario"]["materiais"] as Dictionary).duplicate()

func material(nome: String) -> int:
	return int(estado["inventario"]["materiais"].get(nome, 0))

## Status que vale na justa: o base (do modelo, ou o sorteado na forja) com
## o bônus do nível de melhoria.
func status_do_item(id: String) -> Dictionary:
	var it := item(id)
	if it.is_empty():
		return {}
	var base: Dictionary = it.get("status", Balanceamento.carregar("itens")["modelos"][it["modelo"]]["status"])
	return RegraForja.status_com_nivel(base, int(it.get("nivel", 0)), int(cfg_forja()["bonus_status_por_nivel_pct"]))

## Peças que um projeto permite forjar (modelos do conjunto, em ordem).
func pecas_do_projeto(conjunto: String) -> Array:
	var modelos: Dictionary = Balanceamento.carregar("itens")["modelos"]
	var r: Array = []
	for m: String in modelos:
		if modelos[m]["conjunto"] == conjunto:
			r.append(m)
	r.sort()
	return r

func projetos() -> Array:
	return (estado["inventario"]["projetos"] as Array).duplicate()

## Receita de um modelo (a da raridade dele): {materiais, ouro, segundos}.
func receita(modelo: String) -> Dictionary:
	var rar: String = Balanceamento.carregar("itens")["modelos"][modelo]["raridade"]
	return (cfg_forja()["receitas"][rar] as Dictionary).duplicate(true)

func vagas_forja() -> int:
	var v: Dictionary = cfg_forja()["vagas_forja"]
	return int(v["base"]) + (1 if predio_nivel("armeiro") >= int(v["extra_no_nivel_do_predio"]) else 0)

func forja_em_andamento() -> Array:
	return estado["timers"].filter(func(t): return t["tipo"] == "forja").map(func(t): return t.duplicate())

func pode_forjar(modelo: String) -> Dictionary:
	var modelos: Dictionary = Balanceamento.carregar("itens")["modelos"]
	if not modelos.has(modelo):
		return _erro("modelo_inexistente")
	if not predio_liberado("armeiro"):
		return _erro("predio_bloqueado")
	if not (estado["inventario"]["projetos"] as Array).has(modelos[modelo]["conjunto"]):
		return _erro("sem_projeto")
	if forja_em_andamento().size() >= vagas_forja():
		return _erro("forja_ocupada")
	var rec := receita(modelo)
	if ouro() < int(rec["ouro"]):
		return _erro("ouro_insuficiente")
	for m: String in rec["materiais"]:
		if material(m) < int(rec["materiais"][m]):
			return _erro("material_insuficiente")
	return {"ok": true, "erro": ""}

## Põe a peça na forja: cobra a receita e cria o timer.
func forjar(modelo: String) -> Dictionary:
	var p := pode_forjar(modelo)
	if not p["ok"]:
		return p
	var rec := receita(modelo)
	estado["inventario"]["ouro"] = ouro() - int(rec["ouro"])
	_gastar_materiais(rec["materiais"])
	_evento("forja")
	var agora := ServicoTempo.agora()
	estado["timers"].append({"id": _novo_id(estado, "t"), "tipo": "forja", "alvo": "armeiro", "modelo": modelo,
		"inicio_em": agora, "termina_em": agora + duracao_timer(int(rec["segundos"]))})
	return _concluir("inventario")

func _entregar_forja(modelo: String) -> Dictionary:
	var m: Dictionary = Balanceamento.carregar("itens")["modelos"][modelo]
	var st := RegraForja.variar_status(m["status"], int(cfg_forja()["variacao_status_pct"]), _semente_servico())
	var id := _novo_id(estado, "i")
	estado["inventario"]["itens"].append({"id": id, "modelo": modelo, "nivel": 0, "durabilidade": int(m["durabilidade_max"]), "status": st})
	_evento("peca_nova")
	return {"item": id, "modelo": modelo, "status": st}

## Teto de melhoria pelo nível do armeiro (0 se fechado).
func teto_melhoria() -> int:
	var m: Dictionary = Balanceamento.carregar("economia")["melhoria"]
	if not predio_liberado("armeiro"):
		return 0
	return mini(int(m["nivel_max"]), maxi(predio_nivel("armeiro"), 1) * int(m["teto_por_nivel_armeiro"]))

## Custo da próxima melhoria: {nivel, fragmentos, ouro, lingotes, chance, teto}.
func custo_melhoria(id: String) -> Dictionary:
	var it := item(id)
	if it.is_empty():
		return {}
	var m: Dictionary = Balanceamento.carregar("economia")["melhoria"]
	var n := int(it.get("nivel", 0))
	if n >= int(m["nivel_max"]):
		return {"nivel": n, "teto": teto_melhoria(), "maximo": true}
	return {"nivel": n, "fragmentos": int(m["custo_fragmentos"][n]), "ouro": int(m["custo_ouro"][n]),
		"lingotes": int(m["custo_lingotes"][n]), "chance": int(m["chance_sucesso_pct"][n]), "teto": teto_melhoria(), "maximo": false}

func pode_melhorar_peca(id: String) -> Dictionary:
	var c := custo_melhoria(id)
	if c.is_empty():
		return _erro("item_inexistente")
	if not predio_liberado("armeiro"):
		return _erro("predio_bloqueado")
	if c["maximo"]:
		return _erro("nivel_maximo")
	if int(c["nivel"]) >= int(c["teto"]):
		return _erro("teto_armeiro")
	if not item_em_conserto(id).is_empty():
		return _erro("peca_em_uso")
	if ouro() < int(c["ouro"]):
		return _erro("ouro_insuficiente")
	if fragmentos() < int(c["fragmentos"]) or material("lingote_ferro") < int(c["lingotes"]):
		return _erro("material_insuficiente")
	var r := c.duplicate()
	r.merge({"ok": true, "erro": ""}, true)
	return r

## Tenta subir a peça um nível: cobra sempre; se falhar, a peça fica como
## estava (nunca é destruída). {ok, sucesso, nivel}.
func melhorar_peca(id: String) -> Dictionary:
	var p := pode_melhorar_peca(id)
	if not p["ok"]:
		return p
	estado["inventario"]["ouro"] = ouro() - int(p["ouro"])
	_gastar_materiais({"fragmentos": int(p["fragmentos"]), "lingote_ferro": int(p["lingotes"])})
	var sucesso := RegraForja.melhoria_deu_certo(int(p["nivel"]), Balanceamento.carregar("economia")["melhoria"], _semente_servico())
	var nivel := int(p["nivel"])
	if sucesso:
		nivel += 1
		for it: Dictionary in estado["inventario"]["itens"]:
			if it["id"] == id:
				it["nivel"] = nivel
		_evento("melhoria_peca")
		if nivel >= int(Balanceamento.carregar("economia")["melhoria"]["nivel_max"]):
			_evento("melhoria_10")
	var r := _concluir("inventario")
	r.merge({"sucesso": sucesso, "nivel": nivel}, true)
	return r

## Fundição no ferreiro: produto "lingote_ferro" (de sucata) ou "lingote_aco"
## (de ferro). {ok, origem, custo, segundos}.
func pode_fundir(produto: String, quantidade: int) -> Dictionary:
	var f := cfg_forja()
	var origem := {"lingote_ferro": "sucata", "lingote_aco": "lingote_ferro"}.get(produto, "") as String
	if origem == "" or quantidade <= 0:
		return _erro("material_insuficiente")
	if not predio_liberado("ferreiro"):
		return _erro("predio_bloqueado")
	if estado["timers"].filter(func(t): return t["tipo"] == "fundicao").size() >= int(f["vagas_fundicao"]):
		return _erro("forno_ocupado")
	var custo := quantidade * int(f["lingote_por_sucata"] if produto == "lingote_ferro" else f["aco_por_ferro"])
	if material(origem) < custo:
		return _erro("material_insuficiente")
	var seg := quantidade * int(f["fundir_segundos_por_lingote"]) * (100 + bonus_companheiros("fundicao_tempo_pct")) / 100
	return {"ok": true, "erro": "", "origem": origem, "custo": custo, "segundos": maxi(seg, 1)}

func fundir(produto: String, quantidade: int) -> Dictionary:
	var p := pode_fundir(produto, quantidade)
	if not p["ok"]:
		return p
	_gastar_materiais({p["origem"]: int(p["custo"])})
	var agora := ServicoTempo.agora()
	estado["timers"].append({"id": _novo_id(estado, "t"), "tipo": "fundicao", "alvo": "ferreiro", "produto": produto,
		"quantidade": quantidade, "inicio_em": agora, "termina_em": agora + duracao_timer(int(p["segundos"]))})
	return _concluir("inventario")

## Quantos lingotes dá para fundir agora com o que tem.
func maximo_fundir(produto: String) -> int:
	var f := cfg_forja()
	if produto == "lingote_ferro":
		return material("sucata") / int(f["lingote_por_sucata"])
	return material("lingote_ferro") / int(f["aco_por_ferro"])

func _gastar_materiais(custo: Dictionary) -> void:
	var mats: Dictionary = estado["inventario"]["materiais"]
	for m: String in custo:
		mats[m] = int(mats.get(m, 0)) - int(custo[m])

## Semente dos sorteios do serviço: a do save mais um contador.
func _semente_servico() -> int:
	var bs: Dictionary = estado["baus"]
	bs["sorteios"] = int(bs["sorteios"]) + 1
	return int(bs["semente"]) + 1000003 * int(bs["sorteios"])

# -------------------------------------------------------------------- metas
# Renome, missões diárias e semanais, login dos 7 primeiros dias, conquistas
# e títulos (3.21; números em metas.json). O dia vira na hora de
# virada_hora_utc; a semana começa na segunda. Missões sorteadas com a
# semente do save + o dia (a mesma para quem joga no mesmo save). Os comandos
# do serviço chamam _evento(); resgates passam por aqui.

static func _metas_novas() -> Dictionary:
	return {"renome": 0, "dia": -1, "diarias": [], "semana": -1, "semanais": [], "login": {"dias": 0, "ultimo_dia": -1},
		"contadores": {}, "sequencia": 0, "conquistas": [], "titulos": [], "titulo": "", "novas": []}

func cfg_metas() -> Dictionary:
	return Balanceamento.carregar("metas")

func dia_atual() -> int:
	return (ServicoTempo.agora() - int(cfg_metas()["virada_hora_utc"]) * 3600) / 86400

## Semana que começa na segunda (o dia 0, 1/1/1970, foi uma quinta).
func semana_atual() -> int:
	return (dia_atual() + 3) / 7

func renome() -> int:
	return int(estado["metas"]["renome"])

## Faixa de renome atual: {nome, minimo, torcida, proxima (mínimo da seguinte, -1 se é a última)}.
func faixa_renome() -> Dictionary:
	var faixas: Array = cfg_metas()["renome"]["faixas"]
	var atual: Dictionary = faixas[0]
	var prox := -1
	for i in faixas.size():
		if renome() >= int(faixas[i]["minimo"]):
			atual = faixas[i]
			prox = int(faixas[i + 1]["minimo"]) if i + 1 < faixas.size() else -1
	var r := atual.duplicate()
	r["proxima"] = prox
	return r

## Sorteia as missões do dia/semana quando viram (sem salvar).
func _atualizar_missoes() -> void:
	var m: Dictionary = estado["metas"]
	var cfg: Dictionary = cfg_metas()["missoes"]
	if int(m["dia"]) != dia_atual():
		m["dia"] = dia_atual()
		m["diarias"] = _sortear_missoes(cfg["diarias"], int(cfg["diarias_por_dia"]), dia_atual())
	if int(m["semana"]) != semana_atual():
		m["semana"] = semana_atual()
		m["semanais"] = _sortear_missoes(cfg["semanais"], int(cfg["semanais_por_semana"]), 100000 + semana_atual())
	_evento_maximo("sequencia", int(m["sequencia"]))

func _sortear_missoes(pool: Array, n: int, salt: int) -> Array:
	var rng := Aleatorio.new(int(estado["baus"]["semente"]) + 7919 * salt)
	var ids: Array = pool.map(func(x): return x["id"])
	var res: Array = []
	while res.size() < mini(n, pool.size()):
		var id: String = ids[rng.inteiro(0, ids.size() - 1)]
		ids.erase(id)
		res.append({"id": id, "progresso": 0, "resgatada": false})
	return res

## Missões do dia e da semana com os dados de cada uma:
## {diarias: [{id, evento, meta, recompensa, progresso, resgatada, pronta}], semanais: [...]}.
func missoes() -> Dictionary:
	_atualizar_missoes()
	var cfg: Dictionary = cfg_metas()["missoes"]
	var r := {}
	for tipo: String in ["diarias", "semanais"]:
		var lista: Array = []
		for mi: Dictionary in estado["metas"][tipo]:
			var d: Dictionary = (cfg[tipo] as Array).filter(func(x): return x["id"] == mi["id"])[0].duplicate(true)
			d.merge(mi, true)
			d["pronta"] = int(mi["progresso"]) >= int(d["meta"]) and not mi["resgatada"]
			lista.append(d)
		r[tipo] = lista
	return r

func resgatar_missao(id: String) -> Dictionary:
	_atualizar_missoes()
	for tipo: String in ["diarias", "semanais"]:
		for mi: Dictionary in estado["metas"][tipo]:
			if mi["id"] != id:
				continue
			var d: Dictionary = (cfg_metas()["missoes"][tipo] as Array).filter(func(x): return x["id"] == id)[0]
			if mi["resgatada"]:
				return _erro("ja_resgatada")
			if int(mi["progresso"]) < int(d["meta"]):
				return _erro("missao_incompleta")
			mi["resgatada"] = true
			var g := _dar_recompensa(d["recompensa"])
			var res := _concluir("metas")
			res["recompensa"] = g
			return res
	return _erro("missao_inexistente")

## Login dos 7 primeiros dias: {dia (1 a 7; 0 = acabou), pode, recompensa}.
func login_hoje() -> Dictionary:
	var l: Dictionary = estado["metas"]["login"]
	var tabela: Array = cfg_metas()["login"]
	var feitos := int(l["dias"])
	if feitos >= tabela.size():
		return {"dia": 0, "pode": false, "recompensa": {}}
	return {"dia": feitos + 1, "pode": int(l["ultimo_dia"]) != dia_atual(), "recompensa": (tabela[feitos] as Dictionary).duplicate()}

func resgatar_login() -> Dictionary:
	var h := login_hoje()
	if not h["pode"]:
		return _erro("login_ja_resgatado")
	var l: Dictionary = estado["metas"]["login"]
	l["dias"] = int(l["dias"]) + 1
	l["ultimo_dia"] = dia_atual()
	var g := _dar_recompensa(h["recompensa"])
	var res := _concluir("metas")
	res.merge({"dia": h["dia"], "recompensa": g}, true)
	return res

## Conquistas com o progresso: [{id, evento, meta, recompensa, titulo?, progresso, feita}].
func conquistas() -> Array:
	var r: Array = []
	var cont: Dictionary = estado["metas"]["contadores"]
	for c: Dictionary in cfg_metas()["conquistas"]:
		var d := c.duplicate(true)
		d["progresso"] = mini(int(cont.get(c["evento"], 0)), int(c["meta"]))
		d["feita"] = (estado["metas"]["conquistas"] as Array).has(c["id"])
		r.append(d)
	return r

## Conquistas feitas desde a última leitura (para o letreiro da vila).
func conquistas_novas() -> Array:
	var n: Array = (estado["metas"]["novas"] as Array).duplicate()
	estado["metas"]["novas"] = []
	return n

func titulos() -> Array:
	return (estado["metas"]["titulos"] as Array).duplicate()

func titulo() -> String:
	return str(estado["metas"]["titulo"])

func definir_titulo(id: String) -> Dictionary:
	if id != "" and not titulos().has(id):
		return _erro("titulo_bloqueado")
	estado["metas"]["titulo"] = id
	return _concluir("metas")

## Conta um evento: missões do dia/semana, contador das conquistas (sem salvar;
## quem chama salva).
func _evento(nome: String, qtd := 1) -> void:
	if not estado.has("metas"):
		return
	_atualizar_missoes()
	var m: Dictionary = estado["metas"]
	var cfg: Dictionary = cfg_metas()["missoes"]
	for tipo: String in ["diarias", "semanais"]:
		for mi: Dictionary in m[tipo]:
			var d: Array = (cfg[tipo] as Array).filter(func(x): return x["id"] == mi["id"])
			if not d.is_empty() and d[0]["evento"] == nome:
				mi["progresso"] = mini(int(mi["progresso"]) + qtd, int(d[0]["meta"]))
	var cont: Dictionary = m["contadores"]
	cont[nome] = int(cont.get(nome, 0)) + qtd
	_checar_conquistas()

## Contador que guarda o maior valor (ex.: melhor sequência de vitórias).
func _evento_maximo(nome: String, valor: int) -> void:
	var cont: Dictionary = estado["metas"]["contadores"]
	if valor > int(cont.get(nome, 0)):
		cont[nome] = valor
		_checar_conquistas()

func _checar_conquistas() -> void:
	var m: Dictionary = estado["metas"]
	var cont: Dictionary = m["contadores"]
	for c: Dictionary in cfg_metas()["conquistas"]:
		if (m["conquistas"] as Array).has(c["id"]) or int(cont.get(c["evento"], 0)) < int(c["meta"]):
			continue
		m["conquistas"].append(c["id"])
		m["novas"].append(c["id"])
		if c.has("titulo") and not (m["titulos"] as Array).has(c["titulo"]):
			m["titulos"].append(c["titulo"])
		_dar_recompensa(c.get("recompensa", {}))

## Entrega uma recompensa {ouro, fragmentos, chaves, bau, xp}; devolve o que deu.
func _dar_recompensa(r: Dictionary) -> Dictionary:
	var dado := r.duplicate()
	if r.has("fragmentos"):
		estado["inventario"]["materiais"]["fragmentos"] = fragmentos() + int(r["fragmentos"])
	if r.has("chaves"):
		estado["baus"]["chaves"] = chaves() + int(r["chaves"])
	if r.has("bau"):
		dado["bau_ganho"] = _guardar_bau(str(r["bau"]))
	_ganhar(int(r.get("ouro", 0)), int(r.get("xp", 0)))
	return dado

# ------------------------------------------------------------- configurações
# Preferências do jogador (3.23): notificações por tipo (game/data/
# notificacoes.json) e a chave "todas". Sem registro = ligada.

func notificacao_ligada(tipo: String) -> bool:
	var n: Dictionary = estado.get("config", {}).get("notificacoes", {})
	if not n.get("todas", true):
		return false
	return tipo == "" or bool(n.get(tipo, true))

## Opções de acessibilidade (3.24): canhoto, vibracao, texto, idioma
## (padrões em game/data/ui/acessibilidade.json).
func config_valor(chave: String) -> Variant:
	var padrao: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/ui/acessibilidade.json"))["padrao"]
	return estado.get("config", {}).get(chave, padrao.get(chave))

func definir_config(chave: String, valor: Variant) -> Dictionary:
	var a: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/ui/acessibilidade.json"))
	if not a["padrao"].has(chave):
		return _erro("opcao_inexistente")
	if chave == "texto" and not a["tamanhos_texto"].has(str(valor)):
		return _erro("opcao_invalida")
	if chave == "idioma" and not (a["idiomas"] as Array).has(str(valor)):
		return _erro("opcao_invalida")
	if not estado.has("config"):
		estado["config"] = {"notificacoes": {}}
	estado["config"][chave] = valor
	return _concluir("config")

func definir_notificacao(tipo: String, ligada: bool) -> Dictionary:
	if not estado.has("config"):
		estado["config"] = {"notificacoes": {}}
	estado["config"]["notificacoes"][tipo] = ligada
	return _concluir("config")

# ----------------------------------------------------------------- história
# Cenas curtas entre regiões e companheiros (3.22; enredo provisório em
# game/data/historia/historia.json). Uma cena fica pendente quando a
# condição (contadores das metas) foi atingida e ela ainda não foi vista; a
# vila toca as pendentes na ordem. Companheiro entra com a cena dele e dá um
# bônus (renome, forno do ferreiro, fôlego do cavalo).

func cfg_historia() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://game/data/historia/historia.json"))

## A próxima cena a tocar ("" se nenhuma).
func proxima_cena() -> String:
	var h := cfg_historia()
	var vistas: Array = estado["historia"]["vistas"]
	var cont: Dictionary = estado["metas"]["contadores"]
	for id: String in h["ordem"]:
		if vistas.has(id):
			continue
		var ok := true
		var quando: Dictionary = h["cenas"][id]["quando"]
		for ev: String in quando:
			ok = ok and int(cont.get(ev, 0)) >= int(quando[ev])
		if ok:
			return id
	return ""

func marcar_cena_vista(id: String) -> Dictionary:
	if not cfg_historia()["cenas"].has(id):
		return _erro("cena_inexistente")
	if not (estado["historia"]["vistas"] as Array).has(id):
		estado["historia"]["vistas"].append(id)
	return _concluir("historia")

## Companheiros que já entraram (viram a cena deles).
func companheiros() -> Array:
	var h := cfg_historia()
	var r: Array = []
	for c: String in h["companheiros"]:
		if (estado["historia"]["vistas"] as Array).has(h["companheiros"][c]["entra_na_cena"]):
			r.append(c)
	return r

## Soma do bônus `tipo` dos companheiros presentes (em %).
func bonus_companheiros(tipo: String) -> int:
	if not estado.has("historia"):
		return 0
	var h := cfg_historia()
	var t := 0
	for c: String in companheiros():
		t += int(h["companheiros"][c]["bonus"].get(tipo, 0))
	return t

# --------------------------------------------------------------------- baús
# GDD Baús e itens: 4 espaços, um abrindo por vez, chave abre na hora,
# vitória com os espaços cheios dá só ouro, peça repetida vira fragmentos.
# O sorteio é a regra pura RegraBau com semente do save + contador; na
# Parte 3, abrir vira chamada à Edge Function (o servidor sorteia e grava) e
# aqui só entra o resultado.

static func _baus_novos(criado_em: int, chaves_iniciais: int) -> Dictionary:
	return {"espacos": [], "garantia": 0, "chaves": chaves_iniciais, "abertos": 0, "sorteios": 0,
		"semente": hash(str(criado_em)) & 0x7FFFFFFF}

func cfg_baus() -> Dictionary:
	return Balanceamento.carregar("economia")["baus"]

## Espaços de baú: [{id, tipo, abre_em (0 = fechado; senão o horário em que fica pronto)}].
func baus() -> Array:
	return (estado["baus"]["espacos"] as Array).duplicate(true)

func chaves() -> int:
	return int(estado["baus"]["chaves"])

func fragmentos() -> int:
	return int(estado["inventario"]["materiais"].get("fragmentos", 0))

## O baú que está abrindo ({} se nenhum).
func bau_abrindo() -> Dictionary:
	for b: Dictionary in estado["baus"]["espacos"]:
		if int(b["abre_em"]) > 0:
			return b.duplicate()
	return {}

func bau_pronto(id: String) -> bool:
	var b := _bau(id)
	return not b.is_empty() and int(b["abre_em"]) > 0 and ServicoTempo.pronto(int(b["abre_em"]))

## Ganha um baú. Com os espaços cheios, ganha só o ouro mínimo dele.
## {ok, id ("" se cheio), tipo, cheio, ouro}.
func ganhar_bau(tipo: String) -> Dictionary:
	if not cfg_baus()["tipos"].has(tipo):
		return _erro("bau_inexistente")
	var g := _guardar_bau(tipo)
	var r := _concluir("baus")
	r.merge(g, true)
	return r

func _guardar_bau(tipo: String) -> Dictionary:
	var cfg := cfg_baus()
	var esp: Array = estado["baus"]["espacos"]
	if esp.size() >= int(cfg["espacos"]):
		var consolo := int(cfg["tipos"][tipo]["ouro"][0])
		_ganhar(consolo, 0)
		return {"id": "", "tipo": tipo, "cheio": true, "ouro": consolo}
	var id := _novo_id(estado, "b")
	esp.append({"id": id, "tipo": tipo, "abre_em": 0})
	return {"id": id, "tipo": tipo, "cheio": false, "ouro": 0}

func _bau(id: String) -> Dictionary:
	for b: Dictionary in estado["baus"]["espacos"]:
		if b["id"] == id:
			return b
	return {}

## Começa a abrir um baú (um por vez); o tempo vem de economia.json.
func comecar_abrir(id: String) -> Dictionary:
	var b := _bau(id)
	if b.is_empty():
		return _erro("bau_inexistente")
	if int(b["abre_em"]) > 0:
		return _erro("bau_ja_abrindo")
	if not bau_abrindo().is_empty():
		return _erro("outro_bau_abrindo")
	b["abre_em"] = ServicoTempo.agora() + maxi(duracao_timer(int(cfg_baus()["tipos"][b["tipo"]]["segundos"])), 1)
	return _concluir("baus")

## Abre um baú pronto, ou na hora gastando uma chave (`com_chave`). Entrega
## ouro, fragmentos e peças (repetidas viram fragmentos).
## {ok, tipo, ouro, fragmentos, itens: [{modelo, raridade, repetida, id}]}.
func abrir_bau(id: String, com_chave := false) -> Dictionary:
	var b := _bau(id)
	if b.is_empty():
		return _erro("bau_inexistente")
	if com_chave:
		if chaves() <= 0:
			return _erro("sem_chave")
	elif not bau_pronto(id):
		return _erro("bau_fechado")
	var cfg := cfg_baus()
	var modelos: Dictionary = Balanceamento.carregar("itens")["modelos"]
	var possui: Array = []
	for it: Dictionary in estado["inventario"]["itens"]:
		possui.append(it["modelo"])
	var bs: Dictionary = estado["baus"]
	var r := RegraBau.abrir(b["tipo"], cfg, modelos, possui, int(bs["garantia"]), int(bs["semente"]) + int(bs["abertos"]))
	if com_chave:
		bs["chaves"] = chaves() - 1
	bs["garantia"] = int(r["garantia"])
	bs["abertos"] = int(bs["abertos"]) + 1
	(bs["espacos"] as Array).erase(b)
	estado["inventario"]["materiais"]["fragmentos"] = fragmentos() + int(r["fragmentos"])
	for it: Dictionary in r["itens"]:
		it["id"] = ""
		if not it["repetida"]:
			it["id"] = _novo_id(estado, "i")
			estado["inventario"]["itens"].append({"id": it["id"], "modelo": it["modelo"], "nivel": 0,
				"durabilidade": int(modelos[it["modelo"]]["durabilidade_max"])})
			_evento("peca_nova")
	_evento("bau_aberto")
	_ganhar(int(r["ouro"]), 0)
	var res := _concluir("baus")
	res.merge({"tipo": b["tipo"], "ouro": r["ouro"], "fragmentos": r["fragmentos"], "itens": r["itens"]}, true)
	return res

## Sorteio do serviço (baú de madeira por vitória): semente do save + contador.
func _sorteio_milesimos(chance: int) -> bool:
	return Aleatorio.new(_semente_servico()).chance_milesimos(chance)

# ---------------------------------------------------------------------- PvE

func pve() -> Dictionary:
	return Balanceamento.carregar("pve")

## Progresso de um torneio: {proxima (índice da próxima disputa), concluido,
## estrelas: {índice (texto): melhor}}.
func progresso_torneio(id: String) -> Dictionary:
	var t: Dictionary = estado["pve"]["torneios"].get(id, {})
	return {"proxima": int(t.get("proxima", 0)), "concluido": t.get("concluido", false),
		"estrelas": (t.get("estrelas", {}) as Dictionary).duplicate(), "falhou": t.get("falhou", false)}

## Região de um torneio ("" se não existe).
func regiao_do_torneio(id: String) -> String:
	var dados := pve()
	for r: String in dados["ordem_regioes"]:
		if (dados["regioes"][r]["torneios"] as Array).has(id):
			return r
	return ""

## Regiões abertas, na ordem do circuito: da primeira até a atual (a última
## liberada; vencer o último torneio obrigatório de uma região abre a seguinte).
func regioes_liberadas() -> Array:
	var ordem: Array = pve()["ordem_regioes"]
	return ordem.slice(0, ordem.find(estado["pve"]["regiao"]) + 1)

func regiao_liberada(regiao: String) -> bool:
	return regioes_liberadas().has(regiao)

## Desafios especiais do torneio (ids de pve.json > desafios).
func desafios_do_torneio(id: String) -> Array:
	return (pve()["torneios"].get(id, {}).get("desafios", []) as Array).duplicate()

## Último torneio obrigatório da região: vencê-lo fecha a região.
func torneio_final_da_regiao(regiao: String) -> String:
	var dados := pve()
	var lista: Array = dados["regioes"][regiao]["torneios"]
	for i in range(lista.size() - 1, -1, -1):
		if not dados["torneios"][lista[i]].get("opcional", false):
			return lista[i]
	return ""

## Liberado: região aberta, nível mínimo e todos os torneios obrigatórios
## antes dele (na ordem da região) concluídos. Os opcionais (desafios) não
## bloqueiam os seguintes.
func torneio_liberado(id: String) -> bool:
	var dados := pve()
	var t: Dictionary = dados["torneios"].get(id, {})
	var regiao := regiao_do_torneio(id)
	if t.is_empty() or regiao == "" or not regiao_liberada(regiao) or int(estado["cavaleiro"]["nivel"]) < int(t["nivel_minimo"]):
		return false
	if renome() < int(t.get("renome_minimo", 0)):
		return false  # convite: só com renome (3.21)
	for anterior: String in dados["regioes"][regiao]["torneios"]:
		if anterior == id:
			return true
		if not dados["torneios"][anterior].get("opcional", false) and not progresso_torneio(anterior)["concluido"]:
			return false
	return true

## Pode jogar a disputa `indice` do torneio (a próxima, ou uma já vencida).
func pode_disputar(torneio: String, indice: int) -> Dictionary:
	if not torneio_liberado(torneio):
		return _erro("torneio_bloqueado")
	var rivais: Array = pve()["torneios"][torneio]["rivais"]
	if indice < 0 or indice >= rivais.size():
		return _erro("disputa_inexistente")
	var prog := progresso_torneio(torneio)
	if indice > prog["proxima"]:
		return _erro("disputa_bloqueada")
	# Uma chance só: perdeu, acabou; e nada de repetir disputa já vencida.
	if _uma_chance(torneio) and (prog["falhou"] or prog["concluido"] or indice < prog["proxima"]):
		return _erro("chance_perdida")
	return {"ok": true, "erro": ""}

func _uma_chance(torneio: String) -> bool:
	var defs: Dictionary = pve().get("desafios", {})
	for d: String in desafios_do_torneio(torneio):
		if int(defs.get(d, {}).get("tentativas", 0)) == 1:
			return true
	return false

## Automático: só disputa já vencida com 3 estrelas e que não seja de campeão.
func pode_automatico(torneio: String, indice: int) -> Dictionary:
	var p := pode_disputar(torneio, indice)
	if not p["ok"]:
		return p
	var dados := pve()
	var rival: String = dados["torneios"][torneio]["rivais"][indice]
	if dados["rivais"][rival].get("campeao", false):
		return _erro("campeao_manual")
	if int(progresso_torneio(torneio)["estrelas"].get(str(indice), 0)) < 3:
		return _erro("precisa_tres_estrelas")
	return {"ok": true, "erro": ""}

## Tudo que a justa precisa do rival: {lado, perfil, casa, brasao, nome_chave}.
## O nêmesis cresce a cada encontro (atributos + cresce_por_encontro).
## Na `regiao`, o rival usa os dados de por_regiao (o nêmesis volta mais
## forte em cada região); o crescimento por encontro para em cresce_max.
## Campeões trazem perfil_ajuste (estilo de mira) e provocação.
func rival_para_justa(rival_id: String, regiao := "") -> Dictionary:
	return _rival_de(pve()["rivais"][rival_id], rival_id, regiao)

func _rival_de(r: Dictionary, rival_id: String, regiao := "") -> Dictionary:
	if regiao != "" and r.get("por_regiao", {}).has(regiao):
		r = r.duplicate()
		r.merge(r["por_regiao"][regiao], true)
	var modelos: Dictionary = Balanceamento.carregar("itens")["modelos"]
	var bonus := int(r.get("cresce_por_encontro", 0)) * int(estado["pve"].get("encontros", {}).get(rival_id, 0))
	if r.has("cresce_max"):
		bonus = mini(bonus, int(r["cresce_max"]))
	var cav := {}
	for k: String in r["cavaleiro"]:
		cav[k] = mini(int(r["cavaleiro"][k]) + bonus, 100)
	var equip := {}
	for m: String in r["equipamento"]:
		var st: Dictionary = (modelos[m]["status"] as Dictionary).duplicate()
		st["durabilidade"] = int(modelos[m]["durabilidade_max"])
		equip[modelos[m]["espaco"]] = st
	var lado := {"cavaleiro": cav, "cavalo": (r["cavalo"] as Dictionary).duplicate(), "equipamento": equip,
		"habilidade": r.get("habilidade", "")}
	var perfil := RegraPve.ajustar_perfil(Balanceamento.carregar("ia_rival")["perfis"][r["perfil"]], r.get("perfil_ajuste", {}))
	return {"id": rival_id, "lado": lado, "perfil_nome": r["perfil"], "perfil": perfil, "provocacao": r.get("provocacao", ""),
		"casa": {"principal": r["casa"][0], "secundaria": r["casa"][1]},
		"brasao": GeradorBrasao.opcoes().get("rivais", {}).get(r.get("brasao", ""), {}),
		"nome_chave": "RIVAL_" + rival_id.to_upper(), "nemesis": r.get("nemesis", false), "campeao": r.get("campeao", false)}

## Tudo para jogar uma disputa (manual ou automática), com os desafios do
## torneio já aplicados pela regra: {cfg, lado_jogador, rival (como
## rival_para_justa, com lado e perfil ajustados), desafios, visuais
## (ex.: "chuva", "noite"), gasta_folego (cavalo emprestado não cansa o seu)}.
func preparar_disputa(torneio: String, indice: int) -> Dictionary:
	var dados := pve()
	var rv := rival_para_justa(dados["torneios"][torneio]["rivais"][indice], regiao_do_torneio(torneio))
	var ids := desafios_do_torneio(torneio)
	var defs: Dictionary = dados.get("desafios", {})
	var a := RegraPve.aplicar_desafios(Justa.carregar_configuracao(), lado_para_justa(), rv["lado"], rv["perfil"], ids, defs)
	rv["lado"] = a["lado_rival"]
	rv["perfil"] = a["perfil_rival"]
	var visuais := []
	var gasta := true
	for id: String in ids:
		if defs[id].has("visual"):
			visuais.append(defs[id]["visual"])
		if not defs[id].get("gasta_folego", true):
			gasta = false
	return {"cfg": a["cfg"], "lado_jogador": a["lado_jogador"], "rival": rv, "desafios": ids, "visuais": visuais, "gasta_folego": gasta}

## Fim de uma disputa (manual ou automática), a partir dos eventos da justa:
## estrelas, avanço na chave, recompensa da disputa e, na primeira vez que o
## torneio fecha, a do torneio; XP e nível. {ok, estrelas, ouro, xp, niveis,
## torneio_concluido, venceu, projeto (conjunto ganho ao fechar a região),
## regiao_nova (região que abriu)}. Perder um desafio de uma chance só marca
## o torneio como falhou.
func concluir_disputa(torneio: String, indice: int, eventos: Array, automatico := false) -> Dictionary:
	var p := pode_disputar(torneio, indice)
	if not p["ok"]:
		return p
	var dados := pve()
	var t: Dictionary = dados["torneios"][torneio]
	var rival: String = t["rivais"][indice]
	var est := RegraPve.estrelas(eventos)
	var reg: Dictionary = estado["pve"]["torneios"].get(torneio, {"proxima": 0, "concluido": false, "estrelas": {}})
	estado["pve"]["torneios"][torneio] = reg
	var enc: Dictionary = estado["pve"].get("encontros", {})
	enc[rival] = int(enc.get(rival, 0)) + 1
	estado["pve"]["encontros"] = enc
	var ouro_g := 0
	var xp_g := 0
	var fechou := false
	var regiao := regiao_do_torneio(torneio)
	var pct := int(dados["regioes"][regiao].get("recompensa_pct", 100))
	var projeto := ""
	var regiao_nova := ""
	if est == 0 and _uma_chance(torneio):
		reg["falhou"] = true
	var baus_ganhos: Array = []
	var estrelas_antes := int(reg["estrelas"].get(str(indice), 0))
	if est > 0:
		var r: Dictionary = dados["recompensa_disputa"]
		ouro_g = (int(r["ouro_base"]) + est * int(r["ouro_por_estrela"])) * pct / 100
		xp_g = (int(r["xp_base"]) + est * int(r["xp_por_estrela"])) * pct / 100
		if automatico:
			ouro_g = ouro_g * int(dados["recompensa_automatico_pct"]) / 100
			xp_g = xp_g * int(dados["recompensa_automatico_pct"]) / 100
		reg["estrelas"][str(indice)] = maxi(int(reg["estrelas"].get(str(indice), 0)), est)
		if indice == int(reg["proxima"]):
			reg["proxima"] = indice + 1
			if int(reg["proxima"]) >= (t["rivais"] as Array).size() and not reg["concluido"]:
				reg["concluido"] = true
				fechou = true
				ouro_g += int(t["recompensa"]["ouro"])
				xp_g += int(t["recompensa"]["xp"])
				if torneio == torneio_final_da_regiao(regiao):
					projeto = str(dados["regioes"][regiao].get("recompensa_regiao", {}).get("projeto", ""))
					var projetos: Array = estado["inventario"]["projetos"]
					if projeto != "" and not projetos.has(projeto):
						projetos.append(projeto)
					var ordem: Array = dados["ordem_regioes"]
					var i := ordem.find(regiao)
					if i + 1 < ordem.size() and estado["pve"]["regiao"] == regiao:
						regiao_nova = ordem[i + 1]
						estado["pve"]["regiao"] = regiao_nova
	# Baús (GDD): ferro na primeira vez que a disputa chega a 3 estrelas
	# (repetir no automático não fabrica ferro), senão chance de madeira;
	# ouro ao vencer um campeão.
	if est > 0:
		var cb := cfg_baus()
		if est >= 3 and estrelas_antes < 3 and cb["ferro_por_tres_estrelas"]:
			baus_ganhos.append(_guardar_bau("ferro"))
		elif _sorteio_milesimos(int(round(float(cb["chance_madeira_por_vitoria"]) * 1000.0))):
			baus_ganhos.append(_guardar_bau("madeira"))
		if dados["rivais"][rival].get("campeao", false) and cb["ouro_por_campeao"] and estrelas_antes == 0:
			baus_ganhos.append(_guardar_bau("ouro"))
	# Materiais (3.15): por vitória (no automático, a mesma porcentagem do
	# ouro) e os da região ao fechá-la.
	var mats_g := {}
	if est > 0:
		var mv: Dictionary = dados["regioes"][regiao].get("materiais_vitoria", {})
		for m: String in mv:
			var q := int(mv[m]) * (int(dados["recompensa_automatico_pct"]) if automatico else 100) / 100
			if q > 0:
				mats_g[m] = q
	if projeto != "":
		var mr: Dictionary = dados["regioes"][regiao].get("recompensa_regiao", {}).get("materiais", {})
		for m: String in mr:
			mats_g[m] = int(mats_g.get(m, 0)) + int(mr[m])
	var inv_mats: Dictionary = estado["inventario"]["materiais"]
	for m: String in mats_g:
		inv_mats[m] = int(inv_mats.get(m, 0)) + int(mats_g[m])
	# Metas (3.21): eventos para missões e conquistas, renome e sequência.
	var metas: Dictionary = estado["metas"]
	var renome_g := 0
	var ganho: Dictionary = Balanceamento.carregar("metas")["renome"]["ganho"]
	if est > 0:
		_evento("vitoria")
		renome_g += int(ganho["vitoria"])
		metas["sequencia"] = int(metas["sequencia"]) + 1
		_evento_maximo("sequencia", int(metas["sequencia"]))
		if est >= 3:
			_evento("tres_estrelas")
			renome_g += int(ganho["tres_estrelas"])
		for e: Dictionary in eventos:
			if e.get("tipo", "") == "fim" and e.get("motivo", "") == "derrubada":
				_evento("derrubada")
				renome_g += int(ganho["derrubada"])
		if dados["rivais"][rival].get("campeao", false) and estrelas_antes == 0:
			renome_g += int(ganho["campeao"])
	else:
		metas["sequencia"] = 0
	if fechou:
		_evento("torneio_vencido")
	if projeto != "":
		_evento("regiao_vencida")
		renome_g += int(ganho["regiao_vencida"])
	renome_g = renome_g * (100 + bonus_companheiros("renome_pct")) / 100
	metas["renome"] = int(metas["renome"]) + renome_g
	var niveis := _ganhar(ouro_g, xp_g)
	var res := _concluir("pve")
	res.merge({"estrelas": est, "ouro": ouro_g, "xp": xp_g, "niveis": niveis, "torneio_concluido": fechou, "venceu": est > 0,
		"projeto": projeto, "regiao_nova": regiao_nova, "baus": baus_ganhos, "materiais": mats_g, "renome": renome_g}, true)
	return res

## Disputa no automático: a mesma regra, com uma IA de precisão média no
## lugar do jogador. Gasta fôlego e equipamento como a manual.
func disputa_automatica(torneio: String, indice: int, semente: int) -> Dictionary:
	var p := pode_automatico(torneio, indice)
	if not p["ok"]:
		return p
	var dados := pve()
	var prep := preparar_disputa(torneio, indice)
	var perfil_auto: Dictionary = Balanceamento.carregar("ia_rival")["perfis"][dados["perfil_automatico"]]
	var sim := RegraPve.simular(prep["cfg"], prep["lado_jogador"], prep["rival"]["lado"], semente, prep["rival"]["perfil"], perfil_auto)
	registrar_justa({"equipamento_final": sim["equipamento_final"], "gasta_folego": prep["gasta_folego"]})
	var r := concluir_disputa(torneio, indice, sim["eventos"], true)
	r["eventos"] = sim["eventos"]
	return r

## Duração real de um timer. No primeiro dia (GDD: regra do tutorial) todo
## timer termina em segundos; aqui é o ponto único onde isso entra.
func duracao_timer(segundos: int) -> int:
	var pd: Dictionary = Balanceamento.carregar("inicio")["primeiro_dia"]
	if ServicoTempo.agora() - int(estado.get("criado_em", 0)) < int(pd["duracao_s"]):
		return mini(segundos, int(pd["timer_max_s"]))
	return segundos

# ------------------------------------------------------------------ tutorial
# Passos (GDD Início do jogo): 0 título, 1 criação, 2 brasão, 3 justa de
# exibição, 4 primeira justa, 5 primeiro baú, 6 concluído (vila).

const TUTORIAL_CONCLUIDO := 6

func tutorial_passo() -> int:
	return int(estado["tutorial"]["passo"])

func tutorial_concluido() -> bool:
	return estado["tutorial"].get("concluido", false)

func definir_passo_tutorial(passo: int) -> Dictionary:
	estado["tutorial"]["passo"] = clampi(passo, 0, TUTORIAL_CONCLUIDO)
	if passo >= TUTORIAL_CONCLUIDO:
		estado["tutorial"]["concluido"] = true
	return _concluir("tutorial")

## Recompensa do tutorial (uma vez só): ouro, XP até o nível 2 e a peça do
## primeiro baú, já equipada. Quem pula o tutorial também recebe.
## Devolve {ok, item (id), modelo, niveis}.
func recompensa_tutorial() -> Dictionary:
	var t: Dictionary = estado["tutorial"]
	if t.get("recompensa_dada", false):
		return {"ok": true, "erro": "", "item": t.get("item_bau", ""), "modelo": "", "niveis": []}
	var cfg: Dictionary = Balanceamento.carregar("inicio")["tutorial"]
	var modelo: String = cfg["item_bau"]
	var maximo := int(Balanceamento.carregar("itens")["modelos"][modelo]["durabilidade_max"])
	var id := _novo_id(estado, "i")
	estado["inventario"]["itens"].append({"id": id, "modelo": modelo, "nivel": 0, "durabilidade": maximo})
	estado["equipamento"][Balanceamento.carregar("itens")["modelos"][modelo]["espaco"]] = id
	var niveis := _ganhar(int(cfg["ouro"]), int(cfg["xp"]))
	t["recompensa_dada"] = true
	t["item_bau"] = id
	var r := _concluir("inventario")
	r.merge({"item": id, "modelo": modelo, "niveis": niveis}, true)
	return r

## Rival fraco da primeira justa (dados do tutorial).
func rival_tutorial() -> Dictionary:
	return _rival_de(Balanceamento.carregar("inicio")["tutorial"]["rival_primeira_justa"], "tutorial")

func _garantir_predio(nome: String) -> void:
	if not estado["vila"]["predios"].has(nome):
		estado["vila"]["predios"][nome] = {"nivel": 1}

# ------------------------------------------------------------ persistência

func novo_estado() -> Dictionary:
	var ini := Balanceamento.carregar("inicio")
	var e := {
		"versao": VERSAO,
		"criado_em": ServicoTempo.agora(),
		"proximo_id": 1,
		"cavaleiro": {"nome": "", "corpo": "masculino", "rosto": "1", "cabelo": "1", "pele": "media",
			"cor_cabelo": "castanho", "nivel": int(ini["cavaleiro"]["nivel"]), "xp": int(ini["cavaleiro"]["xp"]),
			"atributos": ini["cavaleiro"]["atributos"].duplicate(), "habilidades": [ini["cavaleiro"]["habilidade"]]},
		"casa": {"nome": "", "cores": {"principal": "azul_real", "secundaria": "ouro_velho", "metal": "ferro"}, "brasao": {}},
		"cavalos": [],
		"cavalo_ativo": "",
		"inventario": {"ouro": int(ini["ouro"]), "gemas": int(ini["gemas"]), "materiais": ini["materiais"].duplicate(), "itens": [], "projetos": []},
		"equipamento": {},
		"visual": {},
		"vila": {"predios": {}},
		"timers": [],
		"pve": {"regiao": "feiras", "torneios": {}},
		"tutorial": {"passo": 0, "concluido": false},
	}
	e["inventario"]["materiais"]["fragmentos"] = int(e["inventario"]["materiais"].get("fragmentos", 0))
	e["baus"] = _baus_novos(int(e["criado_em"]), int(ini.get("chaves", 0)))
	e["metas"] = _metas_novas()
	e["historia"] = {"vistas": []}
	e["config"] = {"notificacoes": {}}
	var cid := _novo_id(e, "c")
	e["cavalos"].append({"id": cid, "nome": "", "pelagem": "alazao", "atributos": ini["cavalo"]["atributos"].duplicate(),
		"folego": int(Balanceamento.carregar("treino")["folego_cavalo"]["maximo"]), "folego_em": e["criado_em"]})
	e["cavalo_ativo"] = cid
	var modelos: Dictionary = Balanceamento.carregar("itens")["modelos"]
	var por_modelo := {}
	for m: String in ini["itens"]:
		var id := _novo_id(e, "i")
		e["inventario"]["itens"].append({"id": id, "modelo": m, "nivel": 0, "durabilidade": int(modelos[m]["durabilidade_max"])})
		por_modelo[m] = id
	for m: String in ini["equipar"]:
		e["equipamento"][modelos[m]["espaco"]] = por_modelo[m]
	for p: String in ini["predios"]:
		e["vila"]["predios"][p] = {"nivel": int(ini["predios"][p])}
	return e

## Grava em arquivo temporário, guarda o anterior como .bak e troca.
func salvar() -> Error:
	var tmp := caminho_save + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(estado, "\t"))
	f.close()
	if FileAccess.file_exists(caminho_save):
		DirAccess.copy_absolute(caminho_save, caminho_save + ".bak")
		DirAccess.remove_absolute(caminho_save)
	return DirAccess.rename_absolute(tmp, caminho_save)

## Lê o save (ou o .bak, se o principal estiver estragado) e migra.
func carregar() -> bool:
	for caminho in [caminho_save, caminho_save + ".bak"]:
		if not FileAccess.file_exists(caminho):
			continue
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
		if v is Dictionary and v.has("versao"):
			estado = migrar(_inteiros(v))
			return true
		push_warning("ServicoJogador: save ilegível em %s" % caminho)
	return false

## Migra saves antigos até VERSAO. Cada versão nova acrescenta um passo aqui.
static func migrar(d: Dictionary) -> Dictionary:
	var v := int(d.get("versao", 0))
	if v > VERSAO:
		push_warning("ServicoJogador: save de versão mais nova (%d)" % v)
	if v < 2:
		# 3.13: projetos ganhos dos campeões de região (forja, 3.15).
		var inv: Dictionary = d.get("inventario", {})
		if not inv.has("projetos"):
			inv["projetos"] = []
		v = 2
	if v < 3:
		# 3.14: baús (4 espaços, garantia, chaves) e fragmentos de peça.
		var inv3: Dictionary = d.get("inventario", {})
		var mat: Dictionary = inv3.get("materiais", {})
		if not mat.has("fragmentos"):
			mat["fragmentos"] = 0
		inv3["materiais"] = mat
		if not d.has("baus"):
			d["baus"] = _baus_novos(int(d.get("criado_em", 0)), 0)
		v = 3
	if v < 4:
		# 3.16: até dois espaços de habilidade (lista no lugar de uma só).
		var cav4: Dictionary = d.get("cavaleiro", {})
		if not cav4.has("habilidades"):
			var h := str(cav4.get("habilidade", ""))
			cav4["habilidades"] = [h] if h != "" else []
		cav4.erase("habilidade")
		v = 4
	if v < 5:
		# 3.21: renome, missões, login, conquistas e títulos.
		if not d.has("metas"):
			d["metas"] = _metas_novas()
		v = 5
	if v < 6:
		# 3.22: cenas da história já vistas.
		if not d.has("historia"):
			d["historia"] = {"vistas": []}
		v = 6
	if v < 7:
		# 3.23: configurações do jogador (notificações; acessibilidade na 3.24).
		if not d.has("config"):
			d["config"] = {"notificacoes": {}}
		v = 7
	d["versao"] = maxi(v, VERSAO)
	return d

# ---------------------------------------------------------------- internos

func _concluir(secao: String) -> Dictionary:
	var e := salvar()
	mudou.emit(secao)
	return {"ok": true, "erro": "" if e == OK else error_string(e)}

static func _erro(codigo: String) -> Dictionary:
	return {"ok": false, "erro": codigo}

static func _novo_id(e: Dictionary, prefixo: String) -> String:
	var n := int(e["proximo_id"])
	e["proximo_id"] = n + 1
	return "%s%d" % [prefixo, n]

## O JSON do Godot lê números como float; inteiros voltam a ser int.
static func _inteiros(v: Variant) -> Variant:
	if v is float and v == floorf(v) and absf(v) < 1e15:
		return int(v)
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _inteiros(v[k])
		return d
	if v is Array:
		return (v as Array).map(_inteiros)
	return v
