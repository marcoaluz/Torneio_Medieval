extends SceneTree
## Confere o ControladorJusta na cena real (headless): uma justa inteira
## simulada a 30 quadros/s com um jogador-robô que larga depois da bandeira e
## toca no compasso. Confere os sinais em ordem, o plano da câmera em cada
## fase, a bandeira do arauto, a barra de distância e os cavaleiros se
## encontrando no fim da Mira.

var _falhas := 0
var _log: Array[String] = []
var _planos := {}
var _toques := {}
var _largadas: Array[String] = []

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
	c.bandeira_baixou.connect(func(p): _log.append("bandeira:%d" % p))
	c.largada_avaliada.connect(func(_p, q, _r, _qm): _largadas.append(q))
	c.toque_galope.connect(func(r, _d, _v, _f): _toques[r] = _toques.get(r, 0) + 1)
	c.corrida_terminou.connect(func(p, _v, _r): _log.append("corrida_fim:%d" % p))
	c.passada_terminou.connect(func(p, pj, pr, _d): _log.append("passada:%d:%d-%d" % [p, pj, pr]))
	c.justa_terminou.connect(func(v, m, pj, pr): _log.append("fim:%s:%s:%d-%d" % [JustaFases.NOMES_LADO[v], m, pj, pr]))
	c.fase_mudou.connect(func(f, _a, _p): _planos[JustaFases.NOMES_FASE[f]] = arena.camera.plano)

	c.iniciar(11)
	_checa("comeca na apresentacao", c.fase() == JustaFases.Fase.APRESENTACAO and _log.has("sinal:apresentacao:1"))
	_checa("cavaleiros parados nas pontas", arena.jogador.global_position == arena.inicio_jogador.global_position)
	_checa("bandeira levantada", arena.arauto.esta_levantada())

	var dist_fim_mira := -1.0
	var barra_fim_mira := 0.0
	var brilho_max := 0.0
	var bandeira_baixada_ok := false
	var quadros := 0
	var passo := 1.0 / 30.0
	while not c.justa.terminou() and quadros < 30 * 120:
		var antes := c.fase()
		var j := c.justa
		# Robô: toca no primeiro quadro depois da bandeira e no quadro mais perto de cada batida.
		if antes == JustaFases.Fase.LARGADA and j.bandeira_baixou and not j.tocou_largada:
			c.tocar()
			bandeira_baixada_ok = not arena.arauto.esta_levantada()
		elif antes == JustaFases.Fase.CORRIDA:
			var p := j.jogador.compasso_ms()
			var resto := j.jogador.t_ms % p
			if j.jogador.t_ms >= p / 2 and (resto <= 17 or resto > p - 17):
				c.tocar()
			brilho_max = maxf(brilho_max, c.barra.brilho)
		c._process(passo)
		arena.camera._process(passo)
		quadros += 1
		if antes == JustaFases.Fase.MIRA and c.fase() == JustaFases.Fase.IMPACTO and dist_fim_mira < 0.0:
			dist_fim_mira = absf(arena.jogador.global_position.x - arena.rival.global_position.x)
			barra_fim_mira = absf(c.barra.posicao_jogador - c.barra.posicao_rival)
		if c.fase() == JustaFases.Fase.MIRA and c.justa.fases.passada == 1:
			c.registrar_resultado(2, 1)

	_checa("justa termina", c.justa.terminou())
	_checa("jogador vence 2-1 na primeira e empata o resto", _log.back() == "fim:jogador:pontos:2-1")
	_checa("tres passadas", _log.count("sinal:corrida:3") == 1 and not _log.has("sinal:corrida:4"))
	_checa("um sinal por fase e na ordem", _log.slice(0, 11) == [
		"fase:apresentacao:1", "sinal:apresentacao:1", "fase:largada:1", "sinal:largada:1", "bandeira:1",
		"fase:corrida:1", "sinal:corrida:1", "corrida_fim:1", "fase:mira:1", "sinal:mira:1", "fase:impacto:1"])
	_checa("bandeira baixa e o arauto mostra", bandeira_baixada_ok)
	_checa("largadas do robo sao perfeitas %s" % [_largadas], _largadas.size() == 3 and _largadas.count("perfeita") == 3)
	_checa("toques no compasso contam %s" % [_toques], _toques.get("no_tempo", 0) >= 18 and _toques.get("perdido", 0) == 0)
	_checa("brilho do compasso acende na corrida", brilho_max == 1.0)
	_checa("cavaleiros se encontram no fim da mira (%.1f px)" % dist_fim_mira, dist_fim_mira >= 0.0 and dist_fim_mira < 6.0)
	_checa("icones da barra se encontram no fim da mira (%.3f)" % barra_fim_mira, barra_fim_mira < 0.01)
	_checa("camera aberta na apresentacao e largada",
		_planos["apresentacao"] == CameraArena.Plano.ABERTO and _planos["largada"] == CameraArena.Plano.ABERTO)
	_checa("camera segue na corrida", _planos["corrida"] == CameraArena.Plano.SEGUIR)
	_checa("camera foca na mira e no impacto",
		_planos["mira"] == CameraArena.Plano.FOCO and _planos["impacto"] == CameraArena.Plano.FOCO)
	_checa("camera volta ao aberto no fim", arena.camera.plano == CameraArena.Plano.ABERTO)
	var segundos := quadros / 30.0
	_checa("duracao da justa entre 30 e 36 s (%.2f s)" % segundos, segundos > 30.0 and segundos < 36.0)

	# Toque pula a apresentação; na largada, larga em vez de pular.
	c.iniciar(12)
	var toque := InputEventScreenTouch.new()
	toque.pressed = true
	c._unhandled_input(toque)
	_checa("toque pula a apresentacao", c.fase() == JustaFases.Fase.LARGADA)
	c._unhandled_input(toque)
	_checa("toque antes da bandeira queima a largada", c.justa.tocou_largada and c.justa.qualidade_largada == "ruim")

	print("JUSTA %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("JUSTA %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
