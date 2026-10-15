class_name Plaquinha
extends PanelContainer
## Plaquinha de um cavaleiro no topo da justa: retrato, nome, barra de
## armadura e barra de fôlego do cavalo. A do rival é espelhada (retrato à
## direita). Encaixe para arte: Linha/Retrato (hoje um ColorRect provisório;
## troque por um TextureRect). Não recebe toques.

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
