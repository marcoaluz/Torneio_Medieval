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

func definir(nome: String, cor_casa: Color) -> void:
	_nome.text = nome
	var prov := _retrato.get_node_or_null("Provisorio") as ColorRect
	if prov:
		prov.color = cor_casa

## Frações de 0 a 1.
func atualizar(armadura: float, folego: float) -> void:
	_armadura.value = clampf(armadura, 0.0, 1.0)
	_folego.value = clampf(folego, 0.0, 1.0)

func _arrumar() -> void:
	if not is_node_ready():
		return
	_linha.move_child(_retrato, _linha.get_child_count() - 1 if espelhada else 0)
	_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if espelhada else HORIZONTAL_ALIGNMENT_LEFT
	var preenche := ProgressBar.FILL_END_TO_BEGIN if espelhada else ProgressBar.FILL_BEGIN_TO_END
	_armadura.fill_mode = preenche
	_folego.fill_mode = preenche
