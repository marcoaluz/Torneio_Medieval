extends SceneTree
## Sensação de impacto (headless): com resultados de impacto fabricados,
## confere hit-stop (e a volta do tempo), tremor proporcional, lascas,
## faíscas só no metal, peça voando com dano alto, lança quebrada, queda na
## derrubada e a restauração na passada seguinte.

var _falhas := 0

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
	var ef: EfeitosImpacto = arena.get_node("Efeitos")
	c.set_process(false)
	c.iniciar(5)

	var erro := _res("erro", "erro", 0, {}, false)
	ef._ao_impacto(1, erro, erro, JustaFases.Lado.NENHUM, JustaFases.Lado.NENHUM)
	_checa("sem contato nao treme nem congela", arena.camera.trauma == 0.0 and Engine.time_scale == 1.0)

	var fraco := _res("escudo", "escudo", 1, {"escudo": 5}, false)
	_checa("forca proporcional ao dano (%.2f)" % ef.forca_do_golpe(fraco), absf(ef.forca_do_golpe(fraco) - 0.2) < 0.01)
	var forte := _res("capacete", "capacete", 3, {"elmo": 25}, true)
	_checa("derrubada tem forca 1", ef.forca_do_golpe(forte) == 1.0)

	ef._ao_impacto(1, forte, erro, JustaFases.Lado.RIVAL, JustaFases.Lado.NENHUM)
	_checa("hit-stop congela o tempo", Engine.time_scale < 1.0 and ef.hit_stop_ativo())
	_checa("tremor maximo na derrubada (%.2f)" % arena.camera.trauma, arena.camera.trauma == 1.0)
	_checa("lascas da lanca", _contar(arena, "Lascas") == 1)
	_checa("faiscas no capacete (metal)", _contar(arena, "Faiscas") == 1)
	_checa("peca voando com dano alto", _pecas_voando(arena) == 1)
	_checa("lanca do jogador quebrou", arena.jogador.get_node("Visual/Lanca").scale.x < 1.0)
	_checa("rival caiu do cavalo", arena.rival.caido)

	await create_timer(0.4, true, false, true).timeout
	_checa("tempo volta ao normal depois do hit-stop", Engine.time_scale == 1.0 and not ef.hit_stop_ativo())

	ef._ao_impacto(2, fraco, erro, JustaFases.Lado.NENHUM, JustaFases.Lado.NENHUM)
	_checa("no escudo nao tem faisca", _contar(arena, "Faiscas") <= 1)
	await create_timer(0.4, true, false, true).timeout

	ef._ao_comecar_passada(2)
	_checa("passada nova restaura o rival e a lanca",
		not arena.rival.caido and arena.rival.get_node("Visual/Cavaleiro").rotation == 0.0
		and arena.jogador.get_node("Visual/Lanca").scale.x == 1.0)

	print("EFEITOS %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _res(zona: String, zona_final: String, pontos: int, dano: Dictionary, derrubou: bool) -> Dictionary:
	return {"zona": zona, "zona_final": zona_final, "bloqueado": false, "bloqueio_por": "", "falta": false,
		"pontos": pontos, "chance_derrubar_milesimos": 0, "derrubou": derrubou, "habilidade": "",
		"dano": dano, "dano_lanca": 0 if zona == "erro" else 4}

func _contar(arena: Node, prefixo: String) -> int:
	var n := 0
	for f in arena.get_children():
		if f is CPUParticles2D and String(f.name).begins_with(prefixo):
			n += 1
	return n

func _pecas_voando(arena: Node) -> int:
	var n := 0
	for f in arena.get_children():
		if f is Node2D and (f as Node2D).z_index == 15:
			n += 1
	return n

func _checa(nome: String, ok: bool) -> void:
	print("EFEITOS %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
