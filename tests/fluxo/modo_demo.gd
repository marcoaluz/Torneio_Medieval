extends Node
## Demonstração para o `driver.sh shot`: a arena no modo TM_MODO (exibicao ou
## tutorial), a primeira disputa do torneio TM_TORNEIO (PvE, com desafios) ou
## a tela TM_TELA (titulo, bau, baus com TM_ABRIR=1|chances, torneios com
## TM_REGIAO). Save em
## user://teste_modo_demo/.

func _ready() -> void:
	var jog: ServicoJogador = get_node("/root/Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_modo_demo/")
	jog.caminho_save = "user://teste_modo_demo/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["cavaleiro"]["nome"] = "Isolda"
	var tela := OS.get_environment("TM_TELA")
	if tela == "titulo":
		add_child(load("res://game/scenes/ui/tela_titulo.tscn").instantiate())
		return
	if tela == "bau":
		var b: TelaBau = load("res://game/scenes/ui/tela_bau.tscn").instantiate()
		add_child(b)
		b.abrir.call_deferred()
		return
	if tela == "baus":
		# Baús: 3 nos espaços (um abrindo); TM_ABRIR=1 mostra a abertura de um real.
		jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
		for tipo in ["madeira", "ferro", "real"]:
			jog.ganhar_bau(tipo)
		jog.comecar_abrir(jog.baus()[1]["id"])
		var tb: TelaBaus = load("res://game/scenes/ui/tela_baus.tscn").instantiate()
		var camada_b := CanvasLayer.new()
		add_child(camada_b)
		camada_b.add_child(tb)
		tb.abrir.call_deferred()
		if OS.get_environment("TM_ABRIR") == "1":
			tb.abrir_bau.call_deferred(jog.baus()[2]["id"], true)
		elif OS.get_environment("TM_ABRIR") == "chances":
			(tb.get_node("Coluna/Botoes/VerChances") as Button).set_pressed.call_deferred(true)
		return
	if tela == "torneios":
		# Circuito aberto até TM_REGIAO (padrão: condado), nível alto.
		jog.estado["cavaleiro"]["nivel"] = 20
		var reg := OS.get_environment("TM_REGIAO") if OS.get_environment("TM_REGIAO") != "" else "condado"
		jog.estado["pve"]["regiao"] = reg
		var t: TelaTorneios = load("res://game/scenes/village/tela_torneios.tscn").instantiate()
		var camada := CanvasLayer.new()
		add_child(camada)
		camada.add_child(t)
		t.abrir.call_deferred()
		return
	var fluxo := get_node("/root/Fluxo") as FluxoTelas
	var torneio := OS.get_environment("TM_TORNEIO")
	if torneio != "":
		# Primeira disputa de um torneio do PvE (ex.: desafio_ribeira = chuva).
		jog.estado["cavaleiro"]["nivel"] = 20
		jog.estado["pve"]["regiao"] = jog.regiao_do_torneio(torneio)
		fluxo.disputa = {"torneio": torneio, "indice": 0}
		fluxo.modo_justa = "disputa"
		add_child(load("res://game/scenes/arena/arena.tscn").instantiate())
		return
	fluxo.modo_justa = OS.get_environment("TM_MODO")
	add_child(load("res://game/scenes/arena/arena.tscn").instantiate())
