extends SceneTree
## Forja (regra pura) contra os casos compartilhados de tests/shared/forja.json
## (oráculo independente; o servidor roda os mesmos).

var _falhas := 0

func _initialize() -> void:
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/shared/forja.json"))
	var erros := 0
	for c: Dictionary in dados["variacao"]:
		var r := RegraForja.variar_status(c["status"], int(c["pct"]), int(c["semente"]))
		if not _iguais(r, c["esperado"]):
			erros += 1
			print("  variacao %s semente %d: %s != %s" % [c["status"], c["semente"], r, c["esperado"]])
	_checa("variacao de status (%d casos)" % dados["variacao"].size(), erros == 0)
	erros = 0
	for c: Dictionary in dados["nivel"]:
		if not _iguais(RegraForja.status_com_nivel(c["status"], int(c["nivel"]), int(c["pct"])), c["esperado"]):
			erros += 1
	_checa("status com nivel (%d casos)" % dados["nivel"].size(), erros == 0)
	erros = 0
	for c: Dictionary in dados["tentativas"]:
		if RegraForja.melhoria_deu_certo(int(c["nivel"]), dados["melhoria"], int(c["semente"])) != c["esperado"]:
			erros += 1
	_checa("tentativas de melhoria (%d casos)" % dados["tentativas"].size(), erros == 0)
	var eco: Dictionary = Balanceamento.carregar("economia")
	_checa("tabela de chances do jogo = a dos casos", JSON.stringify(eco["melhoria"]["chance_sucesso_pct"]) == JSON.stringify(dados["melhoria"]["chance_sucesso_pct"]))
	var garantido := true
	for n in int(eco["melhoria"]["garantido_ate"]):
		for s in 50:
			garantido = garantido and RegraForja.melhoria_deu_certo(n, eco["melhoria"], s)
	_checa("ate +5 nunca falha", garantido)
	var var_max := true
	for s in 300:
		var v := int(RegraForja.variar_status({"defesa": 100}, 10, s)["defesa"])
		var_max = var_max and v >= 90 and v <= 110
	_checa("variacao fica em +-10%", var_max)
	print("FORJA %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _iguais(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in b:
		if not a.has(k) or int(a[k]) != int(b[k]):
			return false
	return true

func _checa(nome: String, ok: bool) -> void:
	print("FORJA %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
