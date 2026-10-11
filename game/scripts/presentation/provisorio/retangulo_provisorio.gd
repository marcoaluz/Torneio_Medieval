@tool
class_name RetanguloProvisorio
extends Node2D
## Arte provisória: um retângulo colorido. Fica como filho de um nó "encaixe"
## (Cavalo, Peito, Escudo...); quando o sprite chegar, apague este nó e ponha
## o Sprite2D/AnimatedSprite2D no mesmo encaixe.

@export var tamanho := Vector2(16, 16):
	set(v):
		tamanho = v
		queue_redraw()
@export var cor := Color.MAGENTA:
	set(v):
		cor = v
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, tamanho), cor)
