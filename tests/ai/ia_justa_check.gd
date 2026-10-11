extends SceneTree
## Justa com o rival controlado pela IA (Justa + IaRival): determinismo,
## diferenças entre os perfis medidas em várias sementes, e a gravação de
## referência tests/shared/justa_referencia_ia.json para o TypeScript.
## Regravar depois de mudar a regra de propósito:
##   TM_GRAVAR=1 timeout 120 bash .claude/skills/run-torneio-medieval/driver.sh script res://tests/ai/ia_justa_check.gd

const REFERENCIA := "res://tests/shared/justa_referencia_ia.json"
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
	_checa("a IA nao muda a bandeira (sorteio separado)", a["bandeiras"] == _jogar(3, "agressivo", true)["bandeiras"])

	# Estatística por perfil, com o jogador parado (não mira): só a IA pontua.
	var media := {}
	for nome: String in ["novato", "equilibrado", "agressivo"]:
		var pontos := 0
		var capacetes := 0
		var golpes := 0
		var no_tempo := 0
		var toques := 0
		for s in SEMENTES:
			var r := _jogar(1000 + s, nome, false)
			pontos += r["pontos_rival"]
			capacetes += r["zonas_rival"].count("capacete")
			golpes += r["zonas_rival"].size()
			no_tempo += r["no_tempo_rival"]
			toques += r["toques_rival"]
		media[nome] = {"pontos": float(pontos) / SEMENTES, "capacete": float(capacetes) / maxi(golpes, 1),
			"ritmo": float(no_tempo) / maxi(toques, 1)}
		print("IA_JUSTA perfil %s: %.2f pontos por justa, %.0f%% no capacete, %.0f%% dos toques no tempo" %
			[nome, media[nome]["pontos"], media[nome]["capacete"] * 100.0, media[nome]["ritmo"] * 100.0])
	_checa("novato pontua menos que equilibrado", media["novato"]["pontos"] < media["equilibrado"]["pontos"])
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

	print("IA_JUSTA %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

## Jogador-robô simples: larga 100 ms depois da bandeira, toca no compasso e,
## se `mira`, segura no peito e solta.
func _jogar(semente: int, perfil: String, mira: bool, lado_rival := {}) -> Dictionary:
	var j := Justa.new(_cfg, _lado, lado_rival if not lado_rival.is_empty() else _lado, semente, _perfis[perfil])
	var r := {"eventos": [], "entradas": [], "toques_rival": 0, "no_tempo_rival": 0, "largadas_rival": 0,
		"bandeiras": [], "zonas_rival": [], "pontos_rival": 0}
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
		"bandeiras": [], "zonas_rival": [], "pontos_rival": 0}
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
			"bandeira":
				r["bandeiras"].append(e["t"])
			"impacto":
				r["zonas_rival"].append(e["rival"]["zona"])

func _checa(nome: String, ok: bool) -> void:
	print("IA_JUSTA %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
