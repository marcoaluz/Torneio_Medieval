class_name ChaoVila
extends Node2D
## Chão da vila com arte gerada no PixelLab (game/art/sprites/vila/chao/): grama
## repetida, trilhas de terra da praça até a frente de cada prédio, a praça
## calçada com o poço, a muralha baixa de pedra e as árvores. Mesmo traçado do
## ChaoVilaProvisorio; sem a arte, `montar` devolve false e o provisório fica.

const PASTA := "res://game/art/sprites/vila/chao/"
const PRACA := Vector2(480, 300)
const MURO := Rect2(20, 40, 920, 490)
const ARVORES := [Vector2(70, 120), Vector2(890, 120), Vector2(80, 480), Vector2(880, 480), Vector2(-60, 300), Vector2(1020, 300)]

## `destinos`: a frente de cada prédio (onde a trilha chega).
func montar(destinos: Array) -> bool:
	if not ResourceLoader.exists(PASTA + "grama.png"):
		return false
	var grama := Sprite2D.new()
	grama.texture = load(PASTA + "grama.png")
	grama.centered = false
	grama.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	grama.region_enabled = true
	grama.region_rect = Rect2(0, 0, 1280, 540)
	grama.position = Vector2(-160, 0)
	grama.modulate = Color(0.82, 0.86, 0.8)  # grama mais calma: os prédios e o povo saltam à vista
	add_child(grama)
	for d: Vector2 in destinos:
		add_child(_faixa(PASTA + "trilha.png", [PRACA, d], 20.0))
	var muro := _faixa(PASTA + "muro.png", [MURO.position, Vector2(MURO.end.x, MURO.position.y), MURO.end,
		Vector2(MURO.position.x, MURO.end.y)], 12.0)
	muro.closed = true
	add_child(muro)
	var praca := Sprite2D.new()
	praca.texture = load(PASTA + "praca.png")
	praca.position = PRACA
	add_child(praca)
	for t: Vector2 in ARVORES:
		var a := Sprite2D.new()
		a.texture = load(PASTA + "arvore.png")
		a.position = t
		add_child(a)
	return true

func _faixa(arq: String, pontos: Array, largura: float) -> Line2D:
	var l := Line2D.new()
	l.texture = load(arq)
	l.texture_mode = Line2D.LINE_TEXTURE_TILE
	l.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	l.width = largura
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	for p: Vector2 in pontos:
		l.add_point(p)
	return l
