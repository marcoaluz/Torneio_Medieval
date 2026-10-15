class_name MiraVisual
extends Node2D
## Mira visível na Mira (só apresentação), presa à ponta da lança (nó
## PontaLanca da arena): um anel em quatro arcos com marcas de cruz e um ponto
## no centro, em traço de 1 px do mundo (a câmera fechada da Mira deixa o
## traço grosso e nítido). A cor diz a zona sob a ponta — a mesma que o
## cavaleiro rival realça — e o anel aperta enquanto o dedo segura; ao soltar,
## trava (fica pequeno e acende) até o choque.

const RAIO := 9.0
const RAIO_SEGURANDO := 6.5
const RAIO_TRAVADO := 4.5
const GIRO_POR_S := 0.9
const PULSO_HZ := 2.2
## Cor por zona (a do brilho no rival; vazio = fora do alvo).
const CORES := {
	"capacete": Color(1.0, 0.82, 0.3),
	"peito": Color(0.62, 1.0, 0.5),
	"escudo": Color(0.75, 0.88, 1.0),
	"cavalo": Color(1.0, 0.35, 0.3),
	"": Color(0.92, 0.9, 0.85),
}

var zona := ""
var segurando := false
var travado := false
var _raio := RAIO
var _giro := 0.0
var _t := 0.0

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_giro = fmod(_giro + GIRO_POR_S * delta * (0.3 if travado else 1.0), TAU)
	var alvo := RAIO_TRAVADO if travado else (RAIO_SEGURANDO if segurando else RAIO)
	_raio = lerpf(_raio, alvo, 1.0 - exp(-14.0 * delta))
	queue_redraw()

## Volta ao começo da Mira (anel aberto, solto).
func reiniciar() -> void:
	zona = ""
	segurando = false
	travado = false
	_raio = RAIO
	_t = 0.0

func cor() -> Color:
	return CORES.get(zona, CORES[""])

func raio() -> float:
	return _raio

func _draw() -> void:
	var c := cor()
	var pulso := 0.5 + 0.5 * sin(_t * TAU * PULSO_HZ)
	var r := _raio + (0.0 if travado else pulso * 0.8)
	var sombra := Color(0.05, 0.03, 0.02, 0.85)
	# Contorno escuro por baixo: a mira lê sobre armadura clara ou escura.
	for desloc: Vector2 in [Vector2(1, 0), Vector2(0, 1)]:
		_anel(desloc, r, sombra)
	_anel(Vector2.ZERO, r, c)
	draw_rect(Rect2(-1, -1, 2, 2), sombra)
	draw_rect(Rect2(-0.5, -0.5, 1, 1), c.lightened(0.3) if travado else c)

## Quatro arcos com vão entre eles e uma marca para dentro em cada vão.
func _anel(desloc: Vector2, r: float, cor_traco: Color) -> void:
	for i in 4:
		var a0 := _giro + i * PI * 0.5 + 0.28
		draw_arc(desloc, r, a0, a0 + PI * 0.5 - 0.56, 8, cor_traco, 1.0, false)
		var a := _giro + i * PI * 0.5
		var dir := Vector2(cos(a), sin(a))
		draw_line(desloc + dir * (r + 1.5), desloc + dir * (r - 2.5), cor_traco, 1.0, false)
