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
	jog.estado["inventario"]["ouro"] = 1000
	var vila: Vila = load("res://game/scenes/village/vila.tscn").instantiate()
	root.add_child(vila)
	await process_frame

	_checa("seis predios", vila.predios.size() == 6)
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
	print("VILA %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("VILA %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
