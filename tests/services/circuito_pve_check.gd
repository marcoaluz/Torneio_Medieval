extends SceneTree
## Circuito completo do PvE (3.13, headless): dados das 5 regiões (5 a 8
## torneios, 3 a 5 rivais, campeão com provocação no fim, tudo existe e tem
## texto), regiões abrindo em ordem com projeto, desafios opcionais que não
## bloqueiam, uma chance só, cavalo emprestado que não cansa o seu, nêmesis
## por região, recompensa por região, migração do save e a arena com chuva
## e noite.

var _falhas := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_circuito/")
	jog.caminho_save = "user://teste_circuito/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000

	# --- Dados
	var d := jog.pve()
	var itens: Dictionary = Balanceamento.carregar("itens")["modelos"]
	var perfis: Dictionary = Balanceamento.carregar("ia_rival")["perfis"]
	_checa("5 regioes na ordem do GDD", d["ordem_regioes"] == ["feiras", "condado", "ducado", "reino", "grande_torneio"])
	var problemas: Array[String] = []
	for r: String in d["ordem_regioes"]:
		var lista: Array = d["regioes"][r]["torneios"]
		if lista.size() < 5 or lista.size() > 8:
			problemas.append("%s tem %d torneios" % [r, lista.size()])
		if tr("REGIAO_" + r.to_upper()) == "REGIAO_" + r.to_upper():
			problemas.append("sem texto REGIAO_" + r.to_upper())
		for t: String in lista:
			var tor: Dictionary = d["torneios"][t]
			var rivais: Array = tor["rivais"]
			if rivais.size() < 3 or rivais.size() > 5:
				problemas.append("%s tem %d rivais" % [t, rivais.size()])
			if tr("TORNEIO_" + t.to_upper()) == "TORNEIO_" + t.to_upper():
				problemas.append("sem texto TORNEIO_" + t.to_upper())
			for dz: String in tor.get("desafios", []):
				if not d["desafios"].has(dz) or tr("DESAFIO_" + dz.to_upper()) == "DESAFIO_" + dz.to_upper():
					problemas.append("desafio %s em %s" % [dz, t])
			if r != "feiras" and not d["rivais"][rivais.back()].get("campeao", false):
				problemas.append("%s nao termina num campeao" % t)
			for rid: String in rivais:
				var rv: Dictionary = d["rivais"].get(rid, {})
				if rv.is_empty():
					problemas.append("rival %s nao existe" % rid)
					continue
				if not perfis.has(rv["perfil"]):
					problemas.append("perfil %s de %s" % [rv["perfil"], rid])
				for m: String in rv["equipamento"]:
					if not itens.has(m):
						problemas.append("item %s de %s" % [m, rid])
				if tr("RIVAL_" + rid.to_upper()) == "RIVAL_" + rid.to_upper():
					problemas.append("sem nome RIVAL_" + rid.to_upper())
				if rv.get("campeao", false) and (rv.get("provocacao", "") == "" or tr(rv["provocacao"]) == rv["provocacao"]):
					problemas.append("campeao %s sem provocacao" % rid)
	for m: String in itens:
		if tr("ITEM_" + m.to_upper()) == "ITEM_" + m.to_upper():
			problemas.append("sem nome ITEM_" + m.to_upper())
	_checa("dados completos %s" % str(problemas.slice(0, 4)), problemas.is_empty())
	var todos_desafios := {}
	for t: String in d["torneios"]:
		for dz: String in d["torneios"][t].get("desafios", []):
			todos_desafios[dz] = true
	_checa("os 5 desafios aparecem em algum torneio", todos_desafios.size() == 5)

	# --- Regiões em ordem
	_checa("comeca so com as feiras", jog.regioes_liberadas() == ["feiras"])
	_checa("condado fechado no comeco", not jog.torneio_liberado("torneio_vale_verde"))
	jog.estado["cavaleiro"]["nivel"] = 20
	_vencer_regiao(jog, "feiras")
	_checa("vencer a grande feira abre o condado", jog.estado["pve"]["regiao"] == "condado" and jog.torneio_liberado("torneio_vale_verde"))
	_checa("projeto do campeao da regiao", (jog.estado["inventario"]["projetos"] as Array).has("vigia"))
	_checa("feiras continuam abertas", jog.regioes_liberadas() == ["feiras", "condado"])

	# Opcional não bloqueia: pula o desafio da ribeira
	_vencer_torneio(jog, "torneio_vale_verde")
	_vencer_torneio(jog, "torneio_ponte_velha")
	_checa("desafio da chuva liberado", jog.torneio_liberado("desafio_ribeira"))
	_checa("torneio seguinte liberado sem o desafio", jog.torneio_liberado("torneio_castelo_alvar"))
	var ouro0 := int(jog.estado["inventario"]["ouro"])
	var r := jog.concluir_disputa("torneio_castelo_alvar", 0, _ev(true))
	var base := int(d["recompensa_disputa"]["ouro_base"]) + 2 * int(d["recompensa_disputa"]["ouro_por_estrela"])
	_checa("recompensa da regiao multiplicada (%d)" % r["ouro"], int(r["ouro"]) == base * int(d["regioes"]["condado"]["recompensa_pct"]) / 100)
	var consolo := 0
	for bg: Dictionary in r["baus"]:
		consolo += int(bg["ouro"])  # espaços de baú cheios viram ouro
	_checa("ouro creditado", int(jog.estado["inventario"]["ouro"]) == ouro0 + int(r["ouro"]) + consolo)
	_vencer_torneio(jog, "torneio_castelo_alvar")
	_vencer_torneio(jog, "torneio_feira_conde")
	var fim := _vencer_torneio(jog, "torneio_conde")
	_checa("conde abre o ducado e da o projeto", fim.get("regiao_nova", "") == "ducado" and fim.get("projeto", "") == "ferro_negro")

	# Chuva: prepara com a regra aplicada e visual
	var prep := jog.preparar_disputa("desafio_ribeira", 0)
	var janela_normal := int(Justa.carregar_configuracao()["galope"]["galope"]["janela_base_ms"])
	_checa("chuva: janela menor e visual", int(prep["cfg"]["galope"]["galope"]["janela_base_ms"]) < janela_normal and prep["visuais"] == ["chuva"])

	# Uma chance só
	jog.estado["pve"]["regiao"] = "reino"
	for t in ["torneio_aurora", "torneio_rocha", "torneio_lis", "torneio_mar"]:
		_vencer_torneio(jog, t)
	_checa("uma chance: liberado", jog.pode_disputar("desafio_unica_chance", 0)["ok"])
	jog.concluir_disputa("desafio_unica_chance", 0, _ev(true))
	_checa("uma chance: nao repete a vencida", jog.pode_disputar("desafio_unica_chance", 0)["erro"] == "chance_perdida")
	jog.concluir_disputa("desafio_unica_chance", 1, _ev(false))
	_checa("uma chance: perdeu, acabou", jog.progresso_torneio("desafio_unica_chance")["falhou"] and jog.pode_disputar("desafio_unica_chance", 1)["erro"] == "chance_perdida")
	_checa("uma chance: nada no automatico", not jog.pode_automatico("desafio_unica_chance", 0)["ok"])

	# Cavalo emprestado: a justa não cansa o cavalo do jogador
	var prep_c := jog.preparar_disputa("desafio_cavalo_estranho", 0)
	_checa("cavalo emprestado no lado do jogador", int(prep_c["lado_jogador"]["cavalo"]["velocidade"]) == int(d["desafios"]["cavalo_emprestado"]["cavalo"]["velocidade"]) and not prep_c["gasta_folego"])
	var folego0 := jog.folego_cavalo(jog.estado["cavalo_ativo"])
	jog.registrar_justa({"equipamento_final": {}, "gasta_folego": prep_c["gasta_folego"]})
	_checa("folego do seu cavalo intacto", jog.folego_cavalo(jog.estado["cavalo_ativo"]) == folego0)
	_checa("sem escudo nos dois", not jog.preparar_disputa("desafio_sem_escudo", 0)["lado_jogador"]["equipamento"].has("escudo"))

	# Nêmesis por região e campeão com estilo
	jog.estado["pve"]["encontros"] = {}
	var n_feira := int(jog.rival_para_justa("nemesis_corvo", "feiras")["lado"]["cavaleiro"]["precisao"])
	var n_reino := int(jog.rival_para_justa("nemesis_corvo", "reino")["lado"]["cavaleiro"]["precisao"])
	_checa("nemesis volta mais forte no reino (%d > %d)" % [n_reino, n_feira], n_reino > n_feira + 20)
	jog.estado["pve"]["encontros"]["nemesis_corvo"] = 50
	var n_max := int(jog.rival_para_justa("nemesis_corvo", "reino")["lado"]["cavaleiro"]["precisao"])
	_checa("crescimento do nemesis tem teto (+%d)" % (n_max - n_reino), n_max - n_reino == int(d["rivais"]["nemesis_corvo"]["cresce_max"]))
	var conde := jog.rival_para_justa("conde_rodrigo_alvar", "condado")
	var base_perfil: Dictionary = perfis[d["rivais"]["conde_rodrigo_alvar"]["perfil"]]
	_checa("campeao com estilo de mira proprio", conde["perfil"]["zona_preferida"] == "capacete" and int(conde["perfil"]["erro_mira_px"]) < int(base_perfil["erro_mira_px"]) and conde["provocacao"] != "")

	# Migração do save v1
	var velho := {"versao": 1, "inventario": {"ouro": 5, "itens": []}}
	ServicoJogador.migrar(velho)
	_checa("migracao v1 -> v2 cria projetos", velho["inventario"]["projetos"] == [] and int(velho["versao"]) == ServicoJogador.VERSAO)

	# Arena noturna (cena de verdade)
	var fluxo: FluxoTelas = root.get_node("Fluxo")
	jog.estado["pve"]["regiao"] = "ducado"
	_vencer_torneio(jog, "torneio_vimar")
	_vencer_torneio(jog, "torneio_lobos")
	_vencer_torneio(jog, "torneio_portas_montargil")
	fluxo.disputa = {"torneio": "desafio_tochas", "indice": 0}
	fluxo.modo_justa = "disputa"
	var arena: Arena = load("res://game/scenes/arena/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var c: ControladorJusta = arena.get_node("Justa")
	_checa("justa noturna: mundo escuro", arena.has_node("Ambiente") and c.desafios == ["noturna"])
	var amp := int(c._cfg["mira"]["oscilacao"]["amplitude_px"])
	_checa("justa noturna: mao mais tremida na mira (%d)" % amp, amp > int(Justa.carregar_configuracao()["mira"]["oscilacao"]["amplitude_px"]))
	arena.free()

	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_circuito/" + arq)
	print("CIRCUITO %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _vencer_torneio(jog: ServicoJogador, t: String) -> Dictionary:
	var ultimo := {}
	var n: int = (jog.pve()["torneios"][t]["rivais"] as Array).size()
	for i in range(jog.progresso_torneio(t)["proxima"], n):
		ultimo = jog.concluir_disputa(t, i, _ev(true))
	return ultimo

func _vencer_regiao(jog: ServicoJogador, r: String) -> void:
	for t: String in jog.pve()["regioes"][r]["torneios"]:
		if not jog.pve()["torneios"][t].get("opcional", false):
			_vencer_torneio(jog, t)

func _ev(venceu: bool) -> Array:
	return [{"tipo": "impacto", "jogador": {"zona": "peito", "falta": false}},
		{"tipo": "fim", "vencedor": JustaFases.Lado.JOGADOR if venceu else JustaFases.Lado.RIVAL, "motivo": "pontos"}]

func _checa(nome: String, ok: bool) -> void:
	print("CIRCUITO %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
