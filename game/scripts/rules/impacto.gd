class_name Impacto
extends RefCounted
## Regra do impacto da justa (pura, determinística). Resolve o choque de uma
## passada: o golpe do jogador no rival e o do rival no jogador.
##
## Entrada (`entrada`): {jogador: golpeador, rival: golpeador}, onde
##   golpeador = {
##     cavaleiro: {forca, precisao, equilibrio},
##     equipamento: {peca: {defesa?, bloqueio_milesimos?, poder?, precisao?, durabilidade}} (opcional),
##     habilidades: [{nome, ativa}] (opcional; nomes em impacto.json/habilidades;
##       no máximo uma ofensiva e uma defensiva). O formato antigo
##       habilidade: {nome, ativa} vale como lista de uma.
##     zona: "capacete" | "peito" | "escudo" | "cavalo" | "erro" (da Mira),
##     velocidade, velocidade_nominal (do galope, no fim da corrida),
##     ritmo_milesimos (0 a 1000),
##     largada: "perfeita" | "boa" | "ruim" (da passada de quem bate; sem
##       largada, ou com uma desconhecida, vale "ruim", como quem não largou),
##   }
## Saída: {jogador: resultado, rival: resultado}, onde resultado descreve o
## golpe DAQUELE lado no outro:
##   {zona, zona_final, bloqueado, bloqueio_por ("" | "habilidade" | "escudo"),
##    falta, pontos, chance_derrubar_milesimos, derrubou,
##    habilidade (a primeira em efeito de quem bate; "" se nenhuma),
##    habilidades (todas em efeito de quem bate), habilidade_bloqueio (a do
##    defensor que desviou; "" se não foi habilidade), dano: {peca: n}, dano_lanca}
##
## Regras (GDD): capacete 3, peito 2, escudo 1, erro 0. Cavalo é falta (perde
## pontos). Bloqueio desvia golpe no capacete/peito para o escudo. Derrubada:
## a largada de quem bate dá a base por zona e o teto (derrubada.por_largada);
## por cima, Força de quem bate contra Equilíbrio de quem leva, mais
## velocidade, ritmo, poder da lança e habilidade, menos a defesa da peça
## atingida; o teto suave usa o teto da largada. Peça com
## durabilidade 0 não dá bônus. Ciclo: cada habilidade tem uma família
## (investida, bloqueio ou golpe_pesado; a de um conjunto herda o ciclo da
## família) e anula as do outro lado da família que ela "vence". Bônus de
## habilidades em efeito somam (derrubada, dano); no bloqueio vale a maior
## chance entre as do defensor, num sorteio só. Campos opcionais (0 se faltar):
## exposicao_milesimos (quem a usa fica mais fácil de derrubar) e
## derrubada_reducao_milesimos (quem a tem fica mais difícil de derrubar), os
## dois somados na chance de derrubar o DONO da habilidade; precisao_bonus_pct
## é lido pela Justa (amplia as zonas da Mira de quem a tem).
##
## Ordem fixa dos sorteios (paridade com TypeScript): golpe do jogador e depois
## o do rival; em cada um, (1) bloqueio da habilidade do defensor, se houver,
## (2) bloqueio do escudo, se ainda não bloqueou, (3) derrubada. Cada sorteio
## acontece sempre que a zona permite, mesmo com chance 0. Só inteiros; toda
## divisão é feita com números não negativos.

const ERRO := "erro"
const QUALIDADES_LARGADA := ["perfeita", "boa", "ruim"]
## Largada que vale quando o golpeador não traz uma (não largou).
const LARGADA_SEM := "ruim"

## Base e teto da derrubada para a largada de quem bate.
static func derrubada_da_largada(cfg: Dictionary, largada: Variant) -> Dictionary:
	var pl: Dictionary = cfg["derrubada"]["por_largada"]
	return pl[largada] if largada is String and pl.has(largada) else pl[LARGADA_SEM]

static func validar(cfg: Dictionary) -> String:
	var grupos := {
		"pontos": [], "falta": ["zona", "penalidade_pontos", "faltas_para_desclassificar"],
		"bloqueio": ["zonas", "vira_zona", "base_milesimos", "teto_milesimos"],
		"derrubada": ["por_largada", "forca_menos_equilibrio_milesimos", "velocidade_por_pct_milesimos",
			"ritmo_max_milesimos", "poder_lanca_milesimos", "defesa_peca_milesimos"],
		"dano": ["base_por_zona", "peca_por_zona", "velocidade_por_pct_milesimos", "defesa_reduz_por_ponto_milesimos",
			"minimo", "lanca_por_contato"],
		"habilidades": [],
	}
	for g: String in grupos:
		if not cfg.get(g) is Dictionary:
			return "falta o grupo \"%s\"" % g
		for k: String in grupos[g]:
			if not cfg[g].has(k):
				return "falta \"%s.%s\"" % [g, k]
	for q in QUALIDADES_LARGADA:
		var pl: Variant = cfg["derrubada"]["por_largada"].get(q)
		if not pl is Dictionary or not pl.get("base_por_zona_milesimos") is Dictionary or not pl.has("teto_milesimos"):
			return "falta \"derrubada.por_largada.%s\" (base_por_zona_milesimos e teto_milesimos)" % q
	for k in ["teto_suave_joelho_pct", "habilidade_carga_ms"]:
		if not cfg.has(k):
			return "falta \"%s\"" % k
	for z in ["capacete", "peito", "escudo", "cavalo", ERRO]:
		if not cfg["pontos"].has(z):
			return "falta \"pontos.%s\"" % z
	for nome: String in cfg["habilidades"]:
		for k in ["vence", "tipo", "derrubada_bonus_milesimos", "dano_bonus_pct", "bloqueio_milesimos"]:
			if not cfg["habilidades"][nome].has(k):
				return "falta \"habilidades.%s.%s\"" % [nome, k]
		if not cfg["habilidades"].has(familia(cfg, nome)):
			return "familia desconhecida em \"habilidades.%s\"" % nome
	return ""

## Teto suave: até `joelho_pct` do teto passa inteiro; acima, cada ponto rende
## menos e o resultado se aproxima do teto sem passar. Negativo vira 0.
static func suave(valor: int, teto: int, joelho_pct: int) -> int:
	if valor <= 0 or teto <= 0:
		return 0
	var joelho := teto * joelho_pct / 100
	if valor <= joelho:
		return valor
	var excesso := valor - joelho
	var resto := teto - joelho
	if resto <= 0:
		return teto
	return joelho + excesso * resto / (excesso + resto)

## Atributo de uma peça equipada; 0 se a peça não existe ou está quebrada
## (durabilidade 0 perde os bônus, GDD).
static func stat(equipamento: Variant, peca: String, chave: String) -> int:
	if not equipamento is Dictionary or not equipamento.has(peca):
		return 0
	var p: Dictionary = equipamento[peca]
	if int(p.get("durabilidade", 0)) <= 0:
		return 0
	return int(p.get(chave, 0))

## Precisão usada na Mira: a do cavaleiro mais a da lança.
static func precisao_efetiva(lado: Dictionary) -> int:
	return int(lado["cavaleiro"]["precisao"]) + stat(lado.get("equipamento"), "lanca", "precisao")

## Família de uma habilidade (a dela mesma, se não disser).
static func familia(cfg: Dictionary, nome: String) -> String:
	return str(cfg["habilidades"][nome].get("familia", nome))

## Habilidades em efeito para `lado`, na ordem dele: ativas e não anuladas
## por nenhuma das ativas do outro.
static func habilidades_em_efeito(cfg: Dictionary, lado: Dictionary, outro: Dictionary) -> Array[String]:
	var minhas := _ativas(cfg, lado)
	var dele := _ativas(cfg, outro)
	var res: Array[String] = []
	for h in minhas:
		var anulada := false
		for o in dele:
			if cfg["habilidades"][o]["vence"] == familia(cfg, h):
				anulada = true
		if not anulada:
			res.append(h)
	return res

## A primeira em efeito ("" se nenhuma); compatível com a versão de uma só.
static func habilidade_em_efeito(cfg: Dictionary, lado: Dictionary, outro: Dictionary) -> String:
	var hs := habilidades_em_efeito(cfg, lado, outro)
	return hs[0] if not hs.is_empty() else ""

static func _ativas(cfg: Dictionary, lado: Dictionary) -> Array[String]:
	var lista: Array = []
	if lado.get("habilidades") is Array:
		lista = lado["habilidades"]
	elif lado.get("habilidade") is Dictionary:
		lista = [lado["habilidade"]]
	var res: Array[String] = []
	for h: Variant in lista:
		if h is Dictionary and h.get("ativa", false) and cfg["habilidades"].has(str(h.get("nome", ""))):
			res.append(str(h["nome"]))
	return res

static func resolver(cfg: Dictionary, entrada: Dictionary, rng: Aleatorio) -> Dictionary:
	var j: Dictionary = entrada["jogador"]
	var r: Dictionary = entrada["rival"]
	var hj := habilidades_em_efeito(cfg, j, r)
	var hr := habilidades_em_efeito(cfg, r, j)
	var res_j := _golpe(cfg, j, r, hj, hr, rng)
	var res_r := _golpe(cfg, r, j, hr, hj, rng)
	return {"jogador": res_j, "rival": res_r}

static func _soma(cfg: Dictionary, hs: Array[String], chave: String) -> int:
	var t := 0
	for h in hs:
		t += int(cfg["habilidades"][h].get(chave, 0))
	return t

## Golpe de `a` (com as habilidades `ha` em efeito) em `d` (com `hd`).
static func _golpe(cfg: Dictionary, a: Dictionary, d: Dictionary, ha: Array[String], hd: Array[String], rng: Aleatorio) -> Dictionary:
	var zona: String = a.get("zona", ERRO)
	var r := {"zona": zona, "zona_final": zona, "bloqueado": false, "bloqueio_por": "", "falta": false,
		"pontos": 0, "chance_derrubar_milesimos": 0, "derrubou": false, "habilidade": ha[0] if not ha.is_empty() else "",
		"habilidades": ha.duplicate(), "habilidade_bloqueio": "", "dano": {}, "dano_lanca": 0}
	if zona == ERRO or not cfg["pontos"].has(zona):
		r["zona"] = ERRO
		r["zona_final"] = ERRO
		return r
	var joelho := int(cfg["teto_suave_joelho_pct"])
	var equip_d: Variant = d.get("equipamento")
	var equip_a: Variant = a.get("equipamento")

	if zona == cfg["falta"]["zona"]:
		r["falta"] = true
		r["pontos"] = -int(cfg["falta"]["penalidade_pontos"])
		_aplicar_dano(cfg, r, a, d, zona, [] as Array[String])
		return r

	# Bloqueio: primeiro a habilidade do defensor, depois o escudo.
	var b: Dictionary = cfg["bloqueio"]
	if b["zonas"].has(zona):
		var hb := ""
		for h in hd:
			var bh := int(cfg["habilidades"][h]["bloqueio_milesimos"])
			if bh > 0 and (hb == "" or bh > int(cfg["habilidades"][hb]["bloqueio_milesimos"])):
				hb = h
		if hb != "":
			if rng.chance_milesimos(int(cfg["habilidades"][hb]["bloqueio_milesimos"])):
				r["bloqueado"] = true
				r["bloqueio_por"] = "habilidade"
				r["habilidade_bloqueio"] = hb
		if not r["bloqueado"]:
			var chance := suave(int(b["base_milesimos"]) + stat(equip_d, "escudo", "bloqueio_milesimos"),
				int(b["teto_milesimos"]), joelho)
			if rng.chance_milesimos(chance):
				r["bloqueado"] = true
				r["bloqueio_por"] = "escudo"
		if r["bloqueado"]:
			r["zona_final"] = b["vira_zona"]
	var zf: String = r["zona_final"]
	r["pontos"] = int(cfg["pontos"][zf])

	# Derrubada.
	var dr: Dictionary = cfg["derrubada"]
	var dl := derrubada_da_largada(cfg, a.get("largada", LARGADA_SEM))
	if dl["base_por_zona_milesimos"].has(zf):
		var peca: String = cfg["dano"]["peca_por_zona"].get(zf, "")
		var vel_pct := _velocidade_pct(a)
		var chance := int(dl["base_por_zona_milesimos"][zf])
		chance += (int(a["cavaleiro"]["forca"]) - int(d["cavaleiro"]["equilibrio"])) * int(dr["forca_menos_equilibrio_milesimos"])
		chance += (vel_pct - 100) * int(dr["velocidade_por_pct_milesimos"])
		chance += int(dr["ritmo_max_milesimos"]) * clampi(int(a.get("ritmo_milesimos", 0)), 0, 1000) / 1000
		chance += stat(equip_a, "lanca", "poder") * int(dr["poder_lanca_milesimos"])
		chance -= stat(equip_d, peca, "defesa") * int(dr["defesa_peca_milesimos"])
		chance += _soma(cfg, ha, "derrubada_bonus_milesimos")
		chance += _soma(cfg, hd, "exposicao_milesimos")  # o defensor arriscou (golpe do campeão)
		chance -= _soma(cfg, hd, "derrubada_reducao_milesimos")  # o defensor segura melhor (fantasma do corcel)
		chance = suave(chance, int(dl["teto_milesimos"]), joelho)
		r["chance_derrubar_milesimos"] = chance
		r["derrubou"] = rng.chance_milesimos(chance)

	_aplicar_dano(cfg, r, a, d, zf, ha)
	return r

## Velocidade no choque em % da nominal (100 = nominal).
static func _velocidade_pct(a: Dictionary) -> int:
	var nominal := int(a.get("velocidade_nominal", 0))
	if nominal <= 0:
		return 100
	return maxi(int(a.get("velocidade", nominal)), 0) * 100 / nominal

static func _aplicar_dano(cfg: Dictionary, r: Dictionary, a: Dictionary, d: Dictionary, zona: String, ha: Array[String]) -> void:
	var dn: Dictionary = cfg["dano"]
	if not dn["base_por_zona"].has(zona):
		return
	var peca: String = dn["peca_por_zona"][zona]
	var extra := maxi(_velocidade_pct(a) - 100, 0)
	var dano := int(dn["base_por_zona"][zona]) * (1000 + extra * int(dn["velocidade_por_pct_milesimos"])) / 1000
	if not ha.is_empty():
		dano = dano * (100 + _soma(cfg, ha, "dano_bonus_pct")) / 100
	var reducao := stat(d.get("equipamento"), peca, "defesa") * int(dn["defesa_reduz_por_ponto_milesimos"]) / 1000
	r["dano"] = {peca: maxi(dano - reducao, int(dn["minimo"]))}
	r["dano_lanca"] = int(dn["lanca_por_contato"])
