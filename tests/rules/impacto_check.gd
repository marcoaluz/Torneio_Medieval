extends SceneTree
## Casos compartilhados de tests/shared/impacto.json (regra do impacto) contra
## game/scripts/rules/impacto.gd, mais o determinismo (mesma semente = mesmo
## resultado). Compara via JSON com chaves ordenadas (int x float do JSON).

const CASOS := "res://tests/shared/impacto.json"

var _falhas := 0

func _initialize() -> void:
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASOS))
	var cfg: Dictionary = dados["config"]
	_checa("config embutida valida", Impacto.validar(cfg) == "")
	_checa("dados do jogo validos", Impacto.validar(Balanceamento.carregar("impacto")) == "")
	for s: Dictionary in dados["suave"]:
		var v := Impacto.suave(int(s["valor"]), int(s["teto"]), int(s["joelho_pct"]))
		_checa("suave(%d, %d, %d) = %d (obtido %d)" % [int(s["valor"]), int(s["teto"]), int(s["joelho_pct"]), int(s["esperado"]), v],
			v == int(s["esperado"]))
	for c: Dictionary in dados["casos"]:
		var obtido := Impacto.resolver(cfg, c["entrada"], Aleatorio.new(int(c["semente"])))
		var de_novo := Impacto.resolver(cfg, c["entrada"], Aleatorio.new(int(c["semente"])))
		var a := _norm(obtido)
		var e := _norm(c["esperado"])
		if a == e and a == _norm(de_novo):
			_checa(c["nome"], true)
		else:
			_falhas += 1
			print("IMPACTO %s FALHOU\n   esperado %s\n   obtido   %s" % [c["nome"], e, a])
	print("IMPACTO %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _norm(v: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(v)), "", true)

func _checa(nome: String, ok: bool) -> void:
	print("IMPACTO %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
