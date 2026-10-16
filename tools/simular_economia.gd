extends SceneTree
## Simulação da economia (Pacote 3.12). Roda cada perfil de
## game/data/balance/economia.json com várias sementes e grava:
##   docs/economia/marcos.csv  — dia em que cada perfil chega a cada marco
##                                (mediana, quartis, % das sementes que chegam)
##   docs/economia/diario.csv  — média por dia de nível, poder, ouro, pontos…
## e confere a meta do GDD: pagante chega primeiro, o grátis chega depois,
## mas chega. Uso:
##   driver.sh script res://tools/simular_economia.gd
## TM_SEMENTES=n muda o número de sementes (padrão em economia.json).
## TM_CATALOGO=original sorteia só as peças dos conjuntos de economia.json
## (os 35 modelos de antes da 4.4), para medir o efeito do catálogo maior;
## grava em docs/economia/original/.

const SAIDA := "res://docs/economia/"
const NUNCA := 9999

func _initialize() -> void:
	var dados := SimulacaoEconomia.carregar()
	var eco: Dictionary = dados["economia"]
	var sim_cfg: Dictionary = eco["simulacao"]
	var n_sementes := int(OS.get_environment("TM_SEMENTES")) if OS.get_environment("TM_SEMENTES") != "" else int(sim_cfg["sementes"])
	var dias := int(sim_cfg["dias"])
	var nomes_marcos := _nomes_marcos(eco)
	var perfis: Array = eco["perfis"].keys()

	var linhas_marcos := ["perfil;marco;mediana;quartil_25;quartil_75;chegam_pct"]
	var linhas_diario := ["perfil;dia;nivel;poder;poder_atributos;melhoria_media;ouro;pontos;liga;regiao;pecas;raras_ou_mais"]
	var so_originais := OS.get_environment("TM_CATALOGO") == "original"
	var saida := SAIDA + ("original/" if so_originais else "")
	var medianas := {}
	var resumo := {}
	for perfil in perfis:
		var dias_marco := {}
		for m in nomes_marcos:
			dias_marco[m] = []
		var soma_dia: Array = []
		for i in dias:
			soma_dia.append({"nivel": 0.0, "poder": 0.0, "poder_atrib": 0.0, "melhoria_media": 0.0, "ouro": 0.0, "pontos": 0.0, "liga": 0.0, "regiao": 0.0, "pecas": 0.0, "raras": 0.0})
		var tot := {"justas": 0.0, "vitorias": 0.0, "baus_perdidos": 0.0, "itens_bau": 0.0, "repetidas": 0.0, "raras_bau": 0.0}
		for s in n_sementes:
			var sim := SimulacaoEconomia.new(dados)
			sim.so_originais = so_originais
			var r := sim.rodar(perfil, int(sim_cfg["semente_base"]) + s)
			for m in nomes_marcos:
				dias_marco[m].append(int(r["marcos"].get(m, NUNCA)))
			for i in dias:
				for k in soma_dia[i]:
					soma_dia[i][k] += float(r["diario"][i][k])
			for k in tot:
				tot[k] += float(r["resumo"][k])
		medianas[perfil] = {}
		for m in nomes_marcos:
			var lista: Array = dias_marco[m]
			lista.sort()
			var chegam := lista.filter(func(x): return x != NUNCA).size()
			var med := _q(lista, 0.5)
			medianas[perfil][m] = med
			linhas_marcos.append("%s;%s;%s;%s;%s;%d" % [perfil, m, _txt(med), _txt(_q(lista, 0.25)), _txt(_q(lista, 0.75)), 100 * chegam / n_sementes])
		for i in dias:
			var sd: Dictionary = soma_dia[i]
			linhas_diario.append("%s;%d;%.1f;%.1f;%.1f;%.1f;%.0f;%.0f;%.2f;%.2f;%.1f;%.1f" % [perfil, i + 1, sd["nivel"] / n_sementes, sd["poder"] / n_sementes,
				sd["poder_atrib"] / n_sementes, sd["melhoria_media"] / n_sementes,
				sd["ouro"] / n_sementes, sd["pontos"] / n_sementes, sd["liga"] / n_sementes, sd["regiao"] / n_sementes, sd["pecas"] / n_sementes, sd["raras"] / n_sementes])
		var fim: Dictionary = soma_dia[dias - 1]
		resumo[perfil] = "nivel %.1f · poder %.1f · ouro %.0f · pontos %.0f · vitorias %.0f%% · baus perdidos/sem. %.1f" % [
			fim["nivel"] / n_sementes, fim["poder"] / n_sementes, fim["ouro"] / n_sementes, fim["pontos"] / n_sementes,
			100.0 * tot["vitorias"] / maxf(1.0, tot["justas"]), tot["baus_perdidos"] / n_sementes / (dias / 7.0)]
		var s30: Dictionary = soma_dia[29]
		var s60: Dictionary = soma_dia[59]
		resumo[perfil] += " · pecas %.1f · raras+ (dia 30/60/90) %.1f/%.1f/%.1f · itens de bau %.0f (raros+ %.1f/sem.) · repetidas %.0f%% · frag. de repetidas %.0f" % [
			fim["pecas"] / n_sementes, s30["raras"] / n_sementes, s60["raras"] / n_sementes, fim["raras"] / n_sementes,
			tot["itens_bau"] / n_sementes, tot["raras_bau"] / n_sementes / (dias / 7.0),
			100.0 * tot["repetidas"] / maxf(1.0, tot["itens_bau"]),
			tot["repetidas"] / n_sementes * float(eco["baus"]["fragmentos_por_repetida"])]

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	_gravar(saida + "marcos.csv", linhas_marcos)
	_gravar(saida + "diario.csv", linhas_diario)

	# Tabela no terminal (só os três perfis da meta e os de teste no fim).
	var cab := "%-22s" % "marco"
	for perfil in perfis:
		cab += "%12s" % str(perfil).left(12)
	print("SIM ", n_sementes, " sementes x ", dias, " dias (mediana do dia; - = nao chega)")
	print("SIM ", cab)
	for m in nomes_marcos:
		var lin := "%-22s" % m
		for perfil in perfis:
			lin += "%12s" % _txt(medianas[perfil][m])
		print("SIM ", lin)
	for perfil in perfis:
		print("SIM fim %s: %s" % [perfil, resumo[perfil]])

	# Meta: pagante <= grátis com anúncios <= grátis, e o grátis chega.
	var problemas := 0
	for m in nomes_marcos:
		var pg := int(medianas["pagante"][m])
		var ga := int(medianas["gratis_anuncios"][m])
		var gr := int(medianas["gratis"][m])
		if pg > ga or ga > gr:
			if not (pg == NUNCA and ga == NUNCA and gr == NUNCA):
				print("SIM META ordem trocada em %s: pagante %s, anuncios %s, gratis %s" % [m, _txt(pg), _txt(ga), _txt(gr)])
				problemas += 1
		if gr == NUNCA and pg != NUNCA:
			print("SIM META gratis nao chega em %s (pagante chega no dia %d)" % [m, pg])
	print("SIM META %s" % ("ordem OK" if problemas == 0 else "%d marco(s) com ordem trocada" % problemas))
	# Metas de ritmo (economia.json > simulacao > metas).
	var tol := float(sim_cfg["tolerancia_pct"]) / 100.0
	var fora := 0
	for perfil in sim_cfg["metas"]:
		for m in sim_cfg["metas"][perfil]:
			var alvo := int(sim_cfg["metas"][perfil][m])
			var real := int(medianas[perfil].get(m, NUNCA))
			var ok := real != NUNCA and absf(real - alvo) <= maxf(2.0, alvo * tol)
			if not ok:
				fora += 1
			print("SIM ALVO %-9s %-26s alvo %3d  simulado %4s  %s" % [perfil, m, alvo, _txt(real), "ok" if ok else ("CEDO" if real < alvo else "TARDE")])
	print("SIM ALVO %d fora da tolerancia" % fora)
	quit(0)

func _nomes_marcos(eco: Dictionary) -> Array:
	var r := ["nivel_5", "nivel_10", "nivel_15", "nivel_20"]
	for reg in eco["regioes"]:
		r.append("regiao_" + reg["nome"])
		r.append("regiao_%s_fim" % reg["nome"])
	for i in range(1, eco["ligas"]["nomes"].size()):
		r.append("liga_" + eco["ligas"]["nomes"][i])
	r.append("conjunto_incomum")
	r.append("conjunto_raro")
	return r

func _q(lista: Array, q: float) -> int:
	return int(lista[clampi(int(round(q * (lista.size() - 1))), 0, lista.size() - 1)])

func _txt(v: int) -> String:
	return "-" if v == NUNCA else str(v)

## CSV no padrão do Excel em português: ";" separa colunas e "," é o decimal.
func _gravar(caminho: String, linhas: Array) -> void:
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	f.store_string("\n".join(linhas).replace(".", ",") + "\n")
