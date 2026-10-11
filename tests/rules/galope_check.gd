extends SceneTree
## Casos compartilhados de tests/shared/galope.json: gerador Aleatorio
## (xorshift32), avaliação da largada e galope de um cavaleiro.
## A config vem embutida no JSON (o teste não muda quando o balanceamento muda).

const CASOS := "res://tests/shared/galope.json"

var _falhas := 0

func _initialize() -> void:
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASOS))
	var cfg: Dictionary = dados["config"]
	_checa("config embutida valida", Galope.validar(cfg) == "")
	_checa("dados do jogo validos", Galope.validar(Balanceamento.carregar("galope")) == "")

	for v: Dictionary in dados["aleatorio"]:
		var r := Aleatorio.new(int(v["semente"]))
		var obtidos: Array = []
		for i in v["primeiros"].size():
			obtidos.append(r.proximo())
		var esperados: Array = v["primeiros"].map(func(x): return int(x))
		_checa("aleatorio semente %d" % int(v["semente"]), obtidos == esperados)

	for l: Dictionary in dados["largada"]:
		var q := Galope.avaliar_largada(cfg, l["tocou"], int(l["reacao_ms"]))
		_checa("largada tocou=%s reacao=%d -> %s" % [l["tocou"], int(l["reacao_ms"]), l["esperado"]], q == l["esperado"])

	for caso: Dictionary in dados["casos"]:
		var obtido := _rodar(cfg, caso["cavalo"], caso["acoes"])
		if obtido == caso["esperado"]:
			_checa(caso["nome"], true)
		else:
			_falhas += 1
			print("GALOPE %s FALHOU\n   esperado %s\n   obtido   %s" % [caso["nome"], caso["esperado"], obtido])

	print("GALOPE %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _rodar(cfg: Dictionary, cavalo: Dictionary, acoes: Array) -> Array:
	var g := Galope.new(cfg, cavalo)
	var ev: Array = ["inicio:nominal%d:janela%d:folego%d" % [g.velocidade_nominal, g.janela_ms, g.folego_max]]
	for a: Array in acoes:
		match a[0]:
			"passada":
				g.nova_passada(a[1])
				ev.append("passada:%s:v%d:f%d" % [a[1], g.velocidade, g.folego])
			"avancar":
				for i in int(a[1]):
					var e := g.avancar_1ms()
					if not e.is_empty():
						ev.append(_fmt(e, g))
			"tocar":
				ev.append(_fmt(g.tocar(), g))
	ev.append("fim:d%d:ritmo%d" % [g.distancia_mil, g.ritmo_milesimos()])
	return ev

func _fmt(e: Dictionary, g: Galope) -> String:
	return "%s:%d:%d:v%d:f%d@%d" % [e["resultado"], e["batida"], e["desvio_ms"], g.velocidade, g.folego, g.t_ms]

func _checa(nome: String, ok: bool) -> void:
	print("GALOPE %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
