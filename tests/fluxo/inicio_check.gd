extends SceneTree
## Início do jogo de ponta a ponta (headless, save em user://teste_inicio/):
## título -> criação -> brasão -> justa de exibição (IA x IA, câmera aberta,
## arauto) -> primeira justa (rival fraco, dicas) -> baú (peça equipada,
## nível 2) -> vila. E o caminho de pular o tutorial, e os timers do primeiro
## dia em segundos.

var _falhas := 0
var _jog: ServicoJogador
var _fluxo: FluxoTelas

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	_jog = root.get_node("Jogador")
	_fluxo = root.get_node("Fluxo")
	DirAccess.make_dir_recursive_absolute("user://teste_inicio/")
	_jog.caminho_save = "user://teste_inicio/jogador.json"
	_jog.estado = _jog.novo_estado()

	_checa("primeiro dia: timer de 5 min termina em 15 s", _jog.duracao_timer(300) == 15)

	_fluxo.iniciar_jogo()
	var cena := await _cena()
	_checa("comeca no titulo", cena is TelaTitulo)
	# Sem aceitar a política de privacidade (3.9) o título não deixa começar.
	_checa("sem aceite da politica", not _jog.privacidade_aceita())
	(cena as TelaTitulo).comecar()
	await process_frame
	var priv: TelaPrivacidade = null
	for c0 in cena.get_children():
		if c0 is TelaPrivacidade:
			priv = c0
	_checa("titulo pede o aceite da politica", priv != null and _jog.tutorial_passo() == 0)
	priv._ao_aceitar()
	cena = await _cena()
	_checa("aceitou: titulo -> criacao", cena is CriacaoPersonagem and _jog.tutorial_passo() == 1 and _jog.privacidade_aceita())
	var cri := cena as CriacaoPersonagem
	cri.sortear()
	cri.confirmar()
	cena = await _cena()
	_checa("criacao -> brasao", cena is EditorBrasao and _jog.tem_personagem() and _jog.tutorial_passo() == 2)
	(cena as EditorBrasao).confirmar()
	cena = await _cena()
	_checa("brasao -> justa de exibicao", cena is Arena and _fluxo.modo_justa == "exibicao" and _jog.tutorial_passo() == 3)

	# Exibição: IA x IA, câmera aberta, arauto; não mexe no jogador.
	var arena := cena as Arena
	var c: ControladorJusta = arena.get_node("Justa")
	var ui: InterfaceJusta = arena.get_node("Interface/InterfaceJusta")
	c.set_process(false)
	_checa("exibicao com dois veteranos", c.modo == "exibicao" and c.justa.ia_jogador != null and c.justa.ia != null)
	var folego0 := _jog.folego_cavalo()
	var sempre_aberta := true
	var falou_mira := false
	var quadros := 0
	while not c.justa.terminou() and quadros < 30 * 120:
		c._process(1.0 / 30.0)
		if arena.camera.plano != CameraArena.Plano.ABERTO:
			sempre_aberta = false
		if ui.get_node("Dica").text.begins_with("O arauto: A mira"):
			falou_mira = true
		quadros += 1
	_checa("camera da arquibancada (sempre aberta)", sempre_aberta)
	_checa("o arauto explica as fases", falou_mira)
	_checa("exibicao nao gasta o cavalo do jogador", _jog.folego_cavalo() == folego0)
	c._tempo_desde_fim = 5.0
	_tocar(c)
	cena = await _cena()
	_checa("exibicao -> primeira justa", cena is Arena and _fluxo.modo_justa == "tutorial" and _jog.tutorial_passo() == 4)

	# Primeira justa: rival fraco e dicas.
	arena = cena as Arena
	c = arena.get_node("Justa")
	ui = arena.get_node("Interface/InterfaceJusta")
	c.set_process(false)
	_checa("rival fraco do tutorial", c.nome_rival == "RIVAL_TUTORIAL" and int(c.lado_rival["cavaleiro"]["precisao"]) == 5)
	var viu_dica_largada := false
	quadros = 0
	while not c.justa.terminou() and quadros < 30 * 120:
		var j := c.justa
		if c.fase() == JustaFases.Fase.LARGADA:
			if ui.get_node("Dica").text.begins_with("Espere a bandeira"):
				viu_dica_largada = true
			if j.bandeira_baixou and not j.tocou_largada:
				c.tocar()
		elif c.fase() == JustaFases.Fase.CORRIDA:
			var p := j.jogador.compasso_ms()
			var resto := j.jogador.t_ms % p
			if j.jogador.t_ms >= p / 2 and (resto <= 17 or resto > p - 17):
				c.tocar()
		elif c.fase() == JustaFases.Fase.MIRA:
			preload("res://tests/arena/justa_check.gd").robo_mira(c, Vector2(-5, -106))
		c._process(1.0 / 30.0)
		quadros += 1
	_checa("dica da largada aparece", viu_dica_largada)
	_checa("vitoria na primeira justa (%s)" % ui.resultado_titulo.text, c.justa.fases.vencedor == JustaFases.Lado.JOGADOR)
	c._tempo_desde_fim = 5.0
	_tocar(c)
	cena = await _cena()
	_checa("primeira justa -> bau", cena is TelaBau and _jog.tutorial_passo() == 5)
	var bau := cena as TelaBau
	bau.abrir()
	_checa("bau da a peca ja equipada e o nivel 2", _jog.equipado("elmo")["modelo"] == "elmo_vigia" and int(_jog.cavaleiro()["nivel"]) == 2)
	bau.abrir()
	_checa("recompensa do tutorial uma vez so", _jog.itens().filter(func(i): return i["modelo"] == "elmo_vigia").size() == 1)
	bau._seguir.pressed.emit()
	cena = await _cena()
	_checa("bau -> vila, tutorial concluido", cena is Vila and _jog.tutorial_concluido())
	_checa("na vila a arena ja abre (nivel 2)", _jog.predio_liberado("arena") and not _jog.predio_liberado("armeiro"))
	_fluxo.iniciar_jogo()
	cena = await _cena()
	_checa("abrir o jogo de novo vai direto para a vila", cena is Vila)

	# Pular o tutorial
	_jog.estado = _jog.novo_estado()
	_jog.aceitar_privacidade(false)  # reinstalou, mas já aceitou (a política vale por versão)
	_fluxo.pulando_tutorial = false
	_fluxo.iniciar_jogo()
	cena = await _cena()
	(cena as TelaTitulo).pular()
	cena = await _cena()
	(cena as CriacaoPersonagem).sortear()
	(cena as CriacaoPersonagem).confirmar()
	cena = await _cena()
	(cena as EditorBrasao).confirmar()
	cena = await _cena()
	_checa("pular: criacao e brasao levam direto a vila", cena is Vila and _jog.tutorial_concluido())
	_checa("pular tambem da a recompensa (nivel 2 e a peca)", int(_jog.cavaleiro()["nivel"]) == 2 and _jog.equipado("elmo")["modelo"] == "elmo_vigia")

	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_inicio/" + arq)
	print("INICIO %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

## Espera a troca de cena (deferida) e devolve a cena atual.
func _cena() -> Node:
	for i in 4:
		await process_frame
	return current_scene

func _tocar(c: ControladorJusta) -> void:
	var t := InputEventScreenTouch.new()
	t.pressed = true
	t.position = Vector2(300, 300)
	c._unhandled_input(t)

func _checa(nome: String, ok: bool) -> void:
	print("INICIO %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
