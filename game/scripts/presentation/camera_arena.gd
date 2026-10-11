class_name CameraArena
extends Camera2D
## Câmera da justa. Três planos (GDD, tabela de fases):
##   plano_aberto() - mostra a arena inteira (Apresentação, Largada)
##   seguir(alvo)   - acompanha um cavaleiro (Corrida)
##   focar(ponto)   - zoom num ponto do mundo (Mira, Impacto)
## A troca de plano é suave: posição e zoom se aproximam do destino com
## decaimento exponencial a cada quadro, o que também funciona quando o
## alvo está em movimento. Os limites da Camera2D seguram a imagem dentro
## do cenário em qualquer zoom.

signal plano_mudou(plano: Plano)

enum Plano { ABERTO, SEGUIR, FOCO }

## Centro do plano aberto, em coordenadas do mundo.
@export var centro_aberto := Vector2(480, 270)
@export var zoom_aberto := 1.0
@export var zoom_seguir := 2.0
@export var zoom_foco := 3.0
## Deslocamento a partir da origem (pés) do alvo seguido; x é multiplicado
## pela direção do cavaleiro, para a câmera olhar um pouco à frente.
@export var deslocamento_seguir := Vector2(70, -80)
## Rapidez da transição (por segundo). Maior = mais seco.
@export var rapidez := 5.0

var plano := Plano.ABERTO
var _alvo: Node2D
var _ponto := Vector2.ZERO
var _zoom_destino := 1.0

func _ready() -> void:
	position_smoothing_enabled = false
	plano_aberto(true)

func plano_aberto(imediato := false) -> void:
	_alvo = null
	_trocar(Plano.ABERTO, zoom_aberto, imediato)

func seguir(alvo: Node2D, imediato := false) -> void:
	_alvo = alvo
	_trocar(Plano.SEGUIR, zoom_seguir, imediato)

## `zoom` <= 0 usa `zoom_foco`.
func focar(ponto: Vector2, zoom_ponto := 0.0, imediato := false) -> void:
	_alvo = null
	_ponto = ponto
	_trocar(Plano.FOCO, zoom_ponto if zoom_ponto > 0.0 else zoom_foco, imediato)

## Posição que a câmera persegue no plano atual.
func destino() -> Vector2:
	match plano:
		Plano.SEGUIR:
			if is_instance_valid(_alvo):
				var d := deslocamento_seguir
				var dir: Variant = _alvo.get("direcao")
				if dir != null:
					d.x *= float(dir)
				return _alvo.global_position + d
			return centro_aberto
		Plano.FOCO:
			return _ponto
	return centro_aberto

func _process(delta: float) -> void:
	var k := 1.0 - exp(-rapidez * delta)
	global_position = global_position.lerp(destino(), k)
	zoom = zoom.lerp(Vector2.ONE * _zoom_destino, k)

func _trocar(novo: Plano, novo_zoom: float, imediato: bool) -> void:
	_zoom_destino = novo_zoom
	var mudou := novo != plano
	plano = novo
	if imediato:
		global_position = destino()
		zoom = Vector2.ONE * _zoom_destino
		reset_smoothing()
	if mudou:
		plano_mudou.emit(plano)
