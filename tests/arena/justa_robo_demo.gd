extends Node
## Demonstração para o `driver.sh shot`: a arena com um jogador-robô que larga
## logo depois da bandeira e toca no compasso. Imprime os sinais com o
## prefixo ROBO para conferir no log. Semente fixa (11).

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
			if j.jogador.t_ms >= p / 2 and (resto <= 17 or resto > p - 17):
				c.tocar()
		JustaFases.Fase.MIRA:
			preload("res://tests/arena/justa_check.gd").robo_mira(c, Vector2(8, -86))
