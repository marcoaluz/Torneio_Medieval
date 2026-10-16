class_name SimulacaoEconomia
extends RefCounted
## Modelo da economia (Pacote 3.12). Simula um jogador dia a dia, sessão a
## sessão, com os números de game/data/balance/ (economia, vila, treino,
## progressao, itens, inicio). Não roda a justa de verdade: cada justa vira
## uma chance de vitória pela diferença de poder
## (prob_base + prob_por_poder × (poder_jogador − poder_rival) + habilidade).
## Modela: PvE por região (torneios, disputas, campeão com projeto), liga
## (pontos, pareamento limitado por faixa de poder, defesas, temporada com
## reinício e baú), baús (4 espaços, um abrindo por vez, chave, garantia de
## raro, repetidas viram fragmentos), melhoria +1..+10, forja por projeto,
## peças sorteadas do catálogo real de itens.json como o RegraBau (raridade
## pelos pesos, depois um modelo entre os da raridade; conjunto completo =
## todas as peças daquele conjunto no catálogo),
## treino (vagas, custo, duração pelo nível), prédios (teto pela casa
## senhorial), fôlego do cavalo, missões, passe, VIP e anúncios.
## Determinístico: mesma semente, mesmo resultado (gerador Aleatorio).

const SEG_DIA := 86400
const ORDEM_RARIDADE := ["comum", "incomum", "raro", "epico", "lendario"]

var d: Dictionary
var eco: Dictionary
var p: Dictionary
var rng: Aleatorio

var dia := 0
var ouro := 0
var gemas := 0
var xp := 0
var nivel := 1
var atrib: Array = []
var equip := {}
var colecao := {}  ## modelo -> raridade
var fragmentos := 0
## Catálogo usado (modelos de itens.json). so_originais = só as peças dos
## conjuntos de economia.json > conjuntos (os 35 modelos de antes da 4.4),
## para separar o efeito do catálogo maior.
var so_originais := false
var catalogo := {}
var espacos: Array = []
var itens_bau := 0
var repetidas := 0
var raras_bau := 0
var sucata := 0
var lingotes := 0
var projetos: Array = []
var forja := {}
var baus: Array = []
var baus_perdidos := 0
var desde_raro := 0
var chaves := 0
var pontos := 0
var liga_temporada := 0
var regiao := 0
var torneio := 0
var disputa := 0
var predios := {}
var obra := {}
var treinos: Array = []
var folego := 100.0
var passe_xp := 0
var anuncios := {}
var marcos := {}
var diario: Array = []
var justas := 0
var vitorias := 0

func _init(dados: Dictionary) -> void:
	d = dados
	eco = dados["economia"]

## Lê os arquivos de balanceamento usados pelo modelo.
static func carregar() -> Dictionary:
	var r := {}
	for nome in ["economia", "vila", "treino", "progressao", "itens", "inicio"]:
		r[nome] = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/balance/%s.json" % nome))
	return r

## Roda um perfil por N dias. Devolve {marcos: {nome: dia}, diario: [...], resumo}.
func rodar(nome_perfil: String, semente: int) -> Dictionary:
	p = eco["perfis"][nome_perfil]
	rng = Aleatorio.new(semente)
	_estado_inicial()
	var dias: int = eco["simulacao"]["dias"]
	var sessoes: int = p["sessoes_dia"]
	var intervalo := SEG_DIA / sessoes
	var por_sessao := int(float(p["minutos_dia"]) / sessoes / float(eco["justa"]["minutos_por_justa"]))
	var seg_justa := int(float(eco["justa"]["minutos_por_justa"]) * 60.0)
	for dd in range(1, dias + 1):
		dia = dd
		_inicio_dia()
		for s in sessoes:
			_gerir()
			for j in por_sessao:
				_justar()
				_avancar(seg_justa)
				_gerir()
			_avancar(intervalo - por_sessao * seg_justa)
		_fim_dia()
	return {"marcos": marcos, "diario": diario, "resumo": {"justas": justas, "vitorias": vitorias, "baus_perdidos": baus_perdidos,
		"nivel": nivel, "poder": poder(), "ouro": ouro, "pontos": pontos,
		"itens_bau": itens_bau, "repetidas": repetidas, "raras_bau": raras_bau}}

# --- Estado ---------------------------------------------------------------

func _estado_inicial() -> void:
	var ini: Dictionary = d["inicio"]
	dia = 0
	ouro = int(ini["ouro"]) + int(ini["tutorial"]["ouro"])
	gemas = 0
	xp = 0
	nivel = 1
	_xp(int(ini["tutorial"]["xp"]))
	atrib = []
	for a in d["treino"]["atributos_cavaleiro"]:
		atrib.append(int(ini["cavaleiro"]["atributos"][a]))
	for a in d["treino"]["atributos_cavalo"]:
		atrib.append(int(ini["cavalo"]["atributos"][a]))
	equip = {}
	colecao = {}
	catalogo = {}
	var originais: Array = eco["conjuntos"].map(func(c): return c["nome"])
	for id: String in d["itens"]["modelos"]:
		var it: Dictionary = d["itens"]["modelos"][id]
		if not so_originais or originais.has(it["conjunto"]):
			catalogo[id] = it
	espacos = []
	for id: String in catalogo:
		if not espacos.has(catalogo[id]["espaco"]):
			espacos.append(catalogo[id]["espaco"])
	itens_bau = 0
	repetidas = 0
	raras_bau = 0
	for id in ini["itens"] + [ini["tutorial"]["item_bau"]]:
		_receber_peca(id)
	fragmentos = 0
	sucata = int(ini["materiais"]["sucata"])
	lingotes = 0
	projetos = []
	forja = {}
	baus = []
	baus_perdidos = 0
	desde_raro = 0
	chaves = 0
	pontos = 0
	liga_temporada = 0
	regiao = 0
	torneio = 0
	disputa = 0
	predios = {}
	for nome in ini["predios"]:
		predios[nome] = int(ini["predios"][nome])
	obra = {}
	treinos = []
	folego = float(d["treino"]["folego_cavalo"]["maximo"])
	passe_xp = 0
	anuncios = {}
	marcos = {}
	diario = []
	justas = 0
	vitorias = 0

func poder() -> float:
	var media := 0.0
	for a in atrib:
		media += a
	media /= atrib.size()
	var soma := media / 2.0
	for e in espacos:
		if equip.has(e):
			soma += _poder_peca(equip[e])
	return soma

func _poder_atrib() -> float:
	var media := 0.0
	for a in atrib:
		media += a
	return media / atrib.size() / 2.0

func _melhoria_media() -> float:
	var t := 0.0
	for e in equip:
		t += int(equip[e]["nivel"])
	return t / maxf(1.0, equip.size())

func _poder_peca(pc: Dictionary) -> float:
	return float(eco["poder_raridade"][pc["raridade"]]) + int(pc["nivel"]) * float(eco["poder_por_melhoria"])

func liga() -> int:
	var l: Dictionary = eco["ligas"]
	return mini(l["nomes"].size() - 1, pontos / (int(l["pontos_por_divisao"]) * l["divisoes"].size()))

func _chance(poder_rival: float, cansado: bool) -> float:
	var j: Dictionary = eco["justa"]
	var c: float = j["prob_base"] + j["prob_por_poder"] * (poder() - poder_rival) + float(p["habilidade"])
	if cansado:
		c -= float(j["penalidade_cansado"])
	return clampf(c, j["prob_min"], j["prob_max"])

func _sorte(chance: float) -> bool:
	return rng.chance_milesimos(int(round(chance * 1000.0)))

func _vip() -> bool:
	return p["vip"]

func _fator_timer() -> float:
	return 1.0 - float(eco["vip"]["timer_reducao_pct"]) / 100.0 if _vip() else 1.0

func _marco(nome: String) -> void:
	if not marcos.has(nome):
		marcos[nome] = dia

# --- Dia ------------------------------------------------------------------

func _inicio_dia() -> void:
	var m: Dictionary = eco["missoes"]
	ouro += int(m["ouro_dia"])
	fragmentos += int(m["fragmentos_dia"])
	if dia % 7 == 0:
		chaves += int(m["chave_semana"])
	anuncios = {}
	var uso: Dictionary = eco["simulacao"]["anuncios_uso"]
	var limite := int(p["anuncios_dia"])
	if _vip() and eco["vip"]["beneficio_anuncios"]:
		limite = int(eco["anuncios"]["limite_dia"])
	limite = mini(limite, int(eco["anuncios"]["limite_dia"]))
	for k in uso:
		var n := mini(int(uso[k]), limite)
		anuncios[k] = n
		limite -= n
	for i in anuncios.get("bau_madeira_extra", 0):
		_ganhar_bau("madeira")
	if _vip() and (dia - 1) % 30 == 0:
		gemas += int(eco["vip"]["gemas_mes"])

func _fim_dia() -> void:
	var l: Dictionary = eco["ligas"]
	# Defesas do fantasma: rivais de pontos parecidos.
	for i in int(l["defesas_por_dia"]):
		if _sorte(_chance(_poder_rival_liga(), false)):
			pontos += int(l["defesa_vencida"])
	_checar_liga()
	if dia % int(l["temporada_dias"]) == 0:
		var rec: Array = l["recompensa_temporada"]
		_ganhar_bau(rec[mini(liga_temporada, rec.size() - 1)])
		pontos = pontos * int(l["reinicio_pct"]) / 100
		liga_temporada = liga()
		passe_xp = 0
	diario.append({"dia": dia, "nivel": nivel, "poder": poder(), "poder_atrib": _poder_atrib(), "melhoria_media": _melhoria_media(), "ouro": ouro, "pontos": pontos, "liga": liga(),
		"regiao": regiao, "torneio": torneio, "fragmentos": fragmentos, "pecas": colecao.size(),
		"raras": colecao.values().filter(func(r): return ORDEM_RARIDADE.find(r) >= 2).size()})

func _checar_liga() -> void:
	var l := liga()
	liga_temporada = maxi(liga_temporada, l)
	for i in range(1, l + 1):
		_marco("liga_" + eco["ligas"]["nomes"][i])

# --- Justa ----------------------------------------------------------------

func _justar() -> void:
	var fc: Dictionary = d["treino"]["folego_cavalo"]
	var cansado := folego < float(fc["cansado_abaixo_de"])
	folego = maxf(0.0, folego - float(fc["gasto_por_justa"]))
	ouro = maxi(0, ouro - int(eco["justa"]["ouro_conserto_por_justa"]))
	justas += 1
	_passe(int(eco["passe"]["xp_por_justa"]))
	var regs: Array = eco["regioes"]
	var arena_nivel: int = d["vila"]["predios"]["arena"]["libera_nivel"]
	if regiao < regs.size() and nivel >= int(regs[regiao]["nivel_minimo"]):
		var c := _chance(_poder_rival_pve(), cansado)
		if c >= float(eco["simulacao"]["limiar_pve"]) or nivel < arena_nivel:
			if _sorte(c):
				_vitoria_pve()
			return
	if nivel < arena_nivel:
		return
	var l: Dictionary = eco["ligas"]
	if _sorte(_chance(_poder_rival_liga(), cansado)):
		vitorias += 1
		pontos += int(l["vitoria"])
		_ouro_vitoria(int(l["ouro_vitoria"]) + liga() * int(l["ouro_por_liga"]))
		_xp(int(l["xp_vitoria"]))
		sucata += int(eco["forja"]["sucata_por_vitoria"])
		if _sorte(float(eco["baus"]["chance_madeira_por_vitoria"])):
			_ganhar_bau("madeira")
	else:
		pontos = maxi(0, pontos + int(l["derrota"]))
	_checar_liga()

func _poder_rival_pve() -> float:
	var r: Dictionary = eco["regioes"][regiao]
	var total := int(r["torneios"]) * int(r["disputas"])
	var t := float(torneio * int(r["disputas"]) + disputa) / maxf(1.0, total - 1.0)
	return lerpf(float(r["poder_inicial"]), float(r["poder_final"]), t)

func _poder_rival_liga() -> float:
	var l: Dictionary = eco["ligas"]
	var pr: float = float(l["poder_rival_base"]) + pontos * float(l["poder_rival_por_ponto"])
	var faixa := float(l["faixa_poder"])
	return clampf(pr, poder() - faixa, poder() + faixa)

func _ouro_vitoria(valor: int) -> void:
	if anuncios.get("dobrar_vitoria", 0) > 0:
		anuncios["dobrar_vitoria"] -= 1
		valor *= int(eco["anuncios"]["dobrar_vitoria"])
	ouro += valor

func _vitoria_pve() -> void:
	vitorias += 1
	var r: Dictionary = eco["regioes"][regiao]
	_ouro_vitoria(int(r["ouro_vitoria"]))
	_xp(int(r["xp_vitoria"]))
	sucata += int(eco["forja"]["sucata_por_vitoria"])
	var b: Dictionary = eco["baus"]
	if b["ferro_por_tres_estrelas"] and _sorte(float(eco["justa"]["tres_estrelas_dada_vitoria"])):
		_ganhar_bau("ferro")
	elif _sorte(float(b["chance_madeira_por_vitoria"])):
		_ganhar_bau("madeira")
	disputa += 1
	if disputa < int(r["disputas"]):
		return
	disputa = 0
	torneio += 1
	ouro += int(r["ouro_torneio"])
	_xp(int(r["xp_torneio"]))
	if torneio < int(r["torneios"]):
		return
	# Campeão da região: baú de ouro e o projeto de um conjunto.
	if b["ouro_por_campeao"]:
		_ganhar_bau("ouro")
	if not projetos.has(r["projeto_campeao"]):
		projetos.append(r["projeto_campeao"])
	_marco("regiao_%s_fim" % r["nome"])
	regiao += 1
	torneio = 0

func _xp(n: int) -> void:
	xp += n
	var tab: Array = d["progressao"]["xp_por_nivel"]
	while nivel < tab.size() and xp >= int(tab[nivel]):
		nivel += 1
	for alvo in [5, 10, 15, 20]:
		if nivel >= alvo:
			_marco("nivel_%d" % alvo)

func _passe(n: int) -> void:
	var ps: Dictionary = eco["passe"]
	var antes := mini(int(ps["niveis"]), passe_xp / int(ps["xp_por_nivel"]))
	passe_xp += n
	var depois := mini(int(ps["niveis"]), passe_xp / int(ps["xp_por_nivel"]))
	for lv in range(antes + 1, depois + 1):
		var g: Dictionary = ps["gratis"]
		ouro += int(g["ouro_por_nivel"])
		if lv % int(g["bau_ferro_a_cada"]) == 0:
			_ganhar_bau("ferro")
		if not p["passe"]:
			continue
		var pr: Dictionary = ps["premium"]
		ouro += int(pr["ouro_por_nivel"])
		fragmentos += int(pr["fragmentos_por_nivel"])
		if lv % int(pr["bau_ferro_a_cada"]) == 0:
			_ganhar_bau("ferro")
		if lv % int(pr["bau_ouro_a_cada"]) == 0:
			_ganhar_bau("ouro")
		if (pr["projeto_nos_niveis"] as Array).any(func(x): return int(x) == lv):  # JSON: números vêm como float
			for c in eco["conjuntos"]:
				if c["raridade"] in ["raro", "epico"] and not projetos.has(c["nome"]):
					projetos.append(c["nome"])
					break

# --- Baús e peças -----------------------------------------------------------

func _ganhar_bau(tipo: String) -> void:
	if baus.size() >= int(eco["baus"]["espacos"]):
		baus_perdidos += 1
		return
	baus.append({"tipo": tipo, "resta": int(eco["baus"]["tipos"][tipo]["segundos"] * _fator_timer()), "abrindo": false})

func _abrir_bau(tipo: String) -> void:
	var b: Dictionary = eco["baus"]["tipos"][tipo]
	ouro += rng.inteiro(int(b["ouro"][0]), int(b["ouro"][1]))
	fragmentos += rng.inteiro(int(b["fragmentos"][0]), int(b["fragmentos"][1]))
	# Garantia (GDD): a cada N baús de ferro ou melhores, um item raro ou superior.
	var conta_garantia: bool = tipo != "madeira"
	if conta_garantia:
		desde_raro += 1
	for i in int(b["itens"]):
		var rar := _sortear(b["raridade"])
		if ORDEM_RARIDADE.find(rar) >= 2:
			desde_raro = 0
		elif conta_garantia and i == 0 and desde_raro >= int(eco["baus"]["garantia_raro_a_cada"]):
			rar = "raro"
			desde_raro = 0
		var pool := RegraBau.modelos_da_raridade(catalogo, rar)
		itens_bau += 1
		if ORDEM_RARIDADE.find(rar) >= 2:
			raras_bau += 1
		if not _receber_peca(pool[rng.inteiro(0, pool.size() - 1)]):
			repetidas += 1

func _sortear(pesos: Dictionary) -> String:
	var total := 0
	for k in pesos:
		total += int(pesos[k])
	var x := rng.inteiro(0, total - 1)
	for k in pesos:
		x -= int(pesos[k])
		if x < 0:
			return k
	return pesos.keys()[0]

## Recebe a peça (modelo do catálogo). Repetida vira fragmentos (devolve false).
func _receber_peca(modelo: String) -> bool:
	if colecao.has(modelo):
		fragmentos += int(eco["baus"]["fragmentos_por_repetida"])
		return false
	var it: Dictionary = d["itens"]["modelos"][modelo]
	var conjunto: String = it["conjunto"]
	var raridade: String = it["raridade"]
	colecao[modelo] = raridade
	var nova := {"conjunto": conjunto, "raridade": raridade, "nivel": 0}
	if not equip.has(it["espaco"]) or _poder_peca(nova) > _poder_peca(equip[it["espaco"]]):
		equip[it["espaco"]] = nova
	var completo := conjunto != ""
	for m in _pecas_do_conjunto(conjunto):
		if not colecao.has(m):
			completo = false
	if completo and dia > 0:
		var r := ORDEM_RARIDADE.find(raridade)
		if r >= 1:
			_marco("conjunto_incomum")
		if r >= 2:
			_marco("conjunto_raro")
	return true

## Modelos do conjunto no catálogo, em ordem alfabética ("" = avulsa, nenhum).
func _pecas_do_conjunto(conjunto: String) -> Array:
	if conjunto == "":
		return []
	var r: Array = catalogo.keys().filter(func(m): return catalogo[m]["conjunto"] == conjunto)
	r.sort()
	return r

# --- Gestão (no começo da sessão e entre justas) ---------------------------

func _gerir() -> void:
	var regs: Array = eco["regioes"]
	if regiao < regs.size() and nivel >= int(regs[regiao]["nivel_minimo"]):
		_marco("regiao_" + regs[regiao]["nome"])
	var f: Dictionary = eco["forja"]
	lingotes += sucata / int(f["lingote_por_sucata"])
	sucata = sucata % int(f["lingote_por_sucata"])
	_gerir_baus()
	_gerir_treino()
	_gerir_forja()
	_gerir_melhorias()
	_gerir_predios()

func _gerir_baus() -> void:
	while true:
		var aberto := -1
		for i in baus.size():
			if baus[i]["abrindo"] and baus[i]["resta"] <= 0:
				aberto = i
		if aberto < 0:
			break
		var tipo: String = baus[aberto]["tipo"]
		baus.remove_at(aberto)
		_abrir_bau(tipo)
	if baus.is_empty():
		return
	if chaves > 0:
		var maior := 0
		for i in baus.size():
			if baus[i]["resta"] > baus[maior]["resta"]:
				maior = i
		chaves -= 1
		var tipo: String = baus[maior]["tipo"]
		baus.remove_at(maior)
		_abrir_bau(tipo)
		if baus.is_empty():
			return
	var abrindo := -1
	for i in baus.size():
		if baus[i]["abrindo"]:
			abrindo = i
	if abrindo < 0:
		abrindo = 0
		for i in baus.size():
			if baus[i]["resta"] < baus[abrindo]["resta"]:
				abrindo = i
		baus[abrindo]["abrindo"] = true
	var b: Dictionary = baus[abrindo]
	if anuncios.get("cortar_timer", 0) > 0 and b["resta"] > 0:
		anuncios["cortar_timer"] -= 1
		b["resta"] -= int(eco["anuncios"]["cortar_minutos"]) * 60
	if gemas > 0 and b["resta"] > 0:
		var custo := int(ceil(b["resta"] / 3600.0)) * int(eco["vip"]["gemas_por_hora_bau"])
		if gemas >= custo:
			gemas -= custo
			b["resta"] = 0

func _tabela(pares: Array, n: int) -> int:
	var v := int(pares[0][1])
	for par in pares:
		if n >= int(par[0]):
			v = int(par[1])
	return v

func _gerir_treino() -> void:
	var t: Dictionary = d["treino"]
	# A vaga extra vem do campo de treino ou do VIP (a mesma vaga; não somam).
	var vagas := int(t["vagas"]["base"])
	if predios.get("campo_treino", 0) >= int(t["vagas"]["extra_no_nivel_do_predio"]):
		vagas += 1
	if _vip():
		vagas = maxi(vagas, int(t["vagas"]["base"]) + int(eco["vip"]["vaga_treino_extra"]))
	while treinos.size() < vagas:
		var custo := _tabela(t["custo_ouro_por_nivel"], nivel)
		var ocupados := treinos.map(func(x): return x["atrib"])
		var alvo := -1
		for i in atrib.size():
			if not ocupados.has(i) and (alvo < 0 or atrib[i] < atrib[alvo]):
				alvo = i
		if alvo < 0 or ouro < custo or atrib[alvo] >= int(t["teto_atributo"]):
			return
		ouro -= custo
		var dur := int(_tabela(t["duracao_por_nivel"], nivel) * _fator_timer())
		if dia == 1:
			dur = mini(dur, int(d["inicio"]["primeiro_dia"]["timer_max_s"]))
		treinos.append({"resta": dur, "atrib": alvo})

func _gerir_forja() -> void:
	var f: Dictionary = eco["forja"]
	if not forja.is_empty() and forja["resta"] <= 0:
		_receber_peca(forja["modelo"])
		forja = {}
	if not forja.is_empty() or nivel < int(d["vila"]["predios"]["armeiro"]["libera_nivel"]):
		return
	var reserva := int(eco["simulacao"]["reserva_ouro"])

	var melhor := {}
	for nome in projetos:
		for m in _pecas_do_conjunto(nome):
			if not colecao.has(m):
				var rar: String = catalogo[m]["raridade"]
				if melhor.is_empty() or ORDEM_RARIDADE.find(rar) > ORDEM_RARIDADE.find(melhor["raridade"]):
					melhor = {"modelo": m, "raridade": rar}
				break
	if melhor.is_empty():
		return
	# Receita da raridade em lingotes de ferro equivalentes (aço = aco_por_ferro ferros;
	# couro, tecido e ornamento ficam fora do modelo).
	var rec: Dictionary = f["receitas"][melhor["raridade"]]
	var custo_l := int(rec["materiais"].get("lingote_ferro", 0)) + int(rec["materiais"].get("lingote_aco", 0)) * int(f["aco_por_ferro"])
	if lingotes < custo_l or ouro < int(rec["ouro"]) + reserva:
		return
	lingotes -= custo_l
	ouro -= int(rec["ouro"])
	melhor["resta"] = int(int(rec["segundos"]) * _fator_timer())
	forja = melhor

func _gerir_melhorias() -> void:
	var m: Dictionary = eco["melhoria"]
	var reserva := int(eco["simulacao"]["reserva_ouro"])
	# Teto de melhoria segue o nível do armeiro (GDD Forja).
	var teto := mini(int(m["nivel_max"]), int(predios.get("armeiro", 0)) * int(m["teto_por_nivel_armeiro"]))
	while true:
		var alvo := ""
		for e in equip:
			if int(equip[e]["nivel"]) < teto and (alvo == "" or int(equip[e]["nivel"]) < int(equip[alvo]["nivel"])):
				alvo = e
		if alvo == "":
			return
		var n := int(equip[alvo]["nivel"])
		if fragmentos < int(m["custo_fragmentos"][n]) or ouro < int(m["custo_ouro"][n]) + reserva:
			return
		fragmentos -= int(m["custo_fragmentos"][n])
		ouro -= int(m["custo_ouro"][n])
		if rng.chance_milesimos(int(m["chance_sucesso_pct"][n]) * 10):
			equip[alvo]["nivel"] = n + 1

func _gerir_predios() -> void:
	if not obra.is_empty():
		if obra["resta"] > 0:
			return
		predios[obra["predio"]] = int(predios.get(obra["predio"], 0)) + 1
		obra = {}
	var v: Dictionary = d["vila"]["predios"]
	var casa := int(predios.get("casa_senhorial", 1))
	var reserva := int(eco["simulacao"]["reserva_ouro"])
	var escolha := ""
	var custo := 0
	for nome in d["vila"]["ordem"]:
		if nivel < int(v[nome]["libera_nivel"]):
			continue
		if not predios.has(nome):
			predios[nome] = 1
		var nv := int(predios[nome])
		if nv >= int(v[nome]["nivel_max"]) or (nome != "casa_senhorial" and nv >= casa):
			continue
		var c := int(v[nome]["melhoria"][nv - 1]["ouro"])
		if escolha == "" or c < custo:
			escolha = nome
			custo = c
	if escolha == "" or ouro < custo + reserva:
		return
	ouro -= custo
	obra = {"predio": escolha, "resta": int(int(v[escolha]["melhoria"][int(predios[escolha]) - 1]["segundos"]) * _fator_timer())}

# --- Tempo ----------------------------------------------------------------

func _avancar(seg: int) -> void:
	var t: Dictionary = d["treino"]
	for tr in treinos.duplicate():
		tr["resta"] -= seg
		if tr["resta"] <= 0:
			var i: int = tr["atrib"]
			atrib[i] = mini(int(t["teto_atributo"]), atrib[i] + int(t["ganho_pontos"]))
			treinos.erase(tr)
	if not obra.is_empty():
		obra["resta"] -= seg
	if not forja.is_empty():
		forja["resta"] -= seg
	for b in baus:
		if b["abrindo"]:
			b["resta"] -= seg
	var fc: Dictionary = t["folego_cavalo"]
	var taxa := float(fc["recupera_por_hora"]) * (1.0 + float(fc["bonus_recupera_por_nivel_estabulo_pct"]) * (int(predios.get("estabulo", 1)) - 1) / 100.0)
	if _vip():
		taxa *= 1.0 + float(eco["vip"]["folego_recuperacao_extra_pct"]) / 100.0
	folego = minf(float(fc["maximo"]), folego + taxa * seg / 3600.0)
