extends SceneTree
## Lança na Corrida (ControladorJusta, cena real, headless): o dedo que toca no
## compasso pode arrastar para subir ou baixar a lança sem virar toque; a
## ponta segue com inércia leve; a Mira começa da altura escolhida e o dedo
## que arrastava a lança já segura; soltar golpeia. Também: o arrasto não
## mexe no galope, e sem arrastar a Mira começa da ponta inicial.

var _falhas := 0

func _initialize() -> void:
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_lanca/")
	jog.caminho_save = "user://teste_lanca/jogador.json"
	jog.estado = jog.novo_estado()
	var arena: Arena = load("res://game/scenes/arena/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var c: ControladorJusta = arena.get_node("Justa")
	c.set_process(false)  # o teste passa o tempo na mão
	var passo := 1.0 / 30.0
	var inicial := Vector2(Mira.ponta_inicial(c._cfg["mira"]))

	c.iniciar(11)
	# Largada perfeita e Corrida até a metade, tocando no compasso.
	_ate_corrida(c, passo)
	_checa("chega na corrida", c.fase() == JustaFases.Fase.CORRIDA)
	var g := c.justa.jogador
	var antes := {"acertos": g.acertos, "compassos": g.compassos, "folego": g.folego}
	var toques_antes := _toques(c)
	# Toque no compasso (encosta o dedo) e arrasta para cima sem soltar.
	_esperar_batida(c, passo)
	_toque(c, true)
	var depois_do_toque := _toques(c)
	_checa("encostar o dedo galopa (1 toque)", depois_do_toque == toques_antes + 1)
	var acertos_toque := g.acertos
	var folego_toque := g.folego
	var saltos := 0.0
	var anterior := c._base_mira
	for i in 12:
		_arrasto(c, Vector2(0, -6))
		c._process(passo)
		saltos = maxf(saltos, c._base_mira.distance_to(anterior))
		anterior = c._base_mira
	_checa("arrastar nao vira toque", _toques(c) == depois_do_toque)
	_checa("arrastar nao mexe no galope (acertos, folego)", g.acertos >= acertos_toque and g.folego == folego_toque)
	_checa("o alvo da lanca subiu (%.0f -> %.0f decimos)" % [inicial.y, c._alvo_mira.y], c._alvo_mira.y < inicial.y - 300.0)
	_checa("a ponta segue com inercia (maior passo %.0f decimos por quadro)" % saltos, saltos > 0.0 and saltos < 160.0)
	for i in 20:
		c._process(passo)
	_checa("a ponta assenta no alvo (%.0f / %.0f)" % [c._base_mira.y, c._alvo_mira.y], absf(c._base_mira.y - c._alvo_mira.y) < 15.0)
	# Inércia leve: passa um pouco do alvo e volta (sem oscilar muito).
	var c2 := _sobra(c, passo)
	_checa("sobra leve da mao (%.1f%% do movimento)" % c2, c2 >= 0.0 and c2 < 12.0)
	var altura := c._alvo_mira.y
	# Segue segurando até a Mira.
	var t := 0
	while c.fase() == JustaFases.Fase.CORRIDA and t < 400:
		c._process(passo)
		t += 1
	_checa("chega na mira com o dedo na tela", c.fase() == JustaFases.Fase.MIRA)
	_checa("o dedo que arrastava a lanca ja segura na mira", c.justa.segurando)
	c._process(passo)
	_checa("a mira comeca da altura escolhida (%.0f ~ %.0f)" % [float(c.justa.ponta.y), altura],
		absf(float(c.justa.ponta.y) - altura) <= 40.0)
	_toque(c, false)
	_checa("soltar golpeia", c.justa.solto)

	# Próxima passada: sem arrastar, a Mira começa da ponta inicial e só segura com toque novo.
	while c.fase() != JustaFases.Fase.LARGADA and not c.justa.terminou():
		c._process(passo)
	if not c.justa.terminou():
		_checa("na largada a lanca volta para a ponta inicial", c._base_mira.is_equal_approx(inicial))
		_ate_corrida(c, passo)
		_esperar_batida(c, passo)
		_toque(c, true)  # toca e segura, sem arrastar
		while c.fase() == JustaFases.Fase.CORRIDA:
			c._process(passo)
		_checa("sem arrastar, o dedo parado nao segura a mira", not c.justa.segurando)
		_checa("sem arrastar, a mira comeca da ponta inicial", Vector2(c.justa.ponta).distance_to(inicial) < 1.0)
		_toque(c, false)
		_checa("soltar sem segurar nao golpeia", not c.justa.solto)
	else:
		_checa("a justa continuou para outra passada", false)

	print("LANCA %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

## Largada perfeita e avança até a Corrida.
func _ate_corrida(c: ControladorJusta, passo: float) -> void:
	var n := 0
	while c.fase() != JustaFases.Fase.CORRIDA and n < 600:
		var j := c.justa
		if c.fase() == JustaFases.Fase.APRESENTACAO:
			c.tocar()
		elif c.fase() == JustaFases.Fase.LARGADA and j.bandeira_baixou and not j.tocou_largada:
			c.tocar()
		c._process(passo)
		n += 1

## Avança até perto de uma batida do galope (o toque cai no tempo).
func _esperar_batida(c: ControladorJusta, passo: float) -> void:
	var g := c.justa.jogador
	var p := g.compasso_ms()
	var n := 0
	while n < 60:
		var resto := g.t_ms % p
		if g.t_ms >= p / 2 and (resto <= 17 or resto > p - 17):
			return
		c._process(passo)
		n += 1

func _toque(c: ControladorJusta, apertou: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.pressed = apertou
	e.position = Vector2(480, 300)
	c._unhandled_input(e)

func _arrasto(c: ControladorJusta, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.relative = rel
	e.position = Vector2(480, 300)
	c._unhandled_input(e)

## Toques de galope já registrados nas entradas.
func _toques(c: ControladorJusta) -> int:
	return c.entradas.filter(func(x): return x[1] == "tocar").size()

## Mede a sobra: move o alvo para baixo de uma vez e vê quanto a ponta passa.
func _sobra(c: ControladorJusta, passo: float) -> float:
	var de := c._base_mira.y
	c._alvo_mira.y += 400.0
	var maximo := de
	for i in 30:
		c._process(passo)
		maximo = maxf(maximo, c._base_mira.y)
	var ida := c._alvo_mira.y - de
	return 100.0 * (maximo - c._alvo_mira.y) / ida

func _checa(nome: String, ok: bool) -> void:
	print("LANCA %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
