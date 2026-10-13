extends Node
## Demonstração da vila viva para o `driver.sh shot`. Hora e clima por
## variáveis de ambiente (TM_HORA, ex. 22; TM_CLIMA: limpo, nublado, chuva,
## neblina) e TM_TELA (campo_treino ou estabulo abre a tela). Põe o campo de treino e o armeiro ocupados (timers falsos, sem
## salvar: save em user://teste_vila_demo/). TM_ORDEM=1 entra numa ordem simulada.

func _ready() -> void:
	var jog: ServicoJogador = get_node("/root/Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_vila_demo/")
	jog.caminho_save = "user://teste_vila_demo/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000  # fora do primeiro dia
	jog.estado["cavaleiro"]["nome"] = "Isolda"
	jog.estado["cavaleiro"]["nivel"] = 3
	jog.estado["casa"]["nome"] = "Casa de Valcorvo"
	var agora := ServicoTempo.agora()
	for alvo in ["campo_treino", "armeiro"]:
		jog.estado["timers"].append({"id": "demo_" + alvo, "tipo": "demo", "alvo": alvo, "inicio_em": agora, "termina_em": agora + 600})
	if OS.get_environment("TM_ORDEM") == "1":
		# Com ordem (simulada): bandeira da ordem na casa senhorial e cavaleiros na praça.
		jog.estado["cavaleiro"]["nivel"] = 8
		jog.entrar_ordem(jog.ordens_para_entrar()[1]["id"])
	var vila: Vila = load("res://game/scenes/village/vila.tscn").instantiate()
	var amb: AmbienteVila = vila.get_node("Ambiente")
	if OS.get_environment("TM_HORA") != "":
		amb.hora_forcada = float(OS.get_environment("TM_HORA"))
	amb.clima_forcado = OS.get_environment("TM_CLIMA")
	add_child(vila)
	jog.adicionar_cavalo("branco", {"velocidade": 55, "folego": 45, "temperamento": 60, "vinculo": 0})
	jog.estado["pve"]["torneios"]["feira_moinho"] = {"proxima": 2, "concluido": false, "estrelas": {"0": 3, "1": 2}}
	var tela := OS.get_environment("TM_TELA")
	if tela == "torneios":
		vila.tela_torneios.abrir.call_deferred()
		vila.tela_torneios.set.call_deferred("torneio", "feira_moinho")
		vila.tela_torneios.montar.call_deferred()
	elif tela != "":
		vila.tela_treino.abrir.call_deferred(tela)
