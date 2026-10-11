class_name RegraForja
extends RefCounted
## Forja (GDD Forja: criar e melhorar), pura e determinística; o servidor
## repete a mesma conta. Números em economia.json > forja e > melhoria.
## Divisões inteiras truncam em direção ao zero (no TypeScript: Math.trunc).

## Peça criada: cada status (em ordem alfabética das chaves) varia
## inteiro(-pct, pct) por cento: v + v * d / 100, nunca abaixo de zero.
## Status 0 fica 0 e não gasta sorteio.
static func variar_status(status: Dictionary, pct: int, semente: int) -> Dictionary:
	var rng := Aleatorio.new(semente)
	var chaves := status.keys()
	chaves.sort()
	var res := {}
	for k: String in chaves:
		var v := int(status[k])
		if v == 0:
			res[k] = 0
			continue
		var d := rng.inteiro(-pct, pct)
		res[k] = maxi(0, v + _div(v * d, 100))
	return res

## Status com o nível de melhoria: v + v * nivel * pct / 100.
static func status_com_nivel(status: Dictionary, nivel: int, pct: int) -> Dictionary:
	var res := {}
	for k: String in status:
		var v := int(status[k])
		res[k] = v + _div(v * nivel * pct, 100)
	return res

## Tentativa de melhoria do nível `nivel` para o seguinte: sucesso com a
## chance da tabela (chance_sucesso_pct[nivel], 100 = garantido). Um sorteio.
static func melhoria_deu_certo(nivel: int, cfg_melhoria: Dictionary, semente: int) -> bool:
	var chance := int(cfg_melhoria["chance_sucesso_pct"][nivel])
	return Aleatorio.new(semente).chance_milesimos(chance * 10)

static func _div(a: int, b: int) -> int:
	# Trunca em direção ao zero, igual ao Math.trunc do TypeScript.
	var q := absi(a) / b
	return q if a >= 0 else -q
