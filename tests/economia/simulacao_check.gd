extends SceneTree
## Simulação da economia (3.12): determinismo, dados completos e a meta do
## GDD (pagante chega primeiro, o grátis chega depois, mas chega), com
## poucas sementes para ser rápido.

var _falhas := 0

func _initialize() -> void:
	var dados := SimulacaoEconomia.carregar()
	var a := SimulacaoEconomia.new(dados).rodar("gratis", 11)
	var b := SimulacaoEconomia.new(dados).rodar("gratis", 11)
	var c := SimulacaoEconomia.new(dados).rodar("gratis", 12)
	_checa("mesma semente, mesmo resultado", a["marcos"] == b["marcos"] and a["resumo"] == b["resumo"])
	_checa("semente diferente muda o resultado", a["resumo"] != c["resumo"])
	_checa("90 dias no diario", a["diario"].size() == int(dados["economia"]["simulacao"]["dias"]))
	_checa("poder cresce (%.0f -> %.0f)" % [a["diario"][0]["poder"], a["diario"].back()["poder"]], a["diario"].back()["poder"] > a["diario"][0]["poder"] + 50)
	var teto := 0.0
	for e in dados["economia"]["espacos_conjunto"]:
		teto += float(dados["economia"]["poder_raridade"]["lendario"]) + int(dados["economia"]["melhoria"]["nivel_max"]) * float(dados["economia"]["poder_por_melhoria"])
	teto += float(dados["treino"]["teto_atributo"]) / 2.0
	_checa("poder nunca passa do teto (%.0f)" % teto, a["diario"].all(func(x): return x["poder"] <= teto + 0.01))
	_checa("ouro nunca negativo", a["diario"].all(func(x): return x["ouro"] >= 0))

	var med := {}
	for perfil in ["gratis", "gratis_anuncios", "pagante"]:
		var dias := []
		for s in 8:
			dias.append(int(SimulacaoEconomia.new(dados).rodar(perfil, 500 + s)["marcos"].get("regiao_ducado", 9999)))
		dias.sort()
		med[perfil] = dias[4]
	_checa("pagante chega ao ducado primeiro (%d < %d)" % [med["pagante"], med["gratis"]], med["pagante"] < med["gratis"])
	_checa("anuncios entre os dois", med["pagante"] <= med["gratis_anuncios"] and med["gratis_anuncios"] <= med["gratis"])
	_checa("o gratis chega ao ducado em 90 dias", med["gratis"] <= 90)
	print("SIMULACAO %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("SIMULACAO %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
