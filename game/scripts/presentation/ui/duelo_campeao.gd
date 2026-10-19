class_name DueloCampeao
extends Control
## Tela de duelo antes da justa contra um campeão (e da revanche heroica):
## os dois lados frente a frente (o jogador à esquerda, o campeão à direita
## com o retrato provocando), o arauto anunciando os dois e a frase de entrada
## do campeão. Os lados aparecem aos poucos; um toque segue para a liça
## (`entrar`). Só apresentação: quem abre decide o que vem depois.

signal entrar

const COR_DESTAQUE := Color(1, 0.88, 0.55)
const COR_FRACA := Color(0.8, 0.75, 0.66)

var rival: Dictionary = {}
var _jog: ServicoJogador
var _esq: VBoxContainer
var _dir: VBoxContainer
var _contra: Label
var _arauto: Label
var _frase: Label
var _dica: Label
var _pronto := false

func _ready() -> void:
	_jog = get_node("/root/Jogador")
	visible = false
	theme = load("res://game/scenes/ui/tema_jogo.tres")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo := ColorRect.new()
	fundo.color = Color(0.06, 0.04, 0.04, 0.94)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 24
	col.offset_right = -24
	col.offset_top = 16
	col.offset_bottom = -12
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	_arauto = _rotulo("", COR_DESTAQUE)
	_arauto.theme_type_variation = &"Titulo"
	col.add_child(_arauto)
	var linha := HBoxContainer.new()
	linha.size_flags_vertical = Control.SIZE_EXPAND_FILL
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 24)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(linha)
	_esq = _lado()
	_esq.name = "Jogador"
	linha.add_child(_esq)
	_contra = _rotulo("", COR_FRACA)
	_contra.name = "Contra"
	_contra.theme_type_variation = &"Titulo"
	_contra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_contra.autowrap_mode = TextServer.AUTOWRAP_OFF  # uma palavra só: sem quebra
	linha.add_child(_contra)
	_dir = _lado()
	_dir.name = "Campeao"
	linha.add_child(_dir)
	_frase = _rotulo("", Color(0.95, 0.9, 0.8))
	col.add_child(_frase)
	_dica = _rotulo("", COR_FRACA)
	col.add_child(_dica)

func _lado() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(300, 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v

## Mostra o duelo contra `rv` (como rival_para_justa ou preparar_revanche).
func mostrar(rv: Dictionary) -> void:
	rival = rv
	_pronto = false
	visible = true
	for lado in [_esq, _dir]:
		for c in lado.get_children():
			lado.remove_child(c)
			c.queue_free()
	var nome_j := str(_jog.cavaleiro().get("nome", ""))
	var ret_j := RetratoCabeca.new()
	ret_j.custom_minimum_size = Vector2(176, 176)
	_esq.add_child(_centro(ret_j))
	ret_j.vestir(_jog)  # já na árvore: as camadas se montam
	_esq.add_child(_rotulo(nome_j if nome_j != "" else tr("FICHA_VOCE"), COR_DESTAQUE, true))
	_esq.add_child(_rotulo(str(_jog.casa().get("nome", "")), COR_FRACA))
	var nome_r := tr(str(rv.get("nome_chave", "")))
	var ret_r := RetratoRival.new()
	ret_r.name = "Retrato"
	ret_r.custom_minimum_size = Vector2(176, 176)
	ret_r.mostrar(str(rv.get("retrato", rv.get("id", ""))), "debochado", rv.get("casa", {}), rv.get("brasao", {}), nome_r, true)
	_dir.add_child(_centro(ret_r))
	_dir.add_child(_rotulo(nome_r, COR_DESTAQUE, true))
	var alcunha := tr(str(rv.get("alcunha", ""))) if str(rv.get("alcunha", "")) != "" else ""
	_dir.add_child(_rotulo(alcunha, COR_FRACA))
	_contra.text = tr("DUELO_CONTRA")
	var chave := "DUELO_ARAUTO_REVANCHE" if rv.get("revanche", false) else "DUELO_ARAUTO"
	_arauto.text = tr(chave).format({"jogador": nome_j, "campeao": nome_r, "alcunha": alcunha})
	_frase.text = tr(str(rv.get("frase_entrada", ""))) if str(rv.get("frase_entrada", "")) != "" else ""
	_dica.text = tr("DUELO_TOQUE")
	var audio := get_node_or_null("/root/Audio") as ServicoAudio
	if audio:
		audio.voz("senhoras_e_senhores")
	# O jogador aparece, depois o campeão, e a dica no fim; o anúncio dá um tranco.
	_dica.modulate.a = 0.0
	_esq.modulate.a = 0.0
	_dir.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_esq, "modulate:a", 1.0, 0.3)
	t.tween_property(_dir, "modulate:a", 1.0, 0.3)
	t.tween_property(_dica, "modulate:a", 1.0, 0.25)
	t.tween_callback(func(): _pronto = true)
	_arauto.pivot_offset = _arauto.size * 0.5
	_arauto.scale = Vector2(1.15, 1.15)
	create_tween().tween_property(_arauto, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)

func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	var toque: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if toque:
		accept_event()
		seguir()

## Segue para a liça (um toque; antes da entrada terminar, o toque só a completa).
func seguir() -> void:
	if not _pronto:
		_pronto = true
		_dica.modulate.a = 1.0
		for lado in [_esq, _dir]:
			lado.modulate.a = 1.0
		return
	visible = false
	entrar.emit()

func _centro(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(c)
	return cc

func _rotulo(texto: String, cor: Color, titulo := false) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", cor)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if titulo:
		l.theme_type_variation = &"Titulo"
	return l
