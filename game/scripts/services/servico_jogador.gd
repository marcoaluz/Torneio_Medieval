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

## Cavalo cansado (fôlego baixo; regras na 2.7). Sem dado de fôlego, não está.
func cavalo_cansado(id := "") -> bool:
	var c := cavalo_ativo() if id == "" else {}
	if id != "":
		for x: Dictionary in estado["cavalos"]:
			if x["id"] == id:
				c = x
	return c.get("cansado", false)

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

## Variante de arte de cada espaço, já com o guarda-roupa (visual) aplicado.
func visual_das_pecas() -> Dictionary:
	var modelos: Dictionary = Balanceamento.carregar("itens")["modelos"]
	var saida := {}
	for espaco: String in estado["equipamento"]:
		var id: String = estado["visual"].get(espaco, estado["equipamento"][espaco])
		var it := item(id)
		if not it.is_empty():
			saida[espaco] = modelos[it["modelo"]]["visual"]
	return saida

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
	return {
		"cavaleiro": estado["cavaleiro"]["atributos"].duplicate(),
		"cavalo": cav.get("atributos", {}).duplicate(),
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

## Timer em andamento (ou já pronto, esperando concluir) de um prédio; {} se não tem.
func timer_do_predio(nome: String) -> Dictionary:
	for t: Dictionary in estado["timers"]:
		if t["alvo"] == nome:
			return t.duplicate()
	return {}

func timers() -> Array:
	return estado["timers"].duplicate(true)

## Se dá para melhorar e quanto custa: {ok, erro, ouro, segundos}.
func pode_melhorar(nome: String) -> Dictionary:
	var vila := Balanceamento.carregar("vila")
	if not vila["predios"].has(nome):
		return _erro("predio_inexistente")
	if not predio_liberado(nome):
		return _erro("predio_bloqueado")
	if not timer_do_predio(nome).is_empty():
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
		match t["tipo"]:
			"melhoria":
				_garantir_predio(t["alvo"])
				estado["vila"]["predios"][t["alvo"]]["nivel"] = int(t["nivel_novo"])
		estado["timers"].remove_at(i)
		return _concluir("vila")
	return _erro("timer_inexistente")

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
	e["cavalos"].append({"id": cid, "nome": "", "pelagem": "alazao", "atributos": ini["cavalo"]["atributos"].duplicate()})
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
