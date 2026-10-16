class_name CameraArena
extends Camera2D
## Câmera da justa. Três planos (GDD, tabela de fases):
##   plano_aberto(centro, zoom) - plano largo; sem argumentos, o padrão
##                    (centro_aberto/zoom_aberto). A justa usa um plano aberto
##                    já próximo, num lado da pista (Apresentação, Largada,
##                    Fim); a exibição usa a arena inteira (zoom 1)
##   seguir(alvo)   - acompanha um cavaleiro
##   duelo(alvo, rival) - acompanha o jogador e, com o rival chegando,
##                    enquadra os dois sem corte, fechando conforme se
##                    aproximam (Corrida e Mira; o corte é só no acerto)
##   focar(ponto)   - zoom num ponto fixo do mundo (Impacto)
##   focar_alvo(no) - zoom num nó que se move (Mira: o peito do rival)
##   impacto(ponto) - corte seco para um close inclinado (ângulo holandês) no
##                    choque, um pouco mais fechado ("soco"), que depois abre
##                    devagar até o zoom pedido
##   deslizar(ponto, zoom, graus) - sem corte, leva o foco a outro ponto,
##                    zoom e inclinação (o Impacto abre do contato para os dois)
##   ajustar_zoom(z) - muda só o zoom de destino (aproximação lenta na Mira)
## A inclinação volta a zero em qualquer outro plano. Com a imagem inclinada,
## a posição é presa de modo que os cantos girados também fiquem no cenário.
## A troca de plano é suave: posição e zoom se aproximam do destino com
## decaimento exponencial a cada quadro, o que também funciona quando o
## alvo está em movimento. Os limites da Camera2D seguram a imagem dentro
## do cenário em qualquer zoom.

signal plano_mudou(plano: Plano)

enum Plano { ABERTO, SEGUIR, FOCO }

## Centro do plano aberto, em coordenadas do mundo.
@export var centro_aberto := Vector2(480, 270)
@export var zoom_aberto := 1.5
@export var zoom_seguir := 2.4
@export var zoom_foco := 2.8
## Deslocamento a partir da origem (pés) do alvo seguido; x é multiplicado
## pela direção do cavaleiro, para a câmera olhar um pouco à frente.
@export var deslocamento_seguir := Vector2(70, -80)
## Duelo: zoom mínimo ao enquadrar os dois, folga (px) além de cada um, e por
## quantos px antes de caberem os dois a câmera começa a abrir para o rival.
@export var zoom_duelo_min := 1.3
@export var folga_duelo := 90.0
@export var entrada_duelo := 320.0
## Rapidez da transição (por segundo). Maior = mais seco.
@export var rapidez := 5.0
## Impacto: inclinação da imagem (graus) e quanto o corte entra mais fechado
## que o zoom final (1.2 = 20% mais perto, abrindo depois).
@export var inclinacao_impacto := -6.0
@export var soco_impacto := 1.06
## Tremor (trauma): deslocamento e giro máximos com trauma 1, e quanto o
## trauma cai por segundo. O deslocamento é trauma² (tremor fraco fica sutil).
@export var tremor_max_px := Vector2(14, 10)
@export var tremor_max_graus := 2.0
@export var tremor_queda := 1.8

var plano := Plano.ABERTO
var _centro := Vector2(480, 270)
var _alvo: Node2D
var _rival: Node2D  ## duelo: o outro cavaleiro (null fora do duelo)
var _ponto := Vector2.ZERO
var _zoom_destino := 1.0
## Inclinação de base (radianos); o tremor soma por cima.
var inclinacao := 0.0
var _inclinacao_destino := 0.0
var trauma := 0.0
var _ruido := FastNoiseLite.new()
var _tempo_ruido := 0.0

func _ready() -> void:
	position_smoothing_enabled = false
	ignore_rotation = false
	_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX
	plano_aberto(true)

## Tremor de câmera: soma trauma (0 a 1, acumula até 1).
func tremer(quanto: float) -> void:
	trauma = minf(trauma + maxf(quanto, 0.0), 1.0)

## `centro` = Vector2.INF usa `centro_aberto`; `zoom_plano` <= 0 usa `zoom_aberto`.
func plano_aberto(imediato := false, centro := Vector2.INF, zoom_plano := 0.0) -> void:
	_alvo = null
	_rival = null
	_inclinacao_destino = 0.0
	_centro = centro_aberto if centro == Vector2.INF else centro
	_trocar(Plano.ABERTO, zoom_plano if zoom_plano > 0.0 else zoom_aberto, imediato)

func seguir(alvo: Node2D, imediato := false) -> void:
	_alvo = alvo
	_rival = null
	_inclinacao_destino = 0.0
	_trocar(Plano.SEGUIR, zoom_seguir, imediato)

func duelo(alvo: Node2D, rival: Node2D, imediato := false) -> void:
	_alvo = alvo
	_rival = rival
	_inclinacao_destino = 0.0
	_trocar(Plano.SEGUIR, zoom_do_duelo(), imediato)

## Vão (px) entre os dois no duelo.
func _vao_duelo() -> float:
	return absf(_rival.global_position.x - _alvo.global_position.x)

## 0 = só o jogador (rival longe), 1 = os dois enquadrados.
func peso_duelo() -> float:
	if not (is_instance_valid(_alvo) and is_instance_valid(_rival)):
		return 0.0
	var cabe := get_viewport_rect().size.x / zoom_duelo_min - 2.0 * folga_duelo
	var t := clampf((cabe + entrada_duelo - _vao_duelo()) / entrada_duelo, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

## Zoom do duelo: o de seguir com o rival longe; o que cabe os dois (entre
## zoom_duelo_min e zoom_seguir) quando ele chega.
func zoom_do_duelo() -> float:
	if not (is_instance_valid(_alvo) and is_instance_valid(_rival)):
		return zoom_seguir
	var cabe := get_viewport_rect().size.x / (_vao_duelo() + 2.0 * folga_duelo)
	return lerpf(zoom_seguir, clampf(cabe, zoom_duelo_min, zoom_seguir), peso_duelo())

## `zoom` <= 0 usa `zoom_foco`.
func focar(ponto: Vector2, zoom_ponto := 0.0, imediato := false) -> void:
	_alvo = null
	_rival = null
	_ponto = ponto
	_inclinacao_destino = 0.0
	_trocar(Plano.FOCO, zoom_ponto if zoom_ponto > 0.0 else zoom_foco, imediato)

## Zoom que acompanha um nó em movimento. `zoom` <= 0 usa `zoom_foco`.
func focar_alvo(no: Node2D, zoom_ponto := 0.0, imediato := false) -> void:
	_alvo = no
	_rival = null
	_ponto = no.global_position
	_inclinacao_destino = 0.0
	_trocar(Plano.FOCO, zoom_ponto if zoom_ponto > 0.0 else zoom_foco, imediato)

## Choque: corte seco para o ponto, inclinado e mais fechado, abrindo devagar
## até `zoom_ponto`. `graus` = 0 usa `inclinacao_impacto`.
func impacto(ponto: Vector2, zoom_ponto: float, graus := 0.0) -> void:
	_alvo = null
	_rival = null
	_ponto = ponto
	_inclinacao_destino = deg_to_rad(graus if graus != 0.0 else inclinacao_impacto)
	_trocar(Plano.FOCO, zoom_ponto, true)
	inclinacao = _inclinacao_destino
	zoom = Vector2.ONE * zoom_ponto * soco_impacto
	global_position = _preso(destino())
	_aplicar_tremor(0.0)

## Sem corte: o foco vai deslizando até outro ponto, zoom e inclinação.
func deslizar(ponto: Vector2, novo_zoom: float, graus: float) -> void:
	_alvo = null
	_rival = null
	_ponto = ponto
	_zoom_destino = novo_zoom
	_inclinacao_destino = deg_to_rad(graus)

## Só o zoom de destino, sem trocar de plano (a Mira aproxima aos poucos).
func ajustar_zoom(novo_zoom: float) -> void:
	_zoom_destino = novo_zoom

## Posição que a câmera persegue no plano atual.
func destino() -> Vector2:
	match plano:
		Plano.SEGUIR:
			if is_instance_valid(_alvo):
				var d := deslocamento_seguir
				var dir: Variant = _alvo.get("direcao")
				if dir != null:
					d.x *= float(dir)
				var p := _alvo.global_position + d
				if is_instance_valid(_rival):
					var meio := Vector2((_alvo.global_position.x + _rival.global_position.x) * 0.5, p.y)
					return p.lerp(meio, peso_duelo())
				return p
			return _centro
		Plano.FOCO:
			if is_instance_valid(_alvo):
				return _alvo.global_position
			return _ponto
	return _centro

func _process(delta: float) -> void:
	if plano == Plano.SEGUIR and is_instance_valid(_rival):
		_zoom_destino = zoom_do_duelo()
	var k := 1.0 - exp(-rapidez * delta)
	zoom = zoom.lerp(Vector2.ONE * _zoom_destino, k)
	inclinacao = lerpf(inclinacao, _inclinacao_destino, k)
	global_position = _preso(global_position.lerp(destino(), k))
	_aplicar_tremor(delta)

## Com a imagem inclinada, os cantos girados saem do retângulo da câmera: prende
## o centro para a caixa girada caber nos limites do cenário. Sem inclinação, os
## limites da própria Camera2D bastam.
func _preso(p: Vector2) -> Vector2:
	if absf(inclinacao) < 0.001:
		return p
	var meia := get_viewport_rect().size / zoom * 0.5
	var c := absf(cos(inclinacao))
	var s := absf(sin(inclinacao))
	var caixa := Vector2(meia.x * c + meia.y * s, meia.x * s + meia.y * c)
	var x_min := float(limit_left) + caixa.x
	var x_max := float(limit_right) - caixa.x
	var y_min := float(limit_top) + caixa.y
	var y_max := float(limit_bottom) - caixa.y
	return Vector2(clampf(p.x, x_min, x_max) if x_min <= x_max else (x_min + x_max) * 0.5,
		clampf(p.y, y_min, y_max) if y_min <= y_max else (y_min + y_max) * 0.5)

func _aplicar_tremor(delta: float) -> void:
	if trauma <= 0.0:
		offset = Vector2.ZERO
		rotation = inclinacao
		return
	trauma = maxf(trauma - tremor_queda * delta, 0.0)
	_tempo_ruido += delta * 60.0
	var forca := trauma * trauma
	offset = Vector2(tremor_max_px.x * _ruido.get_noise_2d(_tempo_ruido, 0.0),
		tremor_max_px.y * _ruido.get_noise_2d(0.0, _tempo_ruido)) * forca
	rotation = inclinacao + deg_to_rad(tremor_max_graus) * forca * _ruido.get_noise_2d(_tempo_ruido, _tempo_ruido)

func _trocar(novo: Plano, novo_zoom: float, imediato: bool) -> void:
	_zoom_destino = novo_zoom
	var mudou := novo != plano
	plano = novo
	if imediato:
		zoom = Vector2.ONE * _zoom_destino
		inclinacao = _inclinacao_destino
		global_position = _preso(destino())
		reset_smoothing()
	if mudou:
		plano_mudou.emit(plano)
