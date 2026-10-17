class_name Bandeirolas
extends Node2D
## Fios de bandeirolas entre os prédios da vila, nas cores vivas da arena da
## justa (game/data/vila/ambiente.json > bandeirolas). Cada fio é uma curva
## (catenária simples) com bandeiras triangulares que balançam de leve. Só
## apresentação, sem toque.

var _cfg: Dictionary
var _t := 0.0

func configurar(cfg: Dictionary) -> void:
	_cfg = cfg
	z_index = 20
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

## Ponto do fio `a`→`b` na fração `k` (0 a 1): reta com a flecha no meio.
static func ponto_do_fio(a: Vector2, b: Vector2, k: float, flecha: float) -> Vector2:
	return a.lerp(b, k) + Vector2(0.0, flecha * 4.0 * k * (1.0 - k))

func _draw() -> void:
	if _cfg.is_empty():
		return
	var cores: Array = _cfg["cores"]
	var flecha := float(_cfg["flecha"])
	var lado := float(_cfg["lado"])
	var fios: Array = _cfg["fios"]
	var cor_fio := Color(0.16, 0.1, 0.07)
	for i in fios.size():
		var f: Array = fios[i]
		var a := Vector2(float(f[0]), float(f[1]))
		var b := Vector2(float(f[2]), float(f[3]))
		var pts := PackedVector2Array()
		for s in 25:
			pts.append(ponto_do_fio(a, b, s / 24.0, flecha))
		draw_polyline(pts, cor_fio, 1.5)
		var n := maxi(int(a.distance_to(b) / float(_cfg["espaco"])), 2)
		for k in range(1, n):
			var u := float(k) / n
			var p := ponto_do_fio(a, b, u, flecha)
			var balanco := sin(_t * 2.0 + float(i) * 1.7 + u * 9.0) * 1.6
			var cor := Color(str(cores[(k + i) % cores.size()]))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-lado * 0.5, 0), p + Vector2(lado * 0.5, 0),
				p + Vector2(balanco, lado * 1.15)]), cor)
			draw_polyline(PackedVector2Array([p + Vector2(-lado * 0.5, 0), p + Vector2(balanco, lado * 1.15), p + Vector2(lado * 0.5, 0)]),
				cor.darkened(0.35), 1.0)
