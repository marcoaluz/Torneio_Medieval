@tool
class_name Arauto
extends Node2D
## Arauto com a bandeira da largada (apresentação). Encaixes para sprites:
## Corpo e Bandeira (a bandeira gira em volta do ombro, a origem do nó).
## levantar() no começo da Largada, baixar() quando a regra manda.

@export var angulo_levantada := -150.0
@export var angulo_baixada := -20.0
@export var duracao_baixar := 0.08

var levantada := true
var _tween: Tween

## Arte gerada (tools: PixelLab): corpo com os pés na origem e a bandeira com o
## pé do mastro na origem do giro, presa ao punho erguido. Sem ela, o provisório.
const ARTE_CORPO := "res://game/art/sprites/arena/arauto_corpo.png"
const ARTE_BANDEIRA := "res://game/art/sprites/arena/arauto_bandeira.png"
const PUNHO := Vector2(12, -53)

func _ready() -> void:
	if not Engine.is_editor_hint():
		_encaixar_arte()
	levantar()

func _encaixar_arte() -> void:
	if not (ResourceLoader.exists(ARTE_CORPO) and ResourceLoader.exists(ARTE_BANDEIRA)):
		return
	for no in [get_node("Corpo"), get_node("Bandeira")]:
		for f in no.get_children():
			if f.is_in_group("provisorio"):
				f.visible = false
	var corpo := Sprite2D.new()
	corpo.texture = load(ARTE_CORPO)
	corpo.centered = false
	corpo.position = Vector2(-corpo.texture.get_width() / 2, -corpo.texture.get_height())
	get_node("Corpo").add_child(corpo)
	var b := get_node("Bandeira") as Node2D
	b.position = PUNHO
	var pano := Sprite2D.new()
	pano.texture = load(ARTE_BANDEIRA)
	pano.centered = false
	pano.position = Vector2(0, -3)
	b.add_child(pano)

func levantar() -> void:
	levantada = true
	_girar(angulo_levantada, 0.0)

func baixar() -> void:
	levantada = false
	_girar(angulo_baixada, duracao_baixar)

func esta_levantada() -> bool:
	return levantada

func _girar(graus: float, duracao: float) -> void:
	var b := get_node_or_null("Bandeira") as Node2D
	if b == null:
		return
	if _tween:
		_tween.kill()
	if duracao <= 0.0 or not is_inside_tree():
		b.rotation_degrees = graus
		return
	_tween = create_tween()
	_tween.tween_property(b, "rotation_degrees", graus, duracao).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
