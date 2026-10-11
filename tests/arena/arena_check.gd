extends SceneTree
## Confere a montagem da arena (headless): posições nas pontas, espelhamento,
## escala do rival, brasão nunca invertido, ordem de desenho e os três planos
## da câmera. Saída: "ARENA ... OK" por item e exit code 0 se tudo passou.

var _falhas := 0

func _initialize() -> void:
	await process_frame
	var _jog_teste: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_arena/")
	_jog_teste.caminho_save = "user://teste_arena/jogador.json"
	_jog_teste.estado = _jog_teste.novo_estado()
	var arena: Arena = load("res://game/scenes/arena/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame  # o _ready da arena só roda depois do primeiro quadro
	var j := arena.jogador
	var r := arena.rival
	var cam := arena.camera

	_checa("pontas", j.global_position == arena.inicio_jogador.global_position \
		and r.global_position == arena.inicio_rival.global_position)
	_checa("jogador embaixo, rival em cima, cerca no meio",
		r.global_position.y < arena.cerca.get_child(0).global_position.y + 56 \
		and j.global_position.y > arena.cerca.get_child(0).global_position.y + 56)
	_checa("jogador a esquerda indo para a direita", j.global_position.x < r.global_position.x and j.direcao == 1 and r.direcao == -1)
	_checa("rival espelhado", r.visual().global_transform.determinant() < 0.0 and j.visual().global_transform.determinant() > 0.0)
	_checa("rival menor", absf(r.visual().global_transform.get_scale().y) < absf(j.visual().global_transform.get_scale().y))
	_checa("brasao do rival nao invertido", r.brasao().global_transform.determinant() > 0.0)
	_checa("brasao do jogador nao invertido", j.brasao().global_transform.determinant() > 0.0)
	_checa("ordem de desenho fundo<rival<cerca<jogador",
		arena.get_node("Fundo").get_index() < r.get_index() and r.get_index() < arena.cerca.get_index() \
		and arena.cerca.get_index() < j.get_index())
	_checa("alvos da mira existem", j.ponto_alvo("Capacete").y < j.ponto_alvo("Peito").y and r.ponto_alvo("Escudo") != Vector2.ZERO)

	_checa("camera comeca aberta", cam.plano == CameraArena.Plano.ABERTO \
		and cam.global_position == cam.centro_aberto and cam.zoom == Vector2.ONE * cam.zoom_aberto)

	cam.seguir(j)
	j.global_position.x += 300.0
	_avanca(cam, 3.0)
	_checa("camera segue o jogador", cam.global_position.distance_to(cam.destino()) < 1.0 \
		and cam.destino().x > j.global_position.x and absf(cam.zoom.x - cam.zoom_seguir) < 0.01)

	var ponto := r.ponto_alvo("Peito")
	cam.focar(ponto)
	_avanca(cam, 3.0)
	_checa("camera foca no ponto", cam.global_position.distance_to(ponto) < 1.0 and absf(cam.zoom.x - cam.zoom_foco) < 0.01)

	cam.plano_aberto()
	_avanca(cam, 3.0)
	_checa("camera volta ao aberto", cam.global_position.distance_to(cam.centro_aberto) < 1.0 and absf(cam.zoom.x - cam.zoom_aberto) < 0.01)

	print("ARENA %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _avanca(cam: CameraArena, segundos: float) -> void:
	var passo := 1.0 / 30.0
	var t := 0.0
	while t < segundos:
		cam._process(passo)
		t += passo

func _checa(nome: String, ok: bool) -> void:
	print("ARENA %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
