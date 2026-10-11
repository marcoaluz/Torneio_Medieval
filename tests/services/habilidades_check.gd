extends SceneTree
## Habilidades especiais e conjuntos (3.16, headless): regra dos conjuntos
## pelos casos compartilhados, espaços (1; o 2º por nível ou liga), uma por
## grupo, habilidade de conjunto só com o conjunto completo, bônus de 2 peças
## no lado da justa (com teto), migração v3 -> v4, a justa com duas
## habilidades (ativa pelo botão, passiva no impacto) e os efeitos visuais.

var _falhas := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	# Regra dos conjuntos (casos compartilhados)
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/shared/conjuntos.json"))
	var erros := 0
	for c: Dictionary in dados["casos"]:
		var r := RegraConjuntos.efeito(c["equipados"], dados["itens"])
		var e: Dictionary = c["esperado"]
		var ok: bool = r["habilidades"] == e["habilidades"] and r["atributos"].size() == e["atributos"].size()
		for k: String in e["atributos"]:
			ok = ok and int(r["atributos"].get(k, -1)) == int(e["atributos"][k])
		if not ok:
			erros += 1
			print("  %s: %s" % [c["nome"], r])
	_checa("conjuntos: %d casos compartilhados" % dados["casos"].size(), erros == 0)

	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_habs/")
	jog.caminho_save = "user://teste_habs/jogador.json"
	jog.estado = jog.novo_estado()
	var cfg: Dictionary = Balanceamento.carregar("progressao")["habilidades"]

	_checa("comeca com investida em uso", jog.habilidades_em_uso() == ["investida"] and jog.espacos_habilidade() == 1)
	_checa("conhece as tres de base", jog.habilidades_conhecidas() == cfg["base"])
	_checa("um espaco so", jog.equipar_habilidades(["investida", "bloqueio"])["erro"] == "sem_espaco_habilidade")
	jog.estado["cavaleiro"]["nivel"] = int(cfg["segundo_espaco_nivel"])
	_checa("segundo espaco pelo nivel", jog.espacos_habilidade() == 2)
	jog.estado["cavaleiro"]["nivel"] = 1
	jog.estado["liga"] = {"melhor": cfg["segundo_espaco_liga"]}
	_checa("segundo espaco pela liga", jog.espacos_habilidade() == 2)
	_checa("uma por grupo", jog.equipar_habilidades(["investida", "golpe_pesado"])["erro"] == "uma_por_grupo")
	_checa("ofensiva + defensiva", jog.equipar_habilidades(["golpe_pesado", "bloqueio"])["ok"] and jog.habilidades_em_uso() == ["golpe_pesado", "bloqueio"])
	_checa("de conjunto sem o conjunto", jog.equipar_habilidades(["olhar_da_vigia"])["erro"] == "habilidade_desconhecida")

	# Conjunto vigia completo
	var modelos: Dictionary = Balanceamento.carregar("itens")["modelos"]
	for m: String in jog.pecas_do_projeto("vigia"):
		var id := "v_" + m
		jog.estado["inventario"]["itens"].append({"id": id, "modelo": m, "nivel": 0, "durabilidade": int(modelos[m]["durabilidade_max"])})
		jog.estado["equipamento"][modelos[m]["espaco"]] = id
	var ef := jog.efeito_conjuntos()
	_checa("vigia completo libera olhar da vigia", jog.habilidades_conhecidas().has("olhar_da_vigia") and int(ef["contagem"]["vigia"]) == 5)
	_checa("equipa a de conjunto", jog.equipar_habilidades(["investida", "olhar_da_vigia"])["ok"])
	var bonus := int(Balanceamento.carregar("itens")["conjuntos"]["vigia"]["bonus_2"]["equilibrio"])
	var lado := jog.lado_para_justa()
	_checa("lado: habilidades e bonus de 2 pecas", lado["habilidades"] == ["investida", "olhar_da_vigia"] and int(lado["cavaleiro"]["equilibrio"]) == int(jog.cavaleiro()["atributos"]["equilibrio"]) + bonus)
	jog.estado["cavaleiro"]["atributos"]["equilibrio"] = 99
	_checa("bonus nao passa do teto", int(jog.lado_para_justa()["cavaleiro"]["equilibrio"]) == int(Balanceamento.carregar("treino")["teto_atributo"]))
	var elmo_esc := ""
	for it: Dictionary in jog.itens():
		if it["modelo"] == "elmo_escudeiro":
			elmo_esc = it["id"]
	jog.equipar(elmo_esc)
	_checa("desfez o conjunto: a habilidade sai do uso", jog.habilidades_em_uso() == ["investida"] and jog.habilidades_escolhidas().has("olhar_da_vigia"))

	# Migração v3 -> v4
	var velho := {"versao": 3, "cavaleiro": {"habilidade": "golpe_pesado"}}
	ServicoJogador.migrar(velho)
	_checa("migracao: habilidade vira lista", velho["cavaleiro"]["habilidades"] == ["golpe_pesado"] and not velho["cavaleiro"].has("habilidade"))

	# Justa com duas habilidades: a ativa pelo botão, a passiva no impacto
	var cfg_j := Justa.carregar_configuracao()
	var padrao := Balanceamento.carregar("padrao")
	var lj := Justa.lado_padrao(padrao)
	lj["habilidades"] = ["investida", "bloqueio"]
	lj.erase("habilidade")
	var lr := Justa.lado_padrao(padrao)
	var j := Justa.new(cfg_j, lj, lr, 5)
	j.iniciar()
	_checa("a ativa da lista e a do botao", j.habilidade_ativa_de(true) == "investida")
	var disparou_passiva := false
	for s in 40:
		var rng := Aleatorio.new(s)
		var res := Impacto.resolver(cfg_j["impacto"], {"jogador": {"cavaleiro": lr["cavaleiro"], "zona": "erro"},
			"rival": {"cavaleiro": lr["cavaleiro"], "zona": "peito", "velocidade": 90, "velocidade_nominal": 90}}, rng)
		var res2 := Impacto.resolver(cfg_j["impacto"], {"jogador": {"cavaleiro": lj["cavaleiro"], "zona": "erro",
			"habilidades": [{"nome": "investida", "ativa": false}, {"nome": "bloqueio", "ativa": true}]},
			"rival": {"cavaleiro": lr["cavaleiro"], "zona": "peito", "velocidade": 90, "velocidade_nominal": 90}}, Aleatorio.new(s))
		if res2["rival"]["habilidade_bloqueio"] == "bloqueio":
			disparou_passiva = true
		if res["rival"]["habilidade_bloqueio"] != "":
			disparou_passiva = false
			break
	_checa("passiva da lista dispara no impacto", disparou_passiva)

	# Efeitos visuais na arena
	var fluxo: FluxoTelas = root.get_node("Fluxo")
	fluxo.modo_justa = "livre"
	var arena: Arena = load("res://game/scenes/arena/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var c: ControladorJusta = arena.get_node("Justa")
	c.habilidade_ativada.emit(1, "rival", "investida")
	await process_frame
	_checa("ativa: rastro no cavaleiro", arena.rival.has_node("Rastro"))
	var interface := arena.get_node_or_null("Interface")
	var letreiro_ok := true
	if interface:
		var r_vazio := {"zona": "erro", "zona_final": "erro", "bloqueado": false, "falta": false, "pontos": 0, "derrubou": false,
			"habilidade_bloqueio": "", "dano": {}}
		var r_blq := r_vazio.duplicate()
		r_blq["zona"] = "peito"
		r_blq["zona_final"] = "escudo"
		r_blq["bloqueado"] = true
		r_blq["habilidade_bloqueio"] = "bloqueio"
		c.impacto_resolvido.emit(1, r_vazio, r_blq, JustaFases.Lado.NENHUM, JustaFases.Lado.NENHUM)
		await process_frame
		letreiro_ok = false
		for n in interface.find_children("*", "Label", true, false):
			if (n as Label).text.contains("Bloqueio!"):
				letreiro_ok = true
	_checa("passiva: letreiro com o nome", letreiro_ok)
	arena.free()

	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_habs/" + arq)
	print("HABS %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("HABS %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
