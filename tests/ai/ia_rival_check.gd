extends SceneTree
## Casos compartilhados de tests/shared/ia_rival.json contra
## game/scripts/ai/ia_rival.gd (mesma sequência de decisões por semente).

const CASOS := "res://tests/shared/ia_rival.json"

var _falhas := 0

func _initialize() -> void:
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASOS))
	var cfg_ia: Dictionary = dados["config_ia"]
	var cfg_mira: Dictionary = dados["config_mira"]
	_checa("config embutida valida", IaRival.validar(cfg_ia) == "")
	_checa("dados do jogo validos", IaRival.validar(Balanceamento.carregar("ia_rival")) == "")
	for z: String in dados["centros"]:
		var c := IaRival.centro_da_zona(cfg_mira, z)
		var e: Array = dados["centros"][z]
		_checa("centro de %s" % z, c == Vector2i(int(e[0]), int(e[1])))
	for caso: Dictionary in dados["casos"]:
		_checa("semente derivada %d" % int(caso["semente_justa"]),
			IaRival.semente_da_justa(int(caso["semente_justa"])) == int(caso["semente_ia"]))
		var ia := IaRival.new(cfg_ia["perfis"][caso["perfil"]], int(caso["semente_ia"]))
		var obtido: Array = []
		for i in caso["passadas"].size():
			var r := ia.reacao_largada_ms()
			var g := ia.plano_galope(500, 6000)
			var m := ia.ponto_mira(cfg_mira)
			obtido.append({"reacao_ms": r, "galope": g, "mira": [m.x, m.y]})
		var a := JSON.stringify(JSON.parse_string(JSON.stringify(obtido)), "", true)
		var e := JSON.stringify(caso["passadas"], "", true)
		if a == e:
			_checa("%s semente %d" % [caso["perfil"], int(caso["semente_justa"])], true)
		else:
			_falhas += 1
			print("IA %s semente %d FALHOU\n   esperado %s\n   obtido   %s" % [caso["perfil"], int(caso["semente_justa"]), e, a])
	print("IA %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("IA %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
