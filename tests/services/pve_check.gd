extends SceneTree
## PvE da primeira região (headless, save em user://teste_pve/): estrelas,
## automático determinístico, liberação por nível e por torneio, chave,
## recompensas e XP, campeão manual, nêmesis que cresce e uma disputa
## jogada na arena de verdade.

var _falhas := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_pve/")
	jog.caminho_save = "user://teste_pve/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000  # fora do primeiro dia

	# Estrelas
	_checa("derrota = 0 estrelas", RegraPve.estrelas(_ev(false, "pontos", ["peito"])) == 0)
	_checa("vitoria com erro = 1", RegraPve.estrelas(_ev(true, "pontos", ["peito", "erro", "peito"])) == 1)
	_checa("vitoria sem errar = 2", RegraPve.estrelas(_ev(true, "pontos", ["peito", "escudo", "capacete"])) == 2)
	_checa("derrubada sem errar = 3", RegraPve.estrelas(_ev(true, "derrubada", ["capacete"])) == 3)
	_checa("derrubada com falta = 2", RegraPve.estrelas(_ev(true, "derrubada", ["cavalo", "capacete"])) == 2)

	# Automático determinístico
	var cfg := Justa.carregar_configuracao()
	var perfis: Dictionary = Balanceamento.carregar("ia_rival")["perfis"]
	var rv := jog.rival_para_justa("camponio_bruno")
	var a := RegraPve.simular(cfg, jog.lado_para_justa(), rv["lado"], 77, rv["perfil"], perfis["equilibrado"])
	var b := RegraPve.simular(cfg, jog.lado_para_justa(), rv["lado"], 77, rv["perfil"], perfis["equilibrado"])
	_checa("automatico: mesma semente, mesma justa", JSON.stringify(a["eventos"]) == JSON.stringify(b["eventos"]))
	var toques: int = a["eventos"].filter(func(e): return e["tipo"] == "toque").size()
	var golpes: int = a["eventos"].filter(func(e): return e["tipo"] == "golpe" and not e["sem_golpe"]).size()
	_checa("a IA joga pelo jogador (%d toques, %d golpes)" % [toques, golpes], toques > 5 and golpes >= 1)
	var vitorias := 0
	for s in 30:
		var sim := RegraPve.simular(cfg, jog.lado_para_justa(), rv["lado"], 1000 + s, rv["perfil"], perfis["equilibrado"])
		if RegraPve.estrelas(sim["eventos"]) > 0:
			vitorias += 1
	_checa("automatico vence o primeiro rival quase sempre (%d/30)" % vitorias, vitorias >= 18)

	# Liberação e chave
	_checa("nivel 1: feiras bloqueadas", not jog.torneio_liberado("feira_moinho"))
	jog._ganhar(0, 50)
	_checa("50 XP sobe para o nivel 2", int(jog.cavaleiro()["nivel"]) == 2)
	_checa("nivel 2: primeiro torneio liberado, segundo nao", jog.torneio_liberado("feira_moinho") and not jog.torneio_liberado("feira_ponte"))
	_checa("segunda disputa bloqueada antes da primeira", jog.pode_disputar("feira_moinho", 1)["erro"] == "disputa_bloqueada")
	_checa("automatico sem 3 estrelas nao", jog.pode_automatico("feira_moinho", 0)["erro"] == "disputa_bloqueada" or jog.pode_automatico("feira_moinho", 0)["erro"] == "precisa_tres_estrelas")
	jog.estado["metas"]["conquistas"].append("primeira_vitoria")  # o ouro da conquista (3.21) não entra nesta conta
	var ouro0 := jog.ouro()
	var r := jog.concluir_disputa("feira_moinho", 0, _ev(true, "derrubada", ["capacete"]))
	_checa("vitoria de 3 estrelas avanca e paga (%d ouro, %d xp)" % [r["ouro"], r["xp"]], r["estrelas"] == 3 and jog.progresso_torneio("feira_moinho")["proxima"] == 1
		and jog.ouro() == ouro0 + r["ouro"] and r["ouro"] == 24)
	_checa("com 3 estrelas libera o automatico", jog.pode_automatico("feira_moinho", 0)["ok"])
	var perdeu := jog.concluir_disputa("feira_moinho", 1, _ev(false, "pontos", ["erro"]))
	_checa("derrota nao avanca nem paga", perdeu["estrelas"] == 0 and perdeu["ouro"] == 0 and jog.progresso_torneio("feira_moinho")["proxima"] == 1)
	jog.concluir_disputa("feira_moinho", 1, _ev(true, "pontos", ["peito"]))
	var fim := jog.concluir_disputa("feira_moinho", 2, _ev(true, "pontos", ["peito"]))
	_checa("ultima disputa fecha o torneio com o premio", fim["torneio_concluido"] and fim["ouro"] == 20 + 60 and jog.progresso_torneio("feira_moinho")["concluido"])
	_checa("torneio seguinte liberado", jog.torneio_liberado("feira_ponte"))
	var r2 := jog.concluir_disputa("feira_moinho", 0, _ev(true, "pontos", ["peito"]))
	_checa("repetir disputa vencida paga de novo sem premio do torneio", not r2["torneio_concluido"] and r2["ouro"] == 20)

	# Nêmesis e campeão
	var f0 := int(jog.rival_para_justa("nemesis_corvo")["lado"]["cavaleiro"]["forca"])
	jog.estado["pve"]["encontros"]["nemesis_corvo"] = 3
	_checa("nemesis cresce a cada encontro", int(jog.rival_para_justa("nemesis_corvo")["lado"]["cavaleiro"]["forca"]) == f0 + 6)
	jog.estado["cavaleiro"]["nivel"] = 4
	for t in ["feira_ponte", "feira_mercado", "feira_colheita"]:
		jog.estado["pve"]["torneios"][t] = {"proxima": 5, "concluido": true, "estrelas": {}}
	jog.estado["pve"]["torneios"]["feira_grande"] = {"proxima": 5, "concluido": true, "estrelas": {"4": 3}}
	_checa("campeao nunca no automatico", jog.pode_automatico("feira_grande", 4)["erro"] == "campeao_manual")

	# Automático pelo serviço
	var folego0 := jog.folego_cavalo()
	var auto := jog.disputa_automatica("feira_moinho", 0, 5)
	_checa("disputa automatica roda e gasta folego", auto["ok"] and jog.folego_cavalo() < folego0)
	_checa("automatico paga menos (%d)" % auto["ouro"], not auto["venceu"] or auto["ouro"] <= 24 * 60 / 100)

	# Arena de verdade numa disputa
	var fluxo: FluxoTelas = root.get_node("Fluxo")
	fluxo.disputa = {"torneio": "feira_moinho", "indice": 1}
	fluxo.modo_justa = "disputa"
	var arena: Arena = load("res://game/scenes/arena/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var c: ControladorJusta = arena.get_node("Justa")
	c.set_process(false)
	c.iniciar(9)
	_checa("arena pega o rival da disputa", c.nome_rival == "RIVAL_ESCUDEIRO_TIAGO" and c.perfil_rival == "novato"
		and int(c.lado_rival["cavaleiro"]["forca"]) == 28)
	var quadros := 0
	while not c.justa.terminou() and quadros < 30 * 90:
		if c.fase() == JustaFases.Fase.MIRA:
			preload("res://tests/arena/justa_check.gd").robo_mira(c, Vector2(-5, -106))
		c._process(1.0 / 30.0)
		quadros += 1
	_checa("fim da justa conclui a disputa no jogador", not c.resultado_disputa.is_empty() and c.resultado_disputa["ok"])
	_checa("resultado guardado para a vila", not fluxo.ultimo_resultado.is_empty())
	fluxo.disputa = {}

	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_pve/" + arq)
	print("PVE %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

## Eventos mínimos de uma justa: um impacto por zona do jogador e o fim.
func _ev(venceu: bool, motivo: String, zonas: Array) -> Array:
	var ev: Array = []
	for z: String in zonas:
		ev.append({"tipo": "impacto", "jogador": {"zona": "erro" if z == "erro" else z, "falta": z == "cavalo"}})
	ev.append({"tipo": "fim", "vencedor": JustaFases.Lado.JOGADOR if venceu else JustaFases.Lado.RIVAL, "motivo": motivo})
	return ev

func _checa(nome: String, ok: bool) -> void:
	print("PVE %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
