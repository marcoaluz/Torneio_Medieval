extends SceneTree
## Inglês e acessibilidade (3.24, headless): toda chave tem inglês, opções
## salvas e validadas, idioma, tamanho do texto (ao entrar e ao trocar),
## modo canhoto na justa e vibração desligável.

var _falhas := 0

func _initialize() -> void:
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_acess/")
	jog.caminho_save = "user://teste_acess/jogador.json"
	jog.estado = jog.novo_estado()
	var ac: OpcoesAcessibilidade = root.get_node("Acessibilidade")

	# Tradução completa
	var linhas := FileAccess.get_file_as_string("res://game/i18n/textos.csv").split("\n")
	var faltando := 0
	for i in range(1, linhas.size()):
		if linhas[i].strip_edges() == "":
			continue
		TranslationServer.set_locale("en")
		var chave := linhas[i].get_slice(",", 0)
		if tr(chave) == chave or tr(chave).strip_edges() == "":
			faltando += 1
	_checa("toda chave tem ingles (%d faltando)" % faltando, faltando == 0)

	# Opções
	_checa("padroes", jog.config_valor("canhoto") == false and jog.config_valor("vibracao") == true and jog.config_valor("texto") == "normal")
	_checa("opcao desconhecida", jog.definir_config("voar", true)["erro"] == "opcao_inexistente")
	_checa("tamanho invalido", jog.definir_config("texto", "gigante")["erro"] == "opcao_invalida")
	jog.definir_config("idioma", "en")
	_checa("idioma ingles", tr("CONFIG_TITULO") == "Settings")
	jog.definir_config("idioma", "pt_BR")
	_checa("idioma portugues", tr("CONFIG_TITULO") == "Configurações")

	# Tamanho do texto
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 20)
	root.add_child(l)
	await process_frame
	var base := l.get_theme_font_size("font_size")
	jog.definir_config("texto", "grande")
	await process_frame
	var escala := float(ac.cfg["tamanhos_texto"]["grande"])
	_checa("texto grande escala o que ja estava na tela (%d -> %d)" % [base, l.get_theme_font_size("font_size")], l.get_theme_font_size("font_size") == roundi(base * escala))
	var l2 := Label.new()
	root.add_child(l2)
	await process_frame
	await process_frame
	var tmp := Label.new()
	var tema_base := tmp.get_theme_font_size("font_size")
	tmp.free()
	_checa("texto novo ja entra grande", l2.get_theme_font_size("font_size") >= roundi(tema_base * escala) - 1)
	jog.definir_config("texto", "normal")
	await process_frame
	_checa("volta ao normal", l.get_theme_font_size("font_size") == base)
	l.queue_free()
	l2.queue_free()

	# Canhoto na justa
	jog.definir_config("canhoto", true)
	(root.get_node("Fluxo") as FluxoTelas).modo_justa = "livre"
	var arena: Arena = load("res://game/scenes/arena/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var botao: Control = arena.get_node("Interface/InterfaceJusta/BotaoHabilidade")
	var ajuste: Control = arena.get_node("PainelAjuste/Abrir")
	_checa("canhoto: habilidade a esquerda", botao.anchor_right <= 0.5)
	_checa("canhoto: ajuste a direita", ajuste.anchor_left >= 0.5)
	arena.free()
	jog.definir_config("canhoto", false)
	jog.definir_config("vibracao", false)
	_checa("vibracao desligada", not ac.vibracao())

	# Economia de bateria (3.25)
	var bat: Dictionary = ac.cfg["bateria"]
	jog.definir_config("economia_bateria", true)
	_checa("bateria: menos quadros e particulas", Engine.max_fps == int(bat["fps_economia"]) and is_equal_approx(ac.fator_particulas(), float(bat["particulas_pct"]) / 100.0))
	jog.definir_config("economia_bateria", false)
	_checa("bateria desligada: normal", Engine.max_fps == int(bat["fps_normal"]) and ac.fator_particulas() == 1.0)

	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_acess/" + arq)
	print("ACESS %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("ACESS %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
