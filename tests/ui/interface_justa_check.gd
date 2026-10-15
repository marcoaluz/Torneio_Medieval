extends SceneTree
## Interface da justa (headless): textos traduzidos, placar e passada,
## plaquinhas, botão de habilidade (carga, uso único, não vira toque do jogo),
## letreiro, resultado no fim e recomeço com toque. Robô igual ao da arena.

const PEITO := Vector2(8, -86)

var _falhas := 0

func _initialize() -> void:
	await process_frame
	var _jog_teste: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_arena/")
	_jog_teste.caminho_save = "user://teste_arena/jogador.json"
	_jog_teste.estado = _jog_teste.novo_estado()
	TranslationServer.set_locale("pt_BR")
	var arena: Arena = load("res://game/scenes/arena/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var c: ControladorJusta = arena.get_node("Justa")
	var ui: InterfaceJusta = arena.get_node("Interface/InterfaceJusta")
	c.set_process(false)
	ui.set_process(false)
	c.iniciar(21)
	ui._process(0.0)

	_checa("passada 1/3 em portugues (%s)" % ui.passada.text, ui.passada.text == "Passada 1/3")
	_checa("placar comeca 0 x 0", ui.placar.text == "0  ×  0")
	_checa("nome do rival traduzido (%s)" % ui.plaquinha_rival.get_node("Linha/Dados/Nome").text,
		ui.plaquinha_rival.get_node("Linha/Dados/Nome").text == "Cavaleiro da Planície")
	_checa("botao de habilidade aparece (investida)", ui.botao.visible and ui.botao.text == "Investida")
	_checa("botao desligado fora da corrida", ui.botao.disabled)
	_checa("so o botao recebe toque", ui.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and ui.barra.mouse_filter == Control.MOUSE_FILTER_IGNORE and ui.botao.mouse_filter == Control.MOUSE_FILTER_STOP)

	var passo := 1.0 / 30.0
	var viu_carga_parcial := false
	var ligou_depois_da_carga := false
	var toque_no_botao_nao_galopou := false
	var letreiros: Array[String] = []
	var quadros := 0
	while not c.justa.terminou() and quadros < 30 * 120:
		var j := c.justa
		var f := c.fase()
		if f == JustaFases.Fase.LARGADA and j.bandeira_baixou and not j.tocou_largada:
			c.tocar()
		elif f == JustaFases.Fase.CORRIDA:
			var p := j.jogador.compasso_ms()
			var resto := j.jogador.t_ms % p
			if j.jogador.t_ms >= p / 2 and (resto <= 17 or resto > p - 17):
				c.tocar()
			if ui.botao.carga > 0.0 and ui.botao.carga < 1.0:
				viu_carga_parcial = true
			if not j.habilidade_usada_jogador and not ui.botao.disabled and j.fases.passada == 1:
				ligou_depois_da_carga = j.habilidade_carregada(true)
				# Toque na área do botão: não pode virar toque de galope.
				var toque := InputEventScreenTouch.new()
				toque.pressed = true
				toque.position = ui.botao.get_global_rect().get_center()
				var antes := j.jogador.acertos + j.jogador.compassos
				var folego_antes := j.jogador.folego
				c._unhandled_input(toque)
				toque_no_botao_nao_galopou = j.jogador.folego == folego_antes and j.jogador.acertos + j.jogador.compassos == antes
				ui.botao.pressed.emit()
		elif f == JustaFases.Fase.MIRA:
			preload("res://tests/arena/justa_check.gd").robo_mira(c, PEITO)
		c._process(passo)
		ui._process(passo)
		if ui.letreiro.visible and (letreiros.is_empty() or letreiros.back() != ui.letreiro.text):
			letreiros.append(ui.letreiro.text)
		quadros += 1

	_checa("anel de carga sobe durante a corrida", viu_carga_parcial)
	_checa("botao so liga depois da carga", ligou_depois_da_carga)
	_checa("toque no botao nao conta como galope", toque_no_botao_nao_galopou)
	_checa("habilidade usada uma vez", c.justa.habilidade_usada_jogador and ui.botao.disabled)
	_checa("letreiros mostram largada, habilidade e golpe %s" % [letreiros],
		letreiros.has("Largada perfeita!") and letreiros.has("Investida") and letreiros.any(func(t): return t.begins_with("Peito +2") or t.begins_with("Escudo +1") or t.begins_with("Bloqueado")))
	_checa("resultado aparece no fim (%s / %s)" % [ui.resultado_titulo.text, ui.resultado_motivo.text],
		ui.resultado.visible and ui.resultado_titulo.text != "" and ui.resultado_dica.text == "Toque para justar de novo")
	var pj := c.justa.fases.placar_jogador
	var pr := c.justa.fases.placar_rival
	_checa("placar na tela bate com a regra", ui.placar.text == "%d  ×  %d" % [pj, pr])

	# Recomeço: toque logo no fim não recomeça; depois da espera, recomeça.
	var t2 := InputEventScreenTouch.new()
	t2.pressed = true
	t2.position = Vector2(300, 300)
	c._unhandled_input(t2)
	_checa("toque logo no fim nao recomeca", c.justa.terminou())
	for i in 40:
		c._process(passo)
	c._unhandled_input(t2)
	ui._process(0.0)
	_checa("toque depois da espera recomeca", not c.justa.terminou() and c.fase() == JustaFases.Fase.APRESENTACAO and not ui.resultado.visible)

	TranslationServer.set_locale("en")
	ui._process(0.0)
	_checa("em ingles: %s" % ui.passada.text, ui.passada.text == "Pass 1/3")

	print("UI %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("UI %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
