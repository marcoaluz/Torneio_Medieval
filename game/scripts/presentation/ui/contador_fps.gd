class_name ContadorFps
extends CanvasLayer
## Contador de FPS no canto da tela, só em build de depuração (some na
## exportação de release). Fica acima de tudo (layer alto) e não recebe toque.
## Carregado como autoload "Depuracao" (project.godot).

@onready var _rotulo: Label = $Rotulo

var _acumulado := 0.0

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_acumulado += delta
	if _acumulado < 0.25:
		return
	_acumulado = 0.0
	_rotulo.text = tr("DEPURACAO_FPS").format({"fps": Engine.get_frames_per_second()})
