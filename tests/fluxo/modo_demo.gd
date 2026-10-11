extends Node
## Demonstração para o `driver.sh shot`: a arena no modo TM_MODO (exibicao ou
## tutorial) ou a tela TM_TELA (titulo, bau). Save em user://teste_modo_demo/.

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
	(get_node("/root/Fluxo") as FluxoTelas).modo_justa = OS.get_environment("TM_MODO")
	add_child(load("res://game/scenes/arena/arena.tscn").instantiate())
