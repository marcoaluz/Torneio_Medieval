class_name Tocha
extends Node2D
## Tocha da vila: poste com chama que tremula e luz 2D, acesa à noite
## (AmbienteVila liga e desliga pelo grupo "tocha"). Arte provisória por código.

var acesa := false:
	set(v):
		acesa = v
		if _luz:
			_luz.enabled = v
		queue_redraw()

var _luz: PointLight2D
var _t := 0.0

static var _textura_luz: GradientTexture2D

func _ready() -> void:
	add_to_group("tocha")
	if _textura_luz == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 0.75, 0.4, 1))
		g.set_color(1, Color(1, 0.6, 0.3, 0))
		_textura_luz = GradientTexture2D.new()
		_textura_luz.gradient = g
		_textura_luz.fill = GradientTexture2D.FILL_RADIAL
		_textura_luz.fill_from = Vector2(0.5, 0.5)
		_textura_luz.fill_to = Vector2(1.0, 0.5)
		_textura_luz.width = 128
		_textura_luz.height = 128
	_luz = PointLight2D.new()
	_luz.texture = _textura_luz
	_luz.texture_scale = 1.6
	_luz.energy = 1.1
	_luz.position = Vector2(0, -20)
	_luz.enabled = acesa
	add_child(_luz)

func _process(delta: float) -> void:
	if not acesa:
		return
	_t += delta
	_luz.energy = 1.0 + 0.15 * sin(_t * 11.0) + 0.08 * sin(_t * 23.0)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-1.5, -18, 3, 18), Color(0.3, 0.2, 0.12))
	if acesa:
		var f := 1.0 + 0.2 * sin(_t * 15.0)
		draw_circle(Vector2(0, -21), 4.0 * f, Color(1, 0.55, 0.15))
		draw_circle(Vector2(0, -22), 2.2 * f, Color(1, 0.9, 0.5))
	else:
		draw_rect(Rect2(-2.5, -22, 5, 4), Color(0.2, 0.15, 0.1))
