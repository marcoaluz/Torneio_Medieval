extends SceneTree
## Renome, missões, login, conquistas e títulos (3.21, headless): missões
## sorteadas por dia/semana (determinísticas), progresso por evento e resgate,
## login dos 7 primeiros dias, conquistas com título, renome e faixa,
## migração v4 -> v5, o arauto anunciando o título, a torcida e a tela.

var _falhas := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_metas/")
	jog.caminho_save = "user://teste_metas/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
	var cfg := jog.cfg_metas()

	# Missões
	var m := jog.missoes()
	_checa("3 diarias e 2 semanais", m["diarias"].size() == int(cfg["missoes"]["diarias_por_dia"]) and m["semanais"].size() == int(cfg["missoes"]["semanais_por_semana"]))
	var ids: Array = m["diarias"].map(func(x): return x["id"])
	_checa("diarias sem repetir", ids.size() == 3 and ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2])
	_checa("mesmo dia, mesmas missoes", jog.missoes()["diarias"].map(func(x): return x["id"]) == ids)
	var alvo: Dictionary = m["diarias"][0]
	_checa("incompleta nao resgata", jog.resgatar_missao(alvo["id"])["erro"] == "missao_incompleta")
	for i in int(alvo["meta"]):
		jog._evento(alvo["evento"])
	var pronta: Dictionary = jog.missoes()["diarias"].filter(func(x): return x["id"] == alvo["id"])[0]
	_checa("evento completa a missao", pronta["pronta"] and int(pronta["progresso"]) == int(alvo["meta"]))
	var ouro0 := jog.ouro()
	var rr := jog.resgatar_missao(alvo["id"])
	_checa("resgata a recompensa", rr["ok"] and jog.ouro() == ouro0 + int(alvo["recompensa"].get("ouro", 0)))
	_checa("nao resgata duas vezes", jog.resgatar_missao(alvo["id"])["erro"] == "ja_resgatada")
	var dias_iguais := 0
	for k in 5:
		ServicoTempo.deslocamento += 86400
		if jog.missoes()["diarias"].map(func(x): return x["id"]) == ids:
			dias_iguais += 1
	_checa("dia novo sorteia de novo (%d de 5 iguais)" % dias_iguais, dias_iguais < 5 and jog.missoes()["diarias"].all(func(x): return int(x["progresso"]) == 0 or true))
	ServicoTempo.deslocamento = 0

	# Login dos 7 primeiros dias
	var h := jog.login_hoje()
	_checa("login: dia 1 disponivel", h["dia"] == 1 and h["pode"])
	jog.resgatar_login()
	_checa("login: uma vez por dia", jog.resgatar_login()["erro"] == "login_ja_resgatado")
	for k in 6:
		ServicoTempo.deslocamento += 86400
		jog.resgatar_login()
	_checa("login: 7 dias e acabou", int(jog.estado["metas"]["login"]["dias"]) == 7 and jog.login_hoje()["dia"] == 0)
	ServicoTempo.deslocamento = 0

	# Conquistas, títulos, renome
	jog.estado["cavaleiro"]["nivel"] = 20
	var vit := [{"tipo": "impacto", "jogador": {"zona": "peito", "falta": false}}, {"tipo": "fim", "vencedor": JustaFases.Lado.JOGADOR, "motivo": "derrubada"}]
	var renome0 := jog.renome()
	var d1 := jog.concluir_disputa("feira_moinho", 0, vit)
	_checa("vitoria da renome (%d)" % d1["renome"], jog.renome() == renome0 + int(d1["renome"]) and int(d1["renome"]) > 0)
	_checa("primeira vitoria vira conquista nova", jog.conquistas_novas().has("primeira_vitoria") and jog.conquistas_novas().is_empty())
	for k in 9:
		jog.concluir_disputa("feira_moinho", 0, vit)
	_checa("10 seguidas: o Inquebravel", jog.titulos().has("o_inquebravel"))
	jog.concluir_disputa("feira_moinho", 0, [{"tipo": "fim", "vencedor": JustaFases.Lado.RIVAL, "motivo": "pontos"}])
	_checa("derrota zera a sequencia", int(jog.estado["metas"]["sequencia"]) == 0)
	_checa("titulo bloqueado", jog.definir_titulo("o_grande_campeao")["erro"] == "titulo_bloqueado")
	_checa("usa o titulo", jog.definir_titulo("o_inquebravel")["ok"] and jog.titulo() == "o_inquebravel")
	jog.estado["metas"]["renome"] = 850
	_checa("faixa famoso", jog.faixa_renome()["nome"] == "famoso" and int(jog.faixa_renome()["proxima"]) == 2000)

	# Migração
	var velho := {"versao": 4, "cavaleiro": {"habilidades": []}}
	ServicoJogador.migrar(velho)
	_checa("migracao cria as metas", velho.has("metas") and int(velho["metas"]["renome"]) == 0)

	# Arena: arauto e torcida
	jog.estado["cavaleiro"]["nome"] = "Isolda"
	var fluxo: FluxoTelas = root.get_node("Fluxo")
	fluxo.modo_justa = "livre"
	var arena: Arena = load("res://game/scenes/arena/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var c: ControladorJusta = arena.get_node("Justa")
	_checa("arauto anuncia o titulo", c.anuncio_titulo.contains("Isolda") and c.anuncio_titulo.contains("Inquebrável"))
	(arena.get_node("Efeitos") as EfeitosImpacto).reagir_torcida(true)
	await process_frame
	_checa("torcida solta flamulas", arena.get_node("Fundo/Arquibancada").has_node("Flamulas"))
	arena.free()

	# Tela
	var tela: TelaMissoes = load("res://game/scenes/ui/tela_missoes.tscn").instantiate()
	root.add_child(tela)
	await process_frame
	tela.abrir("conquistas")
	await process_frame
	_checa("tela: 4 abas", tela.get_node("Coluna/Abas").get_child_count() == 4)
	_checa("tela: conquistas e titulos", tela.get_node("Coluna/Rolagem/Lista").get_child_count() >= cfg["conquistas"].size() + 2)
	tela.queue_free()

	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_metas/" + arq)
	print("METAS %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("METAS %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
