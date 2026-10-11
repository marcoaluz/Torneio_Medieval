class_name RegraLiga
extends RefCounted
## Ligas e PvP assíncrono (GDD PvP, ligas e temporadas), puro: o servidor
## (Edge Function, 3.5/3.6) faz a mesma conta. Números em economia.json > ligas
## e > poder_raridade / poder_por_melhoria.

## Poder do cavaleiro (o mesmo da simulação da economia): média dos 6
## atributos (cavaleiro e cavalo) / 2 + poder das peças (raridade + nível).
## atributos: Array de ints; pecas: [{raridade, nivel}]. Inteiro (trunca).
static func poder(atributos: Array, pecas: Array, eco: Dictionary) -> int:
	var soma := 0
	for a in atributos:
		soma += int(a)
	var p := soma / maxi(atributos.size(), 1) / 2
	for pc: Dictionary in pecas:
		p += int(eco["poder_raridade"].get(pc.get("raridade", "comum"), 0)) + int(pc.get("nivel", 0)) * int(eco["poder_por_melhoria"])
	return p

## Liga e divisão pelos pontos: {liga (índice), nome, divisao (III, II ou I),
## pontos_na_divisao, para_subir (pontos que faltam; -1 no topo)}.
static func posicao(pontos: int, cfg: Dictionary) -> Dictionary:
	var por_div := int(cfg["pontos_por_divisao"])
	var divs: Array = cfg["divisoes"]
	var nomes: Array = cfg["nomes"]
	var total_div := mini(maxi(pontos, 0) / por_div, nomes.size() * divs.size() - 1)
	var liga := total_div / divs.size()
	var div := total_div % divs.size()
	var topo := total_div == nomes.size() * divs.size() - 1
	return {"liga": liga, "nome": nomes[liga], "divisao": divs[div], "pontos_na_divisao": maxi(pontos, 0) - total_div * por_div,
		"para_subir": -1 if topo else (total_div + 1) * por_div - maxi(pontos, 0)}

## Pontos depois de uma partida do atacante (nunca abaixo de zero).
static func depois_da_partida(pontos: int, venceu: bool, cfg: Dictionary) -> int:
	return maxi(0, pontos + int(cfg["vitoria"] if venceu else cfg["derrota"]))

## Pontos do defensor quando a defesa vence (perder a defesa não tira pontos).
static func depois_da_defesa(pontos: int, defendeu: bool, cfg: Dictionary) -> int:
	return pontos + (int(cfg["defesa_vencida"]) if defendeu else 0)

## Pareamento: dos candidatos [{id, pontos, poder}], os que estão na faixa
## de poder e mais perto em pontos; empate pelo id (ordem estável).
## Devolve o id escolhido ("" se nenhum na faixa).
static func parear(pontos: int, poder_jogador: int, candidatos: Array, cfg: Dictionary) -> String:
	var faixa := int(cfg["faixa_poder"])
	var melhor := ""
	var dist := -1
	for c: Dictionary in candidatos:
		if absi(int(c["poder"]) - poder_jogador) > faixa:
			continue
		var d := absi(int(c["pontos"]) - pontos)
		if dist < 0 or d < dist or (d == dist and str(c["id"]) < melhor):
			melhor = str(c["id"])
			dist = d
	return melhor

## Fim da temporada: reinício parcial dos pontos.
static func reinicio(pontos: int, cfg: Dictionary) -> int:
	return pontos * int(cfg["reinicio_pct"]) / 100

## Ouro de uma vitória de PvP na liga `liga` (índice).
static func ouro_vitoria(liga: int, cfg: Dictionary) -> int:
	return int(cfg["ouro_vitoria"]) + liga * int(cfg["ouro_por_liga"])
