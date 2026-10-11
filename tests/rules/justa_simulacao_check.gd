extends SceneTree
## Justa completa (regra pura Justa): determinismo, independência do tamanho
## do passo, propriedades da largada e do galope, e a gravação de referência
## tests/shared/justa_referencia.json (semente + instantes dos toques ->
## eventos), que a versão TypeScript deve reproduzir.
## Para regravar depois de mudar a regra de propósito:
##   TM_GRAVAR=1 timeout 60 bash .claude/skills/run-torneio-medieval/driver.sh script res://tests/rules/justa_simulacao_check.gd

const REFERENCIA := "res://tests/shared/justa_referencia.json"

var _falhas := 0
var _cj: Dictionary
var _cg: Dictionary

func _initialize() -> void:
	_cj = Balanceamento.carregar("justa")
	_cg = Balanceamento.carregar("galope")
	_checa("dados validos juntos", Justa.validar(_cj, _cg) == "")
	var cavalo: Dictionary = _cg["cavalo_padrao"]

	# Jogador-robô: larga 100 ms depois da bandeira e toca no compasso.
	var r1 := _jogar(7, cavalo, 100, 0)
	var r2 := _jogar(7, cavalo, 100, 0)
	_checa("mesma semente e mesmos toques = mesmos eventos", r1["eventos"] == r2["eventos"])
	var r3 := _jogar(8, cavalo, 100, 0)
	_checa("semente diferente muda a bandeira", r1["bandeiras"] != r3["bandeiras"])

	var rep := _repetir(7, cavalo, r1["toques"], 0)
	_checa("repetir os toques gravados reproduz a justa", rep == r1["eventos"])
	_checa("picado em 1 ms da o mesmo", _repetir(7, cavalo, r1["toques"], 1) == r1["eventos"])
	_checa("picado em 33 ms da o mesmo", _repetir(7, cavalo, r1["toques"], 33) == r1["eventos"])

	# Propriedades.
	var bom := _jogar(3, cavalo, 80, 0)
	var parado := _jogar(3, cavalo, -1, -1)
	_checa("largada 80 ms depois da bandeira e perfeita", bom["largadas"][0] == "perfeita")
	_checa("sem tocar na largada e ruim", parado["largadas"][0] == "ruim")
	var queima := _jogar(3, cavalo, -50, -1)
	_checa("tocar antes da bandeira queima a largada", queima["largadas"][0] == "ruim" and queima["queimadas"][0])
	_checa("quem toca no compasso chega antes (%d ms x %d ms)" % [bom["corridas_ms"][0], parado["corridas_ms"][0]],
		bom["corridas_ms"][0] < parado["corridas_ms"][0])
	_checa("corrida normal dura entre 3,5 e 5,5 s (%d ms)" % bom["corridas_ms"][0],
		bom["corridas_ms"][0] >= 3500 and bom["corridas_ms"][0] <= 5500)
	_checa("ritmo perfeito = 1000", bom["ritmos"][0] == 1000)
	var fora := _jogar(3, cavalo, 100, 200)
	_checa("tocar sempre fora do tempo gasta folego", fora["folego_final"] < bom["folego_final"])
	var lento := {"velocidade": 0, "folego": 50, "temperamento": 50}
	var rapido := {"velocidade": 100, "folego": 50, "temperamento": 50}
	_checa("cavalo com mais Velocidade chega antes",
		_jogar(3, rapido, 100, 0)["corridas_ms"][0] < _jogar(3, lento, 100, 0)["corridas_ms"][0])

	# Referência compartilhada.
	var ref := {"versao": 1,
		"descricao": "Justa completa (game/scripts/rules/justa.gd) gravada pelo GDScript. Repita: Justa(config_justa, config_galope, cavalo, cavalo, semente); iniciar(); para cada t em toques_ms avance ate t e toque; avance ate o fim. Eventos: tipo|chave=valor ordenados.",
		"config_justa": _cj, "config_galope": _cg, "cavalo": cavalo, "semente": 7,
		"toques_ms": r1["toques"], "eventos": r1["eventos"]}
	if OS.get_environment("TM_GRAVAR") == "1" or not FileAccess.file_exists(REFERENCIA):
		var f := FileAccess.open(REFERENCIA, FileAccess.WRITE)
		f.store_string(JSON.stringify(ref, "\t") + "\n")
		f.close()
		print("JUSTA_SIM referencia gravada em %s" % REFERENCIA)
	var gravada: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REFERENCIA))
	var toques: Array = gravada["toques_ms"].map(func(x): return int(x))
	var cav: Dictionary = gravada["cavalo"]
	var j := Justa.new(gravada["config_justa"], gravada["config_galope"], cav, cav, int(gravada["semente"]))
	_checa("referencia compartilhada reproduz", _repetir_com(j, toques, 0) == gravada["eventos"])

	print("JUSTA_SIM %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

## Robô: atraso_largada (ms depois da bandeira; < 0 = antes; -1 sem contar = não toca
## quando desvio_galope também é -1), desvio_galope (ms em relação à batida; -1 = não toca).
func _jogar(semente: int, cavalo: Dictionary, atraso_largada: int, desvio_galope: int) -> Dictionary:
	var j := Justa.new(_cj, _cg, cavalo, cavalo, semente)
	var eventos: Array = []
	var toques: Array = []
	var res := {"bandeiras": [], "largadas": [], "queimadas": [], "corridas_ms": [], "ritmos": []}
	var inicio_corrida := 0
	var nao_toca := atraso_largada == -1 and desvio_galope == -1
	_anotar(eventos, j.iniciar(), res)
	while not j.terminou():
		var f := j.fases.fase
		var tocar := false
		if not nao_toca and f == JustaFases.Fase.LARGADA and not j.tocou_largada:
			tocar = j.fases.tempo_na_fase_ms == j.bandeira_ms + atraso_largada
		elif desvio_galope >= 0 and f == JustaFases.Fase.CORRIDA and j.jogador.t_ms > 0:
			tocar = (j.jogador.t_ms - desvio_galope) % j.jogador.compasso_ms() == 0
		if tocar:
			toques.append(j.fases.tempo_total_ms)
			_anotar(eventos, j.tocar(), res)
		var antes := j.fases.fase
		_anotar(eventos, j.avancar(1), res)
		if antes != JustaFases.Fase.CORRIDA and j.fases.fase == JustaFases.Fase.CORRIDA:
			inicio_corrida = j.fases.tempo_total_ms
		if antes == JustaFases.Fase.CORRIDA and j.fases.fase != JustaFases.Fase.CORRIDA:
			res["corridas_ms"].append(j.fases.tempo_total_ms - inicio_corrida)
			res["ritmos"].append(j.jogador.ritmo_milesimos())
	res["eventos"] = eventos
	res["toques"] = toques
	res["folego_final"] = j.jogador.folego
	return res

func _repetir(semente: int, cavalo: Dictionary, toques: Array, pedaco: int) -> Array:
	return _repetir_com(Justa.new(_cj, _cg, cavalo, cavalo, semente), toques, pedaco)

## Avança até cada toque (em pedaços, se pedaco > 0), toca e vai até o fim.
func _repetir_com(j: Justa, toques: Array, pedaco: int) -> Array:
	var eventos: Array = []
	var res := {"bandeiras": [], "largadas": [], "queimadas": [], "corridas_ms": [], "ritmos": []}
	_anotar(eventos, j.iniciar(), res)
	for t: int in toques + [1 << 40]:
		while j.fases.tempo_total_ms < t and not j.terminou():
			var falta: int = t - j.fases.tempo_total_ms
			_anotar(eventos, j.avancar(falta if pedaco <= 0 else mini(pedaco, falta)), res)
		if not j.terminou() and t < (1 << 40):
			_anotar(eventos, j.tocar(), res)
	return eventos

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

func _checa(nome: String, ok: bool) -> void:
	print("JUSTA_SIM %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
