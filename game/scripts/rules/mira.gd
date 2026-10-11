class_name Mira
extends RefCounted
## Zonas do alvo e avaliação do ponto da lança (regra pura).
## Coordenadas em décimos de px do quadro 160×160 do cavaleiro alvo, sem
## espelho (origem no chão, x para a frente, y negativo para cima). Assim a
## regra não depende de tela, zoom nem de qual lado o rival está.
## Precisão (0 a 100) + bônus da largada aumentam o tamanho das zonas que
## pontuam, até o teto; a zona de falta (cavalo) nunca cresce.

const ERRO := "erro"

static func validar(cfg: Dictionary) -> String:
	for chave in ["zonas", "precisao", "ponta_inicial", "limites_ponta", "oscilacao"]:
		if not cfg.has(chave):
			return "falta \"%s\"" % chave
	if not cfg["zonas"] is Array or cfg["zonas"].is_empty():
		return "\"zonas\" deve ser lista não vazia"
	for z: Variant in cfg["zonas"]:
		if not z is Dictionary or not z.has("nome") or not z.has("retangulos") or not z.has("cresce"):
			return "zona sem nome, retangulos ou cresce"
		for r: Variant in z["retangulos"]:
			if not r is Array or r.size() != 4:
				return "retângulo da zona %s deve ter 4 números" % z["nome"]
	for chave in ["crescimento_por_ponto_milesimos", "crescimento_max_pct"]:
		if not cfg["precisao"].has(chave):
			return "falta \"precisao.%s\"" % chave
	return ""

## Crescimento das zonas em % (Precisão e bônus somados, com teto).
static func crescimento_pct(cfg: Dictionary, precisao: int, bonus_pct: int) -> int:
	var p: Dictionary = cfg["precisao"]
	var g := maxi(precisao, 0) * int(p["crescimento_por_ponto_milesimos"]) / 1000 + maxi(bonus_pct, 0)
	return mini(g, int(p["crescimento_max_pct"]))

## Retângulos efetivos (décimos de px) por zona, na ordem de prioridade:
## [{nome, retangulos: Array[Rect2i]}].
static func zonas_efetivas(cfg: Dictionary, precisao: int, bonus_pct: int) -> Array[Dictionary]:
	var g := crescimento_pct(cfg, precisao, bonus_pct)
	var saida: Array[Dictionary] = []
	for z: Dictionary in cfg["zonas"]:
		var rets: Array[Rect2i] = []
		for r: Array in z["retangulos"]:
			var ret := Rect2i(int(r[0]) * 10, int(r[1]) * 10, int(r[2]) * 10, int(r[3]) * 10)
			if z["cresce"]:
				# Cresce g% em cada eixo, metade para cada lado (inteiros não negativos).
				ret = ret.grow_individual(ret.size.x * g / 200, ret.size.y * g / 200, ret.size.x * g / 200, ret.size.y * g / 200)
			rets.append(ret)
		saida.append({"nome": z["nome"], "retangulos": rets})
	return saida

## Zona atingida pelo ponto (décimos de px): nome da zona ou "erro".
## A borda de baixo/direita é inclusiva, como a de cima/esquerda.
static func zona_no_ponto(cfg: Dictionary, ponto: Vector2i, precisao: int, bonus_pct: int) -> String:
	for z in zonas_efetivas(cfg, precisao, bonus_pct):
		for ret: Rect2i in z["retangulos"]:
			if ponto.x >= ret.position.x and ponto.x <= ret.end.x and ponto.y >= ret.position.y and ponto.y <= ret.end.y:
				return z["nome"]
	return ERRO

## Ponto inicial da ponta da lança em décimos de px.
static func ponta_inicial(cfg: Dictionary) -> Vector2i:
	return Vector2i(int(cfg["ponta_inicial"][0]) * 10, int(cfg["ponta_inicial"][1]) * 10)

## Prende o ponto dentro dos limites da mira (décimos de px).
static func limitar(cfg: Dictionary, ponto: Vector2i) -> Vector2i:
	var l: Array = cfg["limites_ponta"]
	var x0 := int(l[0]) * 10
	var y0 := int(l[1]) * 10
	return Vector2i(clampi(ponto.x, x0, x0 + int(l[2]) * 10), clampi(ponto.y, y0, y0 + int(l[3]) * 10))
