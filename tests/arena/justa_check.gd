extends SceneTree
## Confere o ControladorJusta na cena real (headless): uma justa inteira
## simulada a 30 quadros/s com um jogador-robô que larga depois da bandeira e
## toca no compasso. Confere os sinais em ordem, o plano da câmera em cada
## fase, a bandeira do arauto, a barra de distância e os cavaleiros se
## encontrando no fim da Mira.

## Parte do peito que o escudo não cobre, no quadro do alvo (px); ver mira.json.
const PEITO := Vector2(8, -86)

var _falhas := 0
var _log: Array[String] = []
var _planos := {}
var _toques := {}
var _largadas: Array[String] = []
var _golpes: Array[String] = []
var _impactos := 0
var _toques_rival := 0

func _initialize() -> void:
	await process_frame
	var _jog_teste: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_arena/")
	_jog_teste.caminho_save = "user://teste_arena/jogador.json"
	_jog_teste.estado = _jog_teste.novo_estado()
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
	c.impacto_resolvido.connect(func(_p, _j, _r, _d, _q): _impactos += 1)
	c.fase_mudou.connect(func(_f, _a, _p): _toques_rival = c.justa.rival.acertos + _toques_rival if _f == JustaFases.Fase.MIRA else _toques_rival)
	c.golpe_avaliado.connect(func(_p, z, a, s): _golpes.append("%s%s%s" % [z, ":auto" if a else "", ":sem" if s else ""]))
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
	var ponta_visivel := false
	var realce_peito := false
	var mira_peito := false      ## mira visível com a cor do peito enquanto segura
	var zoom_mira_inicio := -1.0
	var zoom_mira_fim := -1.0
	var golpe_antes_do_choque := false
	var inclinou_no_choque := false
	var close_no_contato := false
	var lancas_apontam := false
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
		elif antes == JustaFases.Fase.MIRA:
			robo_mira(c, PEITO)
			if c.justa.segurando:
				ponta_visivel = ponta_visivel or arena.ponta_lanca.visible
				realce_peito = realce_peito or arena.rival.get_node("Visual/Cavaleiro/Peito").modulate != Color.WHITE
				var mv: MiraVisual = arena.ponta_lanca.get_node("Mira")
				mira_peito = mira_peito or (mv.is_visible_in_tree() and mv.zona == "peito" and mv.cor() == MiraVisual.CORES["peito"] and mv.segurando)
			if zoom_mira_inicio < 0.0:
				zoom_mira_inicio = arena.camera._zoom_destino
			zoom_mira_fim = arena.camera._zoom_destino
		c._process(passo)
		arena.camera._process(passo)
		quadros += 1
		if antes == JustaFases.Fase.MIRA and c.fase() == JustaFases.Fase.IMPACTO and not inclinou_no_choque:
			golpe_antes_do_choque = c._golpeou and arena.jogador._tween_gesto != null and arena.rival._tween_gesto != null
			# Jogador (pista da frente) aponta para cima, rival (atrás, espelhado) para baixo: no quadro de cada um, ângulo < 0 e > 0.
			lancas_apontam = arena.jogador.mira_lanca < -deg_to_rad(5.0) and arena.rival.mira_lanca > deg_to_rad(5.0)
			inclinou_no_choque = absf(arena.camera.inclinacao) > deg_to_rad(3.0) and absf(arena.camera.rotation) > deg_to_rad(3.0)
			var meio := (arena.jogador.global_position + arena.rival.global_position) * 0.5
			close_no_contato = arena.camera.zoom.x >= c.zoom_impacto and absf(arena.camera.global_position.x - meio.x) < 40.0
		if antes == JustaFases.Fase.MIRA and c.fase() == JustaFases.Fase.IMPACTO and dist_fim_mira < 0.0:
			dist_fim_mira = absf(arena.jogador.global_position.x - arena.rival.global_position.x)
			barra_fim_mira = absf(c.barra.posicao_jogador - c.barra.posicao_rival)

	_checa("justa termina", c.justa.terminou())
	_checa("justa termina com resultado: %s" % _log.back(), _log.back().begins_with("fim:"))
	_checa("a IA do rival galopa (%d toques)" % _toques_rival, _toques_rival > 0)
	_checa("impacto resolvido a cada passada (%d)" % _impactos, _impactos == _log.count("fase:impacto:1") + _log.count("fase:impacto:2") + _log.count("fase:impacto:3"))
	_checa("um sinal por fase e na ordem", _log.slice(0, 11) == [
		"fase:apresentacao:1", "sinal:apresentacao:1", "fase:largada:1", "sinal:largada:1", "bandeira:1",
		"fase:corrida:1", "sinal:corrida:1", "corrida_fim:1", "fase:mira:1", "sinal:mira:1", "fase:impacto:1"])
	_checa("bandeira baixa e o arauto mostra", bandeira_baixada_ok)
	_checa("largadas do robo sao perfeitas %s" % [_largadas], _largadas.size() >= 1 and _largadas.count("perfeita") == _largadas.size())
	_checa("toques no compasso contam %s" % [_toques], _toques.get("no_tempo", 0) >= 6 * _largadas.size() and _toques.get("perdido", 0) == 0)
	_checa("brilho do compasso acende na corrida", brilho_max == 1.0)
	_checa("robo arrasta ate o peito e acerta %s" % [_golpes], _golpes.size() >= 1 and _golpes.count("peito") == _golpes.size())
	_checa("ponta da lanca aparece na mira", ponta_visivel)
	_checa("zona sob a ponta brilha no rival", realce_peito)
	_checa("brilho apaga fora da mira", arena.rival.get_node("Visual/Cavaleiro/Peito").modulate == Color.WHITE and not arena.ponta_lanca.visible)
	_checa("no choque ficam a uma lanca de distancia (%.1f px)" % dist_fim_mira, dist_fim_mira >= 0.0 and absf(dist_fim_mira - c.vao_encontro) < 6.0)
	_checa("as lancas apontam uma para a outra no choque", lancas_apontam)
	_checa("icones da barra se encontram no fim da mira (%.3f)" % barra_fim_mira, barra_fim_mira < 0.01)
	_checa("camera aberta na apresentacao e largada",
		_planos["apresentacao"] == CameraArena.Plano.ABERTO and _planos["largada"] == CameraArena.Plano.ABERTO)
	_checa("camera segue na corrida", _planos["corrida"] == CameraArena.Plano.SEGUIR)
	_checa("camera foca na mira e no impacto",
		_planos["mira"] == CameraArena.Plano.FOCO and _planos["impacto"] == CameraArena.Plano.FOCO)
	_checa("camera volta ao aberto no fim", arena.camera.plano == CameraArena.Plano.ABERTO)
	_checa("mira visivel sobre a zona, com a cor dela", mira_peito)
	_checa("a camera fecha aos poucos na mira (%.2f -> %.2f)" % [zoom_mira_inicio, zoom_mira_fim],
		zoom_mira_inicio == c.zoom_mira_inicio and zoom_mira_fim > zoom_mira_inicio + 0.3)
	_checa("os dois golpeiam antes do choque", golpe_antes_do_choque)
	_checa("choque: corte inclinado com os dois no quadro", inclinou_no_choque and close_no_contato)
	_checa("sem inclinacao fora do impacto", absf(arena.camera._inclinacao_destino) < 0.001)
	# Gesto: estocada inclina o tronco em torno da sela e a lança vai junto (a guarda fica na mão).
	var cav := arena.jogador
	cav.restaurar()
	var lanca0: Vector2 = (cav.get_node("Visual/Lanca") as Node2D).position
	cav.gesto = 1.0
	var corpo := cav.get_node("Visual/Cavaleiro") as Node2D
	var lanca := cav.get_node("Visual/Lanca") as Node2D
	var mao := Cavaleiro.PIVO_SELA + (lanca0 - Cavaleiro.PIVO_SELA).rotated(corpo.rotation)
	_checa("estocada inclina o tronco para a frente", corpo.rotation > deg_to_rad(5.0))
	_checa("a lanca acompanha a mao (%.1f px)" % lanca.position.distance_to(mao), lanca.position.distance_to(mao) <= Cavaleiro.GESTO_ESTOCADA_PX + 0.01)
	cav.gesto = -0.7
	_checa("preparar recolhe o tronco", corpo.rotation < 0.0)
	cav.restaurar()
	_checa("restaurar volta a guarda", corpo.rotation == 0.0 and lanca.position == lanca0 and cav.gesto == 0.0)
	var segundos := quadros / 30.0
	_checa("duracao da passada entre 10 e 12 s (%.2f s em %d)" % [segundos, _largadas.size()],
		segundos / _largadas.size() > 10.0 and segundos / _largadas.size() < 12.0)

	# Toque pula a apresentação; na largada, larga em vez de pular.
	c.iniciar(12)
	var toque := InputEventScreenTouch.new()
	toque.pressed = true
	c._unhandled_input(toque)
	_checa("toque pula a apresentacao", c.fase() == JustaFases.Fase.LARGADA)
	c._process(0.05)  # dois toques no mesmo instante não são de um dedo (a arena ignora)
	c._unhandled_input(toque)
	_checa("toque antes da bandeira queima a largada", c.justa.tocou_largada and c.justa.qualidade_largada == "ruim")

	print("JUSTA %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

## Robô da Mira: segura aos 300 ms, arrasta (em px da tela) até o peito do
## rival e solta aos 1000 ms.
static func robo_mira(c: ControladorJusta, alvo_quadro: Vector2) -> void:
	var j := c.justa
	if j.fases.fase != JustaFases.Fase.MIRA or j.solto:
		return
	var t := j.fases.tempo_na_fase_ms
	if t >= 300 and not j.segurando:
		c.segurar_mira()
		var falta := alvo_quadro - Vector2(j.ponta) / 10.0
		var tela := c.arena.rival.visual().global_transform.basis_xform(falta) * c.arena.camera.zoom
		c.arrastar_mira(tela)
	elif t >= 1000 and j.segurando:
		c.soltar_mira()

func _checa(nome: String, ok: bool) -> void:
	print("JUSTA %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
