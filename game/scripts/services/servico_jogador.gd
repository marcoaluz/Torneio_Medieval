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

const VERSAO := 1
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
## habilidade}. Peça quebrada (durabilidade 0) vai com durabilidade 0 e a
## regra ignora os bônus dela.
func lado_para_justa() -> Dictionary:
	var modelos: Dictionary = Balanceamento.carregar("itens")["modelos"]
	var equip := {}
	for espaco: String in ESPACOS_REGRA:
		var it := equipado(espaco)
		if it.is_empty():
			continue
		var p: Dictionary = (modelos[it["modelo"]]["status"] as Dictionary).duplicate()
		p["durabilidade"] = int(it["durabilidade"])
		equip[espaco] = p
	var cav := cavalo_ativo()
	var atr_cavalo: Dictionary = cav.get("atributos", {}).duplicate()
	if cavalo_cansado():
		var pen := int(Balanceamento.carregar("treino")["folego_cavalo"]["penalidade_velocidade_cansado_pct"])
		atr_cavalo["velocidade"] = int(atr_cavalo.get("velocidade", 0)) * (100 - pen) / 100
	return {
		"cavaleiro": estado["cavaleiro"]["atributos"].duplicate(),
		"cavalo": atr_cavalo,
		"equipamento": equip,
		"habilidade": estado["cavaleiro"].get("habilidade", ""),
	}

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
		estado["timers"].remove_at(i)
		return _concluir("vila")
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
		if c["id"] == estado["cavalo_ativo"]:
			c["folego"] = maxi(folego_cavalo(c["id"]) - int(f["gasto_por_justa"]), 0)
			c["folego_em"] = ServicoTempo.agora()
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

# ---------------------------------------------------------------------- PvE

func pve() -> Dictionary:
	return Balanceamento.carregar("pve")

## Progresso de um torneio: {proxima (índice da próxima disputa), concluido,
## estrelas: {índice (texto): melhor}}.
func progresso_torneio(id: String) -> Dictionary:
	var t: Dictionary = estado["pve"]["torneios"].get(id, {})
	return {"proxima": int(t.get("proxima", 0)), "concluido": t.get("concluido", false),
		"estrelas": (t.get("estrelas", {}) as Dictionary).duplicate()}

## Liberado: nível mínimo e o torneio anterior da região concluído.
func torneio_liberado(id: String) -> bool:
	var dados := pve()
	var t: Dictionary = dados["torneios"].get(id, {})
	if t.is_empty() or int(estado["cavaleiro"]["nivel"]) < int(t["nivel_minimo"]):
		return false
	var lista: Array = dados["regioes"][estado["pve"]["regiao"]]["torneios"]
	var i := lista.find(id)
	return i <= 0 or progresso_torneio(lista[i - 1])["concluido"]

## Pode jogar a disputa `indice` do torneio (a próxima, ou uma já vencida).
func pode_disputar(torneio: String, indice: int) -> Dictionary:
	if not torneio_liberado(torneio):
		return _erro("torneio_bloqueado")
	var rivais: Array = pve()["torneios"][torneio]["rivais"]
	if indice < 0 or indice >= rivais.size():
		return _erro("disputa_inexistente")
	if indice > progresso_torneio(torneio)["proxima"]:
		return _erro("disputa_bloqueada")
	return {"ok": true, "erro": ""}

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
func rival_para_justa(rival_id: String) -> Dictionary:
	var r: Dictionary = pve()["rivais"][rival_id]
	var modelos: Dictionary = Balanceamento.carregar("itens")["modelos"]
	var bonus := int(r.get("cresce_por_encontro", 0)) * int(estado["pve"].get("encontros", {}).get(rival_id, 0))
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
	var perfil: Dictionary = Balanceamento.carregar("ia_rival")["perfis"][r["perfil"]]
	return {"id": rival_id, "lado": lado, "perfil_nome": r["perfil"], "perfil": perfil,
		"casa": {"principal": r["casa"][0], "secundaria": r["casa"][1]},
		"brasao": GeradorBrasao.opcoes().get("rivais", {}).get(r.get("brasao", ""), {}),
		"nome_chave": "RIVAL_" + rival_id.to_upper(), "nemesis": r.get("nemesis", false), "campeao": r.get("campeao", false)}

## Fim de uma disputa (manual ou automática), a partir dos eventos da justa:
## estrelas, avanço na chave, recompensa da disputa e, na primeira vez que o
## torneio fecha, a do torneio; XP e nível. {ok, estrelas, ouro, xp, niveis,
## torneio_concluido, venceu}.
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
	if est > 0:
		var r: Dictionary = dados["recompensa_disputa"]
		ouro_g = int(r["ouro_base"]) + est * int(r["ouro_por_estrela"])
		xp_g = int(r["xp_base"]) + est * int(r["xp_por_estrela"])
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
	var niveis := _ganhar(ouro_g, xp_g)
	var res := _concluir("pve")
	res.merge({"estrelas": est, "ouro": ouro_g, "xp": xp_g, "niveis": niveis, "torneio_concluido": fechou, "venceu": est > 0}, true)
	return res

## Disputa no automático: a mesma regra, com uma IA de precisão média no
## lugar do jogador. Gasta fôlego e equipamento como a manual.
func disputa_automatica(torneio: String, indice: int, semente: int) -> Dictionary:
	var p := pode_automatico(torneio, indice)
	if not p["ok"]:
		return p
	var dados := pve()
	var rv := rival_para_justa(dados["torneios"][torneio]["rivais"][indice])
	var perfil_auto: Dictionary = Balanceamento.carregar("ia_rival")["perfis"][dados["perfil_automatico"]]
	var sim := RegraPve.simular(Justa.carregar_configuracao(), lado_para_justa(), rv["lado"], semente, rv["perfil"], perfil_auto)
	registrar_justa({"equipamento_final": sim["equipamento_final"]})
	var r := concluir_disputa(torneio, indice, sim["eventos"], true)
	r["eventos"] = sim["eventos"]
	return r

## Duração real de um timer. No primeiro dia (tutorial, 2.11) os timers
## terminam em segundos; aqui é o ponto único onde isso entra.
func duracao_timer(segundos: int) -> int:
	return segundos

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
			"atributos": ini["cavaleiro"]["atributos"].duplicate(), "habilidade": ini["cavaleiro"]["habilidade"]},
		"casa": {"nome": "", "cores": {"principal": "azul_real", "secundaria": "ouro_velho", "metal": "ferro"}, "brasao": {}},
		"cavalos": [],
		"cavalo_ativo": "",
		"inventario": {"ouro": int(ini["ouro"]), "gemas": int(ini["gemas"]), "materiais": ini["materiais"].duplicate(), "itens": []},
		"equipamento": {},
		"visual": {},
		"vila": {"predios": {}},
		"timers": [],
		"pve": {"regiao": "feiras", "torneios": {}},
		"tutorial": {"passo": 0, "concluido": false},
	}
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
	# Exemplo do formato: if v < 2: d["novo_campo"] = ...; v = 2
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
