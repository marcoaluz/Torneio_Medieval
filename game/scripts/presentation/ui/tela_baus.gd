class_name TelaBaus
extends PanelContainer
## Baús da vila (Pacote 3.14, GDD Baús e itens): os 4 espaços, cada um
## fechado (toque começa a abrir), abrindo (tempo que falta) ou pronto
## (toque abre); a chave abre na hora. A abertura anima (o baú treme, a tampa
## abre e as peças aparecem uma a uma, com a cor da raridade; repetida vira
## fragmentos) e a tela de chances mostra as probabilidades de cada baú. Tudo
## que muda dados passa pelo serviço Jogador (depois, pela Edge Function).

var _jog: ServicoJogador
var _acumulado := 0.0
var _tween: Tween

@onready var _titulo: Label = $Coluna/Titulo
@onready var _info: Label = $Coluna/Info
@onready var _espacos: HBoxContainer = $Coluna/Rolagem/Espacos
@onready var _chances: Label = $Coluna/Probabilidades
@onready var _mensagem: Label = $Coluna/Mensagem
@onready var _ver_chances: Button = $Coluna/Botoes/VerChances
@onready var _fechar: Button = $Coluna/Botoes/Fechar
@onready var _abertura: Control = $Abertura
@onready var _bau: Control = $Abertura/Bau
@onready var _itens: HBoxContainer = $Abertura/Itens
@onready var _ganho: Label = $Abertura/Ganho
@onready var _continuar: Button = $Abertura/Continuar

func _ready() -> void:
	_jog = get_node("/root/Jogador")
	visible = false
	_abertura.visible = false
	_titulo.text = tr("BAUS_TITULO")
	_fechar.text = tr("PAINEL_FECHAR")
	_continuar.text = tr("BAUS_CONTINUAR")
	_ver_chances.toggle_mode = true
	_ver_chances.toggled.connect(func(on: bool): _chances.visible = on; _espacos.visible = not on; montar())
	_fechar.pressed.connect(func(): visible = false)
	_continuar.pressed.connect(func(): _abertura.visible = false; montar())
	_jog.mudou.connect(func(_s): if visible and not _abertura.visible: montar())

func abrir() -> void:
	visible = true
	_abertura.visible = false
	_mensagem.text = ""
	montar()

func _process(delta: float) -> void:
	if not visible:
		return
	_acumulado += delta
	if _acumulado >= 1.0:
		_acumulado = 0.0
		if not _abertura.visible and not _chances.visible:
			montar()

func montar() -> void:
	_info.text = tr("BAUS_INFO").format({"chaves": _jog.chaves(), "fragmentos": _jog.fragmentos()})
	# Baú de madeira extra por anúncio (opcional; VIP ganha sem assistir).
	var extra := get_node_or_null("Coluna/AnuncioBau") as Button
	if extra == null:
		extra = Button.new()
		extra.name = "AnuncioBau"
		extra.focus_mode = Control.FOCUS_NONE
		extra.pressed.connect(func(): _anuncio("bau_madeira_extra", ""))
		$Coluna.add_child(extra)
		$Coluna.move_child(extra, 2)
	extra.text = TelaBaus.texto_anuncio(_jog, "ANUNCIO_BAU")
	extra.visible = _jog.pode_recompensa_anuncio("bau_madeira_extra")["ok"] and not _chances.visible
	_ver_chances.text = tr("BAUS_VOLTAR") if _chances.visible else tr("BAUS_PROBABILIDADES")
	if _chances.visible:
		_chances.text = texto_probabilidades()
		return
	for c in _espacos.get_children():
		c.queue_free()
	var baus := _jog.baus()
	var abrindo := _jog.bau_abrindo()
	for i in int(_jog.cfg_baus()["espacos"]):
		var caixa := VBoxContainer.new()
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(140, 150)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caixa.add_child(b)
		_espacos.add_child(caixa)
		if i >= baus.size():
			b.text = tr("BAUS_VAZIO")
			b.disabled = true
			continue
		var bau: Dictionary = baus[i]
		var nome := tr("BAU_" + str(bau["tipo"]).to_upper())
		var arte := _arte_bau(bau["tipo"], false)
		if arte:
			b.icon = arte
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_color_override("font_color", _cor_bau(bau["tipo"]).lightened(0.2))
		b.add_theme_color_override("font_disabled_color", _cor_bau(bau["tipo"]).darkened(0.1))
		var id: String = bau["id"]
		if _jog.bau_pronto(id):
			b.text = "%s\n\n%s" % [nome, tr("BAUS_PRONTO")]
			b.pressed.connect(func(): abrir_bau(id, false))
		elif int(bau["abre_em"]) > 0:
			b.text = "%s\n\n%s" % [nome, tr("BAUS_ABRINDO").format({"tempo": Vila.formatar_tempo(ServicoTempo.restante(int(bau["abre_em"])))})]
			var agora_b := Button.new()
			agora_b.focus_mode = Control.FOCUS_NONE
			agora_b.text = tr("LOJA_TERMINAR_AGORA").format({"n": _jog.custo_pular(ServicoTempo.restante(int(bau["abre_em"])))})
			agora_b.pressed.connect(func(): _resposta(_jog.pular_com_gemas(id)))
			caixa.add_child(agora_b)
			if _jog.pode_recompensa_anuncio("cortar_timer", id)["ok"]:
				var ad := Button.new()
				ad.focus_mode = Control.FOCUS_NONE
				ad.text = TelaBaus.texto_anuncio(_jog, "ANUNCIO_CORTAR")
				ad.pressed.connect(func(): _anuncio("cortar_timer", id))
				caixa.add_child(ad)
		else:
			var seg := _jog.duracao_timer(int(_jog.cfg_baus()["tipos"][bau["tipo"]]["segundos"]))
			b.text = "%s\n\n%s" % [nome, tr("BAUS_TOQUE_ABRIR").format({"tempo": Vila.formatar_tempo(seg)})
				if abrindo.is_empty() else tr("BAUS_NA_FILA")]
			b.disabled = not abrindo.is_empty()
			b.pressed.connect(func(): _resposta(_jog.comecar_abrir(id)))
		if _jog.chaves() > 0 and not _jog.bau_pronto(id):
			var chave := Button.new()
			chave.focus_mode = Control.FOCUS_NONE
			chave.text = tr("BAUS_USAR_CHAVE")
			chave.pressed.connect(func(): abrir_bau(id, true))
			caixa.add_child(chave)

## Abre de verdade (pelo serviço) e mostra a animação com o resultado.
func abrir_bau(id: String, com_chave: bool) -> void:
	var r := _jog.abrir_bau(id, com_chave)
	if not r["ok"]:
		_resposta(r)
		return
	mostrar_abertura(r)

func mostrar_abertura(r: Dictionary) -> void:
	_abertura.visible = true
	_continuar.visible = false
	_ganho.text = ""
	for c in _itens.get_children():
		c.queue_free()
	var desenho := _desenho_bau(r["tipo"])
	(_bau.get_node("Corpo") as ColorRect).color = _cor_bau(r["tipo"]).darkened(0.25)
	(_bau.get_node("Tampa") as ColorRect).color = _cor_bau(r["tipo"])
	var tampa: Control = _bau.get_node("Tampa")
	tampa.rotation_degrees = 0.0
	_bau.rotation_degrees = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	# O baú treme, a tampa abre e as peças saltam uma a uma.
	for k in 4:
		_tween.tween_property(_bau, "rotation_degrees", 6.0 if k % 2 == 0 else -6.0, 0.07)
	_tween.tween_property(_bau, "rotation_degrees", 0.0, 0.07)
	if desenho:
		# Arte do baú: troca para o aberto, com um pulinho.
		_tween.tween_callback(func(): desenho.texture = _arte_bau(r["tipo"], true))
		_tween.tween_property(desenho, "scale", Vector2(1.12, 1.12), 0.08)
		_tween.tween_property(desenho, "scale", Vector2.ONE, 0.12)
	else:
		_tween.tween_property(tampa, "rotation_degrees", -100.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for it: Dictionary in r["itens"]:
		var cartao := _cartao(it)
		cartao.scale = Vector2.ZERO
		_itens.add_child(cartao)
		_tween.tween_property(cartao, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func():
		_ganho.text = tr("BAUS_GANHOU").format({"ouro": r["ouro"], "fragmentos": r["fragmentos"]})
		_continuar.visible = true)

## Arte do baú (game/art/sprites/baus/), fechado ou aberto; null sem arte.
func _arte_bau(tipo: String, aberto: bool) -> Texture2D:
	var arq := "res://game/art/sprites/baus/bau_%s%s.png" % [tipo, "_aberto" if aberto else ""]
	return load(arq) if ResourceLoader.exists(arq) else null

## Com arte: esconde os retângulos e mostra o baú fechado (2x, sem borrar).
func _desenho_bau(tipo: String) -> TextureRect:
	var tex := _arte_bau(tipo, false)
	var d := _bau.get_node_or_null("Arte") as TextureRect
	if tex == null:
		if d:
			d.visible = false
		return null
	if d == null:
		d = TextureRect.new()
		d.name = "Arte"
		d.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		d.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		d.size = Vector2(128, 128)
		d.position = Vector2(-4, -14)
		d.pivot_offset = Vector2(64, 96)
		_bau.add_child(d)
	for n in ["Corpo", "Tampa", "Fecho"]:
		(_bau.get_node(n) as CanvasItem).visible = false
	d.visible = true
	d.scale = Vector2.ONE
	d.texture = tex
	return d

## Texto das chances de cada baú (GDD: sempre visíveis).
func texto_probabilidades() -> String:
	var cfg := _jog.cfg_baus()
	var linhas: Array[String] = []
	for tipo: String in cfg["tipos"]:
		var t: Dictionary = cfg["tipos"][tipo]
		var partes: Array[String] = []
		var p := RegraBau.probabilidades(tipo, cfg)
		for rar: String in p:
			partes.append("%s %s%%" % [tr("RARIDADE_" + rar.to_upper()), str(p[rar])])
		linhas.append(tr("BAUS_PROB_LINHA").format({"bau": tr("BAU_" + tipo.to_upper()), "tempo": Vila.formatar_tempo(int(t["segundos"])),
			"itens": int(t["itens"]), "ouro_min": int(t["ouro"][0]), "ouro_max": int(t["ouro"][1])}) + "\n   " + ", ".join(partes))
	linhas.append(tr("BAUS_GARANTIA").format({"n": int(cfg["garantia_raro_a_cada"])}))
	linhas.append(tr("BAUS_REPETIDAS").format({"n": int(cfg["fragmentos_por_repetida"])}))
	return "\n".join(linhas)

func _cartao(it: Dictionary) -> Control:
	var painel := PanelContainer.new()
	painel.custom_minimum_size = Vector2(130, 150)
	painel.pivot_offset = Vector2(65, 75)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.12, 0.09, 0.07)
	estilo.border_color = cor_raridade(it["raridade"])
	estilo.set_border_width_all(3)
	painel.add_theme_stylebox_override("panel", estilo)
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var extra := tr("BAUS_REPETIDA").format({"n": int(_jog.cfg_baus()["fragmentos_por_repetida"])}) if it["repetida"] else tr("BAUS_NOVA")
	l.text = "%s\n%s\n%s" % [tr("ITEM_" + str(it["modelo"]).to_upper()), tr("RARIDADE_" + str(it["raridade"]).to_upper()), extra]
	l.add_theme_color_override("font_color", cor_raridade(it["raridade"]))
	var coluna := VBoxContainer.new()
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	var tex := ArteUi.icone_item(str(it["modelo"]))
	if tex:
		var ic := TextureRect.new()
		ic.texture = tex
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		ic.custom_minimum_size = Vector2(48, 48)
		coluna.add_child(ic)
	coluna.add_child(l)
	painel.add_child(coluna)
	return painel

static func cor_raridade(raridade: String) -> Color:
	return Color(Balanceamento.carregar("itens").get("cores_raridade", {}).get(raridade, "ffffff"))

func _cor_bau(tipo: String) -> Color:
	return Color(Balanceamento.carregar("itens").get("cores_bau", {}).get(tipo, "8a5a2b"))

## Pede um benefício de anúncio (o autoload mostra; VIP não assiste).
func _anuncio(tipo: String, alvo: String) -> void:
	var an := get_node_or_null("/root/Anuncios") as ServicoAnuncios
	if an == null:
		return
	var r: Dictionary = await an.assistir(tipo, alvo)
	_resposta(r)

## Texto de um botão de anúncio: "▶ ..." (ou "VIP: ...") com quantos restam hoje.
static func texto_anuncio(jog: ServicoJogador, chave: String) -> String:
	var prefixo: String = TranslationServer.translate("ANUNCIO_VIP") if jog.anuncio_sem_assistir() else "▶"
	return "%s %s (%d)" % [prefixo, TranslationServer.translate(chave), jog.anuncios_restantes()]

func _resposta(r: Dictionary) -> void:
	_mensagem.text = "" if r["ok"] else tr("ERRO_" + str(r["erro"]).to_upper())
	montar()
