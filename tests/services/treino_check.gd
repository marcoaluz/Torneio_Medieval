extends SceneTree
## Treino, cavalos e fôlego (headless, save em user://teste_treino/).

var _falhas := 0

func _initialize() -> void:
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_treino/")
	jog.caminho_save = "user://teste_treino/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000  # fora do primeiro dia
	jog.estado["inventario"]["ouro"] = 1000
	var cfg := Balanceamento.carregar("treino")
	var f: Dictionary = cfg["folego_cavalo"]

	# Fôlego
	_checa("cavalo novo com folego cheio", jog.folego_cavalo() == int(f["maximo"]) and not jog.cavalo_cansado())
	jog.registrar_justa({})
	_checa("justa gasta folego", jog.folego_cavalo() == int(f["maximo"]) - int(f["gasto_por_justa"]))
	jog.registrar_justa({})
	jog.registrar_justa({})
	_checa("tres justas deixam cansado", jog.cavalo_cansado() and jog.folego_cavalo() == 25)
	var vel := int(jog.cavalo_ativo()["atributos"]["velocidade"])
	var vel_justa := int(jog.lado_para_justa()["cavalo"]["velocidade"])
	_checa("cansado corre com penalidade (%d -> %d)" % [vel, vel_justa], vel_justa == vel * (100 - int(f["penalidade_velocidade_cansado_pct"])) / 100)
	var cheio_em := jog.descansado_em()
	ServicoTempo.deslocamento = 3600
	_checa("uma hora recupera %d" % int(f["recupera_por_hora"]), jog.folego_cavalo() == 25 + int(f["recupera_por_hora"]) and not jog.cavalo_cansado())
	ServicoTempo.deslocamento = cheio_em - (ServicoTempo.agora() - ServicoTempo.deslocamento)
	_checa("cheio no horario previsto", jog.folego_cavalo() == int(f["maximo"]))
	ServicoTempo.deslocamento = 0

	# Treino do cavaleiro
	_checa("uma vaga no campo nivel 1", jog.vagas_treino("campo_treino") == 1)
	var ouro0 := jog.ouro()
	var r := jog.treinar_cavaleiro("forca")
	_checa("treinar forca", r["ok"] and jog.ouro() == ouro0 - jog.custo_treino())
	var t: Dictionary = jog.treinos_em("campo_treino")[0]
	_checa("duracao pela curva (nivel 1 = %d s)" % jog.duracao_treino(), int(t["termina_em"]) - int(t["inicio_em"]) == jog.duracao_treino())
	_checa("sem segunda vaga", jog.treinar_cavaleiro("precisao")["erro"] == "sem_vaga")
	_checa("atributo invalido", jog.treinar_cavaleiro("magia")["erro"] == "atributo_invalido")
	jog.estado["vila"]["predios"]["casa_senhorial"] = {"nivel": 4}
	jog.estado["vila"]["predios"]["campo_treino"] = {"nivel": 3}
	_checa("campo nivel 3 abre a segunda vaga", jog.vagas_treino("campo_treino") == 2 and jog.treinar_cavaleiro("precisao")["ok"])
	_checa("treino nao impede melhoria do predio", jog.pode_melhorar("campo_treino")["ok"])
	var forca0 := int(jog.cavaleiro()["atributos"]["forca"])
	ServicoTempo.deslocamento = 31
	_checa("concluir treino da +2", jog.concluir_timer(t["id"])["ok"] and int(jog.cavaleiro()["atributos"]["forca"]) == forca0 + int(cfg["ganho_pontos"]))
	ServicoTempo.deslocamento = 0
	jog.estado["cavaleiro"]["atributos"]["equilibrio"] = 100
	_checa("atributo no teto nao treina", jog.treinar_cavaleiro("equilibrio")["erro"] in ["atributo_no_teto", "sem_vaga"])
	jog.estado["cavaleiro"]["nivel"] = 12
	_checa("nivel 12 treina em 1 h", jog.duracao_treino() == 3600)
	jog.estado["cavaleiro"]["nivel"] = 1

	# Cavalos
	var ativo: String = jog.estado["cavalo_ativo"]
	_checa("cavalo ativo nao treina", jog.treinar_cavalo(ativo, "velocidade")["erro"] == "cavalo_ativo_em_uso")
	var novo: String = jog.adicionar_cavalo("preto", {"velocidade": 50, "folego": 50, "temperamento": 50, "vinculo": 0})["id"]
	_checa("dois cavalos no estabulo", jog.cavalos().size() == 2)
	_checa("treinar o outro cavalo", jog.treinar_cavalo(novo, "temperamento")["ok"] and jog.cavalo_treinando(novo))
	_checa("cavalo treinando nao vai para a justa", jog.usar_cavalo(novo)["erro"] == "cavalo_ja_treinando")
	var tc: Dictionary = jog.treinos_em("estabulo")[0]
	ServicoTempo.deslocamento = 31
	jog.concluir_timer(tc["id"])
	ServicoTempo.deslocamento = 0
	_checa("treino do cavalo da +2", int(jog.cavalo(novo)["atributos"]["temperamento"]) == 52 and not jog.cavalo_treinando(novo))
	_checa("usar o cavalo novo na justa", jog.usar_cavalo(novo)["ok"] and jog.cavalo_ativo()["pelagem"] == "preto"
		and not jog.cavalo_cansado())

	# Notificações
	var notif: ServicoNotificacoes = root.get_node("Notificacoes")
	jog.treinar_cavaleiro("forca")
	_checa("notificacao agendada para o treino", notif.agendadas.any(func(n): return n["chave_texto"] == "NOTIF_TREINO_CAVALEIRO"))
	var recebidos := []
	notif.pronto.connect(func(tt): recebidos.append(tt["tipo"]))
	ServicoTempo.deslocamento = 31
	notif._acumulado = 1.0
	notif._process(0.0)
	ServicoTempo.deslocamento = 0
	_checa("aviso no jogo quando termina", recebidos.has("treino_cavaleiro"))

	# Tela
	var tela: TelaTreino = load("res://game/scenes/village/tela_treino.tscn").instantiate()
	root.add_child(tela)
	await process_frame
	tela.abrir("estabulo")
	_checa("tela do estabulo lista os cavalos", tela._lista.get_child_count() >= 4)
	tela.abrir("campo_treino")
	await process_frame
	_checa("tela do campo lista os atributos", tela._lista.get_child_count() == 3)

	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_treino/" + arq)
	print("TREINO %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("TREINO %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
