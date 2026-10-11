extends Node
## Benchmark de desempenho (Pacote 3.25). Roda numa janela de verdade (renderer
## Compatibility, sem vsync) e mede, para a justa (robô jogando) e a vila:
## tempo de carregamento da cena, tempo de processo por quadro (média, p95,
## pior), quadros por segundo, chamadas de desenho, objetos e memória; e o
## custo de chamadas do serviço que rodam com frequência. Uso:
##   "$GODOT" --path . --rendering-driver opengl3 res://tools/benchmark.tscn
## Saída: linhas "BENCH ..." no terminal e docs/desempenho/benchmark.txt.
## TM_BENCH_S = segundos por cena (padrão 8). TM_BENCH_PARTES=1 mede só o
## carregamento a frio de cada parte da vila (telas e prédios), uma a uma.

const SAIDA := "res://docs/desempenho/benchmark.txt"

var _linhas: Array[String] = []
var _segundos := 8.0

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if OS.get_environment("TM_BENCH_S") != "":
		_segundos = float(OS.get_environment("TM_BENCH_S"))
	_rodar.call_deferred()

func _rodar() -> void:
	var jog: ServicoJogador = get_node("/root/Jogador")
	DirAccess.make_dir_recursive_absolute("user://bench/")
	jog.caminho_save = "user://bench/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["cavaleiro"]["nome"] = "Bench"
	jog.estado["tutorial"]["concluido"] = true
	jog.estado["historia"]["vistas"] = jog.cfg_historia()["ordem"]
	_log("versao Godot %s, renderer %s, janela %s" % [Engine.get_version_info()["string"],
		RenderingServer.get_current_rendering_driver_name(), str(DisplayServer.window_get_size())])
	if OS.get_environment("TM_BENCH_PARTES") == "1":
		_partes()
		get_tree().quit()
		return
	_micro(jog)
	(get_node("/root/Fluxo") as FluxoTelas).modo_justa = "livre"
	await _medir_cena("justa", "res://game/scenes/arena/arena.tscn", _robo_justa)
	await _medir_cena("vila", "res://game/scenes/village/vila.tscn", Callable())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/desempenho/"))
	var f := FileAccess.open(SAIDA, FileAccess.WRITE)
	f.store_string("\n".join(_linhas) + "\n")
	get_tree().quit()

## Carregamento a frio de cada parte da vila (load + instantiate + entrar na árvore).
func _partes() -> void:
	for c: String in ["res://game/scenes/village/predio_vila.tscn", "res://game/scenes/village/tela_treino.tscn",
			"res://game/scenes/ui/tela_equipamentos.tscn", "res://game/scenes/village/tela_torneios.tscn",
			"res://game/scenes/ui/tela_baus.tscn", "res://game/scenes/village/tela_forja.tscn",
			"res://game/scenes/ui/tela_habilidades.tscn", "res://game/scenes/ui/tela_missoes.tscn",
			"res://game/scenes/ui/tela_configuracoes.tscn", "res://game/scenes/ui/cena_historia.tscn",
			"res://game/scenes/village/vila.tscn"]:
		var t0 := Time.get_ticks_usec()
		var n: Node = load(c).instantiate()
		var t1 := Time.get_ticks_usec()
		get_tree().root.add_child(n)
		var t2 := Time.get_ticks_usec()
		_log("parte %-45s carregar+instanciar %6.1f ms, entrar %6.1f ms" % [c.get_file(), (t1 - t0) / 1000.0, (t2 - t1) / 1000.0])
		n.queue_free()

## Custo de chamadas do serviço feitas com frequência (por chamada, em µs).
func _micro(jog: ServicoJogador) -> void:
	var casos := {
		"Balanceamento.carregar(pve)": func(): Balanceamento.carregar("pve"),
		"Balanceamento.carregar(impacto)": func(): Balanceamento.carregar("impacto"),
		"jog.missoes()": func(): jog.missoes(),
		"jog.baus()+bau_pronto": func(): for b in jog.baus(): jog.bau_pronto(b["id"]),
		"jog.lado_para_justa()": func(): jog.lado_para_justa(),
		"jog.folego_cavalo()": func(): jog.folego_cavalo(),
		"jog.config_valor()": func(): jog.config_valor("vibracao"),
		"jog.proxima_cena()": func(): jog.proxima_cena(),
	}
	for nome: String in casos:
		var c: Callable = casos[nome]
		c.call()
		var t0 := Time.get_ticks_usec()
		for i in 50:
			c.call()
		_log("micro %-32s %8.1f us" % [nome, float(Time.get_ticks_usec() - t0) / 50.0])

func _medir_cena(nome: String, caminho: String, robo: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	var cena: Node = load(caminho).instantiate()
	get_tree().root.add_child(cena)
	await get_tree().process_frame
	_log("%s carregar %.1f ms" % [nome, float(Time.get_ticks_usec() - t0) / 1000.0])
	var tempos: Array[float] = []
	var quadros := 0
	var draw := 0.0
	var inicio := Time.get_ticks_msec()
	var mem0 := Performance.get_monitor(Performance.MEMORY_STATIC)
	var antes := Time.get_ticks_usec()
	while Time.get_ticks_msec() - inicio < int(_segundos * 1000.0):
		if robo.is_valid():
			robo.call(cena)
		await get_tree().process_frame
		var agora := Time.get_ticks_usec()
		var ms := float(agora - antes) / 1000.0
		tempos.append(ms)  # tempo real do quadro (lógica + desenho)
		if ms > 16.6 and Time.get_ticks_msec() - inicio > 200:
			var fase := ""
			if cena.has_node("Justa") and (cena.get_node("Justa") as ControladorJusta).justa:
				fase = JustaFases.NOMES_FASE[(cena.get_node("Justa") as ControladorJusta).fase()]
			_log("%s quadro lento %.1f ms aos %.2f s %s" % [nome, ms, float(Time.get_ticks_msec() - inicio) / 1000.0, fase])
		antes = agora
		draw = maxf(draw, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		quadros += 1
	var dur := float(Time.get_ticks_msec() - inicio) / 1000.0
	tempos.sort()
	var soma := 0.0
	for t in tempos:
		soma += t
	_log("%s quadros %d em %.1f s = %.0f fps (sem vsync)" % [nome, quadros, dur, quadros / dur])
	_log("%s tempo do quadro: media %.2f ms, p95 %.2f ms, pior %.2f ms" % [nome, soma / tempos.size(),
		tempos[int(tempos.size() * 0.95)], tempos.back()])
	_log("%s chamadas de desenho (max) %d, objetos %d, memoria %.1f MB (+%.1f MB na cena)" % [nome, draw,
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		(Performance.get_monitor(Performance.MEMORY_STATIC) - mem0) / 1048576.0])
	cena.queue_free()
	await get_tree().process_frame

## Robô da justa: larga, galopa no compasso, mira no peito; reinicia ao fim.
func _robo_justa(arena: Node) -> void:
	var c: ControladorJusta = arena.get_node("Justa")
	var j := c.justa
	if j == null:
		return
	if j.terminou():
		c.iniciar()
		return
	match c.fase():
		JustaFases.Fase.LARGADA:
			if j.bandeira_baixou and not j.tocou_largada:
				c.tocar()
		JustaFases.Fase.CORRIDA:
			var p := j.jogador.compasso_ms()
			var resto := j.jogador.t_ms % p
			if j.jogador.t_ms >= p / 2 and (resto <= 17 or resto > p - 17):
				c.tocar()
		JustaFases.Fase.MIRA:
			preload("res://tests/arena/justa_check.gd").robo_mira(c, Vector2(-5, -106))

func _log(t: String) -> void:
	print("BENCH ", t)
	_linhas.append(t)
