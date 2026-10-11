class_name Justa
extends RefCounted
## A justa inteira como regra pura: junta as fases (JustaFases), a largada e
## o galope dos dois lados (Galope), a mira (Mira) e o sorteio da bandeira
## (Aleatorio). O jogador só manda entradas no instante atual: tocar(),
## mirar(ponto) e soltar(). O servidor refaz a justa com a mesma semente e
## as mesmas entradas nos mesmos instantes.
##
## Entradas por fase:
##   Apresentação: tocar() pula
##   Largada: tocar() larga (só o primeiro toque conta)
##   Corrida: tocar() galopa
##   Mira: mirar(ponto) segura e move a ponta da lança; soltar() trava o golpe.
##         Se ainda estiver segurando quando a Mira acaba, o golpe sai onde a
##         ponta estiver (automatico); se nunca segurou, o golpe é "erro".
## A Corrida termina quando a soma das distâncias chega ao ponto da Mira
## (pista.distancia_total - pista.distancia_mira) ou no teto fases_ms.corrida.
## O golpe é avaliado no choque (fim da Mira), não no instante em que solta.
##
## Configuração: {justa, galope, mira} (os JSON de game/data/balance/).
## Cada lado: {cavaleiro: {forca, precisao, equilibrio}, cavalo: {velocidade,
## folego, temperamento}}.
##
## Eventos (além dos de JustaFases), todos com "t":
##   {tipo:"bandeira", passada}
##   {tipo:"largada", passada, qualidade, tocou, reacao_ms, queimada}
##   {tipo:"toque", passada, resultado, batida, desvio_ms, velocidade, folego}
##   {tipo:"corrida_fim", passada, velocidade_jogador, velocidade_rival,
##        ritmo_jogador_milesimos, distancia_jogador_mil, distancia_rival_mil}
##   {tipo:"soltou", passada, x, y, t_mira_ms}
##   {tipo:"golpe", passada, zona, x, y, t_mira_ms, automatico, sem_golpe}
##        (x, y em décimos de px do quadro do rival; vem logo antes da fase Impacto)

var fases: JustaFases
var jogador: Galope
var rival: Galope
var bandeira_ms := 0  ## instante da bandeira dentro da Largada desta passada
var bandeira_baixou := false
var qualidade_largada := ""
var tocou_largada := false
var reacao_largada_ms := 0  ## negativo = tocou antes da bandeira (queimada)
## Mira da passada atual (décimos de px do quadro do rival).
var ponta := Vector2i.ZERO
var segurando := false
var solto := false
var t_soltou_ms := 0
var precisao_jogador := 0

var _cfg: Dictionary
var _rng: Aleatorio

static func validar(cfg: Dictionary) -> String:
	for nome in ["justa", "galope", "mira"]:
		if not cfg.get(nome) is Dictionary:
			return "falta a configuração \"%s\"" % nome
	var erro := JustaFases.validar(cfg["justa"])
	if erro != "":
		return "justa.json: " + erro
	erro = Galope.validar(cfg["galope"])
	if erro != "":
		return "galope.json: " + erro
	erro = Mira.validar(cfg["mira"])
	if erro != "":
		return "mira.json: " + erro
	var l: Dictionary = cfg["galope"]["largada"]
	if int(l["bandeira_ms"]) + int(l["bandeira_variacao_ms"]) >= int(cfg["justa"]["fases_ms"]["largada"]):
		return "a bandeira precisa baixar antes do fim da Largada"
	return ""

## Lê as configurações de game/data/balance/ (para o jogo; os testes montam
## a sua). Devolve {} e avisa se faltar arquivo.
static func carregar_configuracao() -> Dictionary:
	var cfg := {}
	for nome in ["justa", "galope", "mira"]:
		cfg[nome] = Balanceamento.carregar(nome)
	return cfg

func _init(cfg: Dictionary, lado_jogador: Dictionary, lado_rival: Dictionary, semente: int) -> void:
	_cfg = cfg
	fases = JustaFases.new(cfg["justa"])
	jogador = Galope.new(cfg["galope"], lado_jogador["cavalo"])
	rival = Galope.new(cfg["galope"], lado_rival["cavalo"])
	rival.automatico = true
	precisao_jogador = int(lado_jogador["cavaleiro"]["precisao"])
	_rng = Aleatorio.new(semente)

func iniciar() -> Array[Dictionary]:
	return _observar(fases.iniciar())

func terminou() -> bool:
	return fases.terminou()

## Distância (milésimos) em que a Corrida acaba.
func distancia_corrida_mil() -> int:
	var p: Dictionary = _cfg["galope"]["pista"]
	return (int(p["distancia_total"]) - int(p["distancia_mira"])) * 1000

func distancia_total_mil() -> int:
	return int(_cfg["galope"]["pista"]["distancia_total"]) * 1000

## Bônus de precisão (%) desta passada, pela largada.
func bonus_precisao_pct() -> int:
	if qualidade_largada == "":
		return 0
	return int(_cfg["galope"]["largada"]["bonus_precisao_pct"][qualidade_largada])

## Zonas efetivas do rival para o jogador nesta passada (para o realce na tela).
func zonas_efetivas() -> Array[Dictionary]:
	return Mira.zonas_efetivas(_cfg["mira"], precisao_jogador, bonus_precisao_pct())

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
				qualidade_largada = Galope.avaliar_largada(_cfg["galope"], true, reacao_largada_ms)
				eventos.append(_evento_largada())
		JustaFases.Fase.CORRIDA:
			var r := jogador.tocar()
			eventos.append(_evento_toque(r, jogador))
	return eventos

## Segura e move a ponta da lança (décimos de px do quadro do rival). Só na
## Mira e antes de soltar; o ponto é preso aos limites da mira.
func mirar(ponto: Vector2i) -> void:
	if fases.fase != JustaFases.Fase.MIRA or solto:
		return
	ponta = Mira.limitar(_cfg["mira"], ponto)
	segurando = true

## Solta o dedo: trava o golpe no ponto atual. Só na Mira, segurando.
func soltar() -> Array[Dictionary]:
	if fases.fase != JustaFases.Fase.MIRA or solto or not segurando:
		return []
	solto = true
	segurando = false
	t_soltou_ms = fases.tempo_na_fase_ms
	return [{"tipo": "soltou", "passada": fases.passada, "x": ponta.x, "y": ponta.y,
		"t_mira_ms": t_soltou_ms, "t": fases.tempo_total_ms}]

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
## fecha a largada e começa o galope, anota o fim da Corrida, prepara a Mira
## e avalia o golpe no choque.
func _observar(eventos: Array[Dictionary]) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for e in eventos:
		if e["tipo"] == "fase" and e["anterior"] == JustaFases.Fase.CORRIDA:
			saida.append({"tipo": "corrida_fim", "passada": fases.passada,
				"velocidade_jogador": jogador.velocidade, "velocidade_rival": rival.velocidade,
				"ritmo_jogador_milesimos": jogador.ritmo_milesimos(),
				"distancia_jogador_mil": jogador.distancia_mil, "distancia_rival_mil": rival.distancia_mil,
				"t": e["t"]})
		if e["tipo"] == "fase" and e["anterior"] == JustaFases.Fase.MIRA:
			saida.append(_avaliar_golpe(e["t"]))
		saida.append(e)
		if e["tipo"] != "fase":
			continue
		match e["fase"]:
			JustaFases.Fase.LARGADA:
				var l: Dictionary = _cfg["galope"]["largada"]
				bandeira_ms = int(l["bandeira_ms"]) + _rng.inteiro(0, int(l["bandeira_variacao_ms"]))
				bandeira_baixou = false
				tocou_largada = false
				qualidade_largada = ""
				reacao_largada_ms = 0
			JustaFases.Fase.CORRIDA:
				if not tocou_largada:
					qualidade_largada = Galope.avaliar_largada(_cfg["galope"], false, 0)
					saida.append(_evento_largada())
				jogador.nova_passada(qualidade_largada)
				rival.nova_passada("boa")
			JustaFases.Fase.MIRA:
				ponta = Mira.ponta_inicial(_cfg["mira"])
				segurando = false
				solto = false
				t_soltou_ms = 0
	return saida

func _avaliar_golpe(t: int) -> Dictionary:
	var sem_golpe := not solto and not segurando
	var automatico := not solto and segurando
	var zona := Mira.ERRO if sem_golpe else Mira.zona_no_ponto(_cfg["mira"], ponta, precisao_jogador, bonus_precisao_pct())
	var t_mira := t_soltou_ms if solto else fases.duracao_ms(JustaFases.Fase.MIRA)
	solto = true
	segurando = false
	return {"tipo": "golpe", "passada": fases.passada, "zona": zona, "x": ponta.x, "y": ponta.y,
		"t_mira_ms": t_mira, "automatico": automatico, "sem_golpe": sem_golpe, "t": t}

func _evento_largada() -> Dictionary:
	return {"tipo": "largada", "passada": fases.passada, "qualidade": qualidade_largada,
		"tocou": tocou_largada, "reacao_ms": reacao_largada_ms,
		"queimada": tocou_largada and reacao_largada_ms < 0, "t": fases.tempo_total_ms}

func _evento_toque(r: Dictionary, g: Galope) -> Dictionary:
	return {"tipo": "toque", "passada": fases.passada, "resultado": r["resultado"], "batida": r["batida"],
		"desvio_ms": r["desvio_ms"], "velocidade": g.velocidade, "folego": g.folego, "t": fases.tempo_total_ms}
