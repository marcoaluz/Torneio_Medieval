extends Node
## Captura cada menu aberto pela vila (janela real, não headless) para
## conferir sobreposição, margens e camadas em 16:9 e 20:9.
##   TM_SAIDA=build/capturas_menus/antes SIZE=1920x1080 godot --path . res://tools/capturar_menus.tscn
## Sem TM_SAIDA, grava em build/capturas_menus/depois. TM_SO=a,b limita aos nomes.
## Também escreve <saida>/resumo.txt: por menu, o que está visível ao mesmo
## tempo (painéis abertos ao mesmo tempo contam como problema).

func _ready() -> void:
	var jog: ServicoJogador = get_node("/root/Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_capturar_menus/")
	jog.caminho_save = "user://teste_capturar_menus/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
	jog.estado["cavaleiro"]["nivel"] = 12
	jog.estado["cavaleiro"]["nome"] = "Isolda"
	jog.estado["casa"]["nome"] = "Casa de Valcorvo"
	jog.estado["inventario"]["ouro"] = 1234
	jog.estado["inventario"]["gemas"] = 56
	jog.estado["historia"]["vistas"] = jog.cfg_historia()["ordem"].duplicate()
	jog.estado["pve"]["trofeus"] = {"campeao_valdemar": {"em": 1, "torneio": "feira_grande", "revanches": 1}}
	jog.estado["inventario"]["projetos"] = ["vigia"]
	var vila: Vila = load("res://game/scenes/village/vila.tscn").instantiate()
	add_child(vila)
	for i in 6:
		await get_tree().process_frame
	var saida := OS.get_environment("TM_SAIDA") if OS.get_environment("TM_SAIDA") != "" else "build/capturas_menus/depois"
	DirAccess.make_dir_recursive_absolute(saida)
	var vista := get_viewport().get_visible_rect().size
	var tag := "%dx%d" % [int(DisplayServer.window_get_size().x), int(DisplayServer.window_get_size().y)]
	var menus := {
		"00_vila": func(): pass,
		"01_painel_predio": func(): vila.tocar_predio("arena"),
		"02_perfil": func(): vila.tela_perfil.abrir(),
		"03_estante": func():
			vila.tela_perfil.abrir()
			vila.tela_perfil.aba = "trofeus"
			vila.tela_perfil.atualizar(),
		"04_equipamentos": func(): vila.tela_equipamentos.abrir(),
		"05_campo_treino": func(): vila.tocar_predio("campo_treino"),
		"06_estabulo": func(): vila.tocar_predio("estabulo"),
		"07_armeiro": func(): vila.tocar_predio("armeiro"),
		"08_ferreiro": func(): vila.tocar_predio("ferreiro"),
		"09_baus": func(): vila.tela_baus.abrir(),
		"10_missoes": func(): vila.tela_missoes.abrir("diarias"),
		"11_liga": func(): vila.tela_liga.abrir(),
		"12_loja": func(): vila.tela_loja.abrir(),
		"13_social": func(): vila.tela_social.abrir(),
		"14_configuracoes": func(): vila.tela_configuracoes.abrir(),
		"15_habilidades": func(): vila.tela_habilidades.abrir(),
		"16_torneios": func(): vila.tela_torneios.abrir(),
		"17_ficha": func(): vila.preparar_luta(jog.rival_para_justa("dama_elvira_sangue_real"), Callable(), func(): pass),
		"18_duelo": func(): vila.duelo().mostrar(jog.rival_para_justa("sir_baltasar_escudo_ouro")),
	}
	var so := OS.get_environment("TM_SO").split(",", false)
	var resumo: Array[String] = []
	var nomes: Array = menus.keys()
	nomes.sort()
	for nome: String in nomes:
		if not so.is_empty() and not so.has(nome):
			continue
		_fechar_tudo(vila)
		await get_tree().process_frame
		menus[nome].call()
		for i in 12:
			await get_tree().process_frame
		print("capturando ", nome)
		var abertos := _abertos(vila)
		resumo.append("%s %s: abertos=%s" % [tag, nome, abertos])
		get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [saida, tag, nome])
	var f := FileAccess.open("%s/resumo_%s.txt" % [saida, tag], FileAccess.WRITE)
	f.store_string("\n".join(resumo) + "\n")
	f.close()
	print("CAPTURAS %s %d em %s" % [tag, resumo.size(), saida])
	get_tree().quit()

## Telas e painéis de Interface visíveis agora (menos o topo e o letreiro).
func _abertos(vila: Vila) -> Array:
	var r: Array = []
	for c in vila.get_node("Interface").get_children():
		if c is Control and (c as Control).visible and c.name not in [&"Topo", &"Letreiro", &"Fundo"]:
			r.append(str(c.name))
	return r

func _fechar_tudo(vila: Vila) -> void:
	vila.fechar_painel()
	vila.paineis.fechar_todos()
	vila.janela_oferta.visible = false
