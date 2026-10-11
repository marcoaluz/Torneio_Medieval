class_name Galope
extends RefCounted
## Largada e galope de um cavaleiro (regra pura, ms inteiros).
##
## Largada: a reação ao baixar da bandeira dá largada perfeita, boa ou ruim
## (tocar antes da bandeira = queimada = ruim; não tocar = ruim).
## Galope: o compasso bate a cada `compasso_ms` desde o começo da Corrida
## (primeira batida em t = compasso_ms). Cada toque vai para a batida mais
## próxima:
##   dentro da janela e batida livre -> "no_tempo": ganha velocidade
##   batida já usada                 -> "rapido_demais": gasta fôlego
##   fora da janela                  -> "fora_do_tempo": gasta fôlego
## Batida que passa sem toque -> "perdido": perde velocidade.
## Sem fôlego, cada erro também tira velocidade e a velocidade máxima cai.
## Temperamento aumenta a janela (até o teto); Velocidade dá a velocidade
## nominal; Fôlego dá o fôlego máximo, que dura a justa inteira.
##
## Distância em milésimos de unidade; velocidade em unidades por segundo
## (= milésimos por ms), então cada ms soma `velocidade` à distância.

const QUALIDADES: Array[String] = ["perfeita", "boa", "ruim"]

var automatico := false  ## sem toques: velocidade nominal constante (rival até a IA da 1.6)
var velocidade := 0
var velocidade_nominal := 0
var distancia_mil := 0
var folego := 0
var folego_max := 0
var janela_ms := 0
var t_ms := 0  ## tempo desde o começo da Corrida
var acertos := 0
var compassos := 0  ## batidas cuja janela já fechou ou que foram usadas

var _c: Dictionary
var _usadas := {}

## Devolve "" se a configuração (galope.json) estiver completa.
static func validar(cfg: Dictionary) -> String:
	var exigidas := {
		"largada": ["bandeira_ms", "bandeira_variacao_ms", "perfeita_ms", "boa_ms", "velocidade_inicial_pct", "bonus_precisao_pct"],
		"pista": ["distancia_total", "distancia_mira"],
		"galope": ["compasso_ms", "janela_base_ms", "janela_por_temperamento_milesimos", "janela_max_ms",
			"velocidade_base", "velocidade_por_ponto_milesimos", "velocidade_min_pct", "velocidade_max_pct",
			"ganho_pct", "perda_perdido_pct", "perda_sem_folego_pct", "velocidade_max_cansado_pct"],
		"folego": ["base", "por_ponto_milesimos", "custo_por_passada", "custo_erro"],
	}
	for grupo: String in exigidas:
		if not cfg.get(grupo) is Dictionary:
			return "falta o grupo \"%s\"" % grupo
		for chave: String in exigidas[grupo]:
			if not cfg[grupo].has(chave):
				return "falta \"%s.%s\"" % [grupo, chave]
	for q in QUALIDADES:
		if not cfg["largada"]["velocidade_inicial_pct"].has(q) or not cfg["largada"]["bonus_precisao_pct"].has(q):
			return "falta a qualidade \"%s\" na largada" % q
	if int(cfg["galope"]["janela_max_ms"]) * 2 >= int(cfg["galope"]["compasso_ms"]):
		return "janela_max_ms precisa ser menor que metade do compasso"
	if int(cfg["pista"]["distancia_mira"]) >= int(cfg["pista"]["distancia_total"]):
		return "distancia_mira precisa ser menor que distancia_total"
	return ""

## Qualidade da largada pela reação em ms ao baixar da bandeira.
## `reacao_ms` < 0 = tocou antes (queimada); `tocou` false = não tocou.
static func avaliar_largada(cfg: Dictionary, tocou: bool, reacao_ms: int) -> String:
	if not tocou or reacao_ms < 0:
		return "ruim"
	if reacao_ms <= int(cfg["largada"]["perfeita_ms"]):
		return "perfeita"
	if reacao_ms <= int(cfg["largada"]["boa_ms"]):
		return "boa"
	return "ruim"

## `cavalo`: {velocidade, folego, temperamento} (0 a 100).
func _init(cfg: Dictionary, cavalo: Dictionary) -> void:
	_c = cfg
	var g: Dictionary = cfg["galope"]
	velocidade_nominal = int(g["velocidade_base"]) + int(cavalo["velocidade"]) * int(g["velocidade_por_ponto_milesimos"]) / 1000
	janela_ms = mini(int(g["janela_base_ms"]) + int(cavalo["temperamento"]) * int(g["janela_por_temperamento_milesimos"]) / 1000,
		int(g["janela_max_ms"]))
	var f: Dictionary = cfg["folego"]
	folego_max = int(f["base"]) + int(cavalo["folego"]) * int(f["por_ponto_milesimos"]) / 1000
	folego = folego_max
	velocidade = velocidade_nominal

func compasso_ms() -> int:
	return int(_c["galope"]["compasso_ms"])

## Começo da Corrida de uma passada: zera a distância e as batidas, aplica a
## largada na velocidade e cobra o fôlego da passada.
func nova_passada(qualidade_largada: String) -> void:
	distancia_mil = 0
	t_ms = 0
	acertos = 0
	compassos = 0
	_usadas.clear()
	folego = maxi(folego - int(_c["folego"]["custo_por_passada"]), 0)
	if automatico:
		velocidade = velocidade_nominal
	else:
		velocidade = _limitar(velocidade_nominal * int(_c["largada"]["velocidade_inicial_pct"][qualidade_largada]) / 100)

## Ritmo da passada em milésimos (acertos / batidas), 0 se nenhuma batida.
func ritmo_milesimos() -> int:
	return 0 if compassos == 0 else acertos * 1000 / compassos

## Toque no instante atual (t_ms). Devolve {resultado, batida, desvio_ms}.
func tocar() -> Dictionary:
	var p := compasso_ms()
	var k := (t_ms + p / 2) / p
	var desvio := t_ms - k * p
	var resultado: String
	if k >= 1 and _usadas.has(k):
		resultado = "rapido_demais"
	elif k >= 1 and absi(desvio) <= janela_ms:
		resultado = "no_tempo"
		_usadas[k] = true
		acertos += 1
		compassos += 1
		_mudar_velocidade(int(_c["galope"]["ganho_pct"]))
	else:
		resultado = "fora_do_tempo"
	if resultado != "no_tempo":
		_errar()
	return {"resultado": resultado, "batida": k, "desvio_ms": desvio}

## Avança 1 ms da Corrida. Devolve o evento de batida perdida, se houver.
func avancar_1ms() -> Dictionary:
	t_ms += 1
	distancia_mil += velocidade
	if automatico:
		return {}
	var p := compasso_ms()
	# A janela da batida k vai até k*p + janela, inclusive; perdida no ms seguinte.
	var fim_janela := t_ms - janela_ms - 1
	if fim_janela >= p and fim_janela % p == 0:
		var k := fim_janela / p
		if not _usadas.has(k):
			compassos += 1
			_mudar_velocidade(-int(_c["galope"]["perda_perdido_pct"]))
			return {"resultado": "perdido", "batida": k, "desvio_ms": 0}
	return {}

func _errar() -> void:
	if folego > 0:
		folego = maxi(folego - int(_c["folego"]["custo_erro"]), 0)
	else:
		_mudar_velocidade(-int(_c["galope"]["perda_sem_folego_pct"]))

## Divisão só com números não negativos (truncar = arredondar para baixo,
## igual em GDScript e TypeScript); o sinal é aplicado depois.
func _mudar_velocidade(pct: int) -> void:
	var delta := velocidade_nominal * absi(pct) / 100
	velocidade = _limitar(velocidade + (delta if pct >= 0 else -delta))

func _limitar(v: int) -> int:
	var g: Dictionary = _c["galope"]
	var teto_pct := int(g["velocidade_max_pct"]) if folego > 0 else int(g["velocidade_max_cansado_pct"])
	return clampi(v, velocidade_nominal * int(g["velocidade_min_pct"]) / 100, velocidade_nominal * teto_pct / 100)
