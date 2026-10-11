extends SceneTree
## Confere o ControladorJusta na cena real (headless): uma justa inteira
## simulada a 30 quadros/s, os sinais emitidos em ordem, o plano da câmera em
## cada fase e os cavaleiros se encontrando no meio no fim da Mira.

var _falhas := 0
var _log: Array[String] = []
var _planos := {}

func _initialize() -> void:
	var arena: Arena = load("res://game/scenes/arena/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var c: ControladorJusta = arena.get_node("Justa")
	c.set_process(false)  # o teste passa o tempo na mão
	c.fase_mudou.connect(func(f, _a, p): _log.append("fase:%s:%d" % [JustaFases.NOMES_FASE[f], p]))
	c.apresentacao_comecou.connect(func(p): _log.append("sinal:apresentacao:%d" % p))
	c.largada_comecou.connect(func(p): _log.append("sinal:largada:%d" % p))
	c.corrida_comecou.connect(func(p): _log.append("sinal:corrida:%d" % p))
	c.mira_comecou.connect(func(p): _log.append("sinal:mira:%d" % p))
	c.impacto_comecou.connect(func(p): _log.append("sinal:impacto:%d" % p))
	c.passada_terminou.connect(func(p, pj, pr, _d): _log.append("passada:%d:%d-%d" % [p, pj, pr]))
	c.justa_terminou.connect(func(v, m, pj, pr): _log.append("fim:%s:%s:%d-%d" % [JustaFases.NOMES_LADO[v], m, pj, pr]))
	c.fase_mudou.connect(func(f, _a, _p): _planos[JustaFases.NOMES_FASE[f]] = arena.camera.plano)

	c.iniciar()
	_checa("comeca na apresentacao", c.justa.fase == JustaFases.Fase.APRESENTACAO and _log.has("sinal:apresentacao:1"))
	_checa("cavaleiros parados nas pontas", arena.jogador.global_position == arena.inicio_jogador.global_position)

	var encontro_ok := false
	var dist_mira_fim := 0.0
	var quadros := 0
	while not c.justa.terminou() and quadros < 30 * 120:
		var antes := c.justa.fase
		c._process(1.0 / 30.0)
		arena.camera._process(1.0 / 30.0)
		quadros += 1
		if antes == JustaFases.Fase.MIRA and c.justa.fase == JustaFases.Fase.IMPACTO and not encontro_ok:
			dist_mira_fim = absf(arena.jogador.global_position.x - arena.rival.global_position.x)
			encontro_ok = true
		if c.justa.fase == JustaFases.Fase.MIRA and c.justa.passada == 1:
			c.registrar_resultado(2, 1)

	_checa("justa termina", c.justa.terminou())
	_checa("jogador vence 2-1 na primeira e empata o resto", _log.back() == "fim:jogador:pontos:2-1")
	_checa("tres passadas", _log.count("sinal:corrida:3") == 1 and not _log.has("sinal:corrida:4"))
	_checa("um sinal por fase e na ordem", _log.slice(0, 10) == [
		"fase:apresentacao:1", "sinal:apresentacao:1", "fase:largada:1", "sinal:largada:1",
		"fase:corrida:1", "sinal:corrida:1", "fase:mira:1", "sinal:mira:1",
		"fase:impacto:1", "sinal:impacto:1"])
	_checa("cavaleiros se encontram no fim da mira (%.1f px)" % dist_mira_fim, encontro_ok and dist_mira_fim < 6.0)
	_checa("camera aberta na apresentacao e largada",
		_planos["apresentacao"] == CameraArena.Plano.ABERTO and _planos["largada"] == CameraArena.Plano.ABERTO)
	_checa("camera segue na corrida", _planos["corrida"] == CameraArena.Plano.SEGUIR)
	_checa("camera foca na mira e no impacto",
		_planos["mira"] == CameraArena.Plano.FOCO and _planos["impacto"] == CameraArena.Plano.FOCO)
	_checa("camera volta ao aberto no fim", arena.camera.plano == CameraArena.Plano.ABERTO)
	var segundos := quadros / 30.0
	_checa("duracao da justa = 3 x 11,5 s (%.2f s)" % segundos, absf(segundos - 34.5) < 0.1)

	# Pular a apresentação com toque.
	c.iniciar()
	var toque := InputEventScreenTouch.new()
	toque.pressed = true
	c._unhandled_input(toque)
	_checa("toque pula a apresentacao", c.justa.fase == JustaFases.Fase.LARGADA)
	c._unhandled_input(toque)
	_checa("toque na largada nao pula", c.justa.fase == JustaFases.Fase.LARGADA)

	print("JUSTA %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("JUSTA %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
