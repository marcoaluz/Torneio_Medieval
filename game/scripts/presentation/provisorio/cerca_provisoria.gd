@tool
class_name CercaProvisoria
extends Node2D
## Arte provisória da cerca (tilt): tábuas horizontais e postes. Desenhada de
## (0,0) até `tamanho`, com a base em y = tamanho.y.

@export var tamanho := Vector2(1280, 56):
	set(v):
		tamanho = v
		queue_redraw()
@export var distancia_postes := 64.0:
	set(v):
		distancia_postes = v
		queue_redraw()

const COR_TABUA := Color("7a5a3a")
const COR_TABUA_SOMBRA := Color("4a3422")
const COR_POSTE := Color("3a2818")

func _draw() -> void:
	var h := tamanho.y
	draw_rect(Rect2(0, h * 0.10, tamanho.x, h * 0.55), COR_TABUA)
	draw_rect(Rect2(0, h * 0.60, tamanho.x, h * 0.05), COR_TABUA_SOMBRA)
	draw_rect(Rect2(0, h * 0.75, tamanho.x, h * 0.12), COR_TABUA)
	var x := 0.0
	while x <= tamanho.x:
		draw_rect(Rect2(x - 3, 0, 6, h), COR_POSTE)
		x += distancia_postes
