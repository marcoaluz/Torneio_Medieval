extends SceneTree
## Casos compartilhados de tests/shared/mira.json (zonas da mira) contra
## game/scripts/rules/mira.gd. Config embutida no JSON.

const CASOS := "res://tests/shared/mira.json"

var _falhas := 0

func _initialize() -> void:
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASOS))
	var cfg: Dictionary = dados["config"]
	_checa("config embutida valida", Mira.validar(cfg) == "")
	_checa("dados do jogo validos", Mira.validar(Balanceamento.carregar("mira")) == "")
	for c: Dictionary in dados["crescimento"]:
		var g := Mira.crescimento_pct(cfg, int(c["precisao"]), int(c["bonus"]))
		_checa("crescimento precisao %d bonus %d = %d (obtido %d)" % [int(c["precisao"]), int(c["bonus"]), int(c["esperado"]), g],
			g == int(c["esperado"]))
	for z: Dictionary in dados["zonas"]:
		var obtida := Mira.zona_no_ponto(cfg, Vector2i(int(z["x"]), int(z["y"])), int(z["precisao"]), int(z["bonus"]))
		_checa("%s -> %s (obtido %s)" % [z["nome"], z["esperado"], obtida], obtida == z["esperado"])
	for l: Dictionary in dados["limites"]:
		var p := Mira.limitar(cfg, Vector2i(int(l["x"]), int(l["y"])))
		_checa("limitar (%d,%d)" % [int(l["x"]), int(l["y"])], p == Vector2i(int(l["esperado"][0]), int(l["esperado"][1])))
	print("MIRA %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("MIRA %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
