extends SceneTree
## Justa com o rival controlado pela IA (Justa + IaRival): determinismo,
## diferenças entre os perfis medidas em várias sementes, e a gravação de
## referência tests/shared/justa_referencia_ia.json para o TypeScript.
## Regravar depois de mudar a regra de propósito:
##   TM_GRAVAR=1 timeout 120 bash .claude/skills/run-torneio-medieval/driver.sh script res://tests/ai/ia_justa_check.gd

const REFERENCIA := "res://tests/shared/justa_referencia_ia.json"
## Rival "paciente" (traço dos campeões): habilidade_passada 3 no perfil.
const REFERENCIA_PACIENTE := "res://tests/shared/justa_referencia_ia_paciente.json"
const PEITO := Vector2i(-50, -1060)
const SEMENTES := 40

var _falhas := 0
var _cfg: Dictionary
var _lado: Dictionary
var _perfis: Dictionary

func _initialize() -> void:
	_cfg = Justa.carregar_configuracao()
	var padrao := Balanceamento.carregar("padrao")
	_lado = {"cavaleiro": padrao["cavaleiro"], "cavalo": padrao["cavalo"]}
	_perfis = Balanceamento.carregar("ia_rival")["perfis"]

	var a := _jogar(3, "equilibrado", true)
	var b := _jogar(3, "equilibrado", true)
	_checa("mesma semente com IA = mesma justa", a["eventos"] == b["eventos"])
	_checa("a IA toca no galope (%d toques)" % a["toques_rival"], a["toques_rival"] > 0)
	_checa("a IA larga", a["largadas_rival"] > 0)
	# Outro perfil pode derrubar antes (menos passadas): compara as passadas que as duas tiveram.
	var outra: Array = _jogar(3, "agressivo", true)["bandeiras"]
	var n := mini(a["bandeiras"].size(), outra.size())
	_checa("a IA nao muda a bandeira (sorteio separado)", n > 0 and a["bandeiras"].slice(0, n) == outra.slice(0, n))

	# Estatística por perfil, com o jogador parado (não mira): só a IA pontua.
	# Por golpe, não por justa: quem derruba encerra a justa antes (menos passadas).
	var media := {}
	for nome: String in ["novato", "equilibrado", "agressivo"]:
		var pontos := 0
		var capacetes := 0
		var golpes := 0
		var no_tempo := 0
		var toques := 0
		var derrubadas := 0
		var perfeitas := 0
		var largadas := 0
		for s in SEMENTES:
			var r := _jogar(1000 + s, nome, false)
			pontos += r["pontos_rival"]
			capacetes += r["zonas_rival"].count("capacete")
			golpes += r["zonas_rival"].size()
			no_tempo += r["no_tempo_rival"]
			toques += r["toques_rival"]
			derrubadas += r["derrubadas_rival"]
			perfeitas += r["largadas_rival_perfeitas"]
			largadas += r["largadas_rival"]
		media[nome] = {"pontos": float(pontos) / maxi(golpes, 1), "capacete": float(capacetes) / maxi(golpes, 1),
			"ritmo": float(no_tempo) / maxi(toques, 1), "derrubada": float(derrubadas) / maxi(golpes, 1),
			"perfeita": float(perfeitas) / maxi(largadas, 1)}
		print("IA_JUSTA perfil %s: %.2f pontos por golpe, %.0f%% no capacete, %.0f%% dos toques no tempo, %.0f%% de largadas perfeitas, %.0f%% dos golpes derrubam" %
			[nome, media[nome]["pontos"], media[nome]["capacete"] * 100.0, media[nome]["ritmo"] * 100.0,
			media[nome]["perfeita"] * 100.0, media[nome]["derrubada"] * 100.0])
	_checa("novato pontua menos por golpe que equilibrado", media["novato"]["pontos"] < media["equilibrado"]["pontos"])
	_checa("novato larga perfeito menos que equilibrado, e este menos que agressivo",
		media["novato"]["perfeita"] < media["equilibrado"]["perfeita"] and media["equilibrado"]["perfeita"] < media["agressivo"]["perfeita"])
	_checa("novato derruba menos por golpe que equilibrado", media["novato"]["derrubada"] < media["equilibrado"]["derrubada"])
	_checa("novato acerta menos o compasso", media["novato"]["ritmo"] < media["equilibrado"]["ritmo"])
	_checa("agressivo mira no capacete", media["agressivo"]["capacete"] > 0.5 and media["equilibrado"]["capacete"] < 0.2)

	# Referência compartilhada.
	var com_hab := _lado.duplicate(true)
	com_hab["habilidade"] = "investida"
	var r_ref := _jogar(7, "agressivo", true, com_hab)
	var ref := {"versao": 1,
		"descricao": "Justa com IA (game/scripts/rules/justa.gd + game/scripts/ai/ia_rival.gd), gravada pelo GDScript. Repita: Justa(config, lado_jogador, lado_rival, semente, perfil); iniciar(); para cada entrada [t, acao, x, y] avance ate t e aplique (tocar | mirar x y | soltar); avance ate o fim. Eventos: tipo|chave=valor ordenados.",
		"config": _cfg, "lado_jogador": _lado, "lado_rival": com_hab, "perfil": _perfis["agressivo"], "semente": 7,
		"entradas": r_ref["entradas"], "eventos": r_ref["eventos"]}
	if OS.get_environment("TM_GRAVAR") == "1" or not FileAccess.file_exists(REFERENCIA):
		var f := FileAccess.open(REFERENCIA, FileAccess.WRITE)
		f.store_string(JSON.stringify(ref, "\t") + "\n")
		f.close()
		print("IA_JUSTA referencia gravada em %s" % REFERENCIA)
	var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REFERENCIA))
	var j := Justa.new(g["config"], g["lado_jogador"], g["lado_rival"], int(g["semente"]), g["perfil"])
	_checa("referencia com IA reproduz", _repetir(j, g["entradas"]) == g["eventos"])

	# Paciente: a ativa do rival só sai da 3ª passada em diante (nunca antes).
	var paciente: Dictionary = _perfis["agressivo"].duplicate(true)
	paciente["habilidade_passada"] = 3
	_perfis["paciente"] = paciente
	var passadas_hab: Array = []
	var chegaram := 0
	for s in SEMENTES:
		var rp := _jogar(2000 + s, "paciente", true, com_hab)
		var maior := 0
		for ev: String in rp["eventos"]:
			if ev.begins_with("impacto|"):
				maior = maxi(maior, int(ev.split("passada=")[1].split("|")[0]))
			if ev.begins_with("habilidade|") and ev.contains("lado=rival"):
				passadas_hab.append(int(ev.split("passada=")[1].split("|")[0]))
		if maior >= 3:
			chegaram += 1
	_checa("paciente: a ativa do rival nunca sai antes da 3a passada", passadas_hab.all(func(p): return p >= 3))
	_checa("paciente: e sai em toda justa que chega a 3a passada (%d de %d)" % [passadas_hab.size(), chegaram], passadas_hab.size() == chegaram and chegaram > 0)
	var seed_p := 2000
	for s in SEMENTES:
		var rp := _jogar(2000 + s, "paciente", true, com_hab)
		if rp["eventos"].any(func(ev: String): return ev.begins_with("habilidade|") and ev.contains("lado=rival")):
			seed_p = 2000 + s
			break
	var r_pac := _jogar(seed_p, "paciente", true, com_hab)
	var ref_p := {"versao": 1,
		"descricao": "Como justa_referencia_ia.json, com o perfil do rival com habilidade_passada 3 (traco paciente dos campeoes): a ativa so sai da 3a passada.",
		"config": _cfg, "lado_jogador": _lado, "lado_rival": com_hab, "perfil": paciente, "semente": seed_p,
		"entradas": r_pac["entradas"], "eventos": r_pac["eventos"]}
	if OS.get_environment("TM_GRAVAR") == "1" or not FileAccess.file_exists(REFERENCIA_PACIENTE):
		var fp := FileAccess.open(REFERENCIA_PACIENTE, FileAccess.WRITE)
		fp.store_string(JSON.stringify(ref_p, "	") + "
")
		fp.close()
		print("IA_JUSTA referencia do paciente gravada em %s" % REFERENCIA_PACIENTE)
	var gp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REFERENCIA_PACIENTE))
	var jp := Justa.new(gp["config"], gp["lado_jogador"], gp["lado_rival"], int(gp["semente"]), gp["perfil"])
	_checa("referencia do paciente reproduz", _repetir(jp, gp["entradas"]) == gp["eventos"])

	print("IA_JUSTA %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

## Jogador-robô simples: larga 100 ms depois da bandeira, toca no compasso e,
## se `mira`, segura no peito e solta.
func _jogar(semente: int, perfil: String, mira: bool, lado_rival := {}) -> Dictionary:
	var j := Justa.new(_cfg, _lado, lado_rival if not lado_rival.is_empty() else _lado, semente, _perfis[perfil])
	var r := {"eventos": [], "entradas": [], "toques_rival": 0, "no_tempo_rival": 0, "largadas_rival": 0,
		"bandeiras": [], "zonas_rival": [], "pontos_rival": 0, "largadas_rival_perfeitas": 0, "derrubadas_rival": 0}
	_anotar(r, j.iniciar())
	while not j.terminou():
		var t := j.fases.tempo_total_ms
		match j.fases.fase:
			JustaFases.Fase.LARGADA:
				if not j.tocou_largada and j.bandeira_baixou and j.fases.tempo_na_fase_ms == j.bandeira_ms + 100:
					r["entradas"].append([t, "tocar", 0, 0])
					_anotar(r, j.tocar())
			JustaFases.Fase.CORRIDA:
				if j.jogador.t_ms > 0 and j.jogador.t_ms % j.jogador.compasso_ms() == 0:
					r["entradas"].append([t, "tocar", 0, 0])
					_anotar(r, j.tocar())
			JustaFases.Fase.MIRA:
				if mira and j.fases.tempo_na_fase_ms == 100:
					r["entradas"].append([t, "mirar", PEITO.x, PEITO.y])
					j.mirar(PEITO)
				elif mira and j.fases.tempo_na_fase_ms == 900:
					r["entradas"].append([t, "soltar", 0, 0])
					_anotar(r, j.soltar())
		_anotar(r, j.avancar(1))
	r["pontos_rival"] = j.fases.placar_rival
	return r

func _repetir(j: Justa, entradas: Array) -> Array:
	var r := {"eventos": [], "entradas": [], "toques_rival": 0, "no_tempo_rival": 0, "largadas_rival": 0,
		"bandeiras": [], "zonas_rival": [], "pontos_rival": 0, "largadas_rival_perfeitas": 0, "derrubadas_rival": 0}
	_anotar(r, j.iniciar())
	for e: Array in entradas + [[1 << 40, "fim", 0, 0]]:
		while j.fases.tempo_total_ms < int(e[0]) and not j.terminou():
			_anotar(r, j.avancar(int(e[0]) - j.fases.tempo_total_ms))
		if j.terminou():
			break
		match e[1]:
			"tocar": _anotar(r, j.tocar())
			"mirar": j.mirar(Vector2i(int(e[2]), int(e[3])))
			"soltar": _anotar(r, j.soltar())
	return r["eventos"]

func _anotar(r: Dictionary, eventos: Array[Dictionary]) -> void:
	for e in eventos:
		var chaves: Array = e.keys()
		chaves.sort()
		var partes: Array[String] = [str(e["tipo"])]
		for k in chaves:
			if k != "tipo":
				partes.append("%s=%s" % [k, e[k]])
		r["eventos"].append("|".join(partes))
		match e["tipo"]:
			"toque_rival":
				if e["resultado"] != "perdido":
					r["toques_rival"] += 1
				if e["resultado"] == "no_tempo":
					r["no_tempo_rival"] += 1
			"largada_rival":
				r["largadas_rival"] += 1
				if e["qualidade"] == "perfeita":
					r["largadas_rival_perfeitas"] += 1
			"fase":
				if e.get("fase") == JustaFases.Fase.LARGADA:
					r["largada_t"] = e["t"]
			"bandeira":
				# Instante dentro da largada (o tempo absoluto muda com o ritmo de cada perfil).
				r["bandeiras"].append(e["t"] - int(r.get("largada_t", 0)))
			"impacto":
				r["zonas_rival"].append(e["rival"]["zona"])
				if e["rival"]["derrubou"]:
					r["derrubadas_rival"] += 1

func _checa(nome: String, ok: bool) -> void:
	print("IA_JUSTA %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
