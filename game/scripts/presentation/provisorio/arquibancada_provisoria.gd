@tool
class_name ArquibancadaProvisoria
extends Node2D
## Arte provisória da arquibancada: degraus de madeira, público em retângulos e
## camarote no meio. Desenhada a partir de (0,0) até `tamanho`. O padrão do
## público vem de um hash fixo, então a imagem é sempre a mesma.

@export var tamanho := Vector2(1280, 160):
	set(v):
		tamanho = v
		queue_redraw()
@export var degraus := 4:
	set(v):
		degraus = v
		queue_redraw()
@export var largura_camarote := 200.0:
	set(v):
		largura_camarote = v
		queue_redraw()

const COR_MADEIRA := Color("4a3426")
const COR_MADEIRA_CLARA := Color("6b4a33")
const COR_CAMAROTE := Color("5c1f24")
const CORES_PUBLICO: Array[Color] = [
	Color("8a6f5a"), Color("5a6a7a"), Color("7a4a3a"), Color("6a6a4a"),
	Color("3f4a5c"), Color("9a8a6a"), Color("5c3f4a"),
]

func _draw() -> void:
	var altura_degrau := tamanho.y / degraus
	for i in degraus:
		var y := i * altura_degrau
		draw_rect(Rect2(0, y, tamanho.x, altura_degrau), COR_MADEIRA)
		draw_rect(Rect2(0, y + altura_degrau - 4, tamanho.x, 4), COR_MADEIRA_CLARA)
		# Público: cabeça e tronco, um a cada 14 px, com falhas.
		var x := 4.0
		var n := 0
		while x < tamanho.x - 10:
			var h := hash(Vector2i(i, n))
			if h % 5 != 0:
				var cor := CORES_PUBLICO[h % CORES_PUBLICO.size()]
				var dx := float(h % 4)
				draw_rect(Rect2(x + dx, y + altura_degrau - 20, 10, 14), cor)
				draw_rect(Rect2(x + dx + 2, y + altura_degrau - 27, 6, 7), cor.lightened(0.25))
			x += 14
			n += 1
	# Camarote no centro, com toldo.
	var cx := (tamanho.x - largura_camarote) * 0.5
	draw_rect(Rect2(cx, altura_degrau, largura_camarote, tamanho.y - altura_degrau), COR_CAMAROTE)
	draw_rect(Rect2(cx - 8, 0, largura_camarote + 16, altura_degrau), COR_CAMAROTE.darkened(0.3))
	# Estandartes pendurados na frente.
	var passo := tamanho.x / 10.0
	for k in 10:
		var bx := passo * k + passo * 0.5 - 8
		draw_rect(Rect2(bx, tamanho.y - 30, 16, 30), COR_CAMAROTE if k % 2 == 0 else Color("2c3a5a"))
