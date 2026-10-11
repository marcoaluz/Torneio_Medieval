extends SceneTree
## Desgaste e conserto (headless, save em user://teste_desgaste/).
## Elmo do escudeiro: durabilidade máxima 180 (itens.json).

var _falhas := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_desgaste/")
	jog.caminho_save = "user://teste_desgaste/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["inventario"]["ouro"] = 1000
	jog.estado["inventario"]["materiais"]["sucata"] = 20
	jog.estado["cavaleiro"]["nivel"] = 3
	var elmo_id: String = jog.estado["equipamento"]["elmo"]

	# Estágios (elmo do escudeiro: máximo 180)
	var estagios := []
	for dur in [180, 135, 134, 90, 89, 45, 44, 0]:
		_durabilidade(jog, elmo_id, dur)
		estagios.append(jog.estagio_dano(elmo_id))
	_checa("estagios por porcentagem %s" % [estagios], estagios == [0, 0, 1, 1, 2, 2, 3, 3])
	_durabilidade(jog, elmo_id, 60)
	_checa("visual da peca com o estagio", jog.visual_das_pecas()["elmo"] == "provisorio_d2")
	var cav: Cavaleiro = load("res://game/scenes/arena/cavaleiro.tscn").instantiate()
	root.add_child(cav)
	await process_frame
	AparenciaJogador.vestir_cavaleiro(cav, jog)
	_checa("arte do estagio de dano no cavaleiro", cav.camadas().camada("elmo").texture.resource_path.contains("elmo_provisorio_d2"))
	cav.camadas().vestir({"elmo": "semarte_d2"})
	_checa("sem arte de dano usa a peca inteira (e some se nem ela existe)", not cav.camadas().camada("elmo").visible)

	# Durabilidade zero perde os bônus
	_durabilidade(jog, elmo_id, 0)
	var lado := jog.lado_para_justa()
	_checa("peca quebrada vai com durabilidade 0 e sem bonus na regra",
		int(lado["equipamento"]["elmo"]["durabilidade"]) == 0 and Impacto.stat(lado["equipamento"], "elmo", "defesa") == 0)
	_durabilidade(jog, elmo_id, 180)

	# Justa de verdade gastando o elmo
	var cfg := Justa.carregar_configuracao()
	var perfil: Dictionary = Balanceamento.carregar("ia_rival")["perfis"]["agressivo"]
	var j := Justa.new(cfg, jog.lado_para_justa(), Justa.lado_padrao(Balanceamento.carregar("padrao")), 4, perfil)
	j.iniciar()
	while not j.terminou():
		j.avancar(50)
	var fim := j.equipamento_final(true)
	jog.registrar_justa({"equipamento_final": fim})
	_checa("desgaste da justa vai para o inventario (elmo 180 -> %d)" % int(jog.item(elmo_id)["durabilidade"]),
		int(jog.item(elmo_id)["durabilidade"]) == int(fim["elmo"]["durabilidade"]) and int(fim["elmo"]["durabilidade"]) < 180)
	jog.registrar_justa({"equipamento_final": {"elmo": {"durabilidade": 999}}})
	_checa("registrar nunca aumenta a durabilidade", int(jog.item(elmo_id)["durabilidade"]) == int(fim["elmo"]["durabilidade"]))

	# Conserto
	_durabilidade(jog, elmo_id, 140)
	var custo := jog.custo_conserto(elmo_id)
	_checa("custo proporcional ao dano (40 pontos = %d ouro, %d sucata)" % [custo["ouro"], custo["quantidade"]], custo["ouro"] == 20 and custo["quantidade"] == 2)
	_durabilidade(jog, elmo_id, 0)
	var quebrada := jog.custo_conserto(elmo_id)
	_checa("quebrada custa mais (%d ouro)" % quebrada["ouro"], quebrada["ouro"] == 135 and quebrada["quantidade"] == 13)
	_checa("armeiro bloqueado antes do nivel 3", jog.pode_consertar(elmo_id)["ok"])
	var ouro0 := jog.ouro()
	_checa("consertar cobra ouro e sucata", jog.consertar(elmo_id)["ok"] and jog.ouro() == ouro0 - 135
		and int(jog.estado["inventario"]["materiais"]["sucata"]) == 7)
	_checa("nao conserta duas vezes", jog.pode_consertar(elmo_id)["erro"] == "ja_em_conserto")
	var peitoral_id: String = jog.estado["equipamento"]["peitoral"]
	_durabilidade(jog, peitoral_id, 10)
	_checa("uma vaga de conserto no armeiro nivel 1", jog.pode_consertar(peitoral_id)["erro"] == "sem_vaga")
	_checa("armeiro ocupado na vila", not jog.timer_do_predio("armeiro").is_empty())
	var t := jog.item_em_conserto(elmo_id)
	ServicoTempo.deslocamento = int(t["termina_em"]) - ServicoTempo.agora() + 1
	_checa("concluir devolve a durabilidade maxima", jog.concluir_timer(t["id"])["ok"] and int(jog.item(elmo_id)["durabilidade"]) == 180)
	ServicoTempo.deslocamento = 0
	_checa("peca inteira nao conserta", jog.pode_consertar(elmo_id)["erro"] == "item_inteiro")
	jog.estado["inventario"]["materiais"]["sucata"] = 0
	_checa("sem material nao conserta", jog.pode_consertar(peitoral_id)["erro"] == "material_insuficiente")

	# Tela
	jog.estado["inventario"]["materiais"]["sucata"] = 40
	var tela: TelaEquipamentos = load("res://game/scenes/ui/tela_equipamentos.tscn").instantiate()
	root.add_child(tela)
	await process_frame
	tela.abrir_espaco("peitoral")
	tela.selecionar(peitoral_id)
	_checa("tela mostra o dano e o conserto", tela._detalhes.text.contains("Rachada") and tela._consertar.text.begins_with("Consertar ("))
	tela._consertar.pressed.emit()
	_checa("tela manda consertar", not jog.item_em_conserto(peitoral_id).is_empty() and tela._consertar.text.begins_with("No armeiro"))

	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_desgaste/" + arq)
	print("DESGASTE %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _durabilidade(jog: ServicoJogador, id: String, valor: int) -> void:
	for it: Dictionary in jog.estado["inventario"]["itens"]:
		if it["id"] == id:
			it["durabilidade"] = valor

func _checa(nome: String, ok: bool) -> void:
	print("DESGASTE %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
