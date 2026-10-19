class_name IaRival
extends RefCounted
## IA do rival (pura e determinística, como a regra: o servidor refaz a justa
## com ela no PvP assíncrono e no PvE). Produz as mesmas entradas que o
## jogador: reação à bandeira, instantes dos toques do galope, ponto da mira
## e batida em que aciona a habilidade. Quem aplica é a Justa.
##
## Usa o próprio gerador (Aleatorio) com a semente que a Justa passa, para as
## decisões da IA não mudarem os sorteios da bandeira e do impacto.
## Ordem dos sorteios por passada: largada (2: a qualidade pelo perfil e o
## instante dentro da faixa dela), galope (por batida: perder? 1; se toca,
## desvio 2), mira (4). Variação "triangular": média de dois sorteios
## uniformes, com divisão só de número não negativo.
## Largada: o perfil diz quantos milésimos das largadas saem perfeitas
## (largada_perfeita_milesimos) e boas (largada_boa_milesimos); o resto é
## ruim (atrasada até largada_ruim_atraso_ms depois da faixa boa). Campeões
## somam ia_rival.json > ajuste_campeao (RegraPve.perfil_do_rival).

const MASCARA_SEMENTE := 0x5DEECE66

var perfil: Dictionary
var _rng: Aleatorio

static func validar(cfg: Dictionary) -> String:
	if not cfg.get("perfis") is Dictionary or cfg["perfis"].is_empty():
		return "falta \"perfis\""
	if not cfg.get("ajuste_campeao") is Dictionary:
		return "falta \"ajuste_campeao\""
	for nome: String in cfg["perfis"]:
		var erro := validar_perfil(cfg["perfis"][nome])
		if erro != "":
			return "perfil %s: %s" % [nome, erro]
	return ""

static func validar_perfil(p: Dictionary) -> String:
	for k in ["largada_perfeita_milesimos", "largada_boa_milesimos", "largada_ruim_atraso_ms", "desvio_medio_ms", "desvio_variacao_ms",
			"perder_batida_milesimos", "acelera", "metade_batidas", "zona_preferida", "erro_mira_px",
			"deslocamento_mira_px", "habilidade_batida"]:
		if not p.has(k):
			return "falta \"%s\"" % k
	if p["acelera"] != "cedo" and p["acelera"] != "tarde":
		return "\"acelera\" deve ser cedo ou tarde"
	return ""

## Semente da IA a partir da semente da justa.
static func semente_da_justa(semente: int) -> int:
	return (semente ^ MASCARA_SEMENTE) & Aleatorio.MASCARA

func _init(p: Dictionary, semente: int) -> void:
	perfil = p
	_rng = Aleatorio.new(semente)

## Variação em [-v, v], média de dois sorteios (mais perto do centro).
func _variacao(v: int) -> int:
	if v <= 0:
		return 0
	var soma := _rng.inteiro(0, 2 * v) + _rng.inteiro(0, 2 * v)
	return soma / 2 - v

## Reação à bandeira em ms: sorteia a qualidade pelo perfil e o instante
## dentro da faixa dela (galope.json > largada: perfeita até perfeita_ms, boa
## até boa_ms). `cfg_largada` = galope.json > largada.
func reacao_largada_ms(cfg_largada: Dictionary) -> int:
	var perfeita_ms := int(cfg_largada["perfeita_ms"])
	var boa_ms := int(cfg_largada["boa_ms"])
	var q := _rng.inteiro(0, 999)
	var p := int(perfil["largada_perfeita_milesimos"])
	if q < p:
		return _rng.inteiro(0, perfeita_ms)
	if q < p + int(perfil["largada_boa_milesimos"]):
		return _rng.inteiro(perfeita_ms + 1, boa_ms)
	return _rng.inteiro(boa_ms + 1, boa_ms + maxi(int(perfil["largada_ruim_atraso_ms"]), 1))

## Instantes (ms desde o começo da Corrida, crescentes, >= 1) em que o rival
## toca, até `duracao_max_ms`.
func plano_galope(compasso_ms: int, duracao_max_ms: int) -> Array[int]:
	var plano: Array[int] = []
	var batidas := duracao_max_ms / compasso_ms
	var metade := int(perfil["metade_batidas"])
	var cedo: bool = perfil["acelera"] == "cedo"
	for k in range(1, batidas + 1):
		var acelerando := (k <= metade) if cedo else (k > metade)
		if not acelerando and k % 2 == 1:
			continue  # no ritmo de cruzeiro, toca uma batida sim, outra não
		if _rng.chance_milesimos(int(perfil["perder_batida_milesimos"])):
			continue
		var t := k * compasso_ms + int(perfil["desvio_medio_ms"]) + _variacao(int(perfil["desvio_variacao_ms"]))
		if t >= 1 and (plano.is_empty() or t > plano.back()):
			plano.append(t)
	return plano

## Ponto da mira (décimos de px do quadro do alvo): centro da zona preferida
## mais o deslocamento do perfil, com erro em x e em y.
func ponto_mira(cfg_mira: Dictionary) -> Vector2i:
	var desl: Array = perfil["deslocamento_mira_px"]
	var centro := centro_da_zona(cfg_mira, perfil["zona_preferida"]) + Vector2i(int(desl[0]) * 10, int(desl[1]) * 10)
	var erro := int(perfil["erro_mira_px"]) * 10
	var dx := _variacao(erro)
	var dy := _variacao(erro)
	return centro + Vector2i(dx, dy)

## Batida da Corrida em que aciona a habilidade ativa (0 = nunca).
func batida_habilidade() -> int:
	return int(perfil["habilidade_batida"])

## Primeira passada em que tenta acionar a ativa (opcional, padrão 1: logo
## na primeira). O traço "paciente" dos campeões guarda para a última.
func passada_habilidade() -> int:
	return maxi(int(perfil.get("habilidade_passada", 1)), 1)

## Centro do primeiro retângulo da zona, em décimos de px.
static func centro_da_zona(cfg_mira: Dictionary, zona: String) -> Vector2i:
	for z: Dictionary in cfg_mira["zonas"]:
		if z["nome"] == zona:
			var r: Array = z["retangulos"][0]
			return Vector2i(int(r[0]) * 10 + int(r[2]) * 5, int(r[1]) * 10 + int(r[3]) * 5)
	return Vector2i.ZERO
