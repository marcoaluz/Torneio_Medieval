class_name GeradorBrasao
extends RefCounted
## Desenha o brasão pixel a pixel a partir das escolhas do editor e das
## opções de game/data/crests/brasao.json: forma do escudo, divisão do campo
## (duas cores), símbolo na posição escolhida e contorno escuro. Gera no
## tamanho exato de cada uso (escudo da justa, sobreveste, caparação,
## bandeira, editor), porque reduzir pixel art borra.
##
## brasao = {forma, divisao, cor1, cor2, simbolo, posicao, cor_simbolo}

const DADOS := "res://game/data/crests/brasao.json"
const PALETAS := "res://game/data/personagem/paletas.json"

static var _cfg: Dictionary
static var _paleta: Dictionary
static var _cache := {}

## Tintura heráldica de uma cor da casa: "metal", "cor" ou "" (fora das listas).
static func tintura(cor: String) -> String:
	var t: Dictionary = Balanceamento.ler_json(PALETAS)["tinturas"]
	if (t["metais"] as Array).has(cor):
		return "metal"
	return "cor" if (t["cores"] as Array).has(cor) else ""

## Sorteia `n` cores (até 3) que respeitam a regra das tinturas: a 1ª e a 2ª
## de tinturas diferentes (uma ao lado da outra), a 3ª (o símbolo, sobre a
## 1ª) da tintura oposta à 1ª e diferente da 2ª. Só usa cores de `permitidas`.
static func sortear_cores(rng: RandomNumberGenerator, permitidas: Array, n := 2) -> Array[String]:
	var t: Dictionary = Balanceamento.ler_json(PALETAS)["tinturas"]
	var metais: Array = (t["metais"] as Array).filter(func(c): return permitidas.has(c))
	var cores: Array = (t["cores"] as Array).filter(func(c): return permitidas.has(c))
	var r: Array[String] = []
	if metais.is_empty() or cores.is_empty():
		return r
	var primeiro_cor := rng.randf() < 0.75  # o campo escuro com detalhe em metal é o mais comum (e o mais legível)
	var a: Array = cores if primeiro_cor else metais
	var b: Array = metais if primeiro_cor else cores
	r.append(a[rng.randi() % a.size()])
	r.append(b[rng.randi() % b.size()])
	if n >= 3:
		var opcoes_simbolo := b.filter(func(c): return c != r[1])
		if opcoes_simbolo.is_empty():
			opcoes_simbolo = b
		r.append(opcoes_simbolo[rng.randi() % opcoes_simbolo.size()])
	return r

static func opcoes() -> Dictionary:
	if _cfg.is_empty():
		_cfg = _ler(DADOS)
		_paleta = _ler(CamadasPersonagem.PALETAS)["cores_casa"]
	return _cfg

## Brasão completo: chaves que faltarem vêm do padrão.
static func completar(brasao: Dictionary) -> Dictionary:
	var b: Dictionary = (opcoes()["padrao"] as Dictionary).duplicate()
	b.merge(brasao, true)
	return b

static func textura(brasao: Dictionary, tamanho: Vector2i, contorno := true) -> ImageTexture:
	var b := completar(brasao)
	var chave := "%s|%s|%s" % [JSON.stringify(b, "", true), tamanho, contorno]
	if not _cache.has(chave):
		_cache[chave] = ImageTexture.create_from_image(imagem(b, tamanho, contorno))
	return _cache[chave]

static func imagem(brasao: Dictionary, tamanho: Vector2i, contorno := true) -> Image:
	var cfg := opcoes()
	var b := completar(brasao)
	var w := tamanho.x
	var h := tamanho.y
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var forma: Array = cfg["formas"].get(b["forma"], cfg["formas"]["classico"])
	var simbolo: Array = cfg["simbolos"].get(b["simbolo"], [])
	var pos: Dictionary = cfg["posicoes"].get(b["posicao"], cfg["posicoes"]["centro"])
	var c1 := _cor(b["cor1"])
	var c2 := _cor(b["cor2"])
	var cs := _cor(b["cor_simbolo"])
	var dentro := []
	dentro.resize(w * h)
	for y in h:
		for x in w:
			var u := (x + 0.5) / w
			var v := (y + 0.5) / h
			var esta := _contem(forma, Vector2(u, v))
			dentro[y * w + x] = esta
			if not esta:
				continue
			var cor := c1 if _campo(b["divisao"], u, v) else c2
			if not simbolo.is_empty():
				var t := float(pos["tamanho"])
				# Caixa do símbolo quadrada em pixels: o eixo y usa a proporção do escudo.
				var su := (u - float(pos["x"])) / t + 0.5
				var sv := (v - float(pos["y"])) / (t * float(w) / float(h)) + 0.5
				if su >= 0.0 and su <= 1.0 and sv >= 0.0 and sv <= 1.0 and _contem(simbolo, Vector2(su, sv)):
					cor = cs
			img.set_pixel(x, y, cor)
	if contorno:
		var cc := Color(cfg["cor_contorno"])
		for y in h:
			for x in w:
				if dentro[y * w + x] and _na_borda(dentro, x, y, w, h):
					img.set_pixel(x, y, cc)
	return img

## true = cor 1, false = cor 2.
static func _campo(divisao: String, u: float, v: float) -> bool:
	match divisao:
		"partido": return u < 0.5
		"cortado": return v < 0.5
		"esquartelado": return (u < 0.5) == (v < 0.5)
		"bandado": return v < u
	return true

static func _na_borda(dentro: Array, x: int, y: int, w: int, h: int) -> bool:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := Vector2i(x, y) + d
		if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or not dentro[n.y * w + n.x]:
			return true
	return false

## Ponto dentro da união das primitivas (menos os furos).
static func _contem(primitivas: Array, p: Vector2) -> bool:
	var dentro := false
	for prim: Dictionary in primitivas:
		var ok := false
		if prim.has("poligono"):
			var pts := PackedVector2Array()
			for q: Array in prim["poligono"]:
				pts.append(Vector2(float(q[0]), float(q[1])))
			ok = Geometry2D.is_point_in_polygon(p, pts)
		elif prim.has("circulo"):
			var c: Array = prim["circulo"]
			ok = p.distance_to(Vector2(float(c[0]), float(c[1]))) <= float(c[2])
		elif prim.has("arquivo"):
			ok = _contem_png(prim["arquivo"], p)
		if ok:
			# Na ordem da lista: primitiva normal acende, furo apaga.
			dentro = not prim.get("furo", false)
	return dentro

static func _contem_png(arquivo: String, p: Vector2) -> bool:
	var caminho := "res://game/data/crests/simbolos/" + arquivo
	if not _cache.has(caminho):
		_cache[caminho] = Image.load_from_file(ProjectSettings.globalize_path(caminho)) if FileAccess.file_exists(caminho) else null
	var img: Image = _cache[caminho]
	if img == null:
		return false
	var x := clampi(int(p.x * img.get_width()), 0, img.get_width() - 1)
	var y := clampi(int(p.y * img.get_height()), 0, img.get_height() - 1)
	return img.get_pixel(x, y).a > 0.5

static func _cor(nome: String) -> Color:
	opcoes()
	return Color(_paleta.get(nome, "ff00ff"))

static func _ler(caminho: String) -> Dictionary:
	return Balanceamento.ler_json(caminho)
