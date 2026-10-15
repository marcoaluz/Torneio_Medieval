extends SceneTree
## Cena do estábulo (headless, save em user://teste_estabulo/): o cavalo ativo
## aparece na pelagem certa e com a caparação equipada; os espaços do cavalo e
## as peças do inventário daquele espaço; tocar numa peça equipa (o mesmo
## inventário de Equipamentos) e o cavalo reage; trocar o cavalo ativo troca a
## pelagem; o campo de treino não mostra a cena; os botões de treino e de
## melhoria continuam.

var _falhas := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_estabulo/")
	jog.caminho_save = "user://teste_estabulo/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
	jog.estado["cavaleiro"]["nivel"] = 6
	jog.estado["inventario"]["ouro"] = 5000
	jog.estado["cavalos"][0]["pelagem"] = "preto"
	for m in ["caparacao_vigia", "caparacao_dragao"]:
		jog.estado["inventario"]["itens"].append({"id": "t_" + m, "modelo": m, "nivel": 0, "durabilidade": 0})
	jog.equipar("t_caparacao_vigia")

	var tela: TelaTreino = load("res://game/scenes/village/tela_treino.tscn").instantiate()
	root.add_child(tela)
	await process_frame
	tela.abrir("estabulo")
	await process_frame
	var cena: CenaEstabulo = tela.get_node("Coluna/Corpo/Cena")
	var cavalo: CamadasPersonagem = cena.get_node("Palco/Cavalo")

	_checa("estabulo mostra a cena", cena.visible and cena.get_node("Palco/Fundo").texture != null)
	_checa("pelagem do cavalo ativo", cavalo.pecas.get("pelagem") == "preto")
	_checa("caparacao equipada no cavalo", cavalo.pecas.get("caparacao") == "vigia")
	_checa("sem cavaleiro em cima", cavalo.pecas.get("elmo") == "nenhum" and cavalo.pecas.get("corpo") == "nenhum")
	_checa("abrir nao faz o cavalo reagir", not cena.reagindo() and cavalo.animacao == "parado")
	var espacos: Array = JSON.parse_string(FileAccess.get_file_as_string(TelaEquipamentos.ESPACOS))["cavalo"]
	_checa("um botao por espaco do cavalo", cena.get_node("Espacos").get_child_count() == espacos.size())
	var pecas := cena.get_node("RolagemPecas/Pecas")
	var vigia := pecas.get_node_or_null("t_caparacao_vigia") as Button
	var dragao := pecas.get_node_or_null("t_caparacao_dragao") as Button
	_checa("pecas do inventario no espaco da caparacao", vigia != null and dragao != null)
	_checa("a equipada fica marcada e desligada", vigia != null and vigia.disabled and not dragao.disabled)

	dragao.pressed.emit()
	await process_frame
	_checa("tocar na peca equipa (mesmo inventario)", jog.estado["equipamento"]["caparacao"] == "t_caparacao_dragao")
	_checa("o cavalo veste a nova caparacao", cavalo.pecas.get("caparacao") == "dragao")
	_checa("o cavalo reage a troca", cena.reagindo() and cavalo.animacao == "galope")
	await create_timer(CenaEstabulo.REACAO_S + 0.2).timeout
	_checa("depois da reacao volta a ficar parado", not cena.reagindo() and cavalo.animacao == "parado")

	cena.escolher_espaco("sela")
	await process_frame
	_checa("espaco sem pecas avisa", pecas.get_children().any(func(c): return c is Label and c.text == tr("EQUIP_SEM_PECAS")))

	if jog.estado["cavalos"].size() == 1:
		jog.estado["cavalos"].append({"id": "c_teste", "pelagem": "branco", "atributos": {"velocidade": 40, "folego": 40, "temperamento": 40},
			"folego": 100, "folego_em": ServicoTempo.agora()})
	var r := jog.usar_cavalo(jog.estado["cavalos"][-1]["id"])
	await process_frame
	tela.montar()
	_checa("trocar o cavalo ativo troca a pelagem", r["ok"] and cavalo.pecas.get("pelagem") == "branco")

	_checa("botao de melhoria continua", tela.get_node("Coluna/Botoes/Melhorar").visible)
	var treinar := tela._lista.find_children("*", "Button", true, false)
	_checa("botoes de treino do cavalo continuam", treinar.size() >= 3)

	tela.abrir("campo_treino")
	_checa("campo de treino nao mostra a cena", not cena.visible)

	for f in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_estabulo/" + f)
	print("ESTABULO %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("ESTABULO %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
