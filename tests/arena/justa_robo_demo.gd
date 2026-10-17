extends Node
## Demonstração para o `driver.sh shot`: a arena com um jogador-robô que larga
## logo depois da bandeira e toca no compasso. Imprime os sinais com o
## prefixo ROBO para conferir no log. Semente fixa (11).
## TM_LANCA=<px>: na Corrida, o robô toca no compasso, deixa o dedo na tela e
## arrasta a lança <px> na vertical (negativo = sobe), segurando até a Mira;
## lá ele só solta (o golpe sai na altura escolhida).

var _lanca := float(OS.get_environment("TM_LANCA")) if OS.get_environment("TM_LANCA") != "" else 0.0
var _arrastado := 0.0
var _segurando_lanca := false

@onready var arena: Arena = $Arena
@onready var c: ControladorJusta = $Arena/Justa

func _ready() -> void:
	c.fase_mudou.connect(func(f, _a, p): print("ROBO fase %s passada %d t=%d" % [JustaFases.NOMES_FASE[f], p, c.justa.fases.tempo_total_ms]))
	c.largada_avaliada.connect(func(_p, q, r, _qm): print("ROBO largada %s reacao %d" % [q, r]))
	c.toque_galope.connect(func(r, d, v, f): print("ROBO toque %s desvio %d velocidade %d folego %d" % [r, d, v, f]))
	c.golpe_avaliado.connect(func(p, z, a, s): print("ROBO golpe passada %d zona %s automatico %s sem_golpe %s" % [p, z, a, s]))
	c.iniciar.call_deferred(11)

func _process(_delta: float) -> void:
	var j := c.justa
	if j == null or j.terminou():
		return
	match j.fases.fase:
		JustaFases.Fase.LARGADA:
			if j.bandeira_baixou and not j.tocou_largada:
				c.tocar()
		JustaFases.Fase.CORRIDA:
			var p := j.jogador.compasso_ms()
			var resto := j.jogador.t_ms % p
			var na_batida := j.jogador.t_ms >= p / 2 and (resto <= 17 or resto > p - 17)
			if _lanca != 0.0 and j.jogador.t_ms >= 1500 and na_batida and not _segurando_lanca:
				_segurando_lanca = true
				_dedo(true)  # o toque da batida, e o dedo fica
			elif na_batida and not _segurando_lanca:
				c.tocar()
			if _segurando_lanca and absf(_arrastado) < absf(_lanca):
				var d := InputEventScreenDrag.new()
				d.relative = Vector2(0, signf(_lanca) * 4.0)
				_arrastado += d.relative.y
				c._unhandled_input(d)
		JustaFases.Fase.MIRA:
			if _segurando_lanca:
				if j.fases.tempo_na_fase_ms >= 900:
					_segurando_lanca = false
					_dedo(false)
			elif _lanca == 0.0:
				preload("res://tests/arena/justa_check.gd").robo_mira(c, Vector2(8, -86))

func _dedo(apertou: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.pressed = apertou
	e.position = Vector2(480, 300)
	c._unhandled_input(e)
