extends SceneTree
## Abertura de baú (regra pura) contra os casos compartilhados de
## tests/shared/baus.json (gerados por um oráculo independente; o servidor
## roda os mesmos), mais determinismo, garantia de raro e probabilidades.

var _falhas := 0

func _initialize() -> void:
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/shared/baus.json"))
	var cfg: Dictionary = dados["config"]
	for caso: Dictionary in dados["casos"]:
		var r := RegraBau.abrir(caso["tipo"], cfg, dados["modelos"], caso["possui"], int(caso["garantia"]), int(caso["semente"]))
		var e: Dictionary = caso["esperado"]
		var ok := int(r["ouro"]) == int(e["ouro"]) and int(r["fragmentos"]) == int(e["fragmentos"]) and int(r["garantia"]) == int(e["garantia"])
		ok = ok and r["itens"].size() == e["itens"].size()
		if ok:
			for i in e["itens"].size():
				ok = ok and r["itens"][i]["modelo"] == e["itens"][i]["modelo"] and r["itens"][i]["raridade"] == e["itens"][i]["raridade"] \
					and r["itens"][i]["repetida"] == e["itens"][i]["repetida"]
		if not ok:
			print("  veio %s\n  esperado %s" % [JSON.stringify(r), JSON.stringify(e)])
		_checa(caso["nome"], ok)

	# Os dados do jogo batem com os do caso compartilhado (senão regere o oráculo).
	var eco: Dictionary = Balanceamento.carregar("economia")
	_checa("config do jogo = config dos casos", JSON.stringify(eco["baus"]) == JSON.stringify(cfg))

	# Garantia: 10 baús de ferro seguidos sempre trazem um raro ou melhor.
	var modelos: Dictionary = Balanceamento.carregar("itens")["modelos"]
	var sempre := true
	for s in 200:
		var g := 0
		var teve := false
		for k in int(eco["baus"]["garantia_raro_a_cada"]):
			var r := RegraBau.abrir("ferro", eco["baus"], modelos, [], g, s * 31 + k)
			g = int(r["garantia"])
			for it: Dictionary in r["itens"]:
				if RegraBau.ORDEM.find(it["raridade"]) >= 2:
					teve = true
		sempre = sempre and teve
	_checa("garantia: 10 baus de ferro sempre tem raro+", sempre)
	_checa("madeira nao conta para a garantia", int(RegraBau.abrir("madeira", eco["baus"], modelos, [], 9, 5)["garantia"]) <= 9)
	var a := RegraBau.abrir("real", eco["baus"], modelos, [], 0, 99)
	_checa("mesma semente, mesmo bau", JSON.stringify(a) == JSON.stringify(RegraBau.abrir("real", eco["baus"], modelos, [], 0, 99)))
	var p := RegraBau.probabilidades("madeira", eco["baus"])
	var soma := 0.0
	for k in p:
		soma += float(p[k])
	_checa("probabilidades somam 100 (%s)" % str(p), absf(soma - 100.0) < 0.2 and p.keys()[0] == "comum")
	print("BAU %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("BAU %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
