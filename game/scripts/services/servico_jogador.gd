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
## Um comando público deu certo aqui (a Nuvem manda ao servidor; ver _comando).
signal acao_feita(tipo: String, args: Array)

const VERSAO := 11
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
	var f: Dictionary = Balanceamento.ler("treino")["folego_cavalo"]
	var maximo := int(f["maximo"])
	var base := int(c.get("folego", maximo))
	var desde := maxi(ServicoTempo.agora() - int(c.get("folego_em", ServicoTempo.agora())), 0)
	return mini(maximo, base + desde * _recuperacao_por_hora() / 3600)

## Cavalo cansado: fôlego abaixo do limite. Corre mesmo assim, com
## penalidade de velocidade (GDD: nunca existe energia que impede de jogar).
func cavalo_cansado(id := "") -> bool:
	return folego_cavalo(id) < int(Balanceamento.ler("treino")["folego_cavalo"]["cansado_abaixo_de"])

## Horário em que o cavalo estará com o fôlego cheio.
func descansado_em(id := "") -> int:
	var f: Dictionary = Balanceamento.ler("treino")["folego_cavalo"]
	var falta := int(f["maximo"]) - folego_cavalo(id)
	return ServicoTempo.agora() + (falta * 3600 + _recuperacao_por_hora() - 1) / maxi(_recuperacao_por_hora(), 1)

func _recuperacao_por_hora() -> int:
	var f: Dictionary = Balanceamento.ler("treino")["folego_cavalo"]
	var bonus := int(f["bonus_recupera_por_nivel_estabulo_pct"]) * maxi(predio_nivel("estabulo") - 1, 0)
	bonus += bonus_companheiros("folego_recupera_pct")
	if vip_ativo():
		bonus += int(Balanceamento.ler("economia")["vip"]["folego_recuperacao_extra_pct"])
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
	var modelos: Dictionary = Balanceamento.ler("itens")["modelos"]
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
	var maximo := int(Balanceamento.ler("itens")["modelos"][it["modelo"]]["durabilidade_max"])
	if maximo <= 0:
		return 0
	var pct := int(it["durabilidade"]) * 100 / maximo
	var e := 0
	for limite in Balanceamento.ler("desgaste")["estagios_pct"]:
		if pct < int(limite):
			e += 1
	return e

## Lado do jogador para a regra da justa: {cavaleiro, cavalo, equipamento,
## habilidades}. Peça quebrada (durabilidade 0) vai com durabilidade 0 e a
## regra ignora os bônus dela. Os atributos do cavaleiro já levam o bônus de
## conjunto (2 peças), sem passar do teto.
func lado_para_justa() -> Dictionary:
	var modelos: Dictionary = Balanceamento.ler("itens")["modelos"]
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
		var pen := int(Balanceamento.ler("treino")["folego_cavalo"]["penalidade_velocidade_cansado_pct"])
		atr_cavalo["velocidade"] = int(atr_cavalo.get("velocidade", 0)) * (100 - pen) / 100
	var cav_atr: Dictionary = estado["cavaleiro"]["atributos"].duplicate()
	var bonus: Dictionary = efeito_conjuntos()["atributos"]
	var teto := int(Balanceamento.ler("treino")["teto_atributo"])
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
	return RegraConjuntos.efeito(modelos_eq, Balanceamento.ler("itens"))

## Habilidades que o cavaleiro pode equipar agora: as de base e as dos
## conjuntos completos equipados.
func habilidades_conhecidas() -> Array:
	var r: Array = (Balanceamento.ler("progressao")["habilidades"]["base"] as Array).duplicate()
	for h: String in efeito_conjuntos()["habilidades"]:
		if not r.has(h):
			r.append(h)
	return r

func espacos_habilidade() -> int:
	var cfg: Dictionary = Balanceamento.ler("progressao")["habilidades"]
	var n := int(cfg["espacos_iniciais"])
	var ligas: Array = Balanceamento.ler("economia")["ligas"]["nomes"]
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
func _cmd_equipar_habilidades(lista: Array) -> Dictionary:
	if lista.size() > espacos_habilidade():
		return _erro("sem_espaco_habilidade")
	var conhecidas := habilidades_conhecidas()
	var defs: Dictionary = Balanceamento.ler("impacto")["habilidades"]
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
func _cmd_criar_personagem(d: Dictionary) -> Dictionary:
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
func _cmd_definir_brasao(brasao: Dictionary) -> Dictionary:
	estado["casa"]["brasao"] = brasao.duplicate(true)
	return _concluir("casa")

## Equipa uma peça do inventário no espaço dela.
func _cmd_equipar(id: String) -> Dictionary:
	var it := item(id)
	if it.is_empty():
		return _erro("item_inexistente")
	var modelo: Dictionary = Balanceamento.ler("itens")["modelos"].get(it["modelo"], {})
	if modelo.is_empty():
		return _erro("modelo_inexistente")
	estado["equipamento"][modelo["espaco"]] = id
	return _concluir("equipamento")

## Guarda-roupa: aparência de `id_visual` no espaço (vazio = a da peça equipada).
func _cmd_definir_visual(espaco: String, id_visual: String) -> Dictionary:
	if id_visual == "":
		estado["visual"].erase(espaco)
	else:
		var it := item(id_visual)
		if it.is_empty():
			return _erro("item_inexistente")
		if Balanceamento.ler("itens")["modelos"][it["modelo"]]["espaco"] != espaco:
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
	var p: Dictionary = Balanceamento.ler("vila")["predios"].get(nome, {})
	return not p.is_empty() and int(estado["cavaleiro"]["nivel"]) >= int(p["libera_nivel"])

## Teto de nível: a casa senhorial vai até o máximo dela; os outros, até o
## nível da casa senhorial (GDD: ela define o teto dos outros prédios).
func teto_predio(nome: String) -> int:
	var p: Dictionary = Balanceamento.ler("vila")["predios"][nome]
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
	var vila := Balanceamento.ler("vila")
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
func _cmd_melhorar_predio(nome: String) -> Dictionary:
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
func _cmd_concluir_timer(id: String) -> Dictionary:
	for i in estado["timers"].size():
		var t: Dictionary = estado["timers"][i]
		if t["id"] != id:
			continue
		if not ServicoTempo.pronto(int(t["termina_em"])):
			return _erro("timer_nao_terminou")
		var tr_cfg := Balanceamento.ler("treino")
		var extra := {}
		match t["tipo"]:
			"melhoria":
				_garantir_predio(t["alvo"])
				estado["vila"]["predios"][t["alvo"]]["nivel"] = int(t["nivel_novo"])
			"treino_cavaleiro":
				var a: Dictionary = estado["cavaleiro"]["atributos"]
				a[t["atributo"]] = mini(int(a[t["atributo"]]) + int(tr_cfg["ganho_pontos"]), int(tr_cfg["teto_atributo"]))
			"conserto":
				var maximo := int(Balanceamento.ler("itens")["modelos"][item(t["item"])["modelo"]]["durabilidade_max"])
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
	var v: Dictionary = Balanceamento.ler("treino")["vagas"]
	# A vaga extra vem do prédio ou do VIP (é a mesma vaga; não somam).
	var extra := predio_nivel(predio) >= int(v["extra_no_nivel_do_predio"]) or vip_ativo()
	return int(v["base"]) + (1 if extra else 0)

func treinos_em(predio: String) -> Array:
	return timers_do_predio(predio).filter(func(t): return str(t["tipo"]).begins_with("treino_"))

## Duração e custo do treino pelo nível do cavaleiro (curva dos dados).
func duracao_treino() -> int:
	return _da_curva(Balanceamento.ler("treino")["duracao_por_nivel"])

func custo_treino() -> int:
	return _da_curva(Balanceamento.ler("treino")["custo_ouro_por_nivel"])

func _da_curva(curva: Array) -> int:
	var nivel := int(estado["cavaleiro"]["nivel"])
	var v := int(curva[0][1])
	for par: Array in curva:
		if nivel >= int(par[0]):
			v = int(par[1])
	return v

## Treina um atributo do cavaleiro (ocupa uma vaga do campo de treino, não o
## cavaleiro: ele continua disputando).
func _cmd_treinar_cavaleiro(atributo: String) -> Dictionary:
	var cfg := Balanceamento.ler("treino")
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
func _cmd_treinar_cavalo(id: String, atributo: String) -> Dictionary:
	var cfg := Balanceamento.ler("treino")
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
func _cmd_usar_cavalo(id: String) -> Dictionary:
	if cavalo(id).is_empty():
		return _erro("cavalo_inexistente")
	if cavalo_treinando(id):
		return _erro("cavalo_ja_treinando")
	estado["cavalo_ativo"] = id
	return _concluir("cavalos")

## Novo cavalo no estábulo (recompensa ou compra; na Parte 3 vem do servidor).
func adicionar_cavalo(pelagem: String, atributos: Dictionary) -> Dictionary:
	var f: Dictionary = Balanceamento.ler("treino")["folego_cavalo"]
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
	var f: Dictionary = Balanceamento.ler("treino")["folego_cavalo"]
	for c: Dictionary in estado["cavalos"]:
		if c["id"] == estado["cavalo_ativo"] and resultado.get("gasta_folego", true):
			c["folego"] = maxi(folego_cavalo(c["id"]) - int(f["gasto_por_justa"]), 0)
			c["folego_em"] = ServicoTempo.agora()
	_evento("justa")
	_passe_xp(int(Balanceamento.ler("economia")["passe"]["xp_por_justa"]))
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
	var c: Dictionary = Balanceamento.ler("desgaste")["conserto"]
	if it.is_empty():
		return {}
	var maximo := int(Balanceamento.ler("itens")["modelos"][it["modelo"]]["durabilidade_max"])
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
	if timers_do_predio("armeiro").filter(func(t): return t["tipo"] == "conserto").size() >= vagas_conserto():
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
func _cmd_consertar(id: String) -> Dictionary:
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
	var tabela: Array = Balanceamento.ler("progressao")["xp_por_nivel"]
	var novos: Array[int] = []
	while int(cav["nivel"]) < tabela.size() and int(cav["xp"]) >= int(tabela[int(cav["nivel"])]):
		cav["nivel"] = int(cav["nivel"]) + 1
		novos.append(int(cav["nivel"]))
	return novos

## XP que falta para o próximo nível (0 no nível máximo).
func xp_para_proximo() -> int:
	var tabela: Array = Balanceamento.ler("progressao")["xp_por_nivel"]
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
	return Balanceamento.ler("economia")["forja"]

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
	var base: Dictionary = it.get("status", Balanceamento.ler("itens")["modelos"][it["modelo"]]["status"])
	return RegraForja.status_com_nivel(base, int(it.get("nivel", 0)), int(cfg_forja()["bonus_status_por_nivel_pct"]))

## Peças que um projeto permite forjar (modelos do conjunto, em ordem).
func pecas_do_projeto(conjunto: String) -> Array:
	var modelos: Dictionary = Balanceamento.ler("itens")["modelos"]
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
	var rar: String = Balanceamento.ler("itens")["modelos"][modelo]["raridade"]
	return (cfg_forja()["receitas"][rar] as Dictionary).duplicate(true)

## Vagas de conserto (fila do armeiro, também vista no ferreiro).
func vagas_conserto() -> int:
	var v: Dictionary = Balanceamento.ler("desgaste")["conserto"]["vagas"]
	return int(v["base"]) + (1 if predio_nivel("armeiro") >= int(v["extra_no_nivel_do_predio"]) else 0)

func vagas_forja() -> int:
	var v: Dictionary = cfg_forja()["vagas_forja"]
	return int(v["base"]) + (1 if predio_nivel("armeiro") >= int(v["extra_no_nivel_do_predio"]) else 0)

func forja_em_andamento() -> Array:
	return estado["timers"].filter(func(t): return t["tipo"] == "forja").map(func(t): return t.duplicate())

func pode_forjar(modelo: String) -> Dictionary:
	var modelos: Dictionary = Balanceamento.ler("itens")["modelos"]
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
func _cmd_forjar(modelo: String) -> Dictionary:
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
	var m: Dictionary = Balanceamento.ler("itens")["modelos"][modelo]
	var st := RegraForja.variar_status(m["status"], int(cfg_forja()["variacao_status_pct"]), _semente_servico())
	var id := _novo_id(estado, "i")
	estado["inventario"]["itens"].append({"id": id, "modelo": modelo, "nivel": 0, "durabilidade": int(m["durabilidade_max"]), "status": st})
	_evento("peca_nova")
	return {"item": id, "modelo": modelo, "status": st}

## Teto de melhoria pelo nível do armeiro (0 se fechado).
func teto_melhoria() -> int:
	var m: Dictionary = Balanceamento.ler("economia")["melhoria"]
	if not predio_liberado("armeiro"):
		return 0
	return mini(int(m["nivel_max"]), maxi(predio_nivel("armeiro"), 1) * int(m["teto_por_nivel_armeiro"]))

## Custo da próxima melhoria: {nivel, fragmentos, ouro, lingotes, chance, teto}.
func custo_melhoria(id: String) -> Dictionary:
	var it := item(id)
	if it.is_empty():
		return {}
	var m: Dictionary = Balanceamento.ler("economia")["melhoria"]
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
func _cmd_melhorar_peca(id: String) -> Dictionary:
	var p := pode_melhorar_peca(id)
	if not p["ok"]:
		return p
	estado["inventario"]["ouro"] = ouro() - int(p["ouro"])
	_gastar_materiais({"fragmentos": int(p["fragmentos"]), "lingote_ferro": int(p["lingotes"])})
	var sucesso := RegraForja.melhoria_deu_certo(int(p["nivel"]), Balanceamento.ler("economia")["melhoria"], _semente_servico())
	var nivel := int(p["nivel"])
	if sucesso:
		nivel += 1
		for it: Dictionary in estado["inventario"]["itens"]:
			if it["id"] == id:
				it["nivel"] = nivel
		_evento("melhoria_peca")
		if nivel >= int(Balanceamento.ler("economia")["melhoria"]["nivel_max"]):
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

func _cmd_fundir(produto: String, quantidade: int) -> Dictionary:
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
	return Balanceamento.ler("metas")

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

func _cmd_resgatar_missao(id: String) -> Dictionary:
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

func _cmd_resgatar_login() -> Dictionary:
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

func _cmd_definir_titulo(id: String) -> Dictionary:
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

# --------------------------------------------------------------------- liga
# PvP assíncrono e ligas (3.17; regra pura RegraLiga). Até o servidor (3.5/
# 3.6), os fantasmas (cavaleiros de outros jogadores), as defesas, o ranking
# e o campeonato são SIMULADOS aqui com a semente do save; a tela mostra isso.

static func _liga_nova(criado_em: int) -> Dictionary:
	return {"pontos": 0, "melhor": "", "temporada": 1, "temporada_inicio": criado_em, "defesa": {}, "defesas": [],
		"partidas": [], "ultima_simulacao": criado_em, "buscas": 0, "adversario": {}, "campeonato": {}}

func cfg_ligas() -> Dictionary:
	return Balanceamento.ler("economia")["ligas"]

## Posição na liga (RegraLiga.posicao) com os pontos.
func liga_atual() -> Dictionary:
	var r := RegraLiga.posicao(int(estado["liga"]["pontos"]), cfg_ligas())
	r["pontos"] = int(estado["liga"]["pontos"])
	return r

## Poder do cavaleiro equipado (atributos com bônus de conjunto + peças).
func poder_jogador() -> int:
	var lado := lado_para_justa()
	var atr: Array = []
	for k in ["forca", "precisao", "equilibrio"]:
		atr.append(int(lado["cavaleiro"][k]))
	for k in ["velocidade", "folego", "temperamento"]:
		atr.append(int(lado["cavalo"].get(k, 0)))
	var modelos: Dictionary = Balanceamento.ler("itens")["modelos"]
	var pecas: Array = []
	for esp: String in estado["equipamento"]:
		var it := item(estado["equipamento"][esp])
		if not it.is_empty():
			pecas.append({"raridade": modelos[it["modelo"]]["raridade"], "nivel": int(it.get("nivel", 0))})
	return RegraLiga.poder(atr, pecas, Balanceamento.ler("economia"))

## Fantasma simulado `n`, perto de `pontos` (determinístico pela semente do
## save). O poder é o típico daqueles pontos, limitado à faixa de pareamento
## em volta de `poder_ref` (o do jogador; -1 = sem limite), como o servidor
## faria ao procurar jogadores de verdade.
func _fantasma(n: int, pontos_alvo: int, extra_poder := 0, poder_ref := -1) -> Dictionary:
	var cfg := cfg_ligas()
	var eco: Dictionary = Balanceamento.ler("economia")
	var rng := Aleatorio.new(int(estado["baus"]["semente"]) + 7777 * (n + 1))
	var var_p := int(cfg["fantasmas"]["variacao_pontos"])
	var pontos := maxi(0, pontos_alvo + rng.inteiro(-var_p, var_p))
	var alvo := int(float(cfg["poder_rival_base"]) + pontos * float(cfg["poder_rival_por_ponto"])) + rng.inteiro(-8, 8)
	if poder_ref >= 0:
		var faixa := int(cfg["faixa_poder"])
		alvo = clampi(alvo, poder_ref - faixa + 3, poder_ref + faixa - 3)
	alvo += extra_poder
	# Peças: raridade pela faixa de poder, do catálogo (ordem alfabética).
	var ordem := ["comum", "incomum", "raro", "epico", "lendario"]
	var rar: String = ordem[clampi((alvo - 30) / 30, 0, 4)]
	var modelos: Dictionary = Balanceamento.ler("itens")["modelos"]
	var equip := {}
	var pecas: Array = []
	var nivel := clampi((alvo - 30) % 30 / 3, 0, 10)
	for esp in ["elmo", "peitoral", "escudo", "lanca"]:
		var opcoes: Array = []
		for m: String in modelos:
			if modelos[m]["espaco"] == esp and modelos[m]["raridade"] == rar:
				opcoes.append(m)
		if opcoes.is_empty():
			continue
		opcoes.sort()
		var m: String = opcoes[rng.inteiro(0, opcoes.size() - 1)]
		var st := RegraForja.status_com_nivel(modelos[m]["status"], nivel, int(eco["forja"]["bonus_status_por_nivel_pct"]))
		st["durabilidade"] = int(modelos[m]["durabilidade_max"])
		equip[esp] = st
		pecas.append({"raridade": rar, "nivel": nivel})
	var poder_pecas := RegraLiga.poder([], pecas, eco)
	var base_atr := clampi((alvo - poder_pecas) * 2, 20, 100)
	var cav := {"forca": clampi(base_atr + rng.inteiro(-6, 6), 10, 100), "precisao": clampi(base_atr + rng.inteiro(-6, 6), 10, 100),
		"equilibrio": clampi(base_atr + rng.inteiro(-6, 6), 10, 100)}
	var cavalo := {"velocidade": clampi(base_atr + rng.inteiro(-6, 6), 10, 100), "folego": clampi(base_atr + rng.inteiro(-6, 6), 10, 100),
		"temperamento": clampi(base_atr + rng.inteiro(-6, 6), 10, 100)}
	var atr: Array = cav.values() + cavalo.values()
	var nomes: Dictionary = Balanceamento.ler_json("res://game/data/texto/nomes_sorteio.json")
	var lista: Array = (nomes["femininos"] as Array) + (nomes["masculinos"] as Array)
	var casas: Array = nomes["casas"]
	var cores: Array = Balanceamento.ler_json(CamadasPersonagem.PALETAS)["cores_casa"].keys()
	var c1: String = cores[rng.inteiro(0, cores.size() - 1)]
	var c2: String = cores[rng.inteiro(0, cores.size() - 1)]
	var habs := ["investida", "golpe_pesado"]
	return {"id": "f%d" % n, "nome": "%s · %s" % [lista[rng.inteiro(0, lista.size() - 1)], casas[rng.inteiro(0, casas.size() - 1)]],
		"pontos": pontos, "poder": RegraLiga.poder(atr, pecas, eco), "simulado": true,
		"lado": {"cavaleiro": cav, "cavalo": cavalo, "equipamento": equip, "habilidades": [habs[rng.inteiro(0, 1)], "bloqueio"]},
		"casa": {"principal": c1, "secundaria": c2}, "brasao_perfil": ["novato", "equilibrado", "agressivo"][rng.inteiro(0, 2)],
		"raridade": rar, "nivel_pecas": nivel}

## Procura um adversário: candidatos simulados, pareados pela regra (faixa de
## poder e pontos). Guarda como o adversário da próxima justa de PvP.
func procurar_adversario() -> Dictionary:
	var cfg := cfg_ligas()
	var lg: Dictionary = estado["liga"]
	lg["buscas"] = int(lg["buscas"]) + 1
	var candidatos: Array = []
	var meu := poder_jogador()
	for i in int(cfg["fantasmas"]["candidatos"]):
		candidatos.append(_fantasma(int(lg["buscas"]) * 100 + i, int(lg["pontos"]), 0, meu))
	var id := RegraLiga.parear(int(lg["pontos"]), meu, candidatos.map(func(c): return {"id": c["id"], "pontos": c["pontos"], "poder": c["poder"]}), cfg)
	var escolhido: Dictionary = {}
	for c: Dictionary in candidatos:
		if c["id"] == id:
			escolhido = c
	if escolhido.is_empty():
		# Ninguém na faixa: o de poder mais próximo (no servidor, alarga a faixa).
		candidatos.sort_custom(func(a, b): return absi(int(a["poder"]) - meu) < absi(int(b["poder"]) - meu))
		escolhido = candidatos[0]
	lg["adversario"] = escolhido
	var r := _concluir("liga")
	r["adversario"] = escolhido.duplicate(true)
	return r

func adversario() -> Dictionary:
	return (estado["liga"]["adversario"] as Dictionary).duplicate(true)

## Tudo para a justa de PvP: {cfg, lado_jogador, rival {lado, perfil, perfil_nome, casa, brasao, nome_chave}}.
func preparar_pvp() -> Dictionary:
	var a: Dictionary = estado["liga"]["adversario"]
	if a.is_empty():
		return {}
	var perfil_nome: String = cfg_ligas()["fantasmas"]["perfil"]
	var rv := {"id": a["id"], "lado": (a["lado"] as Dictionary).duplicate(true), "perfil_nome": perfil_nome,
		"perfil": Balanceamento.ler("ia_rival")["perfis"][perfil_nome].duplicate(true), "casa": a["casa"].duplicate(),
		"brasao": GeradorBrasao.opcoes().get("rivais", {}).get(a["brasao_perfil"], {}), "nome_chave": a["nome"], "provocacao": ""}
	return {"cfg": Justa.carregar_configuracao(), "lado_jogador": lado_para_justa(), "rival": rv}

## Fim da justa de PvP: pontos (RegraLiga), ouro e XP na vitória, chance de
## baú, histórico; no campeonato, avança ou elimina.
func concluir_pvp(eventos: Array) -> Dictionary:
	var lg: Dictionary = estado["liga"]
	var a: Dictionary = lg["adversario"]
	if a.is_empty():
		return _erro("sem_adversario")
	var cfg := cfg_ligas()
	var venceu := RegraPve.estrelas(eventos) > 0
	if venceu and tem_ordem():
		_virar_semana_torneio()
		_social()["torneio"]["vitorias"] = int(_social()["torneio"]["vitorias"]) + 1
	var antes := int(lg["pontos"])
	var pos_antes := RegraLiga.posicao(antes, cfg)
	var ouro_g := 0
	var xp_g := 0
	var baus_g: Array = []
	var premio := {}
	var camp: Dictionary = lg["campeonato"]
	if a.get("campeonato", false):
		if venceu:
			var premios: Array = cfg["campeonato"]["premios"]
			premio = premios[mini(int(camp["rodada"]), premios.size() - 1)]
			camp["rodada"] = int(camp["rodada"]) + 1
			_dar_recompensa(premio)
		else:
			camp["eliminado"] = true
	else:
		lg["pontos"] = RegraLiga.depois_da_partida(antes, venceu, cfg)
		if venceu:
			ouro_g = RegraLiga.ouro_vitoria(int(pos_antes["liga"]), cfg)
			xp_g = int(cfg["xp_vitoria"])
			if _sorteio_milesimos(int(round(float(cfg_baus()["chance_madeira_por_vitoria"]) * 1000.0))):
				baus_g.append(_guardar_bau("madeira"))
	var pos := RegraLiga.posicao(int(lg["pontos"]), cfg)
	var nomes: Array = cfg["nomes"]
	if str(lg["melhor"]) == "" or nomes.find(lg["melhor"]) < int(pos["liga"]):
		lg["melhor"] = nomes[int(pos["liga"])]
	var partidas: Array = lg["partidas"]
	partidas.push_front({"quando": ServicoTempo.agora(), "adversario": a["nome"], "venceu": venceu, "pontos": int(lg["pontos"]) - antes,
		"campeonato": a.get("campeonato", false)})
	while partidas.size() > 30:
		partidas.pop_back()
	lg["adversario"] = {}
	if not venceu and _derrota_por_pouco(eventos):
		disparar_oferta("derrota_por_pouco")
	if int(pos["liga"]) > int(pos_antes["liga"]):
		disparar_oferta("subiu_liga")
	if venceu and ouro_g > 0:
		_guardar_vitoria(ouro_g)
	var niveis := _ganhar(ouro_g, xp_g)
	var r := _concluir("liga")
	r.merge({"venceu": venceu, "estrelas": 1 if venceu else 0, "pontos_antes": antes, "pontos": int(lg["pontos"]), "ouro": ouro_g, "xp": xp_g,
		"niveis": niveis, "baus": baus_g, "subiu": int(pos["liga"]) > int(pos_antes["liga"]) or pos["divisao"] != pos_antes["divisao"] and int(lg["pontos"]) > antes,
		"premio": premio, "pvp": true}, true)
	return r

## Guarda o equipamento, o cavalo e as habilidades de agora como defesa.
func salvar_defesa() -> Dictionary:
	estado["liga"]["defesa"] = {"equipamento": (estado["equipamento"] as Dictionary).duplicate(), "cavalo": estado["cavalo_ativo"],
		"habilidades": habilidades_em_uso(), "salva_em": ServicoTempo.agora()}
	return _concluir("liga")

func defesa() -> Dictionary:
	return (estado["liga"]["defesa"] as Dictionary).duplicate(true)

## Lado da defesa salva (peças que ainda existem, com o desgaste de agora).
func lado_defesa() -> Dictionary:
	var d: Dictionary = estado["liga"]["defesa"]
	if d.is_empty():
		return {}
	var equip := {}
	for esp: String in d["equipamento"]:
		if not ESPACOS_REGRA.has(esp):
			continue
		var it := item(d["equipamento"][esp])
		if it.is_empty():
			continue
		var st := status_do_item(it["id"])
		st["durabilidade"] = int(it["durabilidade"])
		equip[esp] = st
	var cav := cavalo(d["cavalo"])
	return {"cavaleiro": lado_para_justa()["cavaleiro"], "cavalo": cav.get("atributos", cavalo_ativo().get("atributos", {})).duplicate(),
		"equipamento": equip, "habilidades": d["habilidades"]}

## Ao abrir o salão: fecha a temporada vencida e simula as defesas do tempo
## em que o jogador esteve fora (até 10). Salva.
func atualizar_liga() -> Dictionary:
	var lg: Dictionary = estado["liga"]
	var cfg := cfg_ligas()
	var dur := int(cfg["temporada_dias"]) * 86400
	var fechou := {}
	while ServicoTempo.agora() >= int(lg["temporada_inicio"]) + dur:
		var pos := RegraLiga.posicao(int(lg["pontos"]), cfg)
		var rec: Array = cfg["recompensa_temporada"]
		fechou = {"temporada": int(lg["temporada"]), "liga": pos["nome"], "bau": rec[mini(int(pos["liga"]), rec.size() - 1)]}
		_guardar_bau(fechou["bau"])
		lg["pontos"] = RegraLiga.reinicio(int(lg["pontos"]), cfg)
		lg["temporada"] = int(lg["temporada"]) + 1
		lg["temporada_inicio"] = int(lg["temporada_inicio"]) + dur
	var novas := 0
	var passado := ServicoTempo.agora() - int(lg["ultima_simulacao"])
	var n := mini(10, passado * int(cfg["defesas_por_dia"]) / 86400)
	if n > 0:
		lg["ultima_simulacao"] = ServicoTempo.agora()
		var lado_d := lado_defesa()
		if not lado_d.is_empty():
			var perfis: Dictionary = Balanceamento.ler("ia_rival")["perfis"]
			var perfil: Dictionary = perfis[cfg["fantasmas"]["perfil"]]
			var jcfg := Justa.carregar_configuracao()
			for i in n:
				var semente := int(estado["baus"]["semente"]) + 31 * (int(lg["buscas"]) + 1000 * int(lg["temporada"]) + i + (lg["defesas"] as Array).size())
				var atac := _fantasma(900000 + semente % 100000, int(lg["pontos"]), 0, poder_jogador())
				var sim := RegraPve.simular(jcfg, atac["lado"], lado_d, semente, perfil, perfil)
				var defendeu := RegraPve.estrelas(sim["eventos"]) == 0
				var antes := int(lg["pontos"])
				lg["pontos"] = RegraLiga.depois_da_defesa(antes, defendeu, cfg)
				(lg["defesas"] as Array).push_front({"quando": ServicoTempo.agora(), "atacante": atac["nome"], "defendeu": defendeu,
					"pontos": int(lg["pontos"]) - antes, "simulado": true})
				novas += 1
			while (lg["defesas"] as Array).size() > 20:
				(lg["defesas"] as Array).pop_back()
	var r := _concluir("liga")
	r.merge({"temporada_fechada": fechou, "defesas_novas": novas}, true)
	return r

## Temporada: {numero, termina_em, restante_s, recompensas: [{liga, bau}]}.
func temporada() -> Dictionary:
	var lg: Dictionary = estado["liga"]
	var cfg := cfg_ligas()
	var fim := int(lg["temporada_inicio"]) + int(cfg["temporada_dias"]) * 86400
	var rec: Array = []
	for i in (cfg["nomes"] as Array).size():
		rec.append({"liga": cfg["nomes"][i], "bau": cfg["recompensa_temporada"][mini(i, (cfg["recompensa_temporada"] as Array).size() - 1)]})
	return {"numero": int(lg["temporada"]), "termina_em": fim, "restante_s": maxi(0, fim - ServicoTempo.agora()), "recompensas": rec}

## Ranking simulado de jogadores perto dos seus pontos, com você no meio:
## [{posicao, nome, pontos, voce}].
func ranking_jogadores() -> Array:
	var cfg := cfg_ligas()
	var lista: Array = []
	for i in int(cfg["ranking_simulado"]):
		var f := _fantasma(500000 + i + 1000 * int(estado["liga"]["temporada"]), int(estado["liga"]["pontos"]))
		lista.append({"nome": f["nome"], "pontos": int(f["pontos"]), "voce": false})
	lista.append({"nome": cavaleiro().get("nome", ""), "pontos": int(estado["liga"]["pontos"]), "voce": true})
	lista.sort_custom(func(a, b): return int(a["pontos"]) > int(b["pontos"]) or (int(a["pontos"]) == int(b["pontos"]) and a["voce"]))
	for i in lista.size():
		lista[i]["posicao"] = i + 1
	return lista

## Ranking simulado de ordens (as ordens de verdade vêm com o servidor, 3.8).
func ranking_ordens() -> Array:
	var nomes: Array = Balanceamento.ler_json("res://game/data/texto/nomes_sorteio.json")["casas"]
	var rng := Aleatorio.new(int(estado["baus"]["semente"]) + 4242 * int(estado["liga"]["temporada"]))
	var lista: Array = []
	for i in nomes.size():
		lista.append({"nome": str(nomes[i]).replace("Casa", "Ordem"), "pontos": rng.inteiro(200, 6000)})
	lista.sort_custom(func(a, b): return int(a["pontos"]) > int(b["pontos"]))
	for i in lista.size():
		lista[i]["posicao"] = i + 1
	return lista

## Campeonato de fim de semana (simulado): {aberto, rodada, rodadas, eliminado, chave: [nomes], premios}.
func campeonato() -> Dictionary:
	var cfg: Dictionary = cfg_ligas()["campeonato"]
	var dia_semana := int(Time.get_datetime_dict_from_unix_time(ServicoTempo.agora())["weekday"])
	var semana := semana_atual()
	var c: Dictionary = estado["liga"]["campeonato"]
	if int(c.get("semana", -1)) != semana:
		c.clear()
		c.merge({"semana": semana, "rodada": 0, "eliminado": false, "chave": []}, true)
		var chave: Array = []
		for i in 8:
			chave.append(_fantasma(700000 + semana * 10 + i, int(estado["liga"]["pontos"]), i)["nome"])
		c["chave"] = chave
	return {"aberto": (cfg["dias_semana"] as Array).any(func(x): return int(x) == dia_semana), "rodada": int(c["rodada"]), "rodadas": int(cfg["rodadas"]),
		"eliminado": c["eliminado"], "chave": (c["chave"] as Array).duplicate(), "premios": (cfg["premios"] as Array).duplicate(true)}

## Próxima luta do campeonato: o adversário da rodada vira o da justa de PvP.
func jogar_campeonato() -> Dictionary:
	var info := campeonato()
	if not info["aberto"]:
		return _erro("campeonato_fechado")
	if info["eliminado"] or int(info["rodada"]) >= int(info["rodadas"]):
		return _erro("campeonato_encerrado")
	var f := _fantasma(800000 + semana_atual() * 10 + int(info["rodada"]), int(estado["liga"]["pontos"]), 4 * int(info["rodada"]), poder_jogador())
	f["nome"] = info["chave"][int(info["rodada"]) * 2 + 1] if int(info["rodada"]) * 2 + 1 < info["chave"].size() else f["nome"]
	f["campeonato"] = true
	estado["liga"]["adversario"] = f
	var r := _concluir("liga")
	r["adversario"] = f.duplicate(true)
	return r

# --------------------------------------------------------------------- loja
# Loja, VIP, passe e ofertas (3.18; catálogo em loja.json, números do VIP e
# do passe em economia.json). Compras com DINHEIRO só pelo provedor de teste
# (build de depuração) até a 3.7 validar recibos no servidor; compras com
# gemas valem de verdade.

static func _loja_nova() -> Dictionary:
	return {"vip_ate": 0, "passe": {"temporada": 1, "premium": false, "xp": 0, "gratis": [], "premium_resgatados": []},
		"compras": [], "cosmeticos": [], "frase": "", "vitoria": "", "compras_dia": {"dia": -1}, "ofertas": [], "ultima_oferta": {}}

func cfg_loja() -> Dictionary:
	return Balanceamento.ler("loja")

func gemas() -> int:
	return int(estado["inventario"].get("gemas", 0))

func vip_ativo() -> bool:
	return estado.has("loja") and int(estado["loja"]["vip_ate"]) > ServicoTempo.agora()

## Compras com dinheiro: só o provedor de teste, em build de depuração.
func loja_de_teste() -> bool:
	return OS.is_debug_build()

## Compra um produto pago (gemas, VIP, passe premium ou oferta) pelo provedor
## de teste. {ok, erro, produto, teste}.
func comprar(produto: String) -> Dictionary:
	if not loja_de_teste():
		return _erro("loja_indisponivel")
	var cfg := cfg_loja()
	var lj: Dictionary = estado["loja"]
	var entregue := {}
	var achou := false
	for g: Dictionary in cfg["gemas"]:
		if g["id"] == produto:
			estado["inventario"]["gemas"] = gemas() + int(g["gemas"])
			entregue = {"gemas": int(g["gemas"])}
			achou = true
	if produto == cfg["vip"]["id"]:
		lj["vip_ate"] = maxi(int(lj["vip_ate"]), ServicoTempo.agora()) + int(cfg["vip"]["dias"]) * 86400
		var gm := int(Balanceamento.ler("economia")["vip"]["gemas_mes"])
		estado["inventario"]["gemas"] = gemas() + gm
		entregue = {"vip_dias": int(cfg["vip"]["dias"]), "gemas": gm}
		achou = true
	if produto == cfg["passe"]["id"]:
		_atualizar_passe()
		if lj["passe"]["premium"]:
			return _erro("ja_comprado")
		lj["passe"]["premium"] = true
		entregue = {"passe": true}
		achou = true
	for o: Dictionary in cfg["ofertas"]:
		if o["id"] == produto:
			var ativa: Array = (lj["ofertas"] as Array).filter(func(x): return x["id"] == produto and int(x["ate"]) > ServicoTempo.agora())
			if ativa.is_empty():
				return _erro("oferta_expirada")
			entregue = _entregar_conteudo(o["conteudo"])
			lj["ofertas"] = (lj["ofertas"] as Array).filter(func(x): return x["id"] != produto)
			achou = true
	if not achou:
		return _erro("produto_inexistente")
	(lj["compras"] as Array).append({"produto": produto, "quando": ServicoTempo.agora(), "teste": true})
	var r := _concluir("loja")
	r.merge({"produto": produto, "entregue": entregue, "teste": true}, true)
	return r

func _entregar_conteudo(c: Dictionary) -> Dictionary:
	var dado := {}
	for k: String in c:
		match k:
			"gemas":
				estado["inventario"]["gemas"] = gemas() + int(c[k])
			"bau":
				dado["bau_ganho"] = _guardar_bau(str(c[k]))
			"ouro":
				_ganhar(int(c[k]), 0)
			_:
				var mats: Dictionary = estado["inventario"]["materiais"]
				mats[k] = int(mats.get(k, 0)) + int(c[k])
		dado[k] = c[k]
	return dado

## Gasta gemas: cosmético (uma vez) ou material (limite por dia).
func _cmd_comprar_com_gemas(id: String) -> Dictionary:
	var cfg := cfg_loja()
	var lj: Dictionary = estado["loja"]
	for c: Dictionary in cfg["cosmeticos"]:
		if c["id"] == id:
			if (lj["cosmeticos"] as Array).has(id):
				return _erro("ja_comprado")
			if gemas() < int(c["gemas"]):
				return _erro("gemas_insuficientes")
			estado["inventario"]["gemas"] = gemas() - int(c["gemas"])
			lj["cosmeticos"].append(id)
			return _concluir("loja")
	for m: Dictionary in cfg["materiais"]:
		if m["material"] == id:
			var cd: Dictionary = lj["compras_dia"]
			if int(cd.get("dia", -1)) != dia_atual():
				cd.clear()
				cd["dia"] = dia_atual()
			if int(cd.get(id, 0)) >= int(m["limite_dia"]):
				return _erro("limite_diario")
			if gemas() < int(m["gemas"]):
				return _erro("gemas_insuficientes")
			estado["inventario"]["gemas"] = gemas() - int(m["gemas"])
			cd[id] = int(cd.get(id, 0)) + 1
			var mats: Dictionary = estado["inventario"]["materiais"]
			mats[id] = int(mats.get(id, 0)) + int(m["quantidade"])
			return _concluir("loja")
	return _erro("produto_inexistente")

## Quantas compras de um material ainda dá para fazer hoje.
func compras_restantes_hoje(material: String) -> int:
	var cd: Dictionary = estado["loja"]["compras_dia"]
	var usado := int(cd.get(material, 0)) if int(cd.get("dia", -1)) == dia_atual() else 0
	for m: Dictionary in cfg_loja()["materiais"]:
		if m["material"] == material:
			return maxi(0, int(m["limite_dia"]) - usado)
	return 0

## Usa um cosmético comprado: frase do arauto ou cor da comemoração ("" tira).
func _cmd_usar_cosmetico(id: String) -> Dictionary:
	var lj: Dictionary = estado["loja"]
	if id != "" and not (lj["cosmeticos"] as Array).has(id):
		return _erro("cosmetico_bloqueado")
	var tipo := ""
	for c: Dictionary in cfg_loja()["cosmeticos"]:
		if c["id"] == id:
			tipo = c["tipo"]
	if tipo == "frase_arauto" or id == "":
		lj["frase"] = id
	if tipo == "efeito_vitoria":
		lj["vitoria"] = id
	return _concluir("loja")

## Custo em gemas para terminar agora um timer ou um baú abrindo.
func custo_pular(restante_s: int) -> int:
	return int(ceil(maxi(restante_s, 0) / 3600.0)) * int(cfg_loja()["gemas_por_hora_timer"])

## Termina agora um timer (treino, obra, forja...) ou o baú que está abrindo, com gemas.
func _cmd_pular_com_gemas(id: String) -> Dictionary:
	var alvo: Dictionary = {}
	var chave := "termina_em"
	for t: Dictionary in estado["timers"]:
		if t["id"] == id:
			alvo = t
	if alvo.is_empty():
		alvo = _bau(id)
		chave = "abre_em"
	if alvo.is_empty() or int(alvo.get(chave, 0)) <= 0:
		return _erro("timer_inexistente")
	var custo := custo_pular(int(alvo[chave]) - ServicoTempo.agora())
	if gemas() < custo:
		return _erro("gemas_insuficientes")
	estado["inventario"]["gemas"] = gemas() - custo
	alvo[chave] = ServicoTempo.agora()
	var r := _concluir("loja")
	r["gemas"] = custo
	return r

# Passe da temporada: XP por justa; a temporada é a da liga.
func _atualizar_passe() -> void:
	var p: Dictionary = estado["loja"]["passe"]
	var t := int(estado["liga"]["temporada"])
	if int(p["temporada"]) != t:
		p.clear()
		p.merge({"temporada": t, "premium": false, "xp": 0, "gratis": [], "premium_resgatados": []}, true)

func _passe_xp(xp: int) -> void:
	if not estado.has("loja"):
		return
	_atualizar_passe()
	estado["loja"]["passe"]["xp"] = int(estado["loja"]["passe"]["xp"]) + xp

## Recompensas de um nível do passe nas duas trilhas.
func recompensa_passe(nivel: int) -> Dictionary:
	var ps: Dictionary = Balanceamento.ler("economia")["passe"]
	var g: Dictionary = ps["gratis"]
	var pr: Dictionary = ps["premium"]
	var rg := {"ouro": int(g["ouro_por_nivel"])}
	if nivel % int(g["bau_ferro_a_cada"]) == 0:
		rg["bau"] = "ferro"
	var rp := {"ouro": int(pr["ouro_por_nivel"]), "fragmentos": int(pr["fragmentos_por_nivel"])}
	if nivel % int(pr["bau_ouro_a_cada"]) == 0:
		rp["bau"] = "ouro"
	elif nivel % int(pr["bau_ferro_a_cada"]) == 0:
		rp["bau"] = "ferro"
	if (pr["projeto_nos_niveis"] as Array).any(func(x): return int(x) == nivel):
		rp["projeto"] = true
	return {"gratis": rg, "premium": rp}

## Estado do passe: {temporada, nivel, xp, xp_nivel, niveis, premium, gratis [n], premium_resgatados [n]}.
func passe() -> Dictionary:
	_atualizar_passe()
	var ps: Dictionary = Balanceamento.ler("economia")["passe"]
	var p: Dictionary = estado["loja"]["passe"]
	return {"temporada": int(p["temporada"]), "nivel": mini(int(ps["niveis"]), int(p["xp"]) / int(ps["xp_por_nivel"])), "xp": int(p["xp"]),
		"xp_nivel": int(ps["xp_por_nivel"]), "niveis": int(ps["niveis"]), "premium": p["premium"],
		"gratis": (p["gratis"] as Array).duplicate(), "premium_resgatados": (p["premium_resgatados"] as Array).duplicate()}

## Pega a recompensa de um nível numa trilha ("gratis" ou "premium").
func _cmd_resgatar_passe(nivel: int, trilha: String) -> Dictionary:
	var info := passe()
	if nivel < 1 or nivel > int(info["nivel"]):
		return _erro("nivel_do_passe_bloqueado")
	if trilha == "premium" and not info["premium"]:
		return _erro("passe_sem_premium")
	var lista: Array = estado["loja"]["passe"]["gratis" if trilha == "gratis" else "premium_resgatados"]
	if lista.has(nivel):
		return _erro("ja_resgatada")
	lista.append(nivel)
	var rec: Dictionary = recompensa_passe(nivel)[trilha]
	var dado := _dar_recompensa(rec)
	if rec.get("projeto", false):
		for c: Dictionary in Balanceamento.ler("economia")["conjuntos"]:
			if c["raridade"] in ["raro", "epico"] and not (estado["inventario"]["projetos"] as Array).has(c["nome"]):
				estado["inventario"]["projetos"].append(c["nome"])
				dado["projeto"] = c["nome"]
				break
	var r := _concluir("loja")
	r["recompensa"] = dado
	return r

## Ofertas (GDD): no gatilho, se não houve outra desse gatilho no intervalo.
func disparar_oferta(gatilho: String) -> void:
	if not estado.has("loja"):
		return
	var lj: Dictionary = estado["loja"]
	for o: Dictionary in cfg_loja()["ofertas"]:
		if o["gatilho"] != gatilho:
			continue
		var ultima := int(lj["ultima_oferta"].get(gatilho, -999999999))
		if ServicoTempo.agora() - ultima < int(o["intervalo_s"]):
			return
		lj["ultima_oferta"][gatilho] = ServicoTempo.agora()
		(lj["ofertas"] as Array).append({"id": o["id"], "ate": ServicoTempo.agora() + int(o["duracao_s"]), "vista": false})

## Ofertas ainda valendo, com o conteúdo: [{id, ate, vista, conteudo, preco}].
func ofertas() -> Array:
	var r: Array = []
	for x: Dictionary in estado["loja"]["ofertas"]:
		if int(x["ate"]) > ServicoTempo.agora():
			var d: Dictionary = (cfg_loja()["ofertas"] as Array).filter(func(o): return o["id"] == x["id"])[0]
			var c := x.duplicate()
			c.merge({"conteudo": d["conteudo"].duplicate(), "preco": d["preco"]}, true)
			r.append(c)
	return r

## A próxima oferta a mostrar (uma vez cada); {} se nenhuma.
func oferta_nova() -> Dictionary:
	for o: Dictionary in ofertas():
		if not o["vista"]:
			return o
	return {}

func _cmd_marcar_oferta_vista(id: String) -> void:
	for x: Dictionary in estado["loja"]["ofertas"]:
		if x["id"] == id:
			x["vista"] = true
	salvar()

func _derrota_por_pouco(eventos: Array) -> bool:
	for e: Dictionary in eventos:
		if e.get("tipo", "") == "fim" and e.has("placar_jogador"):
			return e["vencedor"] == JustaFases.Lado.RIVAL and e.get("motivo", "") == "pontos" \
				and int(e["placar_rival"]) - int(e["placar_jogador"]) <= int(cfg_loja()["derrota_por_pouco_pontos"])
	return false

# ----------------------------------------------------------------- anúncios
# Anúncios premiados (3.19; o autoload Anuncios mostra; aqui a recompensa).
# Limite diário em economia.json > anuncios. Na Parte 3 isto vira a Edge
# Function que confere o token do provedor antes de entregar.

func cfg_anuncios() -> Dictionary:
	return Balanceamento.ler("economia")["anuncios"]

## VIP: benefício sem assistir (economia.json > vip > beneficio_anuncios).
func anuncio_sem_assistir() -> bool:
	return vip_ativo() and bool(Balanceamento.ler("economia")["vip"]["beneficio_anuncios"])

func anuncios_restantes() -> int:
	var a: Dictionary = estado["anuncios"]
	var usados := int(a["usados"]) if int(a["dia"]) == dia_atual() else 0
	return maxi(0, int(cfg_anuncios()["limite_dia"]) - usados)

func _guardar_vitoria(ouro_g: int) -> void:
	estado["anuncios"]["ultima_vitoria"] = {"ouro": ouro_g, "quando": ServicoTempo.agora(), "usada": false}

## Dá para pedir este benefício agora? tipo: cortar_timer (alvo = id do timer
## ou do baú abrindo; uma vez por timer), dobrar_vitoria (a última vitória,
## em até 10 min), bau_madeira_extra.
func pode_recompensa_anuncio(tipo: String, alvo := "") -> Dictionary:
	if anuncios_restantes() <= 0:
		return _erro("limite_anuncios")
	match tipo:
		"cortar_timer":
			if (estado["anuncios"]["timers"] as Array).has(alvo):
				return _erro("timer_ja_cortado")
			var achou := false
			for t: Dictionary in estado["timers"]:
				achou = achou or (t["id"] == alvo and not ServicoTempo.pronto(int(t["termina_em"])))
			var b := _bau(alvo)
			achou = achou or (not b.is_empty() and int(b["abre_em"]) > ServicoTempo.agora())
			if not achou:
				return _erro("timer_inexistente")
		"dobrar_vitoria":
			var v: Dictionary = estado["anuncios"]["ultima_vitoria"]
			if v.is_empty() or v.get("usada", false) or ServicoTempo.agora() - int(v["quando"]) > 600:
				return _erro("sem_vitoria_para_dobrar")
		"bau_madeira_extra":
			if baus().size() >= int(cfg_baus()["espacos"]):
				return _erro("espacos_cheios")
		_:
			return _erro("anuncio_inexistente")
	return {"ok": true, "erro": ""}

## Entrega o benefício (depois do anúncio assistido, ou direto para o VIP).
## `token` é o comprovante do provedor (o servidor vai conferir). {ok, recompensa}.
func _cmd_recompensa_anuncio(tipo: String, alvo: String, token: String) -> Dictionary:
	var p := pode_recompensa_anuncio(tipo, alvo)
	if not p["ok"]:
		return p
	if token == "":
		return _erro("anuncio_sem_comprovante")
	var a: Dictionary = estado["anuncios"]
	if int(a["dia"]) != dia_atual():
		a["dia"] = dia_atual()
		a["usados"] = 0
	a["usados"] = int(a["usados"]) + 1
	var cfg := cfg_anuncios()
	var rec := {}
	match tipo:
		"cortar_timer":
			var corte := int(cfg["cortar_minutos"]) * 60
			(a["timers"] as Array).append(alvo)
			for t: Dictionary in estado["timers"]:
				if t["id"] == alvo:
					t["termina_em"] = maxi(ServicoTempo.agora(), int(t["termina_em"]) - corte)
			var b := _bau(alvo)
			if not b.is_empty():
				b["abre_em"] = maxi(ServicoTempo.agora(), int(b["abre_em"]) - corte)
			rec = {"minutos": int(cfg["cortar_minutos"])}
		"dobrar_vitoria":
			var v: Dictionary = a["ultima_vitoria"]
			var extra := int(v["ouro"]) * (int(cfg["dobrar_vitoria"]) - 1)
			v["usada"] = true
			_ganhar(extra, 0)
			rec = {"ouro": extra}
		"bau_madeira_extra":
			rec = {"bau_ganho": _guardar_bau("madeira")}
	var r := _concluir("anuncios")
	r["recompensa"] = rec
	return r

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
	var padrao: Dictionary = Balanceamento.ler_json("res://game/data/ui/acessibilidade.json")["padrao"]
	return estado.get("config", {}).get(chave, padrao.get(chave))

func _cmd_definir_config(chave: String, valor: Variant) -> Dictionary:
	var a: Dictionary = Balanceamento.ler_json("res://game/data/ui/acessibilidade.json")
	if not a["padrao"].has(chave):
		return _erro("opcao_inexistente")
	if chave == "texto" and not a["tamanhos_texto"].has(str(valor)):
		return _erro("opcao_invalida")
	if chave == "idioma" and not (a["idiomas"] as Array).has(str(valor)):
		return _erro("opcao_invalida")
	if chave.begins_with("volume_"):
		var inteiro: bool = valor is int or (valor is float and valor == floorf(valor))
		if not inteiro or float(valor) < 0.0 or float(valor) > 100.0:
			return _erro("opcao_invalida")
	if not estado.has("config"):
		estado["config"] = {"notificacoes": {}}
	estado["config"][chave] = valor
	return _concluir("config")

## Versão atual da política de privacidade (game/data/ui/privacidade.json).
func versao_politica() -> int:
	return int(Balanceamento.ler_json("res://game/data/ui/privacidade.json")["versao_politica"])

## O jogador já aceitou a versão atual da política e dos termos?
func privacidade_aceita() -> bool:
	return int(config_valor("privacidade_aceita")) >= versao_politica()

## Registra o aceite da versão atual e a escolha de anúncios personalizados.
func aceitar_privacidade(personalizados: bool) -> Dictionary:
	if not estado.has("config"):
		estado["config"] = {"notificacoes": {}}
	estado["config"]["privacidade_aceita"] = versao_politica()
	estado["config"]["anuncios_personalizados"] = personalizados
	return _concluir("config")

## Apaga tudo que é do jogador neste aparelho (exclusão de conta, 3.9): volta
## ao estado inicial, sem personagem e sem aceite da política.
func apagar_dados_locais() -> void:
	for sufixo in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(caminho_save + sufixo):
			DirAccess.remove_absolute(caminho_save + sufixo)
	estado = novo_estado()
	_concluir("tudo")

func _cmd_definir_notificacao(tipo: String, ligada: bool) -> Dictionary:
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
	return Balanceamento.ler_json("res://game/data/historia/historia.json")

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

func _cmd_marcar_cena_vista(id: String) -> Dictionary:
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
	return Balanceamento.ler("economia")["baus"]

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
func _cmd_comecar_abrir(id: String) -> Dictionary:
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
func _cmd_abrir_bau(id: String, com_chave := false) -> Dictionary:
	var b := _bau(id)
	if b.is_empty():
		return _erro("bau_inexistente")
	if com_chave:
		if chaves() <= 0:
			return _erro("sem_chave")
	elif not bau_pronto(id):
		return _erro("bau_fechado")
	var cfg := cfg_baus()
	var modelos: Dictionary = Balanceamento.ler("itens")["modelos"]
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
	return Balanceamento.ler("pve")

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
	var modelos: Dictionary = Balanceamento.ler("itens")["modelos"]
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
	var perfil := RegraPve.ajustar_perfil(Balanceamento.ler("ia_rival")["perfis"][r["perfil"]], r.get("perfil_ajuste", {}))
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
	var ganho: Dictionary = Balanceamento.ler("metas")["renome"]["ganho"]
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
		if _derrota_por_pouco(eventos):
			disparar_oferta("derrota_por_pouco")
	if fechou:
		_evento("torneio_vencido")
	if projeto != "":
		_evento("regiao_vencida")
		renome_g += int(ganho["regiao_vencida"])
	renome_g = renome_g * (100 + bonus_companheiros("renome_pct")) / 100
	metas["renome"] = int(metas["renome"]) + renome_g
	if est > 0 and ouro_g > 0:
		_guardar_vitoria(ouro_g)
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
	var perfil_auto: Dictionary = Balanceamento.ler("ia_rival")["perfis"][dados["perfil_automatico"]]
	var sim := RegraPve.simular(prep["cfg"], prep["lado_jogador"], prep["rival"]["lado"], semente, prep["rival"]["perfil"], perfil_auto)
	registrar_justa({"equipamento_final": sim["equipamento_final"], "gasta_folego": prep["gasta_folego"]})
	var r := concluir_disputa(torneio, indice, sim["eventos"], true)
	r["eventos"] = sim["eventos"]
	return r

## Duração real de um timer. No primeiro dia (GDD: regra do tutorial) todo
## timer termina em segundos; aqui é o ponto único onde isso entra.
func duracao_timer(segundos: int) -> int:
	var pd: Dictionary = Balanceamento.ler("inicio")["primeiro_dia"]
	if ServicoTempo.agora() - int(estado.get("criado_em", 0)) < int(pd["duracao_s"]):
		return mini(segundos, int(pd["timer_max_s"]))
	if vip_ativo():
		return segundos * (100 - int(Balanceamento.ler("economia")["vip"]["timer_reducao_pct"])) / 100
	return segundos

# ------------------------------------------------------------------ tutorial
# Passos (GDD Início do jogo): 0 título, 1 criação, 2 brasão, 3 justa de
# exibição, 4 primeira justa, 5 primeiro baú, 6 concluído (vila).

const TUTORIAL_CONCLUIDO := 6

func tutorial_passo() -> int:
	return int(estado["tutorial"]["passo"])

func tutorial_concluido() -> bool:
	return estado["tutorial"].get("concluido", false)

func _cmd_definir_passo_tutorial(passo: int) -> Dictionary:
	estado["tutorial"]["passo"] = clampi(passo, 0, TUTORIAL_CONCLUIDO)
	if passo >= TUTORIAL_CONCLUIDO:
		estado["tutorial"]["concluido"] = true
	return _concluir("tutorial")

## Recompensa do tutorial (uma vez só): ouro, XP até o nível 2 e a peça do
## primeiro baú, já equipada. Quem pula o tutorial também recebe.
## Devolve {ok, item (id), modelo, niveis}.
func _cmd_recompensa_tutorial() -> Dictionary:
	var t: Dictionary = estado["tutorial"]
	if t.get("recompensa_dada", false):
		return {"ok": true, "erro": "", "item": t.get("item_bau", ""), "modelo": "", "niveis": []}
	var cfg: Dictionary = Balanceamento.ler("inicio")["tutorial"]
	var modelo: String = cfg["item_bau"]
	var maximo := int(Balanceamento.ler("itens")["modelos"][modelo]["durabilidade_max"])
	var id := _novo_id(estado, "i")
	estado["inventario"]["itens"].append({"id": id, "modelo": modelo, "nivel": 0, "durabilidade": maximo})
	estado["equipamento"][Balanceamento.ler("itens")["modelos"][modelo]["espaco"]] = id
	var niveis := _ganhar(int(cfg["ouro"]), int(cfg["xp"]))
	t["recompensa_dada"] = true
	t["item_bau"] = id
	var r := _concluir("inventario")
	r.merge({"item": id, "modelo": modelo, "niveis": niveis}, true)
	return r

## Rival fraco da primeira justa (dados do tutorial).
func rival_tutorial() -> Dictionary:
	return _rival_de(Balanceamento.ler("inicio")["tutorial"]["rival_primeira_justa"], "tutorial")

func _garantir_predio(nome: String) -> void:
	if not estado["vila"]["predios"].has(nome):
		estado["vila"]["predios"][nome] = {"nivel": 1}

# ------------------------------------------------------------------- social
# Ordens, ajuda nos timers, doações, torneio semanal, loja da ordem, chat,
# amigos e perfil público (3.20; regra pura RegraOrdem, números em
# ordem.json, mensagens em game/data/social/chat.json). Até o servidor (3.8)
# TUDO isto é simulado: as ordens para entrar, os membros (fantasmas da liga),
# os pedidos de ajuda e de doação, as mensagens e as ordens rivais do torneio
# saem da semente do save, e as telas avisam. Dado de verdade, só o do próprio
# jogador (cargo, moeda, bloqueios, denúncias a enviar, amigos).

static func _social_novo() -> Dictionary:
	return {"codigo": "", "ordem": {}, "pedidos": [], "ajudei": {"balde": -1, "ids": []},
		"doacoes": {"dia": -1, "unidades": 0, "atendidos": []}, "ajuda_moeda": {"dia": -1, "moeda": 0}, "moeda": 0,
		"torneio": {"semana": -1, "vitorias": 0, "participou": false, "pendente": {}}, "loja": {"semana": -1, "compras": {}},
		"chat": {"ordem": [], "global": [], "ultimo_envio": 0, "sim_ordem": 0, "sim_global": 0, "contador": 0},
		"bloqueados": [], "denuncias": [], "amigos": []}

func cfg_ordem() -> Dictionary:
	return Balanceamento.ler("ordem")

func _social() -> Dictionary:
	if not estado.has("social"):
		estado["social"] = _social_novo()
	return estado["social"]

func moeda_ordem() -> int:
	return int(_social()["moeda"])

func tem_ordem() -> bool:
	return not (_social()["ordem"] as Dictionary).is_empty()

func cargo_na_ordem() -> String:
	return str(_social()["ordem"].get("cargo", ""))

## Brasão da ordem ({} sem ordem), para a bandeira da vila.
func brasao_da_ordem() -> Dictionary:
	return (_social()["ordem"].get("brasao", {}) as Dictionary).duplicate(true)

func pode_na_ordem(acao: String) -> bool:
	return tem_ordem() and RegraOrdem.pode(cargo_na_ordem(), acao, cfg_ordem())

## A ordem do jogador: {id, nome, brasao, cargo, criada_em, simulada, membros:
## [{id, nome, cargo, poder, pontos, simulado}]}; {} se não tem. A linha do
## próprio jogador ("voce") sai com o poder e os pontos de agora.
func ordem() -> Dictionary:
	var o: Dictionary = (_social()["ordem"] as Dictionary).duplicate(true)
	if o.is_empty():
		return o
	for m: Dictionary in o["membros"]:
		if m["id"] == "voce":
			m["nome"] = cavaleiro().get("nome", "")
			m["poder"] = poder_jogador()
			m["pontos"] = int(estado["liga"]["pontos"])
	return o

func _nomes_ordens() -> Array:
	var casas: Array = Balanceamento.ler_json("res://game/data/texto/nomes_sorteio.json")["casas"]
	return casas.map(func(c): return str(c).replace("Casa", "Ordem"))

## Ordens simuladas para entrar (até o servidor): [{id, nome, membros, poder, brasao}].
func ordens_para_entrar() -> Array:
	var op := GeradorBrasao.opcoes()
	return RegraOrdem.ordens_simuladas(int(estado["baus"]["semente"]), cfg_ordem(), _nomes_ordens(), op["cores"], op["simbolos"].keys(), op["divisoes"])

func _membro_simulado(ordem_n: int, k: int, cargo: String) -> Dictionary:
	var n := 900000 + ordem_n * 64 + k
	var base := int(estado["liga"]["pontos"])
	var f := _fantasma(n, base)
	return {"id": "m%d_%d" % [ordem_n, k], "nome": f["nome"], "cargo": cargo, "n": n, "base": base, "poder": int(f["poder"]),
		"pontos": int(f["pontos"]), "simulado": true}

func _brasao_da_casa() -> Dictionary:
	var b: Dictionary = casa().get("brasao", {})
	if b.is_empty():
		var cores: Dictionary = casa()["cores"]
		b = {"cor1": cores["principal"], "cor2": cores["secundaria"], "cor_simbolo": cores["secundaria"]}
	return b.duplicate(true)

## {ok, erro, ouro}: dá para criar uma ordem (com este nome, se informado)?
func pode_criar_ordem(nome := "") -> Dictionary:
	var cfg := cfg_ordem()
	if tem_ordem():
		return _erro("ja_tem_ordem")
	if int(cavaleiro()["nivel"]) < int(cfg["nivel_minimo"]):
		return _erro("nivel_baixo")
	if nome != "":
		var e := ServicoNomes.validar(nome)
		if e == "" and ServicoNomes.limpar(nome).length() < int(cfg["nome"]["min"]):
			e = "nome_curto"
		if e != "":
			return _erro(e)
	if ouro() < int(cfg["criar"]["ouro"]):
		return _erro("ouro_insuficiente")
	return {"ok": true, "erro": "", "ouro": int(cfg["criar"]["ouro"])}

func criar_ordem(nome: String) -> Dictionary:
	var p := pode_criar_ordem(nome)
	if not p["ok"]:
		return p
	var cfg := cfg_ordem()
	estado["inventario"]["ouro"] = ouro() - int(cfg["criar"]["ouro"])
	var membros: Array = [{"id": "voce", "nome": cavaleiro().get("nome", ""), "cargo": "lider", "n": 0, "base": 0,
		"poder": poder_jogador(), "pontos": int(estado["liga"]["pontos"]), "simulado": false}]
	for k in int(cfg["criar"]["recrutas"]):
		membros.append(_membro_simulado(40, k, "membro"))
	_social()["ordem"] = {"id": "o_voce", "nome": ServicoNomes.limpar(nome), "brasao": _brasao_da_casa(), "cargo": "lider",
		"criada_em": ServicoTempo.agora(), "simulada": true, "membros": membros}
	_marcar_participacao()
	return _concluir("social")

func entrar_ordem(id: String) -> Dictionary:
	var cfg := cfg_ordem()
	if tem_ordem():
		return _erro("ja_tem_ordem")
	if int(cavaleiro()["nivel"]) < int(cfg["nivel_minimo"]):
		return _erro("nivel_baixo")
	for o: Dictionary in ordens_para_entrar():
		if o["id"] != id:
			continue
		if not RegraOrdem.tem_vaga(int(o["membros"]), cfg):
			return _erro("ordem_cheia")
		var idx := int(str(id).substr(1))
		var membros: Array = []
		for k in int(o["membros"]):
			membros.append(_membro_simulado(idx, k, "lider" if k == 0 else ("oficial" if k <= 2 else "membro")))
		membros.append({"id": "voce", "nome": cavaleiro().get("nome", ""), "cargo": "membro", "n": 0, "base": 0,
			"poder": poder_jogador(), "pontos": int(estado["liga"]["pontos"]), "simulado": false})
		_social()["ordem"] = {"id": str(o["id"]), "nome": o["nome"], "brasao": (o["brasao"] as Dictionary).duplicate(true), "cargo": "membro",
			"criada_em": ServicoTempo.agora(), "simulada": true, "membros": membros}
		_marcar_participacao()
		return _concluir("social")
	return _erro("ordem_inexistente")

func _marcar_participacao() -> void:
	_virar_semana_torneio()
	_social()["torneio"]["participou"] = true

## Sair: o líder precisa passar a liderança antes (ou dissolver).
func sair_ordem() -> Dictionary:
	if not tem_ordem():
		return _erro("sem_ordem")
	var o: Dictionary = _social()["ordem"]
	if o["cargo"] == "lider" and (o["membros"] as Array).size() > 1:
		return _erro("passe_a_lideranca")
	_limpar_ordem()
	return _concluir("social")

func _limpar_ordem() -> void:
	var s := _social()
	s["ordem"] = {}
	s["pedidos"] = []
	s["chat"]["ordem"] = []
	s["chat"]["sim_ordem"] = 0

func dissolver_ordem() -> Dictionary:
	if not pode_na_ordem("dissolver"):
		return _erro("sem_permissao")
	_limpar_ordem()
	return _concluir("social")

## Promover, rebaixar ou expulsar (acao) o membro `id`, pelas permissões do cargo.
func agir_sobre_membro(id: String, acao: String) -> Dictionary:
	var o: Dictionary = _social()["ordem"]
	if o.is_empty():
		return _erro("sem_ordem")
	for m: Dictionary in o["membros"]:
		if m["id"] != id:
			continue
		if id == "voce" or not RegraOrdem.pode_sobre(str(o["cargo"]), str(m["cargo"]), acao, cfg_ordem()):
			return _erro("sem_permissao")
		if acao == "expulsar":
			(o["membros"] as Array).erase(m)
		else:
			m["cargo"] = RegraOrdem.cargo_depois(str(m["cargo"]), acao)
		return _concluir("social")
	return _erro("membro_inexistente")

func passar_lideranca(id: String) -> Dictionary:
	if not pode_na_ordem("passar_lideranca"):
		return _erro("sem_permissao")
	var o: Dictionary = _social()["ordem"]
	for m: Dictionary in o["membros"]:
		if m["id"] == id and id != "voce":
			m["cargo"] = "lider"
			o["cargo"] = "oficial"
			for eu: Dictionary in o["membros"]:
				if eu["id"] == "voce":
					eu["cargo"] = "oficial"
			return _concluir("social")
	return _erro("membro_inexistente")

func editar_brasao_ordem(brasao: Dictionary) -> Dictionary:
	if not pode_na_ordem("editar_brasao"):
		return _erro("sem_permissao")
	_social()["ordem"]["brasao"] = GeradorBrasao.completar(brasao)
	return _concluir("social")

func renomear_ordem(nome: String) -> Dictionary:
	if not pode_na_ordem("editar_nome"):
		return _erro("sem_permissao")
	var e := ServicoNomes.validar(nome)
	if e == "" and ServicoNomes.limpar(nome).length() < int(cfg_ordem()["nome"]["min"]):
		e = "nome_curto"
	if e != "":
		return _erro(e)
	_social()["ordem"]["nome"] = ServicoNomes.limpar(nome)
	return _concluir("social")

func _membros_visiveis() -> Array:
	var r: Array = []
	for m: Dictionary in _social()["ordem"].get("membros", []):
		if m["id"] != "voce" and not (_social()["bloqueados"] as Array).has(m["id"]):
			r.append(m)
	return r

# ----- ajuda nos timers

## Timers do jogador que a ordem pode ajudar: [{id, tipo, alvo, restante_s, pedido}].
func timers_para_pedir_ajuda() -> Array:
	var tipos: Array = cfg_ordem()["ajuda"]["tipos"]
	var r: Array = []
	for t: Dictionary in estado["timers"]:
		if tipos.has(t["tipo"]) and not ServicoTempo.pronto(int(t["termina_em"])):
			r.append({"id": t["id"], "tipo": t["tipo"], "alvo": t["alvo"], "restante_s": ServicoTempo.restante(int(t["termina_em"])),
				"pedido": not pedido_do_timer(t["id"]).is_empty()})
	return r

func pedido_do_timer(timer_id: String) -> Dictionary:
	for p: Dictionary in _social()["pedidos"]:
		if p["timer"] == timer_id:
			return p.duplicate(true)
	return {}

func _timer_ref(id: String) -> Dictionary:
	for t: Dictionary in estado["timers"]:
		if t["id"] == id:
			return t
	return {}

## Pede ajuda da ordem para um timer: sorteia quem ajuda e quando (simulado).
func pedir_ajuda(timer_id: String) -> Dictionary:
	if not tem_ordem():
		return _erro("sem_ordem")
	var cfg: Dictionary = cfg_ordem()["ajuda"]
	var t := _timer_ref(timer_id)
	if t.is_empty() or ServicoTempo.pronto(int(t["termina_em"])) or not (cfg["tipos"] as Array).has(t["tipo"]):
		return _erro("timer_inexistente")
	if not pedido_do_timer(timer_id).is_empty():
		return _erro("ja_pediu")
	var pool := _membros_visiveis().map(func(m): return m["id"])
	if pool.is_empty():
		return _erro("sem_membros")
	var rng := Aleatorio.new(_semente_servico())
	var ajudantes: Array = []
	var atrasos: Array = []
	var acumulado := 0
	for i in mini(int(cfg["ajudas_max_por_pedido"]), pool.size()):
		ajudantes.append(pool.pop_at(rng.inteiro(0, pool.size() - 1)))
		acumulado += rng.inteiro(int(cfg["resposta_s"][0]), int(cfg["resposta_s"][1]))
		atrasos.append(acumulado)
	(_social()["pedidos"] as Array).append({"id": _novo_id(estado, "a"), "timer": timer_id, "em": ServicoTempo.agora(),
		"ajudantes": ajudantes, "atrasos": atrasos, "aplicadas": 0})
	return _concluir("social")

## Aplica as ajudas que já "chegaram" (os membros simulados respondem com
## atraso) e descarta pedidos de timer que acabou. Devolve quantas aplicou.
func atualizar_ajudas() -> int:
	var pedidos: Array = _social()["pedidos"]
	if pedidos.is_empty():
		return 0
	var cfg := cfg_ordem()
	var agora := ServicoTempo.agora()
	var aplicadas := 0
	var manter: Array = []
	for p: Dictionary in pedidos:
		var t := _timer_ref(str(p["timer"]))
		if t.is_empty() or ServicoTempo.pronto(int(t["termina_em"])):
			continue
		var atrasos: Array = p["atrasos"]
		while int(p["aplicadas"]) < atrasos.size() and agora - int(p["em"]) >= int(atrasos[int(p["aplicadas"])]):
			t["termina_em"] = int(t["termina_em"]) - RegraOrdem.segundos_da_ajuda(ServicoTempo.restante(int(t["termina_em"])), cfg)
			p["aplicadas"] = int(p["aplicadas"]) + 1
			aplicadas += 1
		manter.append(p)
	var mudou_lista := manter.size() != pedidos.size()
	_social()["pedidos"] = manter
	if aplicadas > 0 or mudou_lista:
		_concluir("social")
	return aplicadas

## Pedidos de ajuda dos membros (simulados; trocam a cada `balde_s`):
## [{id, membro_id, nome, tipo, ajudado}].
func pedidos_da_ordem() -> Array:
	if not tem_ordem():
		return []
	var cfg: Dictionary = cfg_ordem()["ajuda"]
	var balde := ServicoTempo.agora() / int(cfg["balde_s"])
	var rng := Aleatorio.new(int(estado["baus"]["semente"]) + 7919 * (balde + 1))
	var candidatos := _membros_visiveis()
	var feitos: Array = _social()["ajudei"]["ids"] if int(_social()["ajudei"]["balde"]) == balde else []
	var tipos: Array = cfg["tipos"]
	var r: Array = []
	for i in mini(int(cfg["pedidos_simulados"]), candidatos.size()):
		var m: Dictionary = candidatos.pop_at(rng.inteiro(0, candidatos.size() - 1))
		var id := "p%d_%d" % [balde, i]
		r.append({"id": id, "membro_id": m["id"], "nome": m["nome"], "tipo": tipos[rng.inteiro(0, tipos.size() - 1)], "ajudado": feitos.has(id)})
	return r

## Ajuda um pedido da ordem: ganha moeda da ordem (com teto por dia).
func ajudar(id: String) -> Dictionary:
	for p: Dictionary in pedidos_da_ordem():
		if p["id"] != id:
			continue
		if p["ajudado"]:
			return _erro("ja_ajudou")
		var s := _social()
		var am: Dictionary = s["ajuda_moeda"]
		if int(am["dia"]) != dia_atual():
			am["dia"] = dia_atual()
			am["moeda"] = 0
		var g := RegraOrdem.moeda_da_ajuda(int(am["moeda"]), cfg_ordem())
		am["moeda"] = int(am["moeda"]) + g
		s["moeda"] = int(s["moeda"]) + g
		var balde := ServicoTempo.agora() / int(cfg_ordem()["ajuda"]["balde_s"])
		if int(s["ajudei"]["balde"]) != balde:
			s["ajudei"] = {"balde": balde, "ids": []}
		(s["ajudei"]["ids"] as Array).append(id)
		_evento("ajuda_ordem")
		var r := _concluir("social")
		r["moeda"] = g
		return r
	return _erro("pedido_inexistente")

# ----- doações

## Pedidos de material dos membros (simulados; trocam a cada dia):
## [{id, membro_id, nome, material, quantidade, atendido}].
func pedidos_de_doacao() -> Array:
	if not tem_ordem():
		return []
	var cfg: Dictionary = cfg_ordem()["doacao"]
	var dia := dia_atual()
	var rng := Aleatorio.new(int(estado["baus"]["semente"]) + 104729 * (dia + 1))
	var candidatos := _membros_visiveis()
	var d: Dictionary = _social()["doacoes"]
	var atendidos: Array = d["atendidos"] if int(d["dia"]) == dia else []
	var mats: Array = (cfg["materiais"] as Dictionary).keys()
	mats.sort()
	var r: Array = []
	for i in mini(int(cfg["pedidos_simulados"]), candidatos.size()):
		var m: Dictionary = candidatos.pop_at(rng.inteiro(0, candidatos.size() - 1))
		var mat: String = mats[rng.inteiro(0, mats.size() - 1)]
		var faixa: Array = cfg["materiais"][mat]
		var id := "d%d_%d" % [dia, i]
		r.append({"id": id, "membro_id": m["id"], "nome": m["nome"], "material": mat,
			"quantidade": rng.inteiro(int(faixa[0]), int(faixa[1])), "atendido": atendidos.has(id)})
	return r

## Unidades que ainda podem ser doadas hoje.
func doacao_restante_hoje() -> int:
	var d: Dictionary = _social()["doacoes"]
	return RegraOrdem.doacao_restante(int(d["unidades"]) if int(d["dia"]) == dia_atual() else 0, cfg_ordem())

func doar(id: String) -> Dictionary:
	for p: Dictionary in pedidos_de_doacao():
		if p["id"] != id:
			continue
		if p["atendido"]:
			return _erro("ja_doou")
		var q := int(p["quantidade"])
		if q > doacao_restante_hoje():
			return _erro("limite_diario")
		if material(p["material"]) < q:
			return _erro("material_insuficiente")
		var s := _social()
		var d: Dictionary = s["doacoes"]
		if int(d["dia"]) != dia_atual():
			d["dia"] = dia_atual()
			d["unidades"] = 0
			d["atendidos"] = []
		_gastar_materiais({p["material"]: q})
		d["unidades"] = int(d["unidades"]) + q
		(d["atendidos"] as Array).append(id)
		var g := int(cfg_ordem()["doacao"]["moeda_por_doacao"])
		s["moeda"] = int(s["moeda"]) + g
		_evento("doacao_ordem")
		var r := _concluir("social")
		r["moeda"] = g
		return r
	return _erro("pedido_inexistente")

# ----- torneio semanal e loja da ordem

## Início da semana `semana` (a segunda na hora da virada do dia).
func _inicio_da_semana(semana: int) -> int:
	return (semana * 7 - 3) * 86400 + int(cfg_metas()["virada_hora_utc"]) * 3600

## Fecha a semana que passou (guarda o prêmio a resgatar) e abre a atual.
func _virar_semana_torneio() -> void:
	var t: Dictionary = _social()["torneio"]
	var semana := semana_atual()
	if int(t["semana"]) == semana:
		return
	if int(t["semana"]) >= 0 and t.get("participou", false) and tem_ordem():
		var fin := _resultado_torneio(int(t["semana"]), 1000, int(t["vitorias"]))
		var pr := RegraOrdem.premio_do_torneio(int(fin["posicao"]), cfg_ordem())
		t["pendente"] = {"semana": int(t["semana"]), "posicao": int(fin["posicao"]), "moeda": int(pr["moeda"]), "bau": pr["bau"]}
	t["semana"] = semana
	t["vitorias"] = 0
	t["participou"] = tem_ordem()

## {minhas, posicao, ordens: [{nome, pontos, voce}] por pontos}. fracao = 0..1000 da semana.
func _resultado_torneio(semana: int, fracao: int, vitorias_jogador: int) -> Dictionary:
	var cfg := cfg_ordem()
	var sem := int(estado["baus"]["semente"])
	var o: Dictionary = _social()["ordem"]
	var minhas := mini(vitorias_jogador, int(cfg["torneio"]["vitorias_do_jogador_max"]))
	var idx := 0
	for m: Dictionary in o.get("membros", []):
		if m["id"] != "voce":
			minhas += RegraOrdem.vitorias_simuladas(sem + 17, semana, idx, fracao, cfg)
			idx += 1
	var nomes := _nomes_ordens()
	nomes.erase(o.get("nome", ""))
	var rng := Aleatorio.new(sem + 5003 * (semana + 1))
	var lista: Array = []
	var outras: Array = []
	for i in mini(int(cfg["torneio"]["ordens_simuladas"]), nomes.size()):
		var nome: String = nomes.pop_at(rng.inteiro(0, nomes.size() - 1))
		var membros := rng.inteiro(int(cfg["simuladas"]["membros"][0]), int(cfg["simuladas"]["membros"][1]))
		var pontos := 0
		for k in membros:
			pontos += RegraOrdem.vitorias_simuladas(sem + 977 * (i + 1), semana, k, fracao, cfg)
		lista.append({"nome": nome, "pontos": pontos, "voce": false})
		outras.append(pontos)
	lista.append({"nome": o.get("nome", ""), "pontos": minhas, "voce": true})
	lista.sort_custom(func(a, b): return int(a["pontos"]) > int(b["pontos"]) or (int(a["pontos"]) == int(b["pontos"]) and a["voce"]))
	return {"minhas": minhas, "posicao": RegraOrdem.posicao_no_torneio(minhas, outras), "ordens": lista}

## Torneio de Ordens desta semana (simulado): {semana, restante_s, minhas_vitorias,
## pontos, posicao, premio, ordens, pendente}; {} sem ordem.
func torneio_semana() -> Dictionary:
	if not tem_ordem():
		return {}
	_virar_semana_torneio()
	var t: Dictionary = _social()["torneio"]
	var semana := semana_atual()
	var inicio := _inicio_da_semana(semana)
	var fracao := clampi((ServicoTempo.agora() - inicio) * 1000 / (7 * 86400), 0, 1000)
	var r := _resultado_torneio(semana, fracao, int(t["vitorias"]))
	return {"semana": semana, "restante_s": maxi(0, inicio + 7 * 86400 - ServicoTempo.agora()), "minhas_vitorias": int(t["vitorias"]),
		"pontos": int(r["minhas"]), "posicao": int(r["posicao"]), "ordens": r["ordens"],
		"premio": RegraOrdem.premio_do_torneio(int(r["posicao"]), cfg_ordem()), "pendente": (t["pendente"] as Dictionary).duplicate(true)}

## Resgata o prêmio da semana passada (moeda da ordem e baú).
func resgatar_torneio() -> Dictionary:
	if tem_ordem():
		_virar_semana_torneio()
	var t: Dictionary = _social()["torneio"]
	var p: Dictionary = t["pendente"]
	if p.is_empty():
		return _erro("sem_premio")
	var s := _social()
	s["moeda"] = int(s["moeda"]) + int(p["moeda"])
	var bau := {}
	if str(p["bau"]) != "":
		bau = _guardar_bau(str(p["bau"]))
	t["pendente"] = {}
	var r := _concluir("social")
	r.merge({"moeda": int(p["moeda"]), "bau_ganho": bau, "posicao": int(p["posicao"])}, true)
	return r

## Itens da loja da ordem: [{id, moeda, conteudo, projeto, restantes, erro, pode}].
func loja_ordem() -> Array:
	var l: Dictionary = _social()["loja"]
	if int(l["semana"]) != semana_atual():
		l["semana"] = semana_atual()
		l["compras"] = {}
	var r: Array = []
	for it: Dictionary in cfg_ordem()["loja"]["itens"]:
		var comprados := int(l["compras"].get(it["id"], 0))
		var erro := RegraOrdem.erro_da_compra(moeda_ordem(), comprados, it)
		if erro == "" and it.has("projeto") and (estado["inventario"]["projetos"] as Array).has(it["projeto"]):
			erro = "projeto_ja_tenho"
		r.append({"id": it["id"], "moeda": int(it["moeda"]), "conteudo": (it.get("conteudo", {}) as Dictionary).duplicate(), "projeto": str(it.get("projeto", "")),
			"restantes": int(it["limite_semana"]) - comprados, "erro": erro, "pode": erro == ""})
	return r

func comprar_da_ordem(id: String) -> Dictionary:
	for it: Dictionary in loja_ordem():
		if it["id"] != id:
			continue
		if not it["pode"]:
			return _erro(str(it["erro"]))
		var s := _social()
		s["moeda"] = int(s["moeda"]) - int(it["moeda"])
		s["loja"]["compras"][id] = int(s["loja"]["compras"].get(id, 0)) + 1
		if str(it["projeto"]) != "":
			(estado["inventario"]["projetos"] as Array).append(it["projeto"])
		else:
			_entregar_conteudo(it["conteudo"])
		return _concluir("social")
	return _erro("produto_inexistente")

# ----- chat, denúncia e bloqueio

func _idioma_chat() -> String:
	return "en" if TranslationServer.get_locale().begins_with("en") else "pt"

func mensagens_rapidas() -> Array:
	return (Balanceamento.ler_json("res://game/data/social/chat.json")["rapidas"] as Array).duplicate()

func _chat_msg(canal: String, de_id: String, de_nome: String, texto: String, chave: String, em := -1) -> void:
	var c: Dictionary = _social()["chat"]
	c["contador"] = int(c["contador"]) + 1
	var lista: Array = c[canal]
	lista.append({"id": int(c["contador"]), "de_id": de_id, "de_nome": de_nome, "texto": texto, "chave": chave,
		"em": ServicoTempo.agora() if em < 0 else em, "idioma": _idioma_chat(), "simulado": de_id != "voce"})
	while lista.size() > int(cfg_ordem()["chat"]["mensagens_max"]):
		lista.pop_front()

## Mensagens do canal ("ordem" ou "global") sem as de bloqueados; o global só
## mostra o idioma atual.
func chat_mensagens(canal: String) -> Array:
	var s := _social()
	var r: Array = []
	var idioma := _idioma_chat()
	for m: Dictionary in s["chat"].get(canal, []):
		if (s["bloqueados"] as Array).has(m["de_id"]):
			continue
		if canal == "global" and m["idioma"] != idioma:
			continue
		r.append(m.duplicate())
	return r

## Os membros e jogadores simulados "falam" com o tempo (no máximo
## `simulado_por_abertura_max` de uma vez). Devolve quantas mensagens entraram.
func chat_atualizar() -> int:
	var cfg: Dictionary = cfg_ordem()["chat"]
	var dados := Balanceamento.ler_json("res://game/data/social/chat.json")
	var c: Dictionary = _social()["chat"]
	var agora := ServicoTempo.agora()
	var intervalo := int(cfg["simulado_intervalo_s"])
	var novas := 0
	for canal: String in ["ordem", "global"]:
		if canal == "ordem" and not tem_ordem():
			continue
		var chave_t := "sim_" + canal
		var ultimo := int(c[chave_t])
		if ultimo == 0:
			ultimo = agora - 3 * intervalo
		var n := mini((agora - ultimo) / intervalo, int(cfg["simulado_por_abertura_max"]))
		if n <= 0:
			continue
		var rng := Aleatorio.new(int(estado["baus"]["semente"]) + 31337 * (int(c["contador"]) + 1) + (1 if canal == "global" else 2))
		var falas: Array = dados["simuladas_" + canal]
		var remetentes := _membros_visiveis()
		for i in n:
			var de_id := ""
			var de_nome := ""
			if canal == "ordem":
				if remetentes.is_empty():
					break
				var m: Dictionary = remetentes[rng.inteiro(0, remetentes.size() - 1)]
				de_id = m["id"]
				de_nome = m["nome"]
			else:
				var k := rng.inteiro(0, int(cfg_ordem()["amigos"]["pool_simulado"]) - 1)
				de_id = "f%d" % (1100000 + k)
				de_nome = _fantasma(1100000 + k, int(estado["liga"]["pontos"]))["nome"]
			_chat_msg(canal, de_id, de_nome, "", falas[rng.inteiro(0, falas.size() - 1)], agora - (n - 1 - i) * 20)
			novas += 1
		c[chave_t] = agora
	if novas > 0:
		_concluir("chat")
	return novas

## Envia uma mensagem (rápida pelo id, ou texto livre filtrado). Só vai para
## a tela local até o servidor.
func chat_enviar(canal: String, texto := "", rapida := "") -> Dictionary:
	var cfg: Dictionary = cfg_ordem()["chat"]
	var c: Dictionary = _social()["chat"]
	if canal != "ordem" and canal != "global":
		return _erro("canal_inexistente")
	if canal == "ordem" and not tem_ordem():
		return _erro("sem_ordem")
	if ServicoTempo.agora() - int(c["ultimo_envio"]) < int(cfg["intervalo_envio_s"]):
		return _erro("enviando_rapido")
	var nome: String = cavaleiro().get("nome", "")
	if rapida != "":
		if not mensagens_rapidas().has(rapida):
			return _erro("mensagem_inexistente")
		_chat_msg(canal, "voce", nome, "", rapida)
	else:
		var t := ServicoNomes.limpar(texto)
		if t == "":
			return _erro("mensagem_vazia")
		if t.length() > int(cfg["texto_max"]):
			return _erro("mensagem_longa")
		if ServicoNomes.texto_ofensivo(t):
			return _erro("mensagem_ofensiva")
		_chat_msg(canal, "voce", nome, t, "")
	c["ultimo_envio"] = ServicoTempo.agora()
	return _concluir("chat")

func bloqueados() -> Array:
	return (_social()["bloqueados"] as Array).duplicate()

func esta_bloqueado(id: String) -> bool:
	return (_social()["bloqueados"] as Array).has(id)

func bloquear(id: String) -> Dictionary:
	if id == "" or id == "voce":
		return _erro("alvo_invalido")
	var s := _social()
	if not (s["bloqueados"] as Array).has(id):
		s["bloqueados"].append(id)
	var amigo_id := id
	for m: Dictionary in s["ordem"].get("membros", []):
		if m["id"] == id:
			amigo_id = "f%d" % int(m["n"])
	s["amigos"] = (s["amigos"] as Array).filter(func(a): return a["id"] != id and a["id"] != amigo_id)
	return _concluir("social")

func desbloquear(id: String) -> Dictionary:
	_social()["bloqueados"] = (_social()["bloqueados"] as Array).filter(func(b): return b != id)
	return _concluir("social")

## Denúncia guardada para enviar ao servidor (fila de moderação, 3.8).
func denunciar(alvo_id: String, nome: String, motivo: String, trecho := "") -> Dictionary:
	var cfg: Dictionary = cfg_ordem()["chat"]
	if alvo_id == "" or alvo_id == "voce":
		return _erro("alvo_invalido")
	if not (cfg["motivos_denuncia"] as Array).has(motivo):
		return _erro("motivo_invalido")
	var lista: Array = _social()["denuncias"]
	var recorte := trecho.substr(0, int(cfg["texto_max"]))
	for d: Dictionary in lista:
		if d["alvo"] == alvo_id and d["trecho"] == recorte and not d["enviada"]:
			return _erro("ja_denunciado")
	lista.append({"alvo": alvo_id, "nome": nome, "motivo": motivo, "trecho": recorte, "em": ServicoTempo.agora(), "enviada": false})
	while lista.size() > int(cfg["denuncias_max"]):
		lista.pop_front()
	return _concluir("social")

func denuncias_pendentes() -> Array:
	return (_social()["denuncias"] as Array).filter(func(d): return not d["enviada"]).map(func(d): return d.duplicate())

# ----- amigos e perfil público

## Código para os outros te adicionarem (pela semente do save).
func meu_codigo() -> String:
	var s := _social()
	if str(s["codigo"]) == "":
		s["codigo"] = RegraOrdem.codigo_amigo(int(estado["baus"]["semente"]))
	return s["codigo"]

func amigos() -> Array:
	return (_social()["amigos"] as Array).duplicate(true)

func _ehamigo(id: String) -> bool:
	return (_social()["amigos"] as Array).any(func(a): return a["id"] == id)

## Jogadores simulados que o código pode achar (até o servidor): do pool e
## da própria ordem. {n, base, nome} ou {}.
func _achar_por_codigo(codigo: String) -> Dictionary:
	var base := int(estado["liga"]["pontos"])
	for k in int(cfg_ordem()["amigos"]["pool_simulado"]):
		if RegraOrdem.codigo_amigo(1100000 + k) == codigo:
			return {"n": 1100000 + k, "base": base}
	for m: Dictionary in _social()["ordem"].get("membros", []):
		if m["id"] != "voce" and RegraOrdem.codigo_amigo(int(m["n"])) == codigo:
			return {"n": int(m["n"]), "base": int(m["base"])}
	return {}

## Código de um jogador simulado (do pool ou membro): para a tela de perfil.
func codigo_de(n: int) -> String:
	return RegraOrdem.codigo_amigo(n)

## Códigos de teste (os primeiros do pool simulado), só para build de depuração.
func codigos_de_teste(quantos := 3) -> Array:
	var r: Array = []
	for k in quantos:
		r.append({"codigo": RegraOrdem.codigo_amigo(1100000 + k), "nome": _fantasma(1100000 + k, int(estado["liga"]["pontos"]))["nome"]})
	return r

func adicionar_amigo_por_codigo(texto: String) -> Dictionary:
	if not RegraOrdem.codigo_valido(texto):
		return _erro("codigo_invalido")
	var codigo := RegraOrdem.normalizar_codigo(texto)
	if codigo == meu_codigo():
		return _erro("codigo_proprio")
	var a := _achar_por_codigo(codigo)
	if a.is_empty():
		return _erro("codigo_nao_encontrado")
	return _fazer_amigo("f%d" % int(a["n"]), int(a["n"]), int(a["base"]))

## Adiciona como amigo um membro da ordem ("m…") ou um jogador simulado
## que apareceu num perfil ("f<n>").
func adicionar_amigo(id: String) -> Dictionary:
	var p := perfil_publico(id)
	if p.is_empty() or id == "voce" or id == "":
		return _erro("membro_inexistente")
	return _fazer_amigo(str(p["id"]), int(str(p["id"]).substr(1)), int(p["base"]))

func adicionar_amigo_membro(id: String) -> Dictionary:
	return adicionar_amigo(id)

## Números (n) dos membros da ordem que estão bloqueados (pelo id do membro).
func _membros_bloqueados_n() -> Array:
	var r: Array = []
	for m: Dictionary in _social()["ordem"].get("membros", []):
		if (_social()["bloqueados"] as Array).has(m["id"]):
			r.append(int(m["n"]))
	return r

func _fazer_amigo(id: String, n: int, base: int) -> Dictionary:
	var s := _social()
	if _ehamigo(id):
		return _erro("ja_amigo")
	if esta_bloqueado(id) or _membros_bloqueados_n().has(n):
		return _erro("bloqueado")
	if (s["amigos"] as Array).size() >= int(cfg_ordem()["amigos"]["max"]):
		return _erro("amigos_cheio")
	var f := _fantasma(n, base)
	(s["amigos"] as Array).append({"id": id, "nome": f["nome"], "n": n, "base": base, "desde": ServicoTempo.agora()})
	return _concluir("social")

func remover_amigo(id: String) -> Dictionary:
	var s := _social()
	s["amigos"] = (s["amigos"] as Array).filter(func(a): return a["id"] != id)
	return _concluir("social")

## Perfil público: cavaleiro, cavalo, brasão, liga e títulos. `id` = "voce" (ou
## "") para o próprio; membro da ordem ("m…"), amigo ("f<n>") ou jogador de
## ranking simulado ("f<n>"). {} se não existe.
func perfil_publico(id := "voce") -> Dictionary:
	if id == "" or id == "voce":
		return _perfil_proprio()
	var n := -1
	var base := int(estado["liga"]["pontos"])
	var cargo := ""
	for m: Dictionary in _social()["ordem"].get("membros", []):
		if m["id"] == id and id != "voce":
			n = int(m["n"])
			base = int(m["base"])
			cargo = str(m["cargo"])
	if n < 0:
		for a: Dictionary in _social()["amigos"]:
			if a["id"] == id:
				n = int(a["n"])
				base = int(a["base"])
	if n < 0 and id.begins_with("f") and id.substr(1).is_valid_int():
		n = int(id.substr(1))
	if n < 0:
		return {}
	var p := _perfil_fantasma(n, base)
	p["cargo"] = cargo
	if cargo != "":
		p["ordem_nome"] = str(_social()["ordem"].get("nome", ""))
	p["amigo"] = _ehamigo("f%d" % n)
	p["codigo"] = RegraOrdem.codigo_amigo(n)
	p["base"] = base
	return p

func _perfil_proprio() -> Dictionary:
	var cav := cavaleiro()
	var cont: Dictionary = estado["metas"]["contadores"]
	var lg := liga_atual()
	var cores: Dictionary = casa()["cores"]
	return {"id": "voce", "simulado": false, "nome": cav.get("nome", ""), "nivel": int(cav["nivel"]), "casa_nome": casa().get("nome", ""),
		"casa": {"principal": cores["principal"], "secundaria": cores["secundaria"], "metal": cores.get("metal", "ferro"),
			"pele": cav.get("pele", "media"), "cabelo": cav.get("cor_cabelo", "castanho")},
		"brasao": _brasao_da_casa(), "corpo": cav.get("corpo", "masculino"), "rosto": cav.get("rosto", "1"), "cabelo": cav.get("cabelo", "1"),
		"pelagem": cavalo_ativo().get("pelagem", "alazao"), "liga": {"nome": lg["nome"], "divisao": lg["divisao"], "pontos": lg["pontos"]},
		"melhor_liga": str(estado["liga"]["melhor"]), "poder": poder_jogador(), "titulo": titulo(), "titulos": titulos(), "renome": renome(),
		"ordem_nome": str(_social()["ordem"].get("nome", "")), "cargo": cargo_na_ordem(), "amigo": false, "codigo": meu_codigo(),
		"melhores": {"vitorias": int(cont.get("vitoria", 0)), "tres_estrelas": int(cont.get("tres_estrelas", 0)),
			"derrubadas": int(cont.get("derrubada", 0)), "regioes": int(cont.get("regiao_vencida", 0))}}

## Perfil de um jogador simulado (n = o número do fantasma; aparência e
## títulos pela semente dele).
func _perfil_fantasma(n: int, base: int) -> Dictionary:
	var f := _fantasma(n, base)
	var rng := Aleatorio.new(n * 31 + 7)
	var op: Dictionary = Balanceamento.ler_json("res://game/data/personagem/opcoes_criacao.json")
	var lg := RegraLiga.posicao(int(f["pontos"]), cfg_ligas())
	var com_titulo: Array = cfg_metas()["conquistas"].filter(func(c): return c.has("titulo")).map(func(c): return c["titulo"])
	var titulos_f: Array = []
	for i in clampi(int(f["pontos"]) / 150, 0, 3):
		var t: String = com_titulo[rng.inteiro(0, com_titulo.size() - 1)]
		if not titulos_f.has(t):
			titulos_f.append(t)
	var brasao: Dictionary = GeradorBrasao.opcoes().get("rivais", {}).get(f["brasao_perfil"], {})
	var peles: Array = op["peles"]
	var cabelos: Array = op["cores_cabelo"]
	return {"id": "f%d" % n, "simulado": true, "nome": str(f["nome"]).get_slice(" · ", 0), "nivel": clampi(int(f["poder"]) / 2 + 1, 1, 60),
		"casa_nome": str(f["nome"]).get_slice(" · ", 1),
		"casa": {"principal": f["casa"]["principal"], "secundaria": f["casa"]["secundaria"], "metal": "ferro",
			"pele": peles[rng.inteiro(0, peles.size() - 1)], "cabelo": cabelos[rng.inteiro(0, cabelos.size() - 1)]},
		"brasao": brasao, "corpo": (op["corpos"] as Array)[rng.inteiro(0, (op["corpos"] as Array).size() - 1)], "rosto": "1",
		"cabelo": (op["cabelos"] as Array)[rng.inteiro(0, (op["cabelos"] as Array).size() - 1)],
		"pelagem": (op["pelagens"] as Array)[rng.inteiro(0, (op["pelagens"] as Array).size() - 1)],
		"liga": {"nome": lg["nome"], "divisao": lg["divisao"], "pontos": int(f["pontos"])}, "melhor_liga": str(lg["nome"]),
		"poder": int(f["poder"]), "titulo": titulos_f[0] if not titulos_f.is_empty() else "", "titulos": titulos_f,
		"renome": int(f["pontos"]) / 4, "ordem_nome": "", "cargo": "", "amigo": false,
		"melhores": {"vitorias": int(f["pontos"]) / 12, "tres_estrelas": int(f["pontos"]) / 20, "derrubadas": int(f["pontos"]) / 8,
			"regioes": clampi(int(f["pontos"]) / 400, 0, 5)}}

## Cavaleiros da ordem para a praça da vila (até `praca_max`, sem bloqueados):
## [{id, nome, casa, corpo, pelagem, brasao}] com o brasão da ordem.
func cavaleiros_da_ordem() -> Array:
	var r: Array = []
	if not tem_ordem():
		return r
	var brasao: Dictionary = _social()["ordem"]["brasao"]
	for m: Dictionary in _membros_visiveis():
		if r.size() >= int(cfg_ordem()["praca_max"]):
			break
		var p := _perfil_fantasma(int(m["n"]), int(m["base"]))
		r.append({"id": m["id"], "nome": m["nome"], "casa": p["casa"], "corpo": p["corpo"], "pelagem": p["pelagem"], "brasao": brasao.duplicate(true)})
	return r

## Vale chamar a atenção na vila? (prêmio do torneio esperando)
func social_alerta() -> bool:
	if tem_ordem():
		_virar_semana_torneio()
	return not (_social()["torneio"]["pendente"] as Dictionary).is_empty()

# ------------------------------------------------------------ persistência

func novo_estado() -> Dictionary:
	var ini := Balanceamento.ler("inicio")
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
	e["liga"] = _liga_nova(int(e["criado_em"]))
	e["loja"] = _loja_nova()
	e["anuncios"] = {"dia": -1, "usados": 0, "timers": [], "ultima_vitoria": {}}
	e["social"] = _social_novo()
	var cid := _novo_id(e, "c")
	e["cavalos"].append({"id": cid, "nome": "", "pelagem": "alazao", "atributos": ini["cavalo"]["atributos"].duplicate(),
		"folego": int(Balanceamento.ler("treino")["folego_cavalo"]["maximo"]), "folego_em": e["criado_em"]})
	e["cavalo_ativo"] = cid
	var modelos: Dictionary = Balanceamento.ler("itens")["modelos"]
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
	if v < 8:
		# 3.17: liga, defesa de PvP, histórico, temporada e campeonato.
		if not d.has("liga") or not d["liga"].has("pontos"):
			d["liga"] = _liga_nova(int(d.get("criado_em", 0)))
		v = 8
	if v < 9:
		# 3.18: loja (VIP, passe, cosméticos, limites diários, ofertas).
		if not d.has("loja"):
			d["loja"] = _loja_nova()
		v = 9
	if v < 10:
		# 3.19: anúncios premiados (limite diário, timers já cortados, última vitória).
		if not d.has("anuncios"):
			d["anuncios"] = {"dia": -1, "usados": 0, "timers": [], "ultima_vitoria": {}}
		v = 10
	if v < 11:
		# 3.20: ordem, ajuda, chat, amigos, bloqueios e denúncias (simulados até o servidor).
		if not d.has("social"):
			d["social"] = _social_novo()
		v = 11
	d["versao"] = maxi(v, VERSAO)
	return d

# ------------------------------------------------------- comandos públicos
# Os comandos que o servidor também tem (Edge Function `acao`, lista PUBLICOS
# em supabase/functions/_shared/servidor/comandos.ts). Cada um roda aqui na
# hora (a tela não espera a rede) e, se deu certo, avisa `acao_feita`; com o
# servidor ligado, a Nuvem põe a ação na fila e o estado do servidor vence.

func criar_personagem(d: Dictionary) -> Dictionary:
	return _comando("criar_personagem", [d], _cmd_criar_personagem)

func definir_brasao(brasao: Dictionary) -> Dictionary:
	return _comando("definir_brasao", [brasao], _cmd_definir_brasao)

func equipar(id: String) -> Dictionary:
	return _comando("equipar", [id], _cmd_equipar)

func definir_visual(espaco: String, id_visual: String) -> Dictionary:
	return _comando("definir_visual", [espaco, id_visual], _cmd_definir_visual)

func equipar_habilidades(lista: Array) -> Dictionary:
	return _comando("equipar_habilidades", [lista], _cmd_equipar_habilidades)

func melhorar_predio(nome: String) -> Dictionary:
	return _comando("melhorar_predio", [nome], _cmd_melhorar_predio)

func concluir_timer(id: String) -> Dictionary:
	return _comando("concluir_timer", [id], _cmd_concluir_timer)

func treinar_cavaleiro(atributo: String) -> Dictionary:
	return _comando("treinar_cavaleiro", [atributo], _cmd_treinar_cavaleiro)

func treinar_cavalo(id: String, atributo: String) -> Dictionary:
	return _comando("treinar_cavalo", [id, atributo], _cmd_treinar_cavalo)

func usar_cavalo(id: String) -> Dictionary:
	return _comando("usar_cavalo", [id], _cmd_usar_cavalo)

func consertar(id: String) -> Dictionary:
	return _comando("consertar", [id], _cmd_consertar)

func forjar(modelo: String) -> Dictionary:
	return _comando("forjar", [modelo], _cmd_forjar)

func melhorar_peca(id: String) -> Dictionary:
	return _comando("melhorar_peca", [id], _cmd_melhorar_peca)

func fundir(produto: String, quantidade: int) -> Dictionary:
	return _comando("fundir", [produto, quantidade], _cmd_fundir)

func resgatar_missao(id: String) -> Dictionary:
	return _comando("resgatar_missao", [id], _cmd_resgatar_missao)

func resgatar_login() -> Dictionary:
	return _comando("resgatar_login", [], _cmd_resgatar_login)

func definir_titulo(id: String) -> Dictionary:
	return _comando("definir_titulo", [id], _cmd_definir_titulo)

func comecar_abrir(id: String) -> Dictionary:
	return _comando("comecar_abrir", [id], _cmd_comecar_abrir)

func abrir_bau(id: String, com_chave := false) -> Dictionary:
	return _comando("abrir_bau", [id, com_chave], _cmd_abrir_bau)

func comprar_com_gemas(id: String) -> Dictionary:
	return _comando("comprar_com_gemas", [id], _cmd_comprar_com_gemas)

func usar_cosmetico(id: String) -> Dictionary:
	return _comando("usar_cosmetico", [id], _cmd_usar_cosmetico)

func pular_com_gemas(id: String) -> Dictionary:
	return _comando("pular_com_gemas", [id], _cmd_pular_com_gemas)

func resgatar_passe(nivel: int, trilha: String) -> Dictionary:
	return _comando("resgatar_passe", [nivel, trilha], _cmd_resgatar_passe)

func marcar_oferta_vista(id: String) -> void:
	_comando("marcar_oferta_vista", [id], _cmd_marcar_oferta_vista)

func recompensa_anuncio(tipo: String, alvo: String, token: String) -> Dictionary:
	return _comando("recompensa_anuncio", [tipo, alvo, token], _cmd_recompensa_anuncio)

func marcar_cena_vista(id: String) -> Dictionary:
	return _comando("marcar_cena_vista", [id], _cmd_marcar_cena_vista)

func definir_passo_tutorial(passo: int) -> Dictionary:
	return _comando("definir_passo_tutorial", [passo], _cmd_definir_passo_tutorial)

func recompensa_tutorial() -> Dictionary:
	return _comando("recompensa_tutorial", [], _cmd_recompensa_tutorial)

func definir_config(chave: String, valor: Variant) -> Dictionary:
	return _comando("definir_config", [chave, valor], _cmd_definir_config)

func definir_notificacao(tipo: String, ligada: bool) -> Dictionary:
	return _comando("definir_notificacao", [tipo, ligada], _cmd_definir_notificacao)

# ---------------------------------------------------------------- internos

## Roda o comando aqui e, se deu certo, avisa quem envia ao servidor.
func _comando(tipo: String, args: Array, f: Callable) -> Variant:
	var r: Variant = f.callv(args)
	if r == null or (r is Dictionary and r.get("ok", false)):
		acao_feita.emit(tipo, args)
	return r

## Troca o estado pelo do servidor (que vence): migra, salva e avisa tudo.
func adotar_estado(dados: Dictionary) -> void:
	estado = migrar(_inteiros(dados))
	salvar()
	mudou.emit("tudo")

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
