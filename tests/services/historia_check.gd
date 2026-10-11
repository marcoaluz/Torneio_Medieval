extends SceneTree
## História, companheiros e nêmesis (3.22, headless): dados completos (falas
## com texto, personagens existentes), cenas pendentes na ordem pelas metas,
## companheiros e seus bônus (renome, forno, fôlego), falas do nêmesis por
## região, migração v5 -> v6 e a cena tocando na vila.

var _falhas := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_historia/")
	jog.caminho_save = "user://teste_historia/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
	jog.estado["cavaleiro"]["nome"] = "Isolda"
	var h := jog.cfg_historia()

	# Dados
	var problemas: Array[String] = []
	for id: String in h["ordem"]:
		for f: Dictionary in h["cenas"][id]["falas"]:
			if f["quem"] != "jogador" and not h["personagens"].has(f["quem"]):
				problemas.append("%s: quem %s" % [id, f["quem"]])
			if tr(f["texto"]) == f["texto"]:
				problemas.append("sem texto " + f["texto"])
	for c: String in h["companheiros"]:
		if not h["cenas"].has(h["companheiros"][c]["entra_na_cena"]) or tr("COMPANHEIRO_" + c.to_upper()) == "COMPANHEIRO_" + c.to_upper():
			problemas.append("companheiro " + c)
	_checa("dados completos %s" % str(problemas.slice(0, 3)), problemas.is_empty())

	# Cenas pela ordem
	_checa("nenhuma cena no comeco", jog.proxima_cena() == "")
	jog._evento("vitoria")
	_checa("primeira vitoria: cena do comeco", jog.proxima_cena() == "comeco")
	_checa("sem companheiros antes da cena", jog.companheiros().is_empty() and jog.bonus_companheiros("renome_pct") == 0)
	jog.marcar_cena_vista("comeco")
	_checa("Bento entra com a cena", jog.companheiros() == ["arauto"] and jog.proxima_cena() == "")
	jog.estado["cavaleiro"]["nivel"] = 20
	var vit := [{"tipo": "impacto", "jogador": {"zona": "peito", "falta": false}}, {"tipo": "fim", "vencedor": JustaFases.Lado.JOGADOR, "motivo": "pontos"}]
	var r := jog.concluir_disputa("feira_moinho", 0, vit)
	var ganho: Dictionary = Balanceamento.carregar("metas")["renome"]["ganho"]
	var base := int(ganho["vitoria"])
	_checa("arauto: +20%% de renome (%d)" % r["renome"], int(r["renome"]) == base * (100 + int(h["companheiros"]["arauto"]["bonus"]["renome_pct"])) / 100)
	jog._evento("regiao_vencida")
	jog._evento("regiao_vencida")
	_checa("duas regioes: as duas cenas em ordem", jog.proxima_cena() == "fim_feiras")
	var seg0 := int(jog.pode_fundir("lingote_ferro", 1).get("segundos", 0)) if jog.material("sucata") >= 4 else 0
	jog.estado["inventario"]["materiais"]["sucata"] = 40
	seg0 = int(jog.pode_fundir("lingote_ferro", 2)["segundos"])
	jog.marcar_cena_vista("fim_feiras")
	var seg1 := int(jog.pode_fundir("lingote_ferro", 2)["segundos"])
	_checa("Brigida: forno mais rapido (%d -> %d)" % [seg0, seg1], seg1 == seg0 * (100 + int(h["companheiros"]["ferreira"]["bonus"]["fundicao_tempo_pct"])) / 100)
	_checa("depois vem a do condado", jog.proxima_cena() == "fim_condado")
	var rec0 := jog._recuperacao_por_hora()
	jog.marcar_cena_vista("fim_condado")
	_checa("Tome: folego volta mais rapido", jog._recuperacao_por_hora() > rec0 and jog.companheiros().size() == 3)

	# Nêmesis com fala própria por região
	var falas := {}
	for reg: String in jog.pve()["ordem_regioes"]:
		falas[jog.rival_para_justa("nemesis_corvo", reg)["provocacao"]] = true
	_checa("nemesis: uma fala por regiao (%d)" % falas.size(), falas.size() == jog.pve()["ordem_regioes"].size())

	# Migração
	var velho := {"versao": 5}
	ServicoJogador.migrar(velho)
	_checa("migracao cria a historia", velho.has("historia") and velho["historia"]["vistas"] == [])

	# Na vila
	jog.estado["historia"]["vistas"] = ["comeco"]
	var vila: Vila = load("res://game/scenes/village/vila.tscn").instantiate()
	root.add_child(vila)
	await process_frame
	await process_frame
	var cena: CenaHistoria = vila.cena_historia
	_checa("vila toca a cena pendente", cena.visible and cena.cena == "fim_feiras")
	_checa("fala com nome e texto", cena.get_node("Caixa/Linha/Coluna/Nome").text.contains("Bento") and cena.get_node("Caixa/Linha/Coluna/Texto").text != "")
	var guarda := 0
	while cena.visible and cena.cena == "fim_feiras" and guarda < 30:
		cena.avancar()
		cena.avancar()
		guarda += 1
	_checa("terminou e tocou a proxima", (jog.estado["historia"]["vistas"] as Array).has("fim_feiras") and cena.cena == "fim_condado")
	(cena.get_node("Pular") as Button).pressed.emit()
	_checa("pular encerra e marca", (jog.estado["historia"]["vistas"] as Array).has("fim_condado") and not cena.visible)
	vila.free()

	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_historia/" + arq)
	print("HISTORIA %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("HISTORIA %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
