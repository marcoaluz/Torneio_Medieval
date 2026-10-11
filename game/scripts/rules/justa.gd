class_name Justa
extends RefCounted
## A justa inteira como regra pura: junta as fases (JustaFases), a largada e
## o galope dos dois lados (Galope) e o sorteio da bandeira (Aleatorio).
## O jogador só manda toques: tocar() no instante atual. O servidor refaz a
## justa com a mesma semente e os mesmos instantes de toque.
##
## O toque faz uma coisa por fase:
##   Apresentação -> pula; Largada -> larga (uma vez); Corrida -> galope.
## A Corrida termina quando a soma das distâncias chega ao ponto da Mira
## (pista.distancia_total - pista.distancia_mira) ou no teto fases_ms.corrida.
##
## Eventos (além dos de JustaFases), todos com "t":
##   {tipo:"bandeira", passada}
##   {tipo:"largada", passada, qualidade, tocou, reacao_ms, queimada}
##   {tipo:"toque", passada, resultado, batida, desvio_ms, velocidade, folego}
##   {tipo:"corrida_fim", passada, velocidade_jogador, velocidade_rival,
##        ritmo_jogador_milesimos, distancia_jogador_mil, distancia_rival_mil}

var fases: JustaFases
var jogador: Galope
var rival: Galope
var bandeira_ms := 0  ## instante da bandeira dentro da Largada desta passada
var bandeira_baixou := false
var qualidade_largada := ""
var tocou_largada := false
var reacao_largada_ms := 0  ## negativo = tocou antes da bandeira (queimada)

var _cfg_galope: Dictionary
var _rng: Aleatorio

static func validar(cfg_justa: Dictionary, cfg_galope: Dictionary) -> String:
	var erro := JustaFases.validar(cfg_justa)
	if erro != "":
		return "justa.json: " + erro
	erro = Galope.validar(cfg_galope)
	if erro != "":
		return "galope.json: " + erro
	var l: Dictionary = cfg_galope["largada"]
	if int(l["bandeira_ms"]) + int(l["bandeira_variacao_ms"]) >= int(cfg_justa["fases_ms"]["largada"]):
		return "a bandeira precisa baixar antes do fim da Largada"
	return ""

func _init(cfg_justa: Dictionary, cfg_galope: Dictionary, cavalo_jogador: Dictionary, cavalo_rival: Dictionary, semente: int) -> void:
	_cfg_galope = cfg_galope
	fases = JustaFases.new(cfg_justa)
	jogador = Galope.new(cfg_galope, cavalo_jogador)
	rival = Galope.new(cfg_galope, cavalo_rival)
	rival.automatico = true
	_rng = Aleatorio.new(semente)

func iniciar() -> Array[Dictionary]:
	return _observar(fases.iniciar())

func terminou() -> bool:
	return fases.terminou()

## Distância (milésimos) em que a Corrida acaba.
func distancia_corrida_mil() -> int:
	var p: Dictionary = _cfg_galope["pista"]
	return (int(p["distancia_total"]) - int(p["distancia_mira"])) * 1000

func distancia_total_mil() -> int:
	return int(_cfg_galope["pista"]["distancia_total"]) * 1000

func avancar(ms: int) -> Array[Dictionary]:
	var eventos: Array[Dictionary] = []
	while ms > 0 and not fases.terminou():
		match fases.fase:
			JustaFases.Fase.CORRIDA:
				ms -= 1
				eventos.append_array(_corrida_1ms())
			JustaFases.Fase.LARGADA:
				var ate_fase := fases.duracao_ms(fases.fase) - fases.tempo_na_fase_ms
				var passo := mini(ms, ate_fase)
				if not bandeira_baixou:
					passo = mini(passo, bandeira_ms - fases.tempo_na_fase_ms)
				if passo > 0:
					ms -= passo
					eventos.append_array(_observar(fases.avancar(passo)))
				if not bandeira_baixou and fases.fase == JustaFases.Fase.LARGADA and fases.tempo_na_fase_ms >= bandeira_ms:
					bandeira_baixou = true
					eventos.append({"tipo": "bandeira", "passada": fases.passada, "t": fases.tempo_total_ms})
			_:
				var ate_fase := fases.duracao_ms(fases.fase) - fases.tempo_na_fase_ms
				var passo := mini(ms, ate_fase)
				ms -= passo
				eventos.append_array(_observar(fases.avancar(passo)))
	return eventos

## Toque do jogador no instante atual.
func tocar() -> Array[Dictionary]:
	var eventos: Array[Dictionary] = []
	match fases.fase:
		JustaFases.Fase.APRESENTACAO:
			eventos.append_array(_observar(fases.pular()))
		JustaFases.Fase.LARGADA:
			if not tocou_largada:
				tocou_largada = true
				reacao_largada_ms = fases.tempo_na_fase_ms - bandeira_ms
				qualidade_largada = Galope.avaliar_largada(_cfg_galope, true, reacao_largada_ms)
				eventos.append(_evento_largada())
		JustaFases.Fase.CORRIDA:
			var r := jogador.tocar()
			eventos.append(_evento_toque(r, jogador))
	return eventos

func _corrida_1ms() -> Array[Dictionary]:
	var eventos: Array[Dictionary] = []
	var perdido := jogador.avancar_1ms()
	rival.avancar_1ms()
	if not perdido.is_empty():
		eventos.append(_evento_toque(perdido, jogador))
	# Primeiro o relógio (pode bater o teto); depois a chegada.
	eventos.append_array(_observar(fases.avancar(1)))
	if fases.fase == JustaFases.Fase.CORRIDA and jogador.distancia_mil + rival.distancia_mil >= distancia_corrida_mil():
		eventos.append_array(_observar(fases.encerrar_corrida()))
	return eventos

## Reage às trocas de fase da regra: prepara a Largada (sorteia a bandeira),
## fecha a largada e começa o galope, e anota o fim da Corrida.
func _observar(eventos: Array[Dictionary]) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for e in eventos:
		if e["tipo"] == "fase" and e["anterior"] == JustaFases.Fase.CORRIDA:
			saida.append({"tipo": "corrida_fim", "passada": fases.passada,
				"velocidade_jogador": jogador.velocidade, "velocidade_rival": rival.velocidade,
				"ritmo_jogador_milesimos": jogador.ritmo_milesimos(),
				"distancia_jogador_mil": jogador.distancia_mil, "distancia_rival_mil": rival.distancia_mil,
				"t": e["t"]})
		saida.append(e)
		if e["tipo"] != "fase":
			continue
		match e["fase"]:
			JustaFases.Fase.LARGADA:
				var l: Dictionary = _cfg_galope["largada"]
				bandeira_ms = int(l["bandeira_ms"]) + _rng.inteiro(0, int(l["bandeira_variacao_ms"]))
				bandeira_baixou = false
				tocou_largada = false
				qualidade_largada = ""
				reacao_largada_ms = 0
			JustaFases.Fase.CORRIDA:
				if not tocou_largada:
					qualidade_largada = Galope.avaliar_largada(_cfg_galope, false, 0)
					saida.append(_evento_largada())
				jogador.nova_passada(qualidade_largada)
				rival.nova_passada("boa")
	return saida

func _evento_largada() -> Dictionary:
	return {"tipo": "largada", "passada": fases.passada, "qualidade": qualidade_largada,
		"tocou": tocou_largada, "reacao_ms": reacao_largada_ms,
		"queimada": tocou_largada and reacao_largada_ms < 0, "t": fases.tempo_total_ms}

func _evento_toque(r: Dictionary, g: Galope) -> Dictionary:
	return {"tipo": "toque", "passada": fases.passada, "resultado": r["resultado"], "batida": r["batida"],
		"desvio_ms": r["desvio_ms"], "velocidade": g.velocidade, "folego": g.folego, "t": fases.tempo_total_ms}
