extends SceneTree
## Casos compartilhados de tests/shared/habilidade_precisao.json: o bônus de
## precisão das habilidades passivas (mira do falcão) somado ao da largada, na
## Justa. A mesma conta roda no TypeScript (supabase/tests/regra/justa.test.ts).

const CASOS := "res://tests/shared/habilidade_precisao.json"
const BASE := "res://tests/shared/justa_referencia.json"

var _falhas := 0

func _initialize() -> void:
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASOS))
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE))
	var cfg: Dictionary = base["config"].duplicate(true)
	cfg["impacto"]["habilidades"].merge(dados["habilidades"], true)
	cfg["galope"]["largada"]["bonus_precisao_pct"] = dados["largada_bonus_precisao_pct"]
	_checa("config com as habilidades novas valida", Justa.validar(cfg) == "")
	for c: Dictionary in dados["casos"]:
		var lj: Dictionary = base["lado_jogador"].duplicate(true)
		var lr: Dictionary = base["lado_rival"].duplicate(true)
		lj["habilidades"] = c["habilidades_jogador"]
		lr["habilidades"] = c["habilidades_rival"]
		var j := Justa.new(cfg, lj, lr, int(base["semente"]))
		j.qualidade_largada = str(c["largada_jogador"])
		var bj := j.bonus_precisao_pct()
		var br := j.precisao_de_habilidades(lr)
		_checa("%s (jogador %d, rival %d)" % [c["nome"], bj, br], bj == int(c["esperado_jogador"]) and br == int(c["esperado_rival"]))
	# As zonas efetivas crescem com o bônus (mesma regra da precisão).
	var lj2: Dictionary = base["lado_jogador"].duplicate(true)
	lj2["habilidades"] = ["mira_do_falcao"]
	var com := Justa.new(cfg, lj2, base["lado_rival"].duplicate(true), 1)
	var sem := Justa.new(cfg, base["lado_jogador"].duplicate(true), base["lado_rival"].duplicate(true), 1)
	var a: Array = com.zonas_efetivas()
	var b: Array = sem.zonas_efetivas()
	var r_com: Rect2i = a[0]["retangulos"][0]
	var r_sem: Rect2i = b[0]["retangulos"][0]
	_checa("a mira do falcao amplia as zonas da mira", r_com.size.x * r_com.size.y > r_sem.size.x * r_sem.size.y)
	print("PRECISAO %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("PRECISAO %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
