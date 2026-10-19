extends SceneTree
## Interface legível no celular (GDD A vila > Interface legível no celular),
## headless com a vila de verdade (save em user://teste_legibilidade/):
##  - tema_jogo.tres: texto padrão de 22 px, título de 28 px, botão com ≥ 64 px;
##  - em cada tela aberta pela vila (perfil, campo de treino, estábulo, armeiro,
##    ferreiro, baús, missões, liga, loja, social, configurações, habilidades,
##    torneios, equipamentos, ficha do adversário, duelo do campeão, estante
##    de troféus): todo texto visível tem ≥ 22 px, todo botão
##    visível tem ≥ 64×64 px (o ícone do topo também) e a tela cabe na vista
##    base de 960×540 (16:9) e na de 1200×540 (20:9);
##  - topo da vila: retrato, brasão, nome, nível com barra de XP, ouro e gemas;
##    o retrato abre o perfil, e o perfil abre os Equipamentos.

const TEXTO_MIN := 22
const TITULO := 28
const BOTAO_MIN := 64.0
const VISTAS := [Vector2i(960, 540), Vector2i(1200, 540)]  ## 16:9 e 20:9 (a altura da vista base é sempre 540)

var _falhas := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_legibilidade/")
	jog.caminho_save = "user://teste_legibilidade/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
	jog.estado["cavaleiro"]["nivel"] = 20
	jog.estado["cavaleiro"]["nome"] = "Isolda"
	jog.estado["inventario"]["ouro"] = 12345
	jog.estado["inventario"]["gemas"] = 450
	jog.estado["pve"]["trofeus"] = {"campeao_valdemar": {"em": 1, "torneio": "feira_grande", "revanches": 2}}

	var tema: Theme = load("res://game/scenes/ui/tema_jogo.tres")
	_checa("tema: texto padrao de %d px (%d)" % [TEXTO_MIN, tema.default_font_size], tema.default_font_size >= TEXTO_MIN)
	_checa("tema: botao de %d px" % TEXTO_MIN, tema.get_font_size("font_size", "Button") >= TEXTO_MIN)
	_checa("tema: titulo de %d px" % TITULO, tema.get_font_size("font_size", "Titulo") == TITULO)

	var vila: Vila = load("res://game/scenes/village/vila.tscn").instantiate()
	root.add_child(vila)
	await _quadros(3)
	if vila.cena_historia.visible:
		vila.cena_historia.visible = false
	await _quadros(2)

	# Câmera aproximada: o zoom aumenta os prédios, o nome do prédio lê 22 px na tela
	# e o dedo arrasta a vila sem abrir prédio (só toque curto abre).
	var cam := vila.get_node("Camera") as Camera2D
	_checa("vila: camera aproximada (zoom %.2f)" % cam.zoom.x, cam.zoom.x >= 1.15)
	var nome_px: int = vila.predios["estabulo"].get_node("Nome").get_theme_font_size("font_size")
	_checa("vila: nome do predio le %d px na tela" % int(nome_px * cam.zoom.x), nome_px * cam.zoom.x >= TEXTO_MIN)
	var antes := cam.position
	var arrasto := InputEventScreenTouch.new()
	arrasto.pressed = true
	arrasto.position = Vector2(400, 300)
	vila._unhandled_input(arrasto)
	var mexe := InputEventScreenDrag.new()
	mexe.position = Vector2(300, 300)
	mexe.relative = Vector2(-100, 0)
	vila._unhandled_input(mexe)
	arrasto.pressed = false
	arrasto.position = Vector2(300, 300)
	vila._unhandled_input(arrasto)
	await _quadros(2)
	_checa("vila: arrastar move a camera (%s -> %s)" % [antes, cam.position], cam.position.x > antes.x + 20.0)
	_checa("vila: arrastar nao abre predio", not vila.tela_treino.visible and not vila.tela_forja.visible and vila.aberto == "")
	var pos_predio: Vector2 = vila.predios["campo_treino"].position
	var tela_pt: Vector2 = vila.get_canvas_transform() * pos_predio
	var toque := InputEventScreenTouch.new()
	toque.pressed = true
	toque.position = tela_pt
	vila._unhandled_input(toque)
	toque.pressed = false
	vila._unhandled_input(toque)
	await _quadros(2)
	_checa("vila: toque curto no predio abre (%s)" % tela_pt, vila.tela_treino.visible and vila.tela_treino.predio == "campo_treino")
	vila.tela_treino.fechar()
	await _quadros(1)

	# Topo da vila.
	for vista: Vector2i in VISTAS:
		await _passada(vila, jog, vista)
	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_legibilidade/" + arq)
	print("LEGIBILIDADE %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

## Topo e todas as telas numa proporção de vista.
func _passada(vila: Vila, jog: ServicoJogador, vista: Vector2i) -> void:
	var rotulo := "%dx%d" % [vista.x, vista.y]
	root.size = vista
	await _quadros(3)
	var VISTA := Rect2(Vector2.ZERO, Vector2(vista))
	var topo := vila.get_node("Interface/Topo") as Control
	_checa(rotulo + " topo: nome do cavaleiro", vila._topo_nome.text == "Isolda")
	_checa(rotulo + " topo: nivel com barra de XP", vila._topo_nivel.text.contains("20") and vila._topo_xp.is_visible_in_tree() and vila._topo_xp.max_value > 0)
	_checa(rotulo + " topo: ouro e gemas", vila._recursos["ouro"].text == "12345" and vila._recursos["gemas"].text == "450")
	_checa(rotulo + " topo: retrato do cavaleiro desenhado", vila._retrato != null and vila._retrato.tem_retrato() and vila._retrato.texture != null)
	_checa(rotulo + " topo: brasao da casa", vila._topo_brasao.texture != null)
	_checa(rotulo + " topo: retrato e um botao de 64+ px", vila._topo_retrato.size.x >= BOTAO_MIN and vila._topo_retrato.size.y >= BOTAO_MIN)
	_checa(rotulo + " topo cabe na vista (%s)" % topo.get_global_rect(), VISTA.grow(1).encloses(topo.get_global_rect()))
	_varrer(rotulo + " vila (topo)", topo)
	vila._topo_retrato.pressed.emit()
	await _quadros(2)
	_checa(rotulo + " o retrato abre o perfil", vila.tela_perfil.visible)
	vila.tela_perfil.get_node("Coluna/Rodape/Equipamentos").pressed.emit()
	await _quadros(2)
	_checa(rotulo + " o perfil abre os equipamentos", vila.tela_equipamentos.visible and not vila.tela_perfil.visible)
	vila.tela_equipamentos.visible = false

	# Telas abertas pela vila.
	var telas := {
		"perfil": func(): vila.tela_perfil.abrir(),
		"campo de treino": func(): vila.tocar_predio("campo_treino"),
		"estabulo": func(): vila.tocar_predio("estabulo"),
		"armeiro": func(): vila.tocar_predio("armeiro"),
		"ferreiro": func(): vila.tocar_predio("ferreiro"),
		"baus": func(): vila.tela_baus.abrir(),
		"missoes": func(): vila.tela_missoes.abrir("diarias"),
		"liga": func(): vila.tela_liga.abrir(),
		"loja": func(): vila.tela_loja.abrir(),
		"social": func(): vila.tela_social.abrir(),
		"configuracoes": func(): vila.tela_configuracoes.abrir(),
		"habilidades": func(): vila.tela_habilidades.abrir(),
		"torneios": func(): vila.tela_torneios.abrir(),
		"equipamentos": func(): vila.tela_equipamentos.abrir(),
		"ficha do adversario": func(): vila.preparar_luta(jog.rival_para_justa("dama_elvira_sangue_real"), Callable(), func(): pass),
		"ficha da revanche": func(): vila.pedir_revanche("campeao_valdemar"),
		"duelo do campeao": func(): vila.duelo().mostrar(jog.rival_para_justa("sir_baltasar_escudo_ouro")),
		"estante de trofeus": func():
			vila.tela_perfil.abrir()
			vila.tela_perfil.aba = "trofeus"
			vila.tela_perfil.trofeu = "campeao_valdemar"
			vila.tela_perfil.atualizar(),
	}
	for nome: String in telas:
		telas[nome].call()
		await _quadros(3)
		var tela := _tela_aberta(vila)
		_checa("%s %s: tela aberta" % [rotulo, nome], tela != null)
		if tela == null:
			continue
		_checa("%s %s: cabe na vista (%s)" % [rotulo, nome, tela.get_global_rect()], VISTA.grow(1).encloses(tela.get_global_rect()))
		_varrer(rotulo + " " + nome, tela)
		tela.visible = false
		await _quadros(1)

## A tela visível por cima da vila (filha de Interface, nome Tela*).
func _tela_aberta(vila: Vila) -> Control:
	for t in vila.get_node("Interface").get_children():
		if t is Control and (str(t.name).begins_with("Tela") or t.name in [&"FichaAdversario", &"DueloCampeao"]) and (t as Control).visible:
			return t
	return null

## Texto visível com 22 px ou mais e botão visível com 64×64 ou mais.
func _varrer(nome: String, raiz: Node) -> void:
	var pequenos: Array[String] = []
	var finos: Array[String] = []
	for n in raiz.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree():
			continue
		if c is Label and (c as Label).text != "":
			var tam := c.get_theme_font_size("font_size")
			if tam < TEXTO_MIN:
				pequenos.append("%s=%d" % [c.name, tam])
		elif c is Button and not (c as Button).flat:
			var b := c as Button
			if b.text != "" and b.get_theme_font_size("font_size") < TEXTO_MIN:
				pequenos.append("%s=%d" % [b.name, b.get_theme_font_size("font_size")])
			if b.size.x < BOTAO_MIN - 0.5 or b.size.y < BOTAO_MIN - 0.5:
				if _e_de_scroll(b):
					continue
				finos.append("%s %dx%d" % [b.name, int(b.size.x), int(b.size.y)])
	_checa("%s: texto >= %d px %s" % [nome, TEXTO_MIN, pequenos], pequenos.is_empty())
	_checa("%s: botoes >= 64x64 %s" % [nome, finos], finos.is_empty())

## Botões escondidos pela rolagem (cortados fora da área visível) não contam.
func _e_de_scroll(b: Control) -> bool:
	var p := b.get_parent()
	while p != null:
		if p is ScrollContainer:
			return not (p as ScrollContainer).get_global_rect().intersects(b.get_global_rect())
		p = p.get_parent()
	return false

func _quadros(n: int) -> void:
	for i in n:
		await process_frame

func _checa(nome: String, ok: bool) -> void:
	print("LEGIBILIDADE %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
