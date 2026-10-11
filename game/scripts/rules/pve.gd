class_name RegraPve
extends RefCounted
## Regras puras do PvE (GDD Disputas PvE): estrelas de uma disputa e a
## simulação do modo automático. Puras e determinísticas (o servidor repete).

## Estrelas de uma disputa a partir dos eventos da Justa:
## 0 se não venceu; 1 pela vitória; +1 sem errar (nenhum golpe do jogador
## em "erro" nem falta); +1 se venceu por derrubada.
static func estrelas(eventos: Array) -> int:
	var venceu := false
	var derrubada := false
	var errou := false
	for e: Dictionary in eventos:
		match e["tipo"]:
			"impacto":
				var g: Dictionary = e["jogador"]
				if g["zona"] == Mira.ERRO or g["falta"]:
					errou = true
			"fim":
				venceu = e["vencedor"] == JustaFases.Lado.JOGADOR
				derrubada = e["motivo"] == "derrubada"
	if not venceu:
		return 0
	return 1 + (0 if errou else 1) + (1 if derrubada else 0)

## Joga a justa inteira sem ninguém tocar: o jogador também é uma IA
## (perfil do automático). Devolve {eventos, equipamento_final}.
static func simular(cfg: Dictionary, lado_j: Dictionary, lado_r: Dictionary, semente: int,
		perfil_rival: Dictionary, perfil_jogador: Dictionary) -> Dictionary:
	var j := Justa.new(cfg, lado_j, lado_r, semente, perfil_rival, perfil_jogador)
	var eventos: Array[Dictionary] = j.iniciar()
	var guarda := 0
	while not j.terminou() and guarda < 1000:
		eventos.append_array(j.avancar(1000))
		guarda += 1
	return {"eventos": eventos, "equipamento_final": j.equipamento_final(true)}

## Desafios especiais de um torneio (pve.json > desafios), aplicados antes
## da justa. Puro: devolve cópias {cfg, lado_jogador, lado_rival, perfil_rival}.
##   cavalo: o jogador usa este cavalo (emprestado) no lugar do dele;
##   remover_pecas: tira as peças do jogador (e do rival, se ambos);
##   galope_janela_pct: janela do compasso menor (chuva);
##   mira_oscilacao_pct: mão mais tremida na mira (noite);
##   ia_erro_mira_pct: erro de mira do rival (noite vale para os dois).
## Porcentagens em inteiros (x * pct / 100), igual no servidor.
static func aplicar_desafios(cfg: Dictionary, lado_j: Dictionary, lado_r: Dictionary, perfil_r: Dictionary,
		ids: Array, defs: Dictionary) -> Dictionary:
	var c := cfg.duplicate(true)
	var j := lado_j.duplicate(true)
	var r := lado_r.duplicate(true)
	var p := perfil_r.duplicate(true)
	for id in ids:
		var d: Dictionary = defs[id]
		if d.has("cavalo"):
			j["cavalo"] = (d["cavalo"] as Dictionary).duplicate()
		for peca in d.get("remover_pecas", []):
			(j.get("equipamento", {}) as Dictionary).erase(peca)
			if d.get("ambos", false):
				(r.get("equipamento", {}) as Dictionary).erase(peca)
		if d.has("galope_janela_pct"):
			var g: Dictionary = c["galope"]["galope"]
			var pct := int(d["galope_janela_pct"])
			for k in ["janela_base_ms", "janela_por_temperamento_milesimos", "janela_max_ms"]:
				g[k] = int(g[k]) * pct / 100
		if d.has("mira_oscilacao_pct"):
			var o: Dictionary = c["mira"]["oscilacao"]
			o["amplitude_px"] = int(o["amplitude_px"]) * int(d["mira_oscilacao_pct"]) / 100
		if d.has("ia_erro_mira_pct") and p.has("erro_mira_px"):
			p["erro_mira_px"] = int(p["erro_mira_px"]) * int(d["ia_erro_mira_pct"]) / 100
	return {"cfg": c, "lado_jogador": j, "lado_rival": r, "perfil_rival": p}

## Estilo de um campeão: o ajuste soma nos números do perfil da IA (sem
## passar de zero) e troca os textos (ex.: zona_preferida). Puro.
static func ajustar_perfil(perfil: Dictionary, ajuste: Dictionary) -> Dictionary:
	var p := perfil.duplicate(true)
	for k in ajuste:
		if typeof(ajuste[k]) in [TYPE_INT, TYPE_FLOAT] and p.has(k) and typeof(p[k]) in [TYPE_INT, TYPE_FLOAT]:
			p[k] = maxi(0, int(p[k]) + int(ajuste[k]))
		else:
			p[k] = ajuste[k]
	return p
