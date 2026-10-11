class_name RegraConjuntos
extends RefCounted
## Bônus de conjunto (GDD Conjuntos), puro: com 2 peças equipadas do mesmo
## conjunto o cavaleiro ganha bonus_2 (atributos); com o conjunto completo
## (todas as peças dele no catálogo) libera a habilidade do conjunto. O
## servidor faz a mesma conta a partir do equipamento salvo.
## Dados em itens.json > conjuntos (e as peças em itens.json > modelos).

## modelos_equipados: ids de modelo das peças equipadas (qualquer ordem).
## Devolve {atributos: {nome: bônus}, habilidades: [nome] (ordem alfabética
## do conjunto), contagem: {conjunto: n}, total: {conjunto: peças no catálogo}}.
static func efeito(modelos_equipados: Array, itens: Dictionary) -> Dictionary:
	var modelos: Dictionary = itens["modelos"]
	var cfg: Dictionary = itens.get("conjuntos", {})
	var total := {}
	for m: String in modelos:
		var c: String = modelos[m].get("conjunto", "")
		if c != "":
			total[c] = int(total.get(c, 0)) + 1
	var contagem := {}
	for m: String in modelos_equipados:
		if modelos.has(m):
			var c: String = modelos[m].get("conjunto", "")
			if c != "":
				contagem[c] = int(contagem.get(c, 0)) + 1
	var nomes := contagem.keys()
	nomes.sort()
	var atributos := {}
	var habilidades: Array[String] = []
	for c: String in nomes:
		if not cfg.has(c):
			continue
		var n := int(contagem[c])
		if n >= 2:
			var b: Dictionary = cfg[c].get("bonus_2", {})
			for k: String in b:
				atributos[k] = int(atributos.get(k, 0)) + int(b[k])
		if n >= int(total.get(c, 0)) and str(cfg[c].get("habilidade", "")) != "":
			habilidades.append(str(cfg[c]["habilidade"]))
	return {"atributos": atributos, "habilidades": habilidades, "contagem": contagem, "total": total}
