class_name ChaoVila
extends Node2D
## Chão da vila com arte gerada no PixelLab (game/art/sprites/vila/chao/): grama
## repetida, trilhas de terra da praça até a frente de cada prédio, a praça
## calçada com o poço, a muralha baixa de pedra e as árvores. Mesmo traçado do
## ChaoVilaProvisorio; sem a arte, `montar` devolve false e o provisório fica.
##
## Chão contínuo (feito por código, sem arte nova): sob cada prédio um terreiro
## de terra batida bem maior que a base desenhada, que cobre a borda da base
## (sem ilha flutuante) e se funde na grama por um anel mais claro e
## transparente; os terreiros se ligam por caminhos de terra a vizinhos (anel
## em volta da praça) e a praça ganha uma roda de terra por fora. Árvores
## espalhadas por sorteio fixo, longe de prédio e de caminho. Os números estão
## em ambiente.json > chao.

const PASTA := "res://game/art/sprites/vila/chao/"
const PRACA := Vector2(480, 300)
const MURO := Rect2(20, 40, 920, 490)
const ARVORES := [Vector2(70, 120), Vector2(890, 120), Vector2(80, 480), Vector2(915, 505), Vector2(-60, 300), Vector2(1020, 300)]

var cfg := {}
## Pontos já ocupados (terreiros e caminhos), para as árvores desviarem.
var _livre_de: Array = []  ## [{centro, raio}]
var _segmentos: Array = []  ## [[a, b]]

## `destinos`: a frente de cada prédio (onde a trilha chega). `predios`:
## [{pos, tam}] de cada prédio, para o terreiro e os caminhos entre eles.
func montar(destinos: Array, predios := [], chao := {}) -> bool:
	if not ResourceLoader.exists(PASTA + "grama.png"):
		return false
	cfg = chao
	var grama := Sprite2D.new()
	grama.texture = load(PASTA + "grama.png")
	grama.centered = false
	grama.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	grama.region_enabled = true
	grama.region_rect = Rect2(0, 0, 1280, 540)
	grama.position = Vector2(-160, 0)
	grama.modulate = Color(0.82, 0.86, 0.8)  # grama mais calma: os prédios e o povo saltam à vista
	add_child(grama)
	if not cfg.is_empty() and not predios.is_empty():
		_terreiros(predios)
	var larg := float(cfg.get("largura_trilha", 20.0))
	for d: Vector2 in destinos:
		add_child(_faixa(PASTA + "trilha.png", [PRACA, d], larg))
		_segmentos.append([PRACA, d])
	if not cfg.is_empty() and not predios.is_empty():
		_caminhos_entre(predios, larg)
	var muro := _faixa(PASTA + "muro.png", [MURO.position, Vector2(MURO.end.x, MURO.position.y), MURO.end,
		Vector2(MURO.position.x, MURO.end.y)], 12.0)
	muro.closed = true
	add_child(muro)
	var praca := Sprite2D.new()
	praca.texture = load(PASTA + "praca.png")
	praca.position = PRACA
	add_child(praca)
	for t: Vector2 in ARVORES:
		_arvore(t)
	if not cfg.is_empty():
		_arvores_extras()
	return true

func _arvore(t: Vector2) -> void:
	var a := Sprite2D.new()
	a.texture = load(PASTA + "arvore.png")
	a.position = t
	add_child(a)

## Terreiro de cada prédio: elipse de terra batida com textura de ruído, um
## anel mais claro e transparente por fora (a terra some na grama) e, no
## centro, a roda da praça.
func _terreiros(predios: Array) -> void:
	var tex := _textura_terra()
	var cor := Color(str(cfg["cor_terra"]))
	var borda := Color(str(cfg["cor_borda"]))
	var raios := [Vector2(2.1, 1.35), Vector2(1.7, 1.1)]  # externo (suave) e interno, x tamanho / 2
	for pr: Dictionary in predios:
		var pos: Vector2 = pr["pos"]
		var tam: Vector2 = pr["tam"] * float(cfg["escala_terreiro"])
		var centro := pos + Vector2(0, float(cfg["desloca_y"]))
		add_child(_elipse(centro, tam * Vector2(raios[0].x, raios[0].y) * 0.5, Color(borda.r, borda.g, borda.b, 0.45), null))
		add_child(_elipse(centro, tam * Vector2(raios[1].x, raios[1].y) * 0.5, cor, tex))
		_livre_de.append({"centro": centro, "raio": tam.x * 0.62})
	add_child(_elipse(PRACA, Vector2(104, 78), Color(borda.r, borda.g, borda.b, 0.45), null))
	add_child(_elipse(PRACA, Vector2(86, 64), cor, tex))
	_livre_de.append({"centro": PRACA, "raio": 100.0})

func _elipse(centro: Vector2, raio: Vector2, cor: Color, tex: Texture2D) -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(centro.x * 31.0 + centro.y * 17.0)
	for i in 28:
		var a := TAU * float(i) / 28.0
		var irregular := 1.0 + rng.randf_range(-0.07, 0.07)  # borda irregular, nada de elipse perfeita
		pts.append(centro + Vector2(cos(a) * raio.x, sin(a) * raio.y) * irregular)
	p.polygon = pts
	p.color = cor
	if tex:
		p.texture = tex
		p.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		p.texture_scale = Vector2.ONE
	return p

## Ruído de terra: tons da cor da terra espalhados, 64×64 repetido.
func _textura_terra() -> ImageTexture:
	var base := Color(str(cfg["cor_terra"]))
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for y in 64:
		for x in 64:
			var v := rng.randf_range(-0.08, 0.08)
			if rng.randf() < 0.05:
				v -= 0.12  # pedrinha escura
			img.set_pixel(x, y, Color(clampf(base.r + v, 0, 1), clampf(base.g + v, 0, 1), clampf(base.b + v * 0.8, 0, 1), 1.0))
	return ImageTexture.create_from_image(img)

## Caminhos de terra entre prédios vizinhos (pares em ambiente.json > chao >
## caminhos, por nome), com uma leve curva no meio.
func _caminhos_entre(predios: Array, larg: float) -> void:
	var por_nome := {}
	for pr: Dictionary in predios:
		por_nome[pr["nome"]] = pr["pos"] + Vector2(0, float(pr["tam"].y) * 0.45)
	for par: Array in cfg.get("caminhos", []):
		if not por_nome.has(par[0]) or not por_nome.has(par[1]):
			continue
		var a: Vector2 = por_nome[par[0]]
		var b: Vector2 = por_nome[par[1]]
		var meio := (a + b) * 0.5 + Vector2(0, float(cfg.get("curva_px", 14.0)))
		add_child(_faixa(PASTA + "trilha.png", _curva(a, meio, b), larg * 0.8))
		_segmentos.append([a, b])

func _curva(a: Vector2, m: Vector2, b: Vector2) -> Array:
	var pts := []
	for i in 9:
		var t := float(i) / 8.0
		pts.append(a.lerp(m, t).lerp(m.lerp(b, t), t))
	return pts

## Mais árvores por sorteio fixo, só onde não há prédio nem caminho.
func _arvores_extras() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.get("semente_arvores", 77))
	var limite: Rect2 = Rect2(Vector2(float(cfg["area"][0]), float(cfg["area"][1])), Vector2(float(cfg["area"][2]), float(cfg["area"][3])))
	var postas: Array = []
	var tentativas := 0
	while postas.size() < int(cfg["arvores_extras"]) and tentativas < 800:
		tentativas += 1
		var p := Vector2(rng.randf_range(limite.position.x, limite.end.x), rng.randf_range(limite.position.y, limite.end.y))
		if _ocupado(p) or postas.any(func(q): return q.distance_to(p) < float(cfg["arvore_distancia"])):
			continue
		postas.append(p)
	postas.sort_custom(func(a, b): return a.y < b.y)  # as de trás primeiro
	for p: Vector2 in postas:
		_arvore(p)

func _ocupado(p: Vector2) -> bool:
	for o: Dictionary in _livre_de:
		if p.distance_to(o["centro"]) < float(o["raio"]) + float(cfg["arvore_folga"]):
			return true
	for s: Array in _segmentos:
		var q := Geometry2D.get_closest_point_to_segment(p, s[0], s[1])
		if p.distance_to(q) < float(cfg["arvore_folga"]) + 12.0:
			return true
	return false

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
