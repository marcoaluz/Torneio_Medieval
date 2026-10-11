extends SceneTree
## Forja (3.15, headless): status da peça com nível, criar peça de projeto
## (receita, fila, variação de status), melhorar (+5 garantido, teto pelo
## armeiro, falha sem perder a peça, nível máximo, peça no conserto),
## fundição no ferreiro, materiais das vitórias do PvE, lado da justa com a
## melhoria e a tela (abas, oficina com o martelo).

var _falhas := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_forja/")
	jog.caminho_save = "user://teste_forja/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
	var eco: Dictionary = Balanceamento.carregar("economia")
	var modelos: Dictionary = Balanceamento.carregar("itens")["modelos"]
	var mats: Dictionary = jog.estado["inventario"]["materiais"]

	# Status com nível
	var elmo_id: String = jog.estado["equipamento"]["elmo"]
	var base := int(modelos["elmo_escudeiro"]["status"]["defesa"])
	_checa("status do item = o do modelo no +0", int(jog.status_do_item(elmo_id)["defesa"]) == base)

	# Criar: bloqueios
	_checa("armeiro fechado no nivel 1", jog.pode_forjar("elmo_vigia")["erro"] == "predio_bloqueado")
	jog.estado["cavaleiro"]["nivel"] = 10
	_checa("sem projeto", jog.pode_forjar("elmo_vigia")["erro"] == "sem_projeto")
	jog.estado["inventario"]["projetos"].append("vigia")
	_checa("pecas do projeto vigia", jog.pecas_do_projeto("vigia").size() == 5 and jog.pecas_do_projeto("vigia").has("lanca_vigia"))
	jog.estado["inventario"]["ouro"] = 0
	_checa("sem ouro", jog.pode_forjar("elmo_vigia")["erro"] == "ouro_insuficiente")
	jog.estado["inventario"]["ouro"] = 5000
	_checa("sem material", jog.pode_forjar("elmo_vigia")["erro"] == "material_insuficiente")
	mats["lingote_ferro"] = 50
	mats["couro"] = 10
	var rec := jog.receita("elmo_vigia")
	var r := jog.forjar("elmo_vigia")
	_checa("forjou: cobrou ouro e materiais", r["ok"] and jog.ouro() == 5000 - int(rec["ouro"]) and jog.material("lingote_ferro") == 50 - int(rec["materiais"]["lingote_ferro"]))
	_checa("fila da forja ocupada", jog.pode_forjar("peitoral_vigia")["erro"] == "forja_ocupada")
	var t: Dictionary = jog.forja_em_andamento()[0]
	_checa("timer pela receita", int(t["termina_em"]) - int(t["inicio_em"]) == int(rec["segundos"]))
	ServicoTempo.deslocamento += int(rec["segundos"])
	var c := jog.concluir_timer(t["id"])
	var nova := jog.item(c["item"])
	var d_base := int(modelos["elmo_vigia"]["status"]["defesa"])
	var d_nova := int(nova["status"]["defesa"])
	_checa("peca forjada com variacao (%d de %d)" % [d_nova, d_base], c["ok"] and absi(d_nova - d_base) <= d_base * int(eco["forja"]["variacao_status_pct"]) / 100 + 1)
	_checa("peca forjada com durabilidade cheia", int(nova["durabilidade"]) == int(modelos["elmo_vigia"]["durabilidade_max"]))
	_checa("status do item usa o da forja", int(jog.status_do_item(c["item"])["defesa"]) == d_nova)

	# Melhorar
	mats["fragmentos"] = 2000
	mats["lingote_ferro"] = 200
	jog.estado["vila"]["predios"]["armeiro"] = {"nivel": 1}
	_checa("teto do armeiro nivel 1 = +2", jog.teto_melhoria() == 2)
	var m1 := jog.melhorar_peca(elmo_id)
	var m2 := jog.melhorar_peca(elmo_id)
	_checa("+1 e +2 garantidos", m1["sucesso"] and m2["sucesso"] and int(jog.item(elmo_id)["nivel"]) == 2)
	_checa("teto do armeiro", jog.pode_melhorar_peca(elmo_id)["erro"] == "teto_armeiro")
	jog.estado["vila"]["predios"]["armeiro"] = {"nivel": 5}
	jog.estado["vila"]["predios"]["casa_senhorial"] = {"nivel": 5}
	for i in 3:
		jog.melhorar_peca(elmo_id)
	_checa("ate +5 sempre sobe", int(jog.item(elmo_id)["nivel"]) == 5)
	var ouro_antes := jog.ouro()
	var falhas := 0
	var tentativas := 0
	while int(jog.item(elmo_id)["nivel"]) < 10 and tentativas < 200:
		var n_antes := int(jog.item(elmo_id)["nivel"])
		var mr := jog.melhorar_peca(elmo_id)
		tentativas += 1
		if not mr["ok"]:
			jog.estado["inventario"]["ouro"] = 100000
			mats["fragmentos"] = 5000
			mats["lingote_ferro"] = 500
			continue
		if not mr["sucesso"]:
			falhas += 1
			if int(jog.item(elmo_id)["nivel"]) != n_antes:
				falhas = -999
	_checa("depois do +5 pode falhar sem perder a peca (%d falhas)" % falhas, falhas > 0 and jog.item(elmo_id).size() > 0)
	_checa("chegou ao +10", int(jog.item(elmo_id)["nivel"]) == 10 and jog.pode_melhorar_peca(elmo_id)["erro"] == "nivel_maximo")
	var esperado := base + base * 10 * int(eco["forja"]["bonus_status_por_nivel_pct"]) / 100
	_checa("status do +10 (%d)" % esperado, int(jog.status_do_item(elmo_id)["defesa"]) == esperado)
	_checa("o lado da justa usa a melhoria", int(jog.lado_para_justa()["equipamento"]["elmo"]["defesa"]) == esperado)
	var pt_id: String = jog.estado["equipamento"]["peitoral"]
	jog.estado["timers"].append({"id": "tx", "tipo": "conserto", "alvo": "armeiro", "item": pt_id, "inicio_em": 0, "termina_em": ServicoTempo.agora() + 999})
	_checa("peca no conserto nao melhora", jog.pode_melhorar_peca(pt_id)["erro"] == "peca_em_uso")
	jog.estado["timers"] = []

	# Fundição
	mats["sucata"] = 10
	mats["lingote_ferro"] = 3
	var por_sucata := int(eco["forja"]["lingote_por_sucata"])
	_checa("maximo de ferro pela sucata", jog.maximo_fundir("lingote_ferro") == 10 / por_sucata)
	var f := jog.fundir("lingote_ferro", 2)
	_checa("fundiu: gastou sucata", f["ok"] and jog.material("sucata") == 10 - 2 * por_sucata)
	_checa("forno ocupado", jog.pode_fundir("lingote_aco", 1)["erro"] == "forno_ocupado")
	var tf: Dictionary = jog.timers().filter(func(x): return x["tipo"] == "fundicao")[0]
	ServicoTempo.deslocamento += 3600
	jog.concluir_timer(tf["id"])
	_checa("lingotes entregues", jog.material("lingote_ferro") == 5)
	_checa("aco de ferro", jog.fundir("lingote_aco", 1)["ok"] and jog.material("lingote_ferro") == 5 - int(eco["forja"]["aco_por_ferro"]))
	jog.estado["timers"] = []

	# Materiais do PvE
	var sucata0 := jog.material("sucata")
	var vit := [{"tipo": "impacto", "jogador": {"zona": "peito", "falta": false}}, {"tipo": "fim", "vencedor": JustaFases.Lado.JOGADOR, "motivo": "pontos"}]
	var dv := jog.concluir_disputa("feira_moinho", 0, vit)
	var mv := int(jog.pve()["regioes"]["feiras"]["materiais_vitoria"]["sucata"])
	_checa("vitoria da sucata", int(dv["materiais"]["sucata"]) == mv and jog.material("sucata") == sucata0 + mv)

	# Tela
	jog.estado["inventario"]["projetos"] = ["vigia", "ferro_negro"]
	var tela: TelaForja = load("res://game/scenes/village/tela_forja.tscn").instantiate()
	root.add_child(tela)
	await process_frame
	tela.abrir("armeiro")
	await process_frame
	_checa("armeiro: 3 abas", tela.get_node("Coluna/Cabecalho/Abas").get_child_count() == 3)
	_checa("criar lista os dois projetos (12 linhas)", tela.get_node("Coluna/Rolagem/Lista").get_child_count() == 12)
	mats["lingote_ferro"] = 50
	jog.forjar("lanca_vigia")
	await process_frame
	tela.montar()
	await create_timer(0.3).timeout
	_checa("martelo batendo com peca na forja", tela._martelo != null and tela._martelo.is_valid() and absf((tela.get_node("Coluna/Oficina/Bigorna/Martelo") as Control).rotation_degrees) > 1.0)
	ServicoTempo.deslocamento += 99999
	tela.montar()
	_checa("pronta: botao pegar", (tela.get_node("Coluna/Oficina/Pegar") as Button).visible)
	tela._pegar_pronto()
	_checa("pegar entrega a peca", tela.get_node("Coluna/Mensagem").text.contains("Lança"))
	tela.abrir("ferreiro")
	await process_frame
	_checa("ferreiro: sem abas, com fundicao", tela.get_node("Coluna/Cabecalho/Abas").get_child_count() == 0 and tela.get_node("Coluna/Rolagem/Lista").get_child_count() >= 2)
	tela.queue_free()

	ServicoTempo.deslocamento = 0
	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_forja/" + arq)
	print("FORJA_S %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("FORJA_S %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
