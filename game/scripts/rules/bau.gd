class_name RegraBau
extends RefCounted
## Abertura de baú (GDD Baús e itens), pura e determinística: o servidor
## (Edge Function) repete a mesma conta com a mesma semente e decide de
## verdade; o jogo só mostra. Números em economia.json > baus.
##
## Ordem dos sorteios (igual no TypeScript):
##   1. ouro = inteiro(ouro[0], ouro[1]); 2. fragmentos = inteiro(fragmentos[0], fragmentos[1]);
##   3. para cada item: raridade pelos pesos, na ordem fixa ORDEM; depois o
##      modelo entre os da raridade, em ordem alfabética.
## Garantia: baús que contam (garantia_conta) somam 1 ao contador; ao chegar
## em garantia_raro_a_cada, o próximo item abaixo de raro vira raro. Qualquer
## item raro ou melhor zera o contador. Item que o jogador já tem (ou que
## já saiu neste baú) é repetido e vira fragmentos_por_repetida fragmentos.

const ORDEM: Array[String] = ["comum", "incomum", "raro", "epico", "lendario"]

## Devolve {ouro, fragmentos, itens: [{modelo, raridade, repetida}], garantia}.
static func abrir(tipo: String, cfg: Dictionary, modelos: Dictionary, possui: Array, garantia: int, semente: int) -> Dictionary:
	var rng := Aleatorio.new(semente)
	var b: Dictionary = cfg["tipos"][tipo]
	var ouro := rng.inteiro(int(b["ouro"][0]), int(b["ouro"][1]))
	var fragmentos := rng.inteiro(int(b["fragmentos"][0]), int(b["fragmentos"][1]))
	var conta: bool = (cfg["garantia_conta"] as Array).has(tipo)
	if conta:
		garantia += 1
	var ja := possui.duplicate()
	var itens: Array = []
	for i in int(b["itens"]):
		var rar := _sortear_raridade(b["raridade"], rng)
		if ORDEM.find(rar) >= 2:
			garantia = 0
		elif conta and garantia >= int(cfg["garantia_raro_a_cada"]):
			rar = "raro"
			garantia = 0
		var pool := modelos_da_raridade(modelos, rar)
		var modelo: String = pool[rng.inteiro(0, pool.size() - 1)]
		var repetida := ja.has(modelo)
		if repetida:
			fragmentos += int(cfg["fragmentos_por_repetida"])
		else:
			ja.append(modelo)
		itens.append({"modelo": modelo, "raridade": rar, "repetida": repetida})
	return {"ouro": ouro, "fragmentos": fragmentos, "itens": itens, "garantia": garantia}

## Modelos de uma raridade em ordem alfabética; sem nenhum, desce de raridade.
static func modelos_da_raridade(modelos: Dictionary, raridade: String) -> Array:
	var r := ORDEM.find(raridade)
	while r >= 0:
		var pool: Array = []
		for m: String in modelos:
			if modelos[m]["raridade"] == ORDEM[r]:
				pool.append(m)
		if not pool.is_empty():
			pool.sort()
			return pool
		r -= 1
	return []

## Chance de cada raridade em porcentagem (com uma casa), para a tela de
## probabilidades. {raridade: pct}, na ordem fixa.
static func probabilidades(tipo: String, cfg: Dictionary) -> Dictionary:
	var pesos: Dictionary = cfg["tipos"][tipo]["raridade"]
	var total := 0
	for r in ORDEM:
		total += int(pesos.get(r, 0))
	var res := {}
	for r in ORDEM:
		if int(pesos.get(r, 0)) > 0:
			res[r] = snappedf(100.0 * int(pesos[r]) / total, 0.1)
	return res

static func _sortear_raridade(pesos: Dictionary, rng: Aleatorio) -> String:
	var total := 0
	for r in ORDEM:
		total += int(pesos.get(r, 0))
	var x := rng.inteiro(0, total - 1)
	for r in ORDEM:
		x -= int(pesos.get(r, 0))
		if x < 0:
			return r
	return ORDEM[0]
