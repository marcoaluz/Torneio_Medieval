extends SceneTree
## Som dos prédios (GDD A vila > Som dos prédios), headless com a vila de
## verdade (save em user://teste_som_telas/): entrar e sair de cada prédio
## (campo de treino, estábulo, armeiro, ferreiro) não liga nenhum som contínuo
## (estábulo, armeiro e ferreiro não têm ambiente; nem martelo em laço),
## o estábulo só bufa ao toque no cavalo (uma vez, com 2 s de intervalo) e o
## ferreiro só martela ao toque ou quando a peça fica pronta; os efeitos
## (galope, martelo, bufada) param ao sair com fade curto,
## a chuva da vila some com o prédio aberto e volta ao fechar, o efeito nunca
## toca em laço, e fechar por outro caminho (sem o botão) também para.

var _falhas := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_som_telas/")
	jog.caminho_save = "user://teste_som_telas/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
	jog.estado["cavaleiro"]["nivel"] = 20
	var audio: ServicoAudio = root.get_node("Audio")
	var fade := float(Balanceamento.ler_json(ServicoAudio.CATALOGO)["fade_tela_s"])

	# Efeito nunca toca em laço; o laço é uma cópia (o arquivo fica intacto).
	var efeito := audio._stream("galope")
	var em_laco := audio._stream("galope", true)
	_checa("galope como efeito nao repete", efeito != null and not _repete(efeito))
	_checa("galope como laco repete", em_laco != null and _repete(em_laco))
	_checa("galope de novo como efeito continua sem laco", not _repete(audio._stream("galope")))

	var vila: Vila = load("res://game/scenes/village/vila.tscn").instantiate()
	root.add_child(vila)
	await process_frame
	if vila.cena_historia.visible:
		vila.cena_historia.visible = false
	await process_frame
	_checa("a vila e a cena do som", audio.tela_atual() == "vila" and audio.telas_abertas().size() == 1)
	audio.laco("chuva_vila", true, "vila")
	_checa("chuva da vila tocando", audio.tocando_laco("chuva_vila"))

	var esperado := {"campo_treino": [], "estabulo": [], "armeiro": [], "ferreiro": []}
	for predio: String in esperado:
		_checa("%s liberado" % predio, jog.predio_liberado(predio))
		vila.tocar_predio(predio)
		await process_frame
		_checa("%s: tela do som e o predio" % predio, audio.tela_atual() == predio)
		var ambiente_ok := true
		for id: String in esperado[predio]:
			ambiente_ok = ambiente_ok and audio.tocando_laco(id)
		_checa("%s: ambiente proprio tocando (%s)" % [predio, esperado[predio]], ambiente_ok)
		if predio != "campo_treino":
			_checa("%s: nenhum som continuo tocando (%s)" % [predio, audio.lacos_tocando()], audio.lacos_tocando().is_empty())
		_checa("%s: chuva da vila parada" % predio, not audio.tocando_laco("chuva_vila"))
		# Um efeito repetido do prédio (galope do treino, bufada, martelo).
		match predio:
			"campo_treino": (vila.tela_treino._campo as CenaCampoTreino).passar_agora()
			"estabulo": vila.tela_treino._cena.reagir()
			_: vila.tela_forja._som_do_martelo()
		_checa("%s: efeito tocando" % predio, audio.efeitos_tocando(predio) > 0)
		# Sair: pelo botão Fechar no primeiro e no terceiro, escondendo a tela nos outros.
		var tela: Control = vila.tela_forja if predio in ["armeiro", "ferreiro"] else vila.tela_treino
		if predio in ["campo_treino", "armeiro"]:
			(tela.get_node("Coluna/Botoes/Fechar") as Button).pressed.emit()
		else:
			tela.visible = false
		await process_frame
		_checa("%s: ao sair a vila volta a ser a tela" % predio, audio.tela_atual() == "vila")
		var parou := true
		for id: String in esperado[predio]:
			parou = parou and not audio.tocando_laco(id)
		_checa("%s: ambiente parou" % predio, parou)
		_checa("%s: chuva da vila voltou" % predio, audio.tocando_laco("chuva_vila"))
		await create_timer(fade + 0.15).timeout
		_checa("%s: efeitos pararam com o fade" % predio, audio.efeitos_tocando(predio) == 0)
		# Tela fechada não faz som: um golpe atrasado do martelo é ignorado.
		_checa("%s: efeito pedido depois de sair nao toca" % predio, not audio.tocar("martelo_bigorna", 0.0, predio))

	# Estábulo: sem ambiente; o cavalo bufa uma vez por toque, com 2 s de intervalo.
	vila.tocar_predio("estabulo")
	await process_frame
	var cena: CenaEstabulo = vila.tela_treino._cena
	_checa("estabulo aberto sem nenhum laco", audio.lacos_tocando().is_empty() and audio.efeitos_tocando("estabulo") == 0)
	var intervalo := float(Balanceamento.ler_json(ServicoAudio.CATALOGO)["sons"]["cavalo_bufando"]["intervalo_min_s"])
	_checa("intervalo minimo do relincho e de 2 s", is_equal_approx(intervalo, 2.0))
	await create_timer(intervalo + 0.1).timeout  # a bufada da troca de peça (se houve) já passou do intervalo
	_checa("tocar no cavalo bufa", cena.tocar_no_cavalo())
	_checa("tocar de novo logo depois nao bufa", not cena.tocar_no_cavalo())
	_checa("so uma bufada soando", audio.efeitos_tocando("estabulo") == 1)
	# Toque de verdade no palco (na área do cavalo) e fora dela.
	await create_timer(intervalo + 0.1).timeout
	var toque := InputEventMouseButton.new()
	toque.button_index = MOUSE_BUTTON_LEFT
	toque.pressed = true
	toque.position = Vector2(2, 2)  # canto do palco: fora do cavalo
	cena._ao_tocar_palco(toque)
	_checa("toque fora do cavalo nao bufa", audio.efeitos_tocando("estabulo") == 0 or not audio.tocar("cavalo_bufando", 0.0, "estabulo"))
	await create_timer(intervalo + 0.1).timeout
	toque.position = cena.area_do_cavalo().get_center()
	cena._ao_tocar_palco(toque)
	_checa("toque no cavalo bufa", audio.efeitos_tocando("estabulo") == 1)
	await create_timer(0.3).timeout
	_checa("passado o toque, nada fica em laco", audio.lacos_tocando().is_empty())
	vila.tela_treino.visible = false
	await process_frame

	# Ferreiro: o martelo em laço é só desenho (sem som); uma martelada ao toque.
	vila.tocar_predio("ferreiro")
	await process_frame
	vila.tela_forja._bater_martelo()
	await create_timer(1.3).timeout  # vários golpes do martelo desenhado
	_checa("martelo batendo no desenho nao faz som", audio.efeitos_tocando("ferreiro") == 0 and audio.lacos_tocando().is_empty())
	vila.tela_forja.tocar_no_ferreiro()
	_checa("tocar no ferreiro: uma martelada", audio.efeitos_tocando("ferreiro") == 1)
	await create_timer(fade + 0.8).timeout
	# Peça pronta com a tela aberta: uma martelada (a primeira conferência só anota).
	jog.estado["inventario"]["materiais"].merge({"sucata": 30}, true)
	jog.estado["timers"].append({"id": "t_teste", "tipo": "fundicao", "alvo": "ferreiro", "produto": "ferro", "quantidade": 1,
		"inicio_em": ServicoTempo.agora(), "termina_em": ServicoTempo.agora() + 3600})
	vila.tela_forja._pronto_visto.clear()
	vila.tela_forja._montar_oficina()
	await create_timer(0.1).timeout
	_checa("timer em andamento nao faz som", audio.efeitos_tocando("ferreiro") == 0)
	jog.estado["timers"][-1]["termina_em"] = ServicoTempo.agora() - 1
	vila.tela_forja._montar_oficina()
	_checa("peca ficou pronta: uma martelada", audio.efeitos_tocando("ferreiro") == 1)
	vila.tela_forja.visible = false
	await process_frame
	jog.estado["timers"].pop_back()

	# Uma tela por cima da outra: Equipamentos a partir da forja para a forja e devolve.
	vila.tocar_predio("armeiro")
	await process_frame
	vila.tela_equipamentos.abrir()
	await process_frame
	_checa("equipamentos por cima da forja", audio.tela_atual() == "tela_equipamentos")
	vila.tela_equipamentos.visible = false
	await process_frame
	_checa("ao fechar equipamentos a forja volta (sem laco nenhum)", audio.tela_atual() == "armeiro" and audio.lacos_tocando().size() == 0)
	vila.tela_forja.visible = false
	await process_frame
	_checa("e ao fechar a forja, a vila (so a chuva dela, se chover)", audio.tela_atual() == "vila")

	# Botão de interface não pertence a tela nenhuma.
	_checa("som de interface toca em qualquer tela", audio.tocar("botao"))

	# Trocar de cena (arena) para o ambiente da vila.
	audio.trocar_cena("arena")
	_checa("trocar de cena para a chuva", not audio.tocando_laco("chuva_vila") and audio.tela_atual() == "arena")
	vila.queue_free()
	await process_frame

	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_som_telas/" + arq)
	print("SOMTELAS %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

## O som (ou todas as variações dele) repete sozinho?
static func _repete(s: AudioStream) -> bool:
	if s is AudioStreamRandomizer:
		var r := s as AudioStreamRandomizer
		for i in r.streams_count:
			if not _repete(r.get_stream(i)):
				return false
		return r.streams_count > 0
	if s is AudioStreamWAV:
		return (s as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	return bool(s.get("loop"))

func _checa(nome: String, ok: bool) -> void:
	print("SOMTELAS %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
