@tool
class_name ChaoVilaProvisorio
extends Node2D
## Arte provisória do chão da vila (vista de cima): grama escura, praça de
## terra no meio, caminhos até os prédios, muralha baixa e árvores. Encaixe:
## troque por um Sprite2D com o fundo da vila (1280×540, área segura 960×540).

@export var tamanho := Vector2(1280, 540):
	set(v):
		tamanho = v
		queue_redraw()
## Pontos ligados à praça por caminhos (posições dos prédios).
@export var destinos: PackedVector2Array = PackedVector2Array():
	set(v):
		destinos = v
		queue_redraw()

const GRAMA := Color("2f3a24")
const TERRA := Color("6b5a40")
const MURO := Color("4a4640")

func _draw() -> void:
	var r := Rect2(-(tamanho.x - 960) * 0.5, 0, tamanho.x, tamanho.y)
	draw_rect(r, GRAMA)
	for i in 160:
		var h := hash(i)
		var p := Vector2(r.position.x + (h % int(tamanho.x)), float((h / 7) % int(tamanho.y)))
		draw_rect(Rect2(p, Vector2(2, 2)), GRAMA.lightened(0.08 + (h % 3) * 0.03))
	var praca := Vector2(480, 300)
	for d in destinos:
		draw_line(praca, d, TERRA, 18)
	draw_circle(praca, 60, TERRA)
	draw_circle(praca, 60, TERRA.darkened(0.2), false, 3)
	# Muralha baixa
	draw_rect(Rect2(20, 40, 920, 490), MURO, false, 6)
	# Árvores nos cantos
	for t in [Vector2(70, 120), Vector2(890, 120), Vector2(80, 480), Vector2(880, 480), Vector2(-60, 300), Vector2(1020, 300)]:
		draw_circle(t + Vector2(4, 6), 22, Color(0, 0, 0, 0.25))
		draw_circle(t, 22, Color("24301c"))
		draw_circle(t + Vector2(-5, -5), 12, Color("34422a"))
