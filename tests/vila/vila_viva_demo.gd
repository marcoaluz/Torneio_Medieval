extends Node
## Demonstração da vila viva para o `driver.sh shot`. Hora e clima por
## variáveis de ambiente (TM_HORA, ex. 22; TM_CLIMA: limpo, nublado, chuva,
## neblina). Põe o campo de treino e o armeiro ocupados (timers falsos, sem
## salvar: save em user://teste_vila_demo/).

func _ready() -> void:
	var jog: ServicoJogador = get_node("/root/Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_vila_demo/")
	jog.caminho_save = "user://teste_vila_demo/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["cavaleiro"]["nome"] = "Isolda"
	jog.estado["cavaleiro"]["nivel"] = 3
	jog.estado["casa"]["nome"] = "Casa de Valcorvo"
	var agora := ServicoTempo.agora()
	for alvo in ["campo_treino", "armeiro"]:
		jog.estado["timers"].append({"id": "demo_" + alvo, "tipo": "demo", "alvo": alvo, "inicio_em": agora, "termina_em": agora + 600})
	var vila: Vila = load("res://game/scenes/village/vila.tscn").instantiate()
	var amb: AmbienteVila = vila.get_node("Ambiente")
	if OS.get_environment("TM_HORA") != "":
		amb.hora_forcada = float(OS.get_environment("TM_HORA"))
	amb.clima_forcado = OS.get_environment("TM_CLIMA")
	add_child(vila)
