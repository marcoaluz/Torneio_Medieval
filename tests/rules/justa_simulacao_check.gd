extends SceneTree
## Justa completa (regra pura Justa): determinismo, independência do tamanho
## do passo, propriedades da largada, do galope e da mira, e a gravação de
## referência tests/shared/justa_referencia.json (semente + entradas com
## instante -> eventos), que a versão TypeScript deve reproduzir.
## Para regravar depois de mudar a regra de propósito:
##   TM_GRAVAR=1 timeout 60 bash .claude/skills/run-torneio-medieval/driver.sh script res://tests/rules/justa_simulacao_check.gd

const REFERENCIA := "res://tests/shared/justa_referencia.json"
## Centro do peito do alvo em décimos de px (ver mira.json).
const PEITO := Vector2i(0, -1060)
const CAPACETE := Vector2i(0, -1390)

var _falhas := 0
var _cfg: Dictionary
var _lado: Dictionary

func _initialize() -> void:
	_cfg = Justa.carregar_configuracao()
	_checa("dados validos juntos", Justa.validar(_cfg) == "")
	var padrao := Balanceamento.carregar("padrao")
	_lado = {"cavaleiro": padrao["cavaleiro"], "cavalo": padrao["cavalo"]}

	# Robô padrão: larga 100 ms depois da bandeira, toca no compasso e mira no peito.
	var r1 := _jogar(7, _lado, {})
	var r2 := _jogar(7, _lado, {})
	_checa("mesma semente e mesmas entradas = mesmos eventos", r1["eventos"] == r2["eventos"])
	var r3 := _jogar(8, _lado, {})
	_checa("semente diferente muda a bandeira", r1["bandeiras"] != r3["bandeiras"])

	var rep := _repetir(7, _lado, r1["entradas"], 0)
	_checa("repetir as entradas gravadas reproduz a justa", rep == r1["eventos"])
	_checa("picado em 1 ms da o mesmo", _repetir(7, _lado, r1["entradas"], 1) == r1["eventos"])
	_checa("picado em 33 ms da o mesmo", _repetir(7, _lado, r1["entradas"], 33) == r1["eventos"])

	# Largada e galope.
	var bom := _jogar(3, _lado, {"largada": 80})
	var parado := _jogar(3, _lado, {"largada": null, "galope": null, "mira": null})
	_checa("largada 80 ms depois da bandeira e perfeita", bom["largadas"][0] == "perfeita")
	_checa("sem tocar na largada e ruim", parado["largadas"][0] == "ruim")
	var queima := _jogar(3, _lado, {"largada": -50, "galope": null})
	_checa("tocar antes da bandeira queima a largada", queima["largadas"][0] == "ruim" and queima["queimadas"][0])
	_checa("quem toca no compasso chega antes (%d ms x %d ms)" % [bom["corridas_ms"][0], parado["corridas_ms"][0]],
		bom["corridas_ms"][0] < parado["corridas_ms"][0])
	_checa("corrida normal dura entre 3,5 e 5,5 s (%d ms)" % bom["corridas_ms"][0],
		bom["corridas_ms"][0] >= 3500 and bom["corridas_ms"][0] <= 5500)
	_checa("ritmo perfeito = 1000", bom["ritmos"][0] == 1000)
	var fora := _jogar(3, _lado, {"galope": 200})
	_checa("tocar sempre fora do tempo gasta folego", fora["folego_final"] < bom["folego_final"])
	var lento := {"cavaleiro": _lado["cavaleiro"], "cavalo": {"velocidade": 0, "folego": 50, "temperamento": 50}}
	var rapido := {"cavaleiro": _lado["cavaleiro"], "cavalo": {"velocidade": 100, "folego": 50, "temperamento": 50}}
	_checa("cavalo com mais Velocidade chega antes",
		_jogar(3, rapido, {})["corridas_ms"][0] < _jogar(3, lento, {})["corridas_ms"][0])

	# Mira.
	_checa("mirar no peito e soltar acerta o peito", bom["golpes"][0] == "peito:solto")
	_checa("sem tocar na mira e erro sem golpe", parado["golpes"][0] == "erro:sem_golpe")
	var segura := _jogar(3, _lado, {"mira": PEITO, "solta": false})
	_checa("segurar ate o fim golpeia sozinho", segura["golpes"][0] == "peito:automatico")
	var cap := _jogar(3, _lado, {"mira": CAPACETE})
	_checa("mirar no capacete acerta o capacete", cap["golpes"][0] == "capacete:solto")
	var fora_cap := CAPACETE + Vector2i(-125, 0)
	var sem_prec := {"cavaleiro": {"forca": 50, "precisao": 0, "equilibrio": 50}, "cavalo": _lado["cavalo"]}
	var com_prec := {"cavaleiro": {"forca": 50, "precisao": 100, "equilibrio": 50}, "cavalo": _lado["cavalo"]}
	_checa("sem precisao, um pouco fora do capacete erra",
		_jogar(3, sem_prec, {"largada": 300, "mira": fora_cap})["golpes"][0] == "erro:solto")
	_checa("com precisao, o mesmo ponto acerta o capacete",
		_jogar(3, com_prec, {"largada": 300, "mira": fora_cap})["golpes"][0] == "capacete:solto")
	_checa("largada perfeita alarga a zona (bonus)",
		_jogar(3, sem_prec, {"largada": 80, "mira": CAPACETE + Vector2i(-110, 0)})["golpes"][0] == "capacete:solto")

	# Referência compartilhada.
	var ref := {"versao": 2,
		"descricao": "Justa completa (game/scripts/rules/justa.gd) gravada pelo GDScript. Repita: Justa(config, lado, lado, semente); iniciar(); para cada entrada [t, acao, x, y] avance ate t e aplique (tocar | mirar x y | soltar); avance ate o fim. Eventos: tipo|chave=valor ordenados.",
		"config": _cfg, "lado": _lado, "semente": 7,
		"entradas": r1["entradas"], "eventos": r1["eventos"]}
	if OS.get_environment("TM_GRAVAR") == "1" or not FileAccess.file_exists(REFERENCIA):
		var f := FileAccess.open(REFERENCIA, FileAccess.WRITE)
		f.store_string(JSON.stringify(ref, "\t") + "\n")
		f.close()
		print("JUSTA_SIM referencia gravada em %s" % REFERENCIA)
	var gravada: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REFERENCIA))
	var j := Justa.new(gravada["config"], gravada["lado"], gravada["lado"], int(gravada["semente"]))
	_checa("referencia compartilhada reproduz", _repetir_com(j, gravada["entradas"], 0) == gravada["eventos"])

	print("JUSTA_SIM %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

## Robô. Opções (ausente = padrão; null = não faz):
##   largada: ms depois da bandeira (padrão 100; negativo = antes)
##   galope: desvio em ms em relação a cada batida (padrão 0)
##   mira: ponto (décimos de px) onde segura no começo da Mira (padrão PEITO)
##   solta: se solta no meio da Mira (padrão true)
func _jogar(semente: int, lado: Dictionary, op: Dictionary) -> Dictionary:
	var j := Justa.new(_cfg, lado, lado, semente)
	var largada: Variant = op.get("largada", 100)
	var galope: Variant = op.get("galope", 0)
	var mira: Variant = op.get("mira", PEITO)
	var solta: bool = op.get("solta", true)
	var eventos: Array = []
	var entradas: Array = []
	var res := _res_vazio()
	var inicio_corrida := 0
	_anotar(eventos, j.iniciar(), res)
	while not j.terminou():
		var f := j.fases.fase
		var t := j.fases.tempo_total_ms
		if largada != null and f == JustaFases.Fase.LARGADA and not j.tocou_largada \
				and j.fases.tempo_na_fase_ms == j.bandeira_ms + int(largada):
			entradas.append([t, "tocar", 0, 0])
			_anotar(eventos, j.tocar(), res)
		elif galope != null and f == JustaFases.Fase.CORRIDA and j.jogador.t_ms > 0 \
				and (j.jogador.t_ms - int(galope)) % j.jogador.compasso_ms() == 0:
			entradas.append([t, "tocar", 0, 0])
			_anotar(eventos, j.tocar(), res)
		elif mira != null and f == JustaFases.Fase.MIRA:
			if j.fases.tempo_na_fase_ms == 100:
				entradas.append([t, "mirar", mira.x, mira.y])
				j.mirar(mira)
			elif solta and j.fases.tempo_na_fase_ms == 1000:
				entradas.append([t, "soltar", 0, 0])
				_anotar(eventos, j.soltar(), res)
		var antes := j.fases.fase
		_anotar(eventos, j.avancar(1), res)
		if antes != JustaFases.Fase.CORRIDA and j.fases.fase == JustaFases.Fase.CORRIDA:
			inicio_corrida = j.fases.tempo_total_ms
		if antes == JustaFases.Fase.CORRIDA and j.fases.fase != JustaFases.Fase.CORRIDA:
			res["corridas_ms"].append(j.fases.tempo_total_ms - inicio_corrida)
			res["ritmos"].append(j.jogador.ritmo_milesimos())
	res["eventos"] = eventos
	res["entradas"] = entradas
	res["folego_final"] = j.jogador.folego
	return res

func _repetir(semente: int, lado: Dictionary, entradas: Array, pedaco: int) -> Array:
	return _repetir_com(Justa.new(_cfg, lado, lado, semente), entradas, pedaco)

## Avança até cada entrada (em pedaços, se pedaco > 0), aplica e vai até o fim.
func _repetir_com(j: Justa, entradas: Array, pedaco: int) -> Array:
	var eventos: Array = []
	var res := _res_vazio()
	_anotar(eventos, j.iniciar(), res)
	for e: Array in entradas + [[1 << 40, "fim", 0, 0]]:
		var t := int(e[0])
		while j.fases.tempo_total_ms < t and not j.terminou():
			var falta: int = t - j.fases.tempo_total_ms
			_anotar(eventos, j.avancar(falta if pedaco <= 0 else mini(pedaco, falta)), res)
		if j.terminou():
			break
		match e[1]:
			"tocar": _anotar(eventos, j.tocar(), res)
			"mirar": j.mirar(Vector2i(int(e[2]), int(e[3])))
			"soltar": _anotar(eventos, j.soltar(), res)
	return eventos

func _res_vazio() -> Dictionary:
	return {"bandeiras": [], "largadas": [], "queimadas": [], "corridas_ms": [], "ritmos": [], "golpes": []}

func _anotar(saida: Array, eventos: Array[Dictionary], res: Dictionary) -> void:
	for e in eventos:
		var chaves: Array = e.keys()
		chaves.sort()
		var partes: Array[String] = [str(e["tipo"])]
		for k in chaves:
			if k != "tipo":
				partes.append("%s=%s" % [k, e[k]])
		saida.append("|".join(partes))
		match e["tipo"]:
			"bandeira": res["bandeiras"].append(e["t"])
			"largada":
				res["largadas"].append(e["qualidade"])
				res["queimadas"].append(e["queimada"])
			"golpe":
				var modo := "sem_golpe" if e["sem_golpe"] else ("automatico" if e["automatico"] else "solto")
				res["golpes"].append("%s:%s" % [e["zona"], modo])

func _checa(nome: String, ok: bool) -> void:
	print("JUSTA_SIM %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
