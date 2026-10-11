extends SceneTree
## Ligas e PvP (3.17, headless): regra pelos casos compartilhados, procurar
## adversário (determinístico, na faixa de poder), justa de PvP com pontos,
## ouro e melhor liga, defesa salva e defesas simuladas, temporada que
## fecha com baú e reinício, rankings, campeonato, migração e a tela.

var _falhas := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	# Regra (casos compartilhados)
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/shared/liga.json"))
	var erros := 0
	for c: Dictionary in d["posicao"]:
		var r := RegraLiga.posicao(int(c["pontos"]), d["ligas"])
		for k: String in c["esperado"]:
			if str(r[k]) != str(c["esperado"][k]) and not (typeof(c["esperado"][k]) == TYPE_FLOAT and int(r[k]) == int(c["esperado"][k])):
				erros += 1
				print("  posicao %d %s: %s != %s" % [c["pontos"], k, r[k], c["esperado"][k]])
	for c: Dictionary in d["partida"]:
		erros += 0 if RegraLiga.depois_da_partida(int(c["pontos"]), c["venceu"], d["ligas"]) == int(c["esperado"]) else 1
	for c: Dictionary in d["defesa"]:
		erros += 0 if RegraLiga.depois_da_defesa(int(c["pontos"]), c["defendeu"], d["ligas"]) == int(c["esperado"]) else 1
	for c: Dictionary in d["parear"]:
		erros += 0 if RegraLiga.parear(int(c["pontos"]), int(c["poder"]), c["candidatos"], d["ligas"]) == c["esperado"] else 1
	for c: Dictionary in d["reinicio"]:
		erros += 0 if RegraLiga.reinicio(int(c["pontos"]), d["ligas"]) == int(c["esperado"]) else 1
	for c: Dictionary in d["ouro"]:
		erros += 0 if RegraLiga.ouro_vitoria(int(c["liga"]), d["ligas"]) == int(c["esperado"]) else 1
	for c: Dictionary in d["poder"]:
		erros += 0 if RegraLiga.poder(c["atributos"], c["pecas"], d["economia"]) == int(c["esperado"]) else 1
	_checa("regra da liga: casos compartilhados", erros == 0)

	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_liga/")
	jog.caminho_save = "user://teste_liga/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
	jog.estado["liga"]["temporada_inicio"] = ServicoTempo.agora()
	jog.estado["liga"]["ultima_simulacao"] = ServicoTempo.agora()
	var cfg := jog.cfg_ligas()

	# Procurar adversário
	var pa := jog.procurar_adversario()
	var a: Dictionary = pa["adversario"]
	_checa("adversario simulado com cavaleiro (poder %d, meu %d)" % [a["poder"], jog.poder_jogador()], a["simulado"] and a["lado"]["equipamento"].size() >= 3 and a["nome"] != "")
	_checa("dentro da faixa de poder", absi(int(a["poder"]) - jog.poder_jogador()) <= int(cfg["faixa_poder"]))
	jog.estado["liga"]["pontos"] = 1200
	var alto: Dictionary = jog.procurar_adversario()["adversario"]
	_checa("pontos altos com poder baixo: ainda na faixa (%d)" % alto["poder"], absi(int(alto["poder"]) - jog.poder_jogador()) <= int(cfg["faixa_poder"]))
	jog.estado["liga"]["pontos"] = 0
	var mesma := jog.estado.duplicate(true)
	var a2: Dictionary = jog.procurar_adversario()["adversario"]
	jog.estado = mesma
	_checa("deterministico pela semente", jog.procurar_adversario()["adversario"]["nome"] == a2["nome"])
	var prep := jog.preparar_pvp()
	_checa("prepara a justa contra o fantasma", prep["rival"]["nome_chave"] == jog.adversario()["nome"] and prep["rival"]["perfil_nome"] == cfg["fantasmas"]["perfil"])

	# Vitória e derrota
	var vit := [{"tipo": "fim", "vencedor": JustaFases.Lado.JOGADOR, "motivo": "pontos"}]
	var der := [{"tipo": "fim", "vencedor": JustaFases.Lado.RIVAL, "motivo": "pontos"}]
	var ouro0 := jog.ouro()
	var r := jog.concluir_pvp(vit)
	_checa("vitoria: +pontos e ouro", r["venceu"] and int(r["pontos"]) == int(cfg["vitoria"]) and jog.ouro() >= ouro0 + int(cfg["ouro_vitoria"]))
	_checa("sem adversario depois", jog.concluir_pvp(vit)["erro"] == "sem_adversario")
	jog.procurar_adversario()
	var r2 := jog.concluir_pvp(der)
	_checa("derrota tira pontos (sem negativo)", int(r2["pontos"]) == maxi(0, int(cfg["vitoria"]) + int(cfg["derrota"])))
	_checa("historico de partidas", (jog.estado["liga"]["partidas"] as Array).size() == 2)
	jog.estado["liga"]["pontos"] = 950
	jog.procurar_adversario()
	jog.concluir_pvp(vit)
	_checa("melhor liga: platina abre o 2o espaco", jog.estado["liga"]["melhor"] == "platina" and jog.espacos_habilidade() == 2)

	# Defesa
	_checa("sem defesa: nenhuma defesa simulada", (jog.atualizar_liga()["defesas_novas"]) == 0)
	jog.salvar_defesa()
	_checa("defesa salva com as pecas", (jog.defesa()["equipamento"] as Dictionary).size() >= 4 and not jog.lado_defesa().is_empty())
	ServicoTempo.deslocamento += 86400
	var at := jog.atualizar_liga()
	_checa("um dia fora: defesas simuladas (%d)" % at["defesas_novas"], int(at["defesas_novas"]) == int(cfg["defesas_por_dia"]) and (jog.estado["liga"]["defesas"] as Array).size() == int(cfg["defesas_por_dia"]))

	# Temporada
	var pontos_antes := int(jog.estado["liga"]["pontos"])
	var baus_antes := jog.baus().size()
	ServicoTempo.deslocamento += int(cfg["temporada_dias"]) * 86400
	var at2 := jog.atualizar_liga()
	_checa("temporada fecha com bau e reinicio", not (at2["temporada_fechada"] as Dictionary).is_empty() and int(jog.estado["liga"]["temporada"]) == 2
		and jog.baus().size() > baus_antes and int(jog.estado["liga"]["pontos"]) <= pontos_antes)
	ServicoTempo.deslocamento = 0

	# Rankings e campeonato
	var rk := jog.ranking_jogadores()
	_checa("ranking com voce e posicoes", rk.size() == int(cfg["ranking_simulado"]) + 1 and rk.any(func(x): return x["voce"]) and int(rk[0]["posicao"]) == 1)
	_checa("ranking de ordens", jog.ranking_ordens().size() > 3)
	var camp := jog.campeonato()
	_checa("campeonato com chave de 8", (camp["chave"] as Array).size() == 8)
	var sab := 0
	while int(Time.get_datetime_dict_from_unix_time(ServicoTempo.agora())["weekday"]) != 6 and sab < 8:
		ServicoTempo.deslocamento += 86400
		sab += 1
	var jc := jog.jogar_campeonato()
	_checa("sabado: joga a rodada", jc["ok"] and jog.adversario()["campeonato"])
	var ouro1 := jog.ouro()
	jog.concluir_pvp(vit)
	_checa("vence a rodada: premio e avanca", int(jog.campeonato()["rodada"]) == 1 and jog.ouro() >= ouro1 + int(cfg["campeonato"]["premios"][0]["ouro"]))
	jog.jogar_campeonato()
	jog.concluir_pvp(der)
	_checa("perde: eliminado", jog.campeonato()["eliminado"] and jog.jogar_campeonato()["erro"] == "campeonato_encerrado")
	ServicoTempo.deslocamento = 0

	# Migração
	var velho := {"versao": 7, "criado_em": 5}
	ServicoJogador.migrar(velho)
	_checa("migracao cria a liga", velho.has("liga") and int(velho["liga"]["pontos"]) == 0)

	# Tela
	var tela: TelaLiga = load("res://game/scenes/ui/tela_liga.tscn").instantiate()
	root.add_child(tela)
	await process_frame
	tela.abrir()
	await process_frame
	_checa("tela: 5 abas e procurar", tela.get_node("Coluna/Abas").get_child_count() == 5 and tela.get_node("Coluna/Rolagem/Lista").get_child_count() >= 1)
	for aba_t in ["defesa", "ranking", "temporada", "campeonato"]:
		tela.aba = aba_t
		tela.montar()
	await process_frame
	_checa("tela: todas as abas montam", tela.get_node("Coluna/Rolagem/Lista").get_child_count() >= 4)
	tela.queue_free()

	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_liga/" + arq)
	print("LIGA %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("LIGA %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
