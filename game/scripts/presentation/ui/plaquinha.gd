class_name Plaquinha
extends PanelContainer
## Plaquinha de um cavaleiro no topo da justa: retrato, nome, barra de
## armadura e barra de fôlego do cavalo. A do rival é espelhada (retrato à
## direita). Retrato: o próprio cavaleiro (cabeça e ombros, com o elmo que usa),
## desenhado pelas camadas do tamanho de Equipamentos num SubViewport, em quadro
## como na referência de arte; o brasão da casa vira um selo no canto. Sem retrato,
## fica o brasão sobre a cor da casa. Não recebe toques.

@export var espelhada := false:
	set(v):
		espelhada = v
		_arrumar()

@onready var _linha: HBoxContainer = $Linha
@onready var _retrato: Control = $Linha/Retrato
@onready var _nome: Label = $Linha/Dados/Nome
@onready var _armadura: ProgressBar = $Linha/Dados/Armadura
@onready var _folego: ProgressBar = $Linha/Dados/Folego

func _ready() -> void:
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrumar()

func definir(nome: String, cor_casa: Color, brasao: Texture2D = null) -> void:
	_nome.text = nome
	var prov := _retrato.get_node_or_null("Provisorio") as ColorRect
	if prov:
		prov.color = cor_casa.darkened(0.35)
	# Brasão da casa sobre a cor da casa (o mesmo do escudo, ampliado sem borrar).
	var b := _retrato.get_node_or_null("Brasao") as TextureRect
	if brasao and b == null:
		b = TextureRect.new()
		b.name = "Brasao"
		b.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_retrato.add_child(b)
	if b:
		b.texture = brasao

const RETRATO_PX := 64
## Centro da cabeça a partir da origem (pés) do quadro de Equipamentos (256).
const RETRATO_CABECA := Vector2(2, -212)
var _vista: SubViewport

## Retrato a partir das camadas de um cavaleiro já vestido (mesmas peças e cores).
func definir_retrato(fonte: CamadasPersonagem) -> void:
	if fonte == null:
		return
	if _vista == null:
		_vista = SubViewport.new()
		_vista.size = Vector2i(RETRATO_PX, RETRATO_PX)
		_vista.transparent_bg = true
		_vista.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		_vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_vista)
		var c := CamadasPersonagem.new()
		c.name = "Camadas"
		c.tamanho = "equipamentos"
		c.position = Vector2(RETRATO_PX * 0.5, RETRATO_PX * 0.5) - RETRATO_CABECA
		_vista.add_child(c)
		var tr_ := TextureRect.new()
		tr_.name = "Rosto"
		tr_.texture = _vista.get_texture()
		tr_.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr_.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr_.flip_h = espelhada  # o rival olha para dentro da tela
		tr_.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_retrato.add_child(tr_)
		_retrato.move_child(tr_, 1)  # sobre o fundo da cor da casa, sob o selo
	var cam := _vista.get_node("Camadas") as CamadasPersonagem
	var pecas := fonte.pecas.duplicate()
	pecas["escudo"] = "nenhum"  # o escudo na frente cobriria o rosto
	cam.cores = fonte.cores.duplicate()
	cam._aplicar_cores()  # as cores da casa dele (o padrão já foi aplicado no _ready)
	cam.vestir(pecas)
	cam.tocar("parado", true)
	# Com retrato, o brasão vira um selo pequeno no canto de baixo.
	var b := _retrato.get_node_or_null("Brasao") as TextureRect
	if b:
		b.set_anchors_preset(Control.PRESET_BOTTOM_LEFT if espelhada else Control.PRESET_BOTTOM_RIGHT)
		b.custom_minimum_size = Vector2(14, 17)
		b.size = Vector2(14, 17)
		b.position = Vector2(-4 if espelhada else _retrato.size.x - 10, _retrato.size.y - 13)
		_retrato.move_child(b, _retrato.get_child_count() - 1)

func tem_retrato() -> bool:
	return _vista != null

## Frações de 0 a 1.
func atualizar(armadura: float, folego: float) -> void:
	_armadura.value = clampf(armadura, 0.0, 1.0)
	_folego.value = clampf(folego, 0.0, 1.0)

func _arrumar() -> void:
	if not is_node_ready():
		return
	_linha.move_child(_retrato, _linha.get_child_count() - 1 if espelhada else 0)
	_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if espelhada else HORIZONTAL_ALIGNMENT_LEFT
	var moldura := ArteUi.caixa("plaquinha", Vector2(10, 6), -1, espelhada)
	if moldura:
		# O círculo do retrato fica todo na borda do lado dele (não estica).
		if espelhada:
			moldura.texture_margin_right = 40.0
		else:
			moldura.texture_margin_left = 40.0
		add_theme_stylebox_override("panel", moldura)
	var preenche := ProgressBar.FILL_END_TO_BEGIN if espelhada else ProgressBar.FILL_BEGIN_TO_END
	_armadura.fill_mode = preenche
	_folego.fill_mode = preenche
