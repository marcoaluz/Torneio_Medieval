extends SceneTree
## Roda os casos compartilhados de tests/shared/justa_fases.json contra
## game/scripts/rules/justa_fases.gd. Cada caso roda duas vezes: com os
## avanços inteiros e picados em pedaços de 17 ms (o resultado tem de ser
## idêntico: o tempo não pode depender do tamanho do quadro). Também confere
## que o JSON de balanceamento do jogo é válido.

const CASOS := "res://tests/shared/justa_fases.json"

var _falhas := 0

func _initialize() -> void:
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASOS))
	var base: Dictionary = dados["config_base"]
	for caso: Dictionary in dados["casos"]:
		var cfg := base.duplicate(true)
		cfg.merge(caso.get("config", {}), true)
		var erro := JustaFases.validar(cfg)
		if erro != "":
			_falha(caso["nome"], "config inválida: " + erro)
			continue
		var esperado: Array = caso["esperado"]
		var inteiro := _rodar(cfg, caso["acoes"], 0)
		var picado := _rodar(cfg, caso["acoes"], 17)
		if inteiro != esperado:
			_falha(caso["nome"], "eventos diferentes\n   esperado %s\n   obtido   %s" % [esperado, inteiro])
		elif picado != esperado:
			_falha(caso["nome"], "picado em 17 ms deu outro resultado\n   %s" % [picado])
		else:
			print("FASES %s OK" % caso["nome"])

	var jogo := Balanceamento.carregar("justa")
	_checa("dados do jogo validos", JustaFases.validar(jogo) == "")
	_checa("rejeita config sem fases", JustaFases.validar({"passadas": 3, "passadas_extras_max": 1}) != "")
	var ruim := base.duplicate(true)
	ruim["fases_ms"]["mira"] = 1.5
	_checa("rejeita duracao nao inteira", JustaFases.validar(ruim) != "")
	ruim = base.duplicate(true)
	ruim["fases_ms"].erase("impacto")
	_checa("rejeita fase faltando", JustaFases.validar(ruim) != "")

	print("FASES %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

## pedaco = 0: aplica cada avanço inteiro; > 0: pica o avanço em pedaços.
func _rodar(cfg: Dictionary, acoes: Array, pedaco: int) -> Array:
	var j := JustaFases.new(cfg)
	var saida: Array = []
	_anotar(saida, j.iniciar())
	for a: Dictionary in acoes:
		match a["acao"]:
			"avancar":
				var ms := int(a["ms"])
				if pedaco <= 0:
					_anotar(saida, j.avancar(ms))
				else:
					while ms > 0:
						var p := mini(pedaco, ms)
						_anotar(saida, j.avancar(p))
						ms -= p
			"pular":
				_anotar(saida, j.pular())
			"resultado":
				var lado := JustaFases.NOMES_LADO.find(a.get("derrubado", "nenhum"))
				j.registrar_resultado(int(a["jogador"]), int(a["rival"]), lado)
	return saida

func _anotar(saida: Array, eventos: Array[Dictionary]) -> void:
	for e in eventos:
		match e["tipo"]:
			"fase":
				saida.append("fase:%s:%d@%d" % [JustaFases.NOMES_FASE[e["fase"]], e["passada"], e["t"]])
			"passada":
				saida.append("passada:%d:%d-%d:%s@%d" % [e["passada"], e["pontos_jogador"], e["pontos_rival"],
					JustaFases.NOMES_LADO[e["derrubado"]], e["t"]])
			"fim":
				saida.append("fim:%s:%s:%d-%d@%d" % [JustaFases.NOMES_LADO[e["vencedor"]], e["motivo"],
					e["placar_jogador"], e["placar_rival"], e["t"]])

func _checa(nome: String, ok: bool) -> void:
	if ok:
		print("FASES %s OK" % nome)
	else:
		_falha(nome, "")

func _falha(nome: String, detalhe: String) -> void:
	_falhas += 1
	print("FASES %s FALHOU %s" % [nome, detalhe])
