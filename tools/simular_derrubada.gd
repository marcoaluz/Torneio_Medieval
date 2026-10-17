extends SceneTree
## Chance de derrubar por largada e zona (impacto.json > derrubada.por_largada),
## em justas inteiras da regra (Justa + IA nos dois lados), com status médios
## (game/data/balance/padrao.json: atributos 50, equipamento inicial) e sem
## habilidades, para medir só a base da largada e os modificadores.
## A IA de cada lado larga perfeita, boa ou ruim em partes iguais e mira, em
## rodízio, no capacete, no peito ou no escudo; a zona contada é a final (um
## golpe bloqueado pelo escudo conta como escudo).
## Saída: tabela no console e docs/economia/derrubada.csv. Uso:
##   bash .claude/skills/run-torneio-medieval/driver.sh script res://tools/simular_derrubada.gd
## TM_JUSTAS=n muda o número de justas (padrão 600).

const SAIDA := "res://docs/economia/derrubada.csv"
const LARGADAS := ["perfeita", "boa", "ruim"]
const ZONAS := ["capacete", "peito", "escudo"]

var _soma := {}  ## "largada|zona" -> {n, chance, derrubou}

func _initialize() -> void:
	var cfg := Justa.carregar_configuracao()
	var padrao := Balanceamento.carregar("padrao")
	var lado := {"cavaleiro": padrao["cavaleiro"], "cavalo": padrao["cavalo"], "equipamento": padrao["equipamento"]}
	var base: Dictionary = Balanceamento.carregar("ia_rival")["perfis"]["equilibrado"]
	var justas := int(OS.get_environment("TM_JUSTAS")) if OS.get_environment("TM_JUSTAS") != "" else 600
	for l in LARGADAS:
		for z in ZONAS:
			_soma[l + "|" + z] = {"n": 0, "chance": 0, "derrubou": 0}
	var bloqueados := 0
	var golpes := 0
	for i in justas:
		var pj := _perfil(base, ZONAS[i % 3])
		var pr := _perfil(base, ZONAS[(i + 1) % 3])
		var j := Justa.new(cfg, lado, lado, 50000 + i, pr, pj)
		var larg := {"jogador": "", "rival": ""}
		var eventos := j.iniciar()
		while true:
			for e in eventos:
				match e["tipo"]:
					"largada":
						larg["jogador"] = e["qualidade"]
					"largada_rival":
						larg["rival"] = e["qualidade"]
					"impacto":
						for lado_nome in ["jogador", "rival"]:
							var r: Dictionary = e[lado_nome]
							if r["zona"] in ZONAS:
								golpes += 1
								if r["bloqueado"]:
									bloqueados += 1
							if r["zona_final"] in ZONAS:
								var s: Dictionary = _soma[larg[lado_nome] + "|" + r["zona_final"]]
								s["n"] += 1
								s["chance"] += int(r["chance_derrubar_milesimos"])
								s["derrubou"] += 1 if r["derrubou"] else 0
			if j.terminou():
				break
			eventos = j.avancar(50)
	var linhas: Array[String] = ["largada,zona,golpes,chance_media_pct,derrubou_pct"]
	print("SIM_DERRUBADA %d justas, status medios, sem habilidades; %d golpes nas zonas, %.0f%% bloqueados pelo escudo" %
		[justas, golpes, 100.0 * bloqueados / maxi(golpes, 1)])
	print("SIM_DERRUBADA largada   zona       golpes  chance media  derrubou")
	for l in LARGADAS:
		for z in ZONAS:
			var s: Dictionary = _soma[l + "|" + z]
			var media: float = 0.1 * s["chance"] / maxi(s["n"], 1)
			var real: float = 100.0 * s["derrubou"] / maxi(s["n"], 1)
			print("SIM_DERRUBADA %-9s %-9s %6d %12.1f%% %8.1f%%" % [l, z, s["n"], media, real])
			linhas.append("%s,%s,%d,%.1f,%.1f" % [l, z, s["n"], media, real])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA.get_base_dir()))
	var f := FileAccess.open(SAIDA, FileAccess.WRITE)
	f.store_string("\n".join(linhas) + "\n")
	f.close()
	print("SIM_DERRUBADA gravado em %s" % SAIDA)
	quit(0)

## Perfil equilibrado com a largada em três partes iguais e a zona escolhida.
func _perfil(base: Dictionary, zona: String) -> Dictionary:
	var p := base.duplicate(true)
	p["largada_perfeita_milesimos"] = 334
	p["largada_boa_milesimos"] = 333
	p["zona_preferida"] = zona
	p["deslocamento_mira_px"] = [9, 0] if zona == "peito" else [0, 0]
	p["habilidade_batida"] = 0
	return p
