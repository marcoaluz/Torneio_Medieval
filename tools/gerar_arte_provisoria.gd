extends SceneTree
## Gera a arte provisória do personagem em camadas (tons de cinza + máscaras
## + folhas de pontos), no mesmo formato que a arte do PixelLab deve seguir
## (ver docs/PERSONAGEM.md). Rode e depois extraia os pontos:
##   bash .claude/skills/run-torneio-medieval/driver.sh script res://tools/gerar_arte_provisoria.gd
##   bash .claude/skills/run-torneio-medieval/driver.sh script res://tools/extrair_pontos.gd
## Coordenadas das caixas: a partir da origem do quadro (chão), y negativo
## para cima, iguais às do cavaleiro.tscn e às zonas de mira.json.

const PASTA := "res://game/art/sprites/personagem"
const R := Color(1, 0, 0)
const G := Color(0, 1, 0)
const B := Color(0, 0, 1)
const PELAGENS := {"alazao": Color(0.55, 0.3, 0.17), "preto": Color(0.17, 0.15, 0.14), "branco": Color(0.8, 0.78, 0.74)}

var _arquivos := 0

func _initialize() -> void:
	_justa()
	_vila()
	_equipamentos()
	_conjunto_vigia()
	print("ARTE gerados %d arquivos em %s" % [_arquivos, PASTA])
	quit(0)

# ---------------------------------------------------------------- justa (160)

func _justa() -> void:
	var anims := {"parado": [0], "galope": [0, -2, -3, -1]}
	var o := Vector2i(80, 160)
	for anim: String in anims:
		var bobs: Array = anims[anim]
		for pelagem: String in PELAGENS:
			_folha("justa", "cavalo_%s_%s" % [pelagem, anim], Vector2i(160, 160), o, bobs, func(c: Desenho, i: int, dy: int):
				var cor: Color = PELAGENS[pelagem]
				var pernas := _pernas_cavalo(anim, i)
				for p: Vector3i in pernas:
					c.caixa_cor(p.x, -44 + dy, 8, 44 - dy - p.z, cor.darkened(0.15))
				c.caixa_cor(-60, -80 + dy, 10, 26, cor.darkened(0.35))
				c.caixa_cor(-50, -82 + dy, 100, 40, cor)
				c.caixa_cor(36, -108 + dy, 18, 34, cor)
				c.caixa_cor(42, -116 + dy, 32, 16, cor.darkened(0.08)), false)
		_folha("justa", "caparacao_provisorio_%s" % anim, Vector2i(160, 160), o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(-52, -84 + dy, 96, 26, 0.55, R)
			c.caixa(-52, -62 + dy, 96, 4, 0.6, G))
		for corpo: String in ["masculino", "feminino"]:
			var l := 12 if corpo == "masculino" else 10
			_folha("justa", "corpo_%s_%s" % [corpo, anim], Vector2i(160, 160), o, bobs, func(c: Desenho, _i: int, dy: int):
				c.caixa(-l, -128 + dy, l * 2, 44, 0.45)
				c.caixa(-3, -118 + dy, 8, 22, 0.4))
		_folha("justa", "pernas_provisorio_%s" % anim, Vector2i(160, 160), o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(-4, -90 + dy, 10, 30, 0.55))
		_folha("justa", "peitoral_provisorio_%s" % anim, Vector2i(160, 160), o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(-12, -128 + dy, 24, 40, 0.62)
			for k in 4:
				c.ponto(-8 + k * 5, -124 + dy, 0.3))
		_folha("justa", "sobreveste_provisorio_%s" % anim, Vector2i(160, 160), o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(-11, -112 + dy, 22, 24, 0.5, R)
			c.caixa(-2, -112 + dy, 4, 24, 0.55, G))
		_folha("justa", "elmo_provisorio_%s" % anim, Vector2i(160, 160), o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(-10, -150 + dy, 20, 22, 0.66)
			c.caixa(-2, -143 + dy, 12, 2, 0.08))
		_folha("justa", "cimeira_provisorio_%s" % anim, Vector2i(160, 160), o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(-3, -157 + dy, 6, 8, 0.6, R))
		_folha("justa", "escudo_provisorio_%s" % anim, Vector2i(160, 160), o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(6, -123 + dy, 16, 30, 0.6, B)
			c.caixa(7, -122 + dy, 14, 28, 0.5, R))
		_folha("justa", "lanca_provisorio_%s" % anim, Vector2i(320, 160), o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(8, -120 + dy, 120, 4, 0.6)
			c.caixa(4, -125 + dy, 5, 14, 0.6, B)
			c.caixa(128, -120 + dy, 5, 4, 0.7, B))
		# Pontos de encaixe: brasão no escudo (vermelho), na sobreveste (azul)
		# e na caparação (amarelo).
		_folha("justa", "pontos_%s" % anim, Vector2i(160, 160), o, bobs, func(c: Desenho, _i: int, dy: int):
			c.pixel_puro(14, -108 + dy, R)
			c.pixel_puro(0, -100 + dy, B)
			c.pixel_puro(-4, -71 + dy, Color(1, 1, 0)), false)

## Pernas do cavalo por quadro: (x, _, quanto a pata está levantada).
func _pernas_cavalo(anim: String, i: int) -> Array[Vector3i]:
	if anim != "galope":
		return [Vector3i(-44, 0, 0), Vector3i(-30, 0, 0), Vector3i(26, 0, 0), Vector3i(40, 0, 0)]
	var a := 5 if i % 2 == 0 else -5
	var lev_tras := 6 if i in [1, 2] else 0
	var lev_frente := 6 if i in [0, 3] else 0
	return [Vector3i(-44 + a, 0, lev_tras), Vector3i(-30 - a, 0, 0), Vector3i(26 - a, 0, lev_frente), Vector3i(40 + a, 0, 0)]

# ----------------------------------------------------------------- vila (96)

func _vila() -> void:
	var anims := {"parado": [0], "andar": [0, -1, 0, -1]}
	var o := Vector2i(48, 96)
	var t := Vector2i(96, 96)
	for anim: String in anims:
		var bobs: Array = anims[anim]
		for corpo: String in ["masculino", "feminino"]:
			var l := 9 if corpo == "masculino" else 8
			_folha("vila", "corpo_%s_%s" % [corpo, anim], t, o, bobs, func(c: Desenho, _i: int, dy: int):
				c.caixa(-l, -58 + dy, l * 2, 30, 0.45))
		_folha("vila", "pernas_provisorio_%s" % anim, t, o, bobs, func(c: Desenho, i: int, dy: int):
			var p := (2 if i % 2 == 1 else 0) if anim == "andar" else 0
			c.caixa(-7 + p, -30 + dy, 6, 30 - dy, 0.55)
			c.caixa(1 - p, -30 + dy, 6, 30 - dy, 0.5))
		_folha("vila", "peitoral_provisorio_%s" % anim, t, o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(-9, -58 + dy, 18, 24, 0.62))
		_folha("vila", "sobreveste_provisorio_%s" % anim, t, o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(-8, -46 + dy, 16, 18, 0.5, R)
			c.caixa(-1, -46 + dy, 3, 18, 0.55, G))
		_folha("vila", "elmo_provisorio_%s" % anim, t, o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(-7, -72 + dy, 14, 15, 0.66)
			c.caixa(-1, -67 + dy, 8, 2, 0.08))
		_folha("vila", "escudo_provisorio_%s" % anim, t, o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(6, -56 + dy, 11, 20, 0.6, B)
			c.caixa(7, -55 + dy, 9, 18, 0.5, R))

# --------------------------------------------------------- equipamentos (256)

func _equipamentos() -> void:
	var anims := {"parado": [0], "respirar": [0, -2]}
	var o := Vector2i(128, 256)
	var t := Vector2i(256, 256)
	for anim: String in anims:
		var bobs: Array = anims[anim]
		for corpo: String in ["masculino", "feminino"]:
			var l := 64 if corpo == "masculino" else 54
			_folha("equipamentos", "corpo_%s_%s" % [corpo, anim], t, o, bobs, func(c: Desenho, _i: int, dy: int):
				c.caixa(-l, -150 + dy, l * 2, 150, 0.45)
				c.caixa(-12, -162 + dy, 24, 14, 0.5))
		_folha("equipamentos", "rosto_1_%s" % anim, t, o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(-22, -212 + dy, 44, 54, 0.62)
			c.caixa(-12, -192 + dy, 6, 4, 0.15)
			c.caixa(6, -192 + dy, 6, 4, 0.15)
			c.caixa(-8, -172 + dy, 16, 3, 0.35))
		_folha("equipamentos", "cabelo_1_%s" % anim, t, o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(-24, -222 + dy, 48, 16, 0.5))
		_folha("equipamentos", "cabelo_2_%s" % anim, t, o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(-26, -222 + dy, 52, 14, 0.5)
			c.caixa(-28, -210 + dy, 8, 60, 0.45)
			c.caixa(20, -210 + dy, 8, 60, 0.45))
		_folha("equipamentos", "peitoral_provisorio_%s" % anim, t, o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(-58, -146 + dy, 116, 120, 0.62)
			for k in 6:
				c.caixa(-48 + k * 18, -140 + dy, 3, 3, 0.3))
		_folha("equipamentos", "sobreveste_provisorio_%s" % anim, t, o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(-50, -96 + dy, 100, 96, 0.5, R)
			c.caixa(-6, -96 + dy, 12, 96, 0.55, G))
		_folha("equipamentos", "elmo_provisorio_%s" % anim, t, o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(-28, -228, 56, 64, 0.66)
			c.caixa(-16, -198 + dy, 36, 5, 0.08))
		_folha("equipamentos", "escudo_provisorio_%s" % anim, t, o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(44, -126 + dy, 64, 96, 0.6, B)
			c.caixa(48, -122 + dy, 56, 88, 0.5, R))
		_folha("equipamentos", "pontos_%s" % anim, t, o, bobs, func(c: Desenho, _i: int, dy: int):
			c.pixel_puro(76, -82 + dy, R), false)

# ------------------------------------------- conjunto "vigia" (segundo estilo)

## Segundo conjunto provisório, com silhueta diferente, para a tela de
## Equipamentos mostrar a troca de peça (bacinete arredondado, brigantina
## rebitada, escudo maior e lança pintada).
func _conjunto_vigia() -> void:
	var o := Vector2i(80, 160)
	for anim: String in {"parado": [0], "galope": [0, -2, -3, -1]}:
		var bobs: Array = [0] if anim == "parado" else [0, -2, -3, -1]
		_folha("justa", "elmo_vigia_%s" % anim, Vector2i(160, 160), o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(-10, -153 + dy, 20, 25, 0.7)
			c.caixa(-8, -156 + dy, 16, 3, 0.75)
			c.caixa(-11, -132 + dy, 22, 6, 0.45)
			c.caixa(0, -144 + dy, 10, 2, 0.08))
		_folha("justa", "peitoral_vigia_%s" % anim, Vector2i(160, 160), o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(-13, -128 + dy, 26, 42, 0.5, R)
			for k in 3:
				for m in 4:
					c.ponto(-9 + m * 6, -124 + k * 9 + dy, 0.85))
		_folha("justa", "escudo_vigia_%s" % anim, Vector2i(160, 160), o, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(4, -126 + dy, 20, 34, 0.62, B)
			c.caixa(6, -124 + dy, 16, 30, 0.5, R))
		_folha("justa", "lanca_vigia_%s" % anim, Vector2i(320, 160), o, bobs, func(c: Desenho, _i: int, dy: int):
			for k in 12:
				c.caixa(8 + k * 10, -120 + dy, 10, 4, 0.55 if k % 2 == 0 else 0.7, R if k % 2 == 0 else G)
			c.caixa(2, -127 + dy, 7, 18, 0.65, B)
			c.caixa(128, -121 + dy, 6, 6, 0.75, B))
	for anim: String in ["parado", "andar"]:
		var bobs: Array = [0] if anim == "parado" else [0, -1, 0, -1]
		var t := Vector2i(96, 96)
		_folha("vila", "elmo_vigia_%s" % anim, t, Vector2i(48, 96), bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(-7, -74 + dy, 14, 17, 0.7))
		_folha("vila", "peitoral_vigia_%s" % anim, t, Vector2i(48, 96), bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(-10, -58 + dy, 20, 26, 0.5, R))
		_folha("vila", "escudo_vigia_%s" % anim, t, Vector2i(48, 96), bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(5, -58 + dy, 13, 23, 0.62, B)
			c.caixa(6, -57 + dy, 11, 21, 0.5, R))
	for anim: String in ["parado", "respirar"]:
		var bobs: Array = [0] if anim == "parado" else [0, -2]
		var t := Vector2i(256, 256)
		var oe := Vector2i(128, 256)
		_folha("equipamentos", "elmo_vigia_%s" % anim, t, oe, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(-28, -236 + dy, 56, 72, 0.7)
			c.caixa(-32, -170 + dy, 64, 14, 0.45)
			c.caixa(-4, -206 + dy, 26, 5, 0.08))
		_folha("equipamentos", "peitoral_vigia_%s" % anim, t, oe, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(-60, -148 + dy, 120, 124, 0.5, R)
			for k in 5:
				for m in 7:
					c.caixa(-48 + m * 16, -138 + k * 22 + dy, 3, 3, 0.85))
		_folha("equipamentos", "escudo_vigia_%s" % anim, t, oe, bobs, func(c: Desenho, _i: int, dy: int):
			c.caixa(38, -134 + dy, 76, 110, 0.62, B)
			c.caixa(44, -128 + dy, 64, 98, 0.5, R))

# --------------------------------------------------------------- utilidades

## Uma folha: `bobs.size()` quadros lado a lado. `desenhar(desenho, quadro, dy)`.
## Gera também a máscara, se alguma caixa pediu canal de cor.
func _folha(tamanho: String, nome: String, quadro: Vector2i, origem: Vector2i, bobs: Array, desenhar: Callable, cinza := true) -> void:
	var n := bobs.size()
	var img := Image.create_empty(quadro.x * n, quadro.y, false, Image.FORMAT_RGBA8)
	var masc := Image.create_empty(quadro.x * n, quadro.y, false, Image.FORMAT_RGBA8)
	var d := Desenho.new(img, masc, cinza)
	for i in n:
		d.base = Vector2i(quadro.x * i, 0) + origem
		desenhar.call(d, i, int(bobs[i]))
	DirAccess.make_dir_recursive_absolute("%s/%s" % [PASTA, tamanho])
	img.save_png("%s/%s/%s.png" % [PASTA, tamanho, nome])
	_arquivos += 1
	if d.usou_mascara:
		masc.save_png("%s/%s/%s_mascara.png" % [PASTA, tamanho, nome])
		_arquivos += 1
	# Armaduras ganham os três estágios de dano (d1 riscada, d2 amassada,
	# d3 rachada), mesmo quadro e posição: <camada>_<variante>_dN_<anim>.
	for prefixo in ["elmo_", "peitoral_", "escudo_"]:
		if nome.begins_with(prefixo):
			var anim := nome.get_slice("_", nome.get_slice_count("_") - 1)
			var base := nome.trim_suffix("_" + anim)
			for estagio in [1, 2, 3]:
				var dano := _danificar(img, estagio, quadro.x)
				dano.save_png("%s/%s/%s_d%d_%s.png" % [PASTA, tamanho, base, estagio, anim])
				_arquivos += 1
				if d.usou_mascara:
					masc.save_png("%s/%s/%s_d%d_%s_mascara.png" % [PASTA, tamanho, base, estagio, anim])
					_arquivos += 1

## Cópia da folha com marcas de dano determinísticas sobre os pixels opacos.
func _danificar(img: Image, estagio: int, largura_quadro: int) -> Image:
	var out := img.duplicate() as Image
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var h := hash(Vector2i(x % largura_quadro, y))
			if estagio >= 1 and h % 19 == 0:
				out.set_pixel(x, y, c.lightened(0.35))
			if estagio >= 2 and h % 9 == 0:
				out.set_pixel(x, y, c.darkened(0.45))
			if estagio >= 3:
				# Rachadura em zigue-zague e lascas faltando.
				var xq := x % largura_quadro
				var zigue := (y / 3) % 3 - 1
				if xq == largura_quadro * 42 / 100 + zigue or xq == largura_quadro * 57 / 100 - zigue:
					out.set_pixel(x, y, Color(0.05, 0.05, 0.05, 1))
				elif h % 29 == 0:
					out.set_pixel(x, y, Color(0, 0, 0, 0))
	return out

class Desenho:
	var img: Image
	var masc: Image
	var base := Vector2i.ZERO
	var usou_mascara := false
	var cinza := true

	func _init(i: Image, m: Image, c: bool) -> void:
		img = i
		masc = m
		cinza = c

	## Caixa em tons de cinza com brilho em cima e sombra embaixo/direita.
	## `canal` (R/G/B) marca a máscara de cor da casa nessa área.
	func caixa(x: int, y: int, w: int, h: int, valor: float, canal := Color.TRANSPARENT) -> void:
		caixa_cor(x, y, w, h, Color(valor, valor, valor), canal)

	func caixa_cor(x: int, y: int, w: int, h: int, cor: Color, canal := Color.TRANSPARENT) -> void:
		for yy in range(y, y + h):
			for xx in range(x, x + w):
				var c := cor
				if yy == y:
					c = cor.lightened(0.3)
				elif yy == y + h - 1 or xx == x + w - 1:
					c = cor.darkened(0.35)
				_pintar(xx, yy, c, canal)

	func ponto(x: int, y: int, valor: float) -> void:
		_pintar(x, y, Color(valor, valor, valor), Color.TRANSPARENT)

	## Pixel com a cor exata (folha de pontos).
	func pixel_puro(x: int, y: int, cor: Color) -> void:
		var p := base + Vector2i(x, y)
		if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
			img.set_pixelv(p, cor)

	func _pintar(x: int, y: int, c: Color, canal: Color) -> void:
		var p := base + Vector2i(x, y)
		if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height():
			return
		img.set_pixelv(p, c)
		if canal.a > 0.0:
			masc.set_pixelv(p, Color(canal.r, canal.g, canal.b, 1.0))
			usou_mascara = true
		else:
			masc.set_pixelv(p, Color(0, 0, 0, 1))
