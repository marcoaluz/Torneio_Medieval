extends Node2D
## Cena de fumaça: confere a configuração de exibição (960x540), injeta um
## toque simulado e imprime tudo no log com prefixo SMOKE. Usada pelo driver
## da skill run-torneio-medieval.

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	print("SMOKE viewport=%dx%d" % [vp.x, vp.y])
	print("SMOKE renderer=%s" % ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	print("SMOKE filter=%d" % ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"))
	var tap := InputEventScreenTouch.new()
	tap.index = 0
	tap.position = Vector2(480, 270)
	tap.pressed = true
	Input.parse_input_event(tap)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		print("SMOKE touch=%d,%d" % [event.position.x, event.position.y])
