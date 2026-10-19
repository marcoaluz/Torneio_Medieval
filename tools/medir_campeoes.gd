extends RefCounted
## Mede o traço de luta dos campeões do PvE (pve.json > tracos) simulando
## justas inteiras pela regra pura: o campeão (perfil + ajuste_campeao +
## perfil_ajuste, a habilidade dele) contra um cavaleiro-espelho (os mesmos
## atributos e peças, IA "equilibrado", com a habilidade pedida). Usado por
## tools/simular_campeoes.gd (relatório) e tests/rules/tracos_check.gd
## (assinatura de cada traço). Sem nós e sem relógio: mesma semente, mesmo número.

## Lado da justa a partir dos dados do rival (como ServicoJogador._rival_de,
## sem o crescimento do nêmesis).
static func lado_do_rival(r: Dictionary, modelos: Dictionary) -> Dictionary:
	var equip := {}
	for m: String in r["equipamento"]:
		var st: Dictionary = (modelos[m]["status"] as Dictionary).duplicate()
		st["durabilidade"] = int(modelos[m]["durabilidade_max"])
		equip[modelos[m]["espaco"]] = st
	return {"cavaleiro": (r["cavaleiro"] as Dictionary).duplicate(), "cavalo": (r["cavalo"] as Dictionary).duplicate(),
		"equipamento": equip, "habilidade": r.get("habilidade", "")}

## Métricas de `n` justas do rival `r` (já com por_regiao aplicado, se for o
## caso) contra o espelho com `habilidade_jogador`. sem_ajuste = mede o mesmo
## campeão sem o perfil_ajuste (a base para comparar o traço).
## Devolve {vitorias_rival_pct, derrubadas_rival_pct, largada_perfeita_pct,
## zona_<z>_pct (golpes do rival por zona sorteada), bloqueio_pct (golpes do
## espelho em capacete/peito bloqueados pela habilidade do rival),
## habilidade_passada1_pct (justas em que a ativa do rival saiu na 1ª
## passada), habilidade_ultima_pct (das justas que chegaram à 3ª passada,
## em quantas a ativa do rival saiu da 3ª em diante), velocidade_rival
## (média no fim da Corrida), pontos_rival_por_golpe (×10), cresce_por_encontro}.
static func medir(r: Dictionary, n: int, semente: int, habilidade_jogador: String, sem_ajuste := false) -> Dictionary:
	var cfg := Justa.carregar_configuracao()
	var ia: Dictionary = Balanceamento.carregar("ia_rival")
	var modelos: Dictionary = Balanceamento.carregar("itens")["modelos"]
	var rr := r.duplicate(true)
	if sem_ajuste:
		rr.erase("perfil_ajuste")
	var perfil_r := RegraPve.perfil_do_rival(ia, rr)
	var lado_r := lado_do_rival(rr, modelos)
	var lado_j := lado_r.duplicate(true)
	lado_j.erase("habilidade")
	lado_j["habilidades"] = [habilidade_jogador] if habilidade_jogador != "" else []
	var perfil_j: Dictionary = ia["perfis"]["equilibrado"]
	var c := {"vitorias": 0, "derrubadas": 0, "largadas": 0, "perfeitas": 0, "golpes": 0, "zonas": {},
		"alvo_bloqueio": 0, "bloqueados": 0, "hab_p1": 0, "vel_soma": 0, "vel_n": 0, "pontos": 0,
		"chegou_3": 0, "hab_ultima": 0}
	for i in n:
		var sim := RegraPve.simular(cfg, lado_j, lado_r, semente + i * 7919, perfil_r, perfil_j)
		var hab_p1 := false
		var hab_ultima := false
		var passadas := 0
		for e: Dictionary in sim["eventos"]:
			match e["tipo"]:
				"largada_rival":
					c["largadas"] += 1
					if e["qualidade"] == "perfeita":
						c["perfeitas"] += 1
				"corrida_fim":
					c["vel_soma"] += int(e["velocidade_rival"])
					c["vel_n"] += 1
				"habilidade":
					if e["lado"] == "rival" and int(e["passada"]) == 1:
						hab_p1 = true
					if e["lado"] == "rival" and int(e["passada"]) >= 3:
						hab_ultima = true
				"impacto":
					var g: Dictionary = e["rival"]
					c["golpes"] += 1
					passadas = maxi(passadas, int(e["passada"]))
					c["zonas"][g["zona"]] = int(c["zonas"].get(g["zona"], 0)) + 1
					c["pontos"] += int(g.get("pontos", 0))
					var gj: Dictionary = e["jogador"]
					if gj["zona"] in ["capacete", "peito"]:
						c["alvo_bloqueio"] += 1
						if gj["bloqueado"] and gj["bloqueio_por"] == "habilidade":
							c["bloqueados"] += 1
				"fim":
					if e["vencedor"] == JustaFases.Lado.RIVAL:
						c["vitorias"] += 1
						if e["motivo"] == "derrubada":
							c["derrubadas"] += 1
		if hab_p1:
			c["hab_p1"] += 1
		if passadas >= 3:
			c["chegou_3"] += 1
			if hab_ultima:
				c["hab_ultima"] += 1
	var golpes := maxi(int(c["golpes"]), 1)
	var m := {"vitorias_rival_pct": int(c["vitorias"]) * 100 / maxi(n, 1),
		"derrubadas_rival_pct": int(c["derrubadas"]) * 100 / maxi(n, 1),
		"largada_perfeita_pct": int(c["perfeitas"]) * 100 / maxi(int(c["largadas"]), 1),
		"bloqueio_pct": int(c["bloqueados"]) * 100 / maxi(int(c["alvo_bloqueio"]), 1),
		"habilidade_passada1_pct": int(c["hab_p1"]) * 100 / maxi(n, 1),
		"habilidade_ultima_pct": int(c["hab_ultima"]) * 100 / maxi(int(c["chegou_3"]), 1),
		"cresce_por_encontro": int(r.get("cresce_por_encontro", 0)),
		"velocidade_rival": int(c["vel_soma"]) / maxi(int(c["vel_n"]), 1),
		"pontos_rival_por_golpe": int(c["pontos"]) * 10 / golpes}
	for z in ["capacete", "peito", "escudo", "cavalo", "erro"]:
		m["zona_%s_pct" % z] = int(c["zonas"].get(z, 0)) * 100 / golpes
	return m

## Campeões e o nêmesis com o traço: [{id, regiao, rival (dados prontos)}].
## O nêmesis entra uma vez por região (por_regiao aplicado).
static func lista(pve: Dictionary) -> Array:
	var saida := []
	for reg: String in pve["ordem_regioes"]:
		var vistos := {}
		for t: String in pve["regioes"][reg]["torneios"]:
			for rid: String in pve["torneios"][t]["rivais"]:
				var r: Dictionary = pve["rivais"][rid]
				if vistos.has(rid) or not (r.get("campeao", false) or r.get("nemesis", false)):
					continue
				vistos[rid] = true
				var dados := r.duplicate(true)
				if r.get("por_regiao", {}).has(reg):
					dados.merge(r["por_regiao"][reg], true)
				saida.append({"id": rid, "regiao": reg, "rival": dados})
	return saida
