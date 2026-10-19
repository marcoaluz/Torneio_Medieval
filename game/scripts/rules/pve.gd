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

## Revanche heroica (pve.json > revanche): o campeão já vencido volta mais
## forte. Devolve uma cópia de `r` com os atributos do cavaleiro e do cavalo
## + bonus (bonus_atributos + bonus_por_vitoria × revanches já vencidas, até
## bonus_max; nenhum passa de teto_atributo) e o perfil_ajuste da revanche
## somado ao do campeão (números somam; textos trocam). Puro.
static func rival_revanche(r: Dictionary, cfg: Dictionary, vitorias: int) -> Dictionary:
	var saida := r.duplicate(true)
	var bonus := mini(int(cfg["bonus_atributos"]) + int(cfg["bonus_por_vitoria"]) * maxi(vitorias, 0), int(cfg["bonus_max"]))
	var teto := int(cfg["teto_atributo"])
	for parte in ["cavaleiro", "cavalo"]:
		var atr: Dictionary = saida[parte]
		var nomes: Array = atr.keys()
		nomes.sort()
		for k: String in nomes:
			atr[k] = mini(int(atr[k]) + bonus, teto)
	var ajuste: Dictionary = saida.get("perfil_ajuste", {})
	var extra: Dictionary = cfg.get("perfil_ajuste", {})
	var chaves: Array = extra.keys()
	chaves.sort()
	for k: String in chaves:
		if k.begins_with("_"):
			continue
		if typeof(extra[k]) in [TYPE_INT, TYPE_FLOAT] and typeof(ajuste.get(k)) in [TYPE_INT, TYPE_FLOAT]:
			ajuste[k] = int(ajuste[k]) + int(extra[k])
		else:
			ajuste[k] = extra[k]
	saida["perfil_ajuste"] = ajuste
	return saida

## Faixa da ficha do adversário pelo poder dos dois (pve.json > ficha):
## quanto o rival é mais forte, em % do poder do jogador (inteiro, trunca);
## até verde_max_pct é "verde", até amarelo_max_pct "amarelo", acima "vermelho".
static func faixa_poder(poder_jogador: int, poder_rival: int, cfg: Dictionary) -> String:
	var dif := (poder_rival - poder_jogador) * 100 / maxi(poder_jogador, 1)
	if dif <= int(cfg["verde_max_pct"]):
		return "verde"
	if dif <= int(cfg["amarelo_max_pct"]):
		return "amarelo"
	return "vermelho"

## Estilo de um campeão: o ajuste soma nos números do perfil da IA (sem
## passar de zero) e troca os textos (ex.: zona_preferida). Puro. O traço
## de luta de cada campeão (pve.json > tracos) é feito só com o perfil_ajuste
## e a habilidade dele; tests/rules/tracos_check.gd confere que aparece.
## Perfil da IA de um rival do PvE: o do perfil dele, mais ajuste_campeao se
## for campeão, mais o perfil_ajuste dele (ia = ia_rival.json; r = pve.json > rivais).
static func perfil_do_rival(ia: Dictionary, r: Dictionary) -> Dictionary:
	var p: Dictionary = ia["perfis"][r["perfil"]]
	if r.get("campeao", false):
		p = ajustar_perfil(p, ia["ajuste_campeao"])
	return ajustar_perfil(p, r.get("perfil_ajuste", {}))

static func ajustar_perfil(perfil: Dictionary, ajuste: Dictionary) -> Dictionary:
	var p := perfil.duplicate(true)
	for k in ajuste:
		if str(k).begins_with("_"):
			continue  # nota
		if typeof(ajuste[k]) in [TYPE_INT, TYPE_FLOAT] and p.has(k) and typeof(p[k]) in [TYPE_INT, TYPE_FLOAT]:
			p[k] = maxi(0, int(p[k]) + int(ajuste[k]))
		else:
			p[k] = ajuste[k]
	return p
