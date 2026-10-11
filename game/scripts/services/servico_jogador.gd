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
