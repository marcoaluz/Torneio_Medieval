extends SceneTree
## Regra pura das ordens (3.20, headless): casos compartilhados de
## tests/shared/ordem.json (gerados por um oráculo Python independente) e a
## conferência de que a config do arquivo ainda é a do ordem.json do jogo.

var _falhas := 0

func _initialize() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/shared/ordem.json"))
	var cfg: Dictionary = d["cfg"]

	# A config usada nos casos tem que ser a do jogo (senão, regerar os casos).
	var real: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/balance/ordem.json"))
	var igual := true
	for k: String in cfg:
		if JSON.stringify(_ordenado(cfg[k])) != JSON.stringify(_ordenado(real[k])) and k != "torneio" and k != "ajuda" and k != "doacao":
			igual = false
			print("  config diferente em ", k)
	for k: String in ["segundos_por_ajuda", "ajudas_max_por_pedido", "moeda_por_ajuda", "moeda_max_dia"]:
		igual = igual and int(cfg["ajuda"][k]) == int(real["ajuda"][k])
	igual = igual and int(cfg["doacao"]["limite_dia_unidades"]) == int(real["doacao"]["limite_dia_unidades"])
	igual = igual and JSON.stringify(cfg["torneio"]["premios"]) == JSON.stringify(real["torneio"]["premios"])
	igual = igual and JSON.stringify(cfg["torneio"]["vitorias_por_membro_semana"]) == JSON.stringify(real["torneio"]["vitorias_por_membro_semana"])
	_checa("config dos casos = ordem.json", igual)

	var e := 0
	for c: Dictionary in d["pode"]:
		e += 0 if RegraOrdem.pode(c["cargo"], c["acao"], cfg) == c["esperado"] else 1
	_checa("permissoes por cargo", e == 0)
	e = 0
	for c: Dictionary in d["pode_sobre"]:
		e += 0 if RegraOrdem.pode_sobre(c["ator"], c["alvo"], c["acao"], cfg) == c["esperado"] else 1
	_checa("acoes sobre outro membro (ninguem age sobre o lider)", e == 0)
	e = 0
	for c: Dictionary in d["cargo_depois"]:
		e += 0 if RegraOrdem.cargo_depois(c["cargo"], c["acao"]) == c["esperado"] else 1
	_checa("cargo depois de promover e rebaixar", e == 0)
	e = 0
	for c: Dictionary in d["vaga"]:
		e += 0 if RegraOrdem.tem_vaga(int(c["membros"]), cfg) == c["esperado"] else 1
	_checa("limite de membros", e == 0)
	e = 0
	for c: Dictionary in d["segundos_da_ajuda"]:
		e += 0 if RegraOrdem.segundos_da_ajuda(int(c["restante"]), cfg) == int(c["esperado"]) else 1
	for c: Dictionary in d["aceita_ajuda"]:
		e += 0 if RegraOrdem.pedido_aceita_ajuda(int(c["ajudas"]), cfg) == c["esperado"] else 1
	for c: Dictionary in d["moeda_da_ajuda"]:
		e += 0 if RegraOrdem.moeda_da_ajuda(int(c["hoje"]), cfg) == int(c["esperado"]) else 1
	for c: Dictionary in d["doacao_restante"]:
		e += 0 if RegraOrdem.doacao_restante(int(c["hoje"]), cfg) == int(c["esperado"]) else 1
	_checa("ajuda e doacao", e == 0)
	e = 0
	for c: Dictionary in d["posicao_torneio"]:
		e += 0 if RegraOrdem.posicao_no_torneio(int(c["minhas"]), c["outras"]) == int(c["esperado"]) else 1
	for c: Dictionary in d["premio_torneio"]:
		var p := RegraOrdem.premio_do_torneio(int(c["posicao"]), cfg)
		e += 0 if int(p["moeda"]) == int(c["esperado"]["moeda"]) and p["bau"] == c["esperado"]["bau"] else 1
	_checa("posicao e premio do torneio", e == 0)
	e = 0
	for c: Dictionary in d["vitorias_simuladas"]:
		e += 0 if RegraOrdem.vitorias_simuladas(int(c["semente"]), int(c["semana"]), int(c["indice"]), int(c["fracao"]), cfg) == int(c["esperado"]) else 1
	_checa("vitorias simuladas dos membros", e == 0)
	e = 0
	for c: Dictionary in d["codigo_amigo"]:
		e += 0 if RegraOrdem.codigo_amigo(int(c["semente"])) == c["esperado"] else 1
	for c: Dictionary in d["codigo_valido"]:
		e += 0 if RegraOrdem.codigo_valido(c["texto"]) == c["esperado"] else 1
	_checa("codigo de amigo", e == 0)
	e = 0
	for c: Dictionary in d["ordens_simuladas"]:
		var r := RegraOrdem.ordens_simuladas(int(c["semente"]), cfg, d["nomes"], d["cores"], d["simbolos"], d["divisoes"])
		if JSON.stringify(_inteiros(r)) != JSON.stringify(_inteiros(c["esperado"])):
			e += 1
			print("  ordens ", c["semente"], ": ", r[0], " != ", c["esperado"][0])
	_checa("ordens simuladas pela semente", e == 0)
	e = 0
	for c: Dictionary in d["erro_da_compra"]:
		e += 0 if RegraOrdem.erro_da_compra(int(c["moeda"]), int(c["comprados"]), c["item"]) == c["esperado"] else 1
	_checa("compra na loja da ordem", e == 0)

	print("ORDEM %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

## O JSON do Godot lê inteiro como float: normaliza para comparar texto.
static func _inteiros(v: Variant) -> Variant:
	if v is float and v == floorf(v):
		return int(v)
	if v is Dictionary:
		var r := {}
		for k in v:
			r[k] = _inteiros(v[k])
		return r
	if v is Array:
		return (v as Array).map(_inteiros)
	return v

static func _ordenado(v: Variant) -> Variant:
	return _inteiros(v)

func _checa(nome: String, ok: bool) -> void:
	print("ORDEM %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
