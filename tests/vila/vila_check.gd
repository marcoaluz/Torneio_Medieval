extends SceneTree
## Vila (headless, save em user://teste_vila/): liberação por nível, teto da
## casa senhorial, melhoria (ouro cobrado, timer por horário de término,
## balão, ocupado), relógio adiantado deixa pronto e tocar conclui, toque no
## prédio certo, painel e botão de justar na arena.

var _falhas := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame  # o _ready do autoload Jogador roda antes de mexermos nele
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_vila/")
	jog.caminho_save = "user://teste_vila/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000  # fora do primeiro dia
	jog.estado["inventario"]["ouro"] = 1000
	var vila: Vila = load("res://game/scenes/village/vila.tscn").instantiate()
	root.add_child(vila)
	await process_frame

	_checa("um predio por item de vila.json", vila.predios.size() == (Balanceamento.ler("vila")["ordem"] as Array).size())
	_checa("arena bloqueada no nivel 1", vila.predios["arena"].bloqueado and not jog.predio_liberado("arena"))
	_checa("estabulo liberado", not vila.predios["estabulo"].bloqueado)
	vila.tocar_predio("arena")
	_checa("tocar bloqueado avisa o nivel", vila._letreiro.text == "Arena de torneios abre no nível 2")
	_checa("estabulo no teto da casa senhorial (1)", jog.pode_melhorar("estabulo")["erro"] == "predio_no_teto")

	# Melhorar a casa senhorial
	var ouro_antes := jog.ouro()
	vila.abrir_painel("casa_senhorial")
	_checa("painel mostra custo", vila._melhorar.text.begins_with("Melhorar (80 ouro"))
	vila._melhorar.pressed.emit()
	_checa("ouro cobrado", jog.ouro() == ouro_antes - 80)
	var t := jog.timer_do_predio("casa_senhorial")
	_checa("timer com horario de termino", not t.is_empty() and int(t["termina_em"]) - ServicoTempo.agora() >= 119)
	vila.atualizar()
	_checa("balao com o tempo", vila.predios["casa_senhorial"]._balao.visible and vila.predios["casa_senhorial"]._balao.text in ["2:00", "1:59"])
	_checa("ocupado nao melhora de novo", jog.pode_melhorar("casa_senhorial")["erro"] == "predio_ocupado")
	_checa("concluir antes da hora falha", jog.concluir_timer(t["id"])["erro"] == "timer_nao_terminou")

	ServicoTempo.deslocamento = 121
	vila.atualizar()
	_checa("pronto mostra o icone", vila.predios["casa_senhorial"].pronto and not vila.predios["casa_senhorial"]._balao.visible)
	vila.tocar_predio("casa_senhorial")
	_checa("tocar conclui e sobe de nivel", jog.predio_nivel("casa_senhorial") == 2 and jog.timer_do_predio("casa_senhorial").is_empty())
	_checa("teto dos outros sobe junto", jog.teto_predio("estabulo") == 2 and jog.pode_melhorar("estabulo")["ok"])
	ServicoTempo.deslocamento = 0

	jog.estado["inventario"]["ouro"] = 10
	_checa("sem ouro nao melhora", jog.pode_melhorar("estabulo")["erro"] == "ouro_insuficiente")

	# Toque no mapa
	var pos: Vector2 = vila.predios["ferreiro"].position
	_checa("ponto no predio acha o predio", vila.predio_em(pos) == "ferreiro")
	_checa("ponto vazio nao acha nada", vila.predio_em(Vector2(480, 300)) == "")

	# Arena liberada no nivel 2 com botao de justar
	jog.estado["cavaleiro"]["nivel"] = 2
	vila.atualizar()
	var justar := [false]
	vila.abrir_justa.connect(func(): justar[0] = true)
	vila.tocar_predio("arena")
	_checa("arena abre no nivel 2 com botao justar", vila._painel.visible and vila._acao.visible and vila._acao.text == "Justar")
	vila._acao.pressed.emit()
	_checa("botao justar pede a justa", justar[0])
	_checa("formato de tempo", Vila.formatar_tempo(45) == "45 s" and Vila.formatar_tempo(3725) == "1 h 02 min")

	for f in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_vila/" + f)
	# Sede da ordem: bloqueada abaixo do nível mínimo da ordem, brasão na fachada só com ordem, toque abre o social.
	var nivel_ordem := int(Balanceamento.ler("ordem")["nivel_minimo"])
	_checa("sede da ordem libera no nivel minimo da ordem", int(Balanceamento.ler("vila")["predios"]["guilda"]["libera_nivel"]) == nivel_ordem)
	var guilda: PredioVila = vila.predios["guilda"]
	_checa("sede bloqueada e sem estandarte antes da ordem", guilda.bloqueado and (guilda._estandarte == null or not guilda._estandarte.visible))
	jog.estado["cavaleiro"]["nivel"] = nivel_ordem
	jog.estado["inventario"]["ouro"] = 5000
	vila.atualizar()
	_checa("sede liberada no nivel da ordem", not guilda.bloqueado)
	vila.tocar_predio("guilda")
	_checa("tocar a sede abre a tela social na ordem", vila.tela_social.visible and vila.tela_social.aba == "ordem")
	vila.tela_social.visible = false
	_checa("sem ordem, sem brasao na fachada", guilda._estandarte == null or not guilda._estandarte.visible)
	_checa("cria a ordem", jog.criar_ordem("Ordem da Rosa")["ok"])
	vila.atualizar()
	_checa("com ordem, o estandarte aparece", guilda._estandarte != null and guilda._estandarte.visible and guilda._estandarte_brasao.texture != null)
	var textura_antes := guilda._estandarte_brasao.texture
	var novo: Dictionary = jog.brasao_da_ordem().duplicate(true)
	novo["cor1"] = "verde_floresta" if str(novo.get("cor1", "")) != "verde_floresta" else "azul_real"
	jog.editar_brasao_ordem(novo)
	vila.atualizar()
	_checa("trocar o brasao da ordem refaz o estandarte", guilda._estandarte_brasao.texture != textura_antes)
	# Trocar o idioma com a vila aberta refaz a legenda dos prédios e os botões fixos.
	TranslationServer.set_locale("en")
	_checa("legenda do predio segue o idioma (en)", vila.predios["arena"]._nome.text == "Tournament arena"
		and vila.predios["loja"]._nome.text == "Shop")
	_checa("botao Fechar segue o idioma (en)", vila._fechar.text == "Close")
	_checa("tela de treino segue o idioma (en)", vila.tela_treino._fechar.text == "Close" and vila.tela_treino._habilidades.text == "Abilities")
	TranslationServer.set_locale("pt_BR")
	_checa("volta ao portugues", vila.predios["arena"]._nome.text == "Arena de torneios" and vila._fechar.text == "Fechar")
	print("VILA %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("VILA %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
