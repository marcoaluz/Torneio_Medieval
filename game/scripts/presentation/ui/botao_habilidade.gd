class_name BotaoHabilidade
extends Button
## Botão redondo da habilidade ativa (canto inferior direito). O anel mostra
## a carga durante a Corrida; quando carregado e ainda não usado, fica aceso.
## O texto é o nome da habilidade (tradução).

@export var cor_anel := Color(1.0, 0.85, 0.45, 1)
@export var cor_anel_fundo := Color(0.2, 0.17, 0.14, 0.9)
@export var espessura_anel := 4.0

## 0 a 1.
var carga := 0.0:
	set(v):
		carga = clampf(v, 0.0, 1.0)
		queue_redraw()

func _draw() -> void:
	var centro := size * 0.5
	var raio := minf(size.x, size.y) * 0.5 - espessura_anel * 0.5
	draw_arc(centro, raio, 0.0, TAU, 48, cor_anel_fundo, espessura_anel)
	if carga > 0.0:
		draw_arc(centro, raio, -PI * 0.5, -PI * 0.5 + TAU * carga, 48, cor_anel, espessura_anel)
