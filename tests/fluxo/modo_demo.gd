extends Node
## Demonstração para o `driver.sh shot`: a arena no modo TM_MODO (exibicao ou
## tutorial), a primeira disputa do torneio TM_TORNEIO (PvE, com desafios) ou
## a tela TM_TELA (titulo, bau, baus com TM_ABRIR=1|chances, forja com
## TM_PREDIO/TM_ABA, habilidades, missoes com TM_ABA, torneios com TM_REGIAO);
## social (TM_ABA, TM_SUB, TM_CANAL, TM_ORDEM=0); TM_TITULO dá um título ao jogador na arena; historia (TM_CENA, TM_FALA) mostra
## a vila tocando uma cena; vila (TM_NIVEL, TM_ORDEM=1 com a ordem criada). Save em
## user://teste_modo_demo/.

func _ready() -> void:
	var jog: ServicoJogador = get_node("/root/Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_modo_demo/")
	jog.caminho_save = "user://teste_modo_demo/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["cavaleiro"]["nome"] = "Isolda"
	# Acessibilidade (3.24) para qualquer demo: TM_IDIOMA, TM_TEXTO, TM_CANHOTO=1.
	if OS.get_environment("TM_IDIOMA") != "":
		jog.definir_config("idioma", OS.get_environment("TM_IDIOMA"))
	if OS.get_environment("TM_TEXTO") != "":
		jog.definir_config("texto", OS.get_environment("TM_TEXTO"))
	if OS.get_environment("TM_CANHOTO") == "1":
		jog.definir_config("canhoto", true)
	var tela := OS.get_environment("TM_TELA")
	if tela == "titulo":
		add_child(load("res://game/scenes/ui/tela_titulo.tscn").instantiate())
		return
	if tela == "bau":
		var b: TelaBau = load("res://game/scenes/ui/tela_bau.tscn").instantiate()
		add_child(b)
		b.abrir.call_deferred()
		return
	if tela == "baus":
		# Baús: 3 nos espaços (um abrindo); TM_ABRIR=1 mostra a abertura de um real.
		jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
		for tipo in ["madeira", "ferro", "real"]:
			jog.ganhar_bau(tipo)
		jog.comecar_abrir(jog.baus()[1]["id"])
		var tb: TelaBaus = load("res://game/scenes/ui/tela_baus.tscn").instantiate()
		var camada_b := CanvasLayer.new()
		add_child(camada_b)
		camada_b.add_child(tb)
		tb.abrir.call_deferred()
		if OS.get_environment("TM_ABRIR") == "1":
			tb.abrir_bau.call_deferred(jog.baus()[2]["id"], true)
		elif OS.get_environment("TM_ABRIR") == "chances":
			(tb.get_node("Coluna/Botoes/VerChances") as Button).set_pressed.call_deferred(true)
		return
	if tela == "forja":
		# Armeiro (TM_ABA=criar|melhorar) ou ferreiro (TM_PREDIO=ferreiro), com
		# projetos, materiais e uma peça na forja.
		jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
		jog.estado["cavaleiro"]["nivel"] = 10
		jog.estado["inventario"]["ouro"] = 3000
		jog.estado["inventario"]["projetos"] = ["vigia", "ferro_negro"]
		jog.estado["vila"]["predios"]["armeiro"] = {"nivel": 2}
		var mats: Dictionary = jog.estado["inventario"]["materiais"]
		mats.merge({"sucata": 23, "lingote_ferro": 30, "couro": 6, "lingote_aco": 1, "fragmentos": 60}, true)
		jog.forjar("escudo_vigia")
		var tf: TelaForja = load("res://game/scenes/village/tela_forja.tscn").instantiate()
		var camada_f := CanvasLayer.new()
		add_child(camada_f)
		camada_f.add_child(tf)
		var predio := OS.get_environment("TM_PREDIO") if OS.get_environment("TM_PREDIO") != "" else "armeiro"
		tf.abrir.call_deferred(predio)
		if OS.get_environment("TM_ABA") == "melhorar":
			(func(): tf.aba = "melhorar"; tf.montar()).call_deferred()
		return
	if tela == "habilidades":
		# Nível 15 (dois espaços) com o conjunto da vigia completo.
		jog.estado["cavaleiro"]["nivel"] = 15
		var modelos: Dictionary = Balanceamento.carregar("itens")["modelos"]
		for m: String in jog.pecas_do_projeto("vigia"):
			jog.estado["inventario"]["itens"].append({"id": "v_" + m, "modelo": m, "nivel": 0, "durabilidade": int(modelos[m]["durabilidade_max"])})
			jog.estado["equipamento"][modelos[m]["espaco"]] = "v_" + m
		jog.equipar_habilidades(["investida", "olhar_da_vigia"])
		var th: TelaHabilidades = load("res://game/scenes/ui/tela_habilidades.tscn").instantiate()
		var camada_h := CanvasLayer.new()
		add_child(camada_h)
		camada_h.add_child(th)
		th.abrir.call_deferred()
		return
	if tela == "missoes":
		# Missões com uma pronta, 2 dias de login, conquistas e um título (TM_ABA).
		jog.estado["metas"]["renome"] = 340
		var m := jog.missoes()
		for i in int(m["diarias"][0]["meta"]):
			jog._evento(m["diarias"][0]["evento"])
		jog.estado["metas"]["login"] = {"dias": 2, "ultimo_dia": -1}
		for i in 10:
			jog._evento("vitoria")
		jog._evento_maximo("sequencia", 10)
		jog.definir_titulo("o_inquebravel")
		var tm: TelaMissoes = load("res://game/scenes/ui/tela_missoes.tscn").instantiate()
		var camada_m := CanvasLayer.new()
		add_child(camada_m)
		camada_m.add_child(tm)
		var aba := OS.get_environment("TM_ABA") if OS.get_environment("TM_ABA") != "" else "diarias"
		tm.abrir.call_deferred(aba)
		return
	if tela == "vila":
		# Vila no nível TM_NIVEL (padrão 8); TM_ORDEM=1 cria uma ordem (brasão na sede).
		jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
		jog.estado["tutorial"]["concluido"] = true
		jog.estado["cavaleiro"]["nivel"] = int(OS.get_environment("TM_NIVEL")) if OS.get_environment("TM_NIVEL") != "" else 8
		jog.estado["inventario"]["ouro"] = 3000
		if OS.get_environment("TM_ORDEM") == "1":
			jog.criar_ordem("Ordem da Rosa")
		add_child(load("res://game/scenes/village/vila.tscn").instantiate())
		return
	if tela == "historia":
		# Vila com a cena TM_CENA pendente (padrão: a do começo); TM_FALA avança falas.
		jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
		jog.estado["tutorial"]["concluido"] = true
		var cena_id := OS.get_environment("TM_CENA") if OS.get_environment("TM_CENA") != "" else "comeco"
		var h := jog.cfg_historia()
		for ev: String in h["cenas"][cena_id]["quando"]:
			jog.estado["metas"]["contadores"][ev] = int(h["cenas"][cena_id]["quando"][ev])
		for id: String in h["ordem"]:
			if id == cena_id:
				break
			jog.estado["historia"]["vistas"].append(id)
		var vila_h: Vila = load("res://game/scenes/village/vila.tscn").instantiate()
		add_child(vila_h)
		var falas := int(OS.get_environment("TM_FALA")) if OS.get_environment("TM_FALA") != "" else 0
		(func():
			for i in falas:
				vila_h.cena_historia.avancar()
				vila_h.cena_historia.avancar()).call_deferred()
		return
	if tela == "config":
		jog.definir_notificacao("conserto", false)
		var tc: TelaConfiguracoes = load("res://game/scenes/ui/tela_configuracoes.tscn").instantiate()
		var camada_c := CanvasLayer.new()
		add_child(camada_c)
		camada_c.add_child(tc)
		tc.abrir.call_deferred()
		return
	if tela == "liga":
		# Salão da liga com adversário, defesa e histórico (TM_ABA).
		jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
		jog.estado["cavaleiro"]["nivel"] = 8
		jog.estado["liga"]["pontos"] = 340
		jog.salvar_defesa()
		jog.estado["liga"]["ultima_simulacao"] = int(jog.estado["liga"]["ultima_simulacao"]) - 86400
		jog.procurar_adversario()
		var tl: TelaLiga = load("res://game/scenes/ui/tela_liga.tscn").instantiate()
		var camada_l := CanvasLayer.new()
		add_child(camada_l)
		camada_l.add_child(tl)
		tl.abrir.call_deferred(OS.get_environment("TM_ABA") if OS.get_environment("TM_ABA") != "" else "liga")
		return
	if tela == "social":
		# Telas sociais (TM_ABA = ordem|chat|amigos|perfil, TM_SUB = membros|ajuda|doacoes|
		# torneio|loja|gerir, TM_CANAL = ordem|global, TM_ORDEM=0 = sem ordem).
		jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
		jog.estado["cavaleiro"]["nivel"] = 8
		jog.estado["inventario"]["ouro"] = 2000
		jog.estado["liga"]["pontos"] = 340
		if OS.get_environment("TM_ORDEM") != "0":
			jog.entrar_ordem(jog.ordens_para_entrar()[1]["id"])
			jog.treinar_cavaleiro("forca")
			for tm: Dictionary in jog.estado["timers"]:
				tm["termina_em"] = ServicoTempo.agora() + 5400
			jog.pedir_ajuda(jog.estado["timers"][0]["id"])
			jog.estado["social"]["moeda"] = 87
			jog.estado["social"]["torneio"]["vitorias"] = 4
			jog.adicionar_amigo(jog.ordem()["membros"][1]["id"])
			jog.adicionar_amigo_por_codigo(jog.codigos_de_teste(1)[0]["codigo"])
		jog.chat_atualizar()
		jog.chat_enviar("global", "", "boa_justa")
		var ts: TelaSocial = load("res://game/scenes/ui/tela_social.tscn").instantiate()
		var camada_s := CanvasLayer.new()
		add_child(camada_s)
		camada_s.add_child(ts)
		if OS.get_environment("TM_SUB") != "":
			ts.sub = OS.get_environment("TM_SUB")
		if OS.get_environment("TM_CANAL") != "":
			ts.canal = OS.get_environment("TM_CANAL")
		var aba_s := OS.get_environment("TM_ABA") if OS.get_environment("TM_ABA") != "" else "ordem"
		var perfil_s := ""
		if aba_s == "perfil" and OS.get_environment("TM_ORDEM") != "0":
			perfil_s = jog.ordem()["membros"][2]["id"]
		ts.abrir.call_deferred(aba_s, perfil_s)
		return
	if tela == "loja":
		# Loja com passe no nível 7 (premium comprado), ofertas e gemas (TM_ABA).
		jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
		jog.comprar("gemas_medio")
		jog.comprar("passe_premium")
		for i in 90:
			jog.registrar_justa({"equipamento_final": {}, "gasta_folego": false})
		jog.resgatar_passe(1, "gratis")
		jog.resgatar_passe(1, "premium")
		jog.disparar_oferta("subiu_liga")
		var tlj: TelaLoja = load("res://game/scenes/ui/tela_loja.tscn").instantiate()
		var camada_lj := CanvasLayer.new()
		add_child(camada_lj)
		camada_lj.add_child(tlj)
		tlj.abrir.call_deferred(OS.get_environment("TM_ABA"))
		return
	if tela == "torneios":
		# Circuito aberto até TM_REGIAO (padrão: condado), nível alto.
		jog.estado["cavaleiro"]["nivel"] = 20
		var reg := OS.get_environment("TM_REGIAO") if OS.get_environment("TM_REGIAO") != "" else "condado"
		jog.estado["pve"]["regiao"] = reg
		var t: TelaTorneios = load("res://game/scenes/village/tela_torneios.tscn").instantiate()
		var camada := CanvasLayer.new()
		add_child(camada)
		camada.add_child(t)
		t.abrir.call_deferred()
		return
	var fluxo := get_node("/root/Fluxo") as FluxoTelas
	var torneio := OS.get_environment("TM_TORNEIO")
	if torneio != "":
		# Primeira disputa de um torneio do PvE (ex.: desafio_ribeira = chuva).
		jog.estado["cavaleiro"]["nivel"] = 20
		jog.estado["pve"]["regiao"] = jog.regiao_do_torneio(torneio)
		fluxo.disputa = {"torneio": torneio, "indice": 0}
		fluxo.modo_justa = "disputa"
		add_child(load("res://game/scenes/arena/arena.tscn").instantiate())
		return
	if OS.get_environment("TM_TITULO") != "":
		# Justa livre com título (o arauto anuncia na apresentação).
		jog.estado["metas"]["titulos"] = [OS.get_environment("TM_TITULO")]
		jog.definir_titulo(OS.get_environment("TM_TITULO"))
	fluxo.modo_justa = OS.get_environment("TM_MODO")
	add_child(load("res://game/scenes/arena/arena.tscn").instantiate())
