extends SceneTree
## Tela de Equipamentos (headless, save em user://teste_equip/): espaços dos
## dados, lista por espaço, pré-visualização sem equipar, equipar, guarda-
## roupa (aparência de outra peça) e restaurar, detalhes e aba do cavalo.

var _falhas := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_equip/")
	jog.caminho_save = "user://teste_equip/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["inventario"]["itens"].append({"id": "v1", "modelo": "peitoral_vigia", "nivel": 0, "durabilidade": 240})
	var tela: TelaEquipamentos = load("res://game/scenes/ui/tela_equipamentos.tscn").instantiate()
	root.add_child(tela)
	await process_frame

	_checa("13 espacos do cavaleiro", tela._botoes_espaco.size() == 13)
	_checa("espaco vazio aparece vazio", tela._botoes_espaco["capa"].text.ends_with("vazio"))
	_checa("espaco equipado mostra a peca", tela._botoes_espaco["peitoral"].text.ends_with("Peitoral do escudeiro"))
	tela.abrir_espaco("peitoral")
	await process_frame
	_checa("lista so as pecas do espaco (2)", tela._lista.get_child_count() == 2)
	tela.selecionar("v1")
	_checa("previa veste o personagem sem equipar", tela._retrato.camada("peitoral").texture.resource_path.contains("peitoral_vigia")
		and jog.equipado("peitoral")["modelo"] == "peitoral_escudeiro")
	_checa("detalhes com raridade, status, durabilidade e conjunto",
		tela._detalhes.text == "Incomum\nDefesa +12\nDurabilidade 240/240\nConjunto Vigia (0 equipadas)")
	tela._equipar.pressed.emit()
	await process_frame
	_checa("equipar troca a peca", jog.equipado("peitoral")["id"] == "v1" and tela._botoes_espaco["peitoral"].text.ends_with("Brigantina da vigia"))
	_checa("lado da justa usa a peca nova", int(jog.lado_para_justa()["equipamento"]["peitoral"]["defesa"]) == 12)

	# Guarda-roupa: status da vigia com a aparência do escudeiro
	var escudeiro_id := ""
	for it: Dictionary in jog.itens():
		if it["modelo"] == "peitoral_escudeiro":
			escudeiro_id = it["id"]
	tela.selecionar(escudeiro_id)
	tela._aparencia.pressed.emit()
	await process_frame
	_checa("guarda-roupa: aparencia do escudeiro, status da vigia",
		jog.visual_das_pecas()["peitoral"] == "provisorio" and jog.equipado("peitoral")["id"] == "v1"
		and tela._retrato.camada("peitoral").texture.resource_path.contains("peitoral_provisorio"))
	tela._restaurar.pressed.emit()
	await process_frame
	_checa("restaurar volta a aparencia da peca equipada", jog.visual_das_pecas()["peitoral"] == "vigia")

	tela.mudar_aba("cavalo")
	await process_frame
	_checa("aba do cavalo com 7 espacos e o cavalo", tela._botoes_espaco.size() == 7 and tela._retrato_cavalo.visible
		and not tela._retrato.visible and tela._retrato_cavalo.camada("cavalo").visible)

	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_equip/" + arq)
	print("EQUIP %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("EQUIP %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
