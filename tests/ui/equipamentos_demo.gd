extends Node
## Demonstração da tela de Equipamentos para o `driver.sh shot`: jogador com
## o conjunto da vigia no inventário, peitoral da vigia em pré-visualização.
## Save em user://teste_equip_demo/.

func _ready() -> void:
	var jog: ServicoJogador = get_node("/root/Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_equip_demo/")
	jog.caminho_save = "user://teste_equip_demo/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000  # fora do primeiro dia
	for m in ["elmo_vigia", "peitoral_vigia", "escudo_vigia", "lanca_vigia"]:
		jog.estado["inventario"]["itens"].append({"id": "d_" + m, "modelo": m, "nivel": 0, "durabilidade": 70})
	var tela: TelaEquipamentos = load("res://game/scenes/ui/tela_equipamentos.tscn").instantiate()
	add_child(tela)
	if OS.get_environment("TM_ABA") == "cavalo":
		tela.mudar_aba.call_deferred("cavalo")
	else:
		tela.abrir_espaco.call_deferred("peitoral")
		tela.selecionar.call_deferred("d_peitoral_vigia")
