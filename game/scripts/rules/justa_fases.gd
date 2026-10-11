class_name JustaFases
extends RefCounted
## Sequência de fases de uma justa (regra pura, ver skill regra-da-justa).
## Uma passada: Apresentação → Largada → Corrida → Mira → Impacto.
## Uma justa: `passadas` passadas; empate depois delas leva a passadas extras
## (até `passadas_extras_max`); derrubada encerra a justa ao fim da passada.
##
## Tempo em milissegundos inteiros, passado de fora por avancar(ms): sem
## relógio, sem nós, sem sinais. Cada chamada devolve a lista de eventos que
## aconteceram, em ordem, cada um com o instante exato "t" (ms desde o início):
##   {tipo:"fase", fase, anterior, passada, t}
##   {tipo:"passada", passada, pontos_jogador, pontos_rival, derrubado, t}
##   {tipo:"fim", vencedor, motivo, placar_jogador, placar_rival, t}
## O resultado de cada passada (pontos, derrubada) vem de fora, pela regra do
## impacto, via registrar_resultado() durante a Mira ou o Impacto. Sem
## resultado registrado, a passada vale 0 a 0.
## Espelho em TypeScript na Parte 3; casos em tests/shared/justa_fases.json.

enum Fase { APRESENTACAO, LARGADA, CORRIDA, MIRA, IMPACTO, FIM }
enum Lado { NENHUM, JOGADOR, RIVAL }

const NOMES_FASE: Array[String] = ["apresentacao", "largada", "corrida", "mira", "impacto", "fim"]
const NOMES_LADO: Array[String] = ["nenhum", "jogador", "rival"]

var fase := Fase.FIM
var passada := 0
var tempo_total_ms := 0
var tempo_na_fase_ms := 0
var placar_jogador := 0
var placar_rival := 0
var vencedor := Lado.NENHUM
## "pontos", "derrubada" ou "empate"; vazio enquanto a justa não termina.
var motivo := ""

var _passadas := 0
var _extras_max := 0
var _duracao_ms: Array[int] = []
var _pontos_passada_jogador := 0
var _pontos_passada_rival := 0
var _derrubado := Lado.NENHUM

## Devolve "" se a configuração (o JSON de justa) estiver completa, senão a
## descrição do problema.
static func validar(config: Dictionary) -> String:
	for chave in ["passadas", "passadas_extras_max", "fases_ms"]:
		if not config.has(chave):
			return "falta \"%s\"" % chave
	if not _inteiro_valido(config["passadas"], 1):
		return "\"passadas\" deve ser inteiro >= 1"
	if not _inteiro_valido(config["passadas_extras_max"], 0):
		return "\"passadas_extras_max\" deve ser inteiro >= 0"
	var fases: Variant = config["fases_ms"]
	if not fases is Dictionary:
		return "\"fases_ms\" deve ser objeto"
	for i in Fase.FIM:
		var nome := NOMES_FASE[i]
		if not (fases as Dictionary).has(nome):
			return "falta \"fases_ms.%s\"" % nome
		if not _inteiro_valido(fases[nome], 1):
			return "\"fases_ms.%s\" deve ser inteiro >= 1" % nome
	return ""

static func _inteiro_valido(v: Variant, minimo: int) -> bool:
	if not (v is int or v is float):
		return false
	return float(v) == floorf(float(v)) and int(v) >= minimo

## A configuração precisa passar em validar() antes.
func _init(config: Dictionary) -> void:
	_passadas = int(config["passadas"])
	_extras_max = int(config["passadas_extras_max"])
	for i in Fase.FIM:
		_duracao_ms.append(int(config["fases_ms"][NOMES_FASE[i]]))

func duracao_ms(f: Fase) -> int:
	return _duracao_ms[f] if f < Fase.FIM else 0

## Começa a justa na Apresentação da primeira passada.
func iniciar() -> Array[Dictionary]:
	passada = 0
	tempo_total_ms = 0
	placar_jogador = 0
	placar_rival = 0
	vencedor = Lado.NENHUM
	motivo = ""
	var eventos: Array[Dictionary] = []
	_nova_passada(eventos)
	return eventos

func terminou() -> bool:
	return fase == Fase.FIM

## Avança o relógio da justa em `ms` (>= 0), atravessando quantas fases couberem.
func avancar(ms: int) -> Array[Dictionary]:
	var eventos: Array[Dictionary] = []
	while ms > 0 and fase != Fase.FIM:
		var restante := _duracao_ms[fase] - tempo_na_fase_ms
		if ms < restante:
			tempo_na_fase_ms += ms
			tempo_total_ms += ms
			break
		ms -= restante
		tempo_total_ms += restante
		_fim_da_fase(eventos)
	return eventos

## Pula a Apresentação (GDD: "2 s (pula)"). Fora dela, não faz nada.
func pular() -> Array[Dictionary]:
	var eventos: Array[Dictionary] = []
	if fase == Fase.APRESENTACAO:
		_fim_da_fase(eventos)
	return eventos

## Termina a Corrida antes do teto de tempo (os cavaleiros chegaram ao
## ponto da Mira). Fora da Corrida, não faz nada.
func encerrar_corrida() -> Array[Dictionary]:
	var eventos: Array[Dictionary] = []
	if fase == Fase.CORRIDA:
		_fim_da_fase(eventos)
	return eventos

## Resultado da passada atual, calculado pela regra do impacto. Só vale na
## Mira ou no Impacto; devolve false (e ignora) fora delas ou com valores
## inválidos. Registrar de novo na mesma passada substitui o anterior.
func registrar_resultado(pontos_jogador: int, pontos_rival: int, derrubado := Lado.NENHUM) -> bool:
	if fase != Fase.MIRA and fase != Fase.IMPACTO:
		return false
	if pontos_jogador < 0 or pontos_rival < 0:
		return false
	_pontos_passada_jogador = pontos_jogador
	_pontos_passada_rival = pontos_rival
	_derrubado = derrubado
	return true

func _nova_passada(eventos: Array[Dictionary]) -> void:
	passada += 1
	_pontos_passada_jogador = 0
	_pontos_passada_rival = 0
	_derrubado = Lado.NENHUM
	_entrar(Fase.APRESENTACAO, eventos)

func _entrar(nova: Fase, eventos: Array[Dictionary]) -> void:
	var anterior := fase
	fase = nova
	tempo_na_fase_ms = 0
	eventos.append({"tipo": "fase", "fase": nova, "anterior": anterior, "passada": passada, "t": tempo_total_ms})

func _fim_da_fase(eventos: Array[Dictionary]) -> void:
	if fase != Fase.IMPACTO:
		_entrar(fase + 1 as Fase, eventos)
		return
	placar_jogador += _pontos_passada_jogador
	placar_rival += _pontos_passada_rival
	eventos.append({"tipo": "passada", "passada": passada,
		"pontos_jogador": _pontos_passada_jogador, "pontos_rival": _pontos_passada_rival,
		"derrubado": _derrubado, "t": tempo_total_ms})
	if _derrubado == Lado.RIVAL:
		_encerrar(Lado.JOGADOR, "derrubada", eventos)
	elif _derrubado == Lado.JOGADOR:
		_encerrar(Lado.RIVAL, "derrubada", eventos)
	elif passada >= _passadas and placar_jogador != placar_rival:
		_encerrar(Lado.JOGADOR if placar_jogador > placar_rival else Lado.RIVAL, "pontos", eventos)
	elif passada >= _passadas + _extras_max:
		_encerrar(Lado.NENHUM, "empate", eventos)
	else:
		_nova_passada(eventos)

func _encerrar(quem: Lado, por: String, eventos: Array[Dictionary]) -> void:
	vencedor = quem
	motivo = por
	_entrar(Fase.FIM, eventos)
	eventos.append({"tipo": "fim", "vencedor": quem, "motivo": por,
		"placar_jogador": placar_jogador, "placar_rival": placar_rival, "t": tempo_total_ms})
