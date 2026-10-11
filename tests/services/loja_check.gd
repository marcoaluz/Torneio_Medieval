extends SceneTree
## Loja, VIP, passe e ofertas (3.18, headless): compras pelo provedor de
## teste, VIP com efeito (timers, vaga, fôlego, gemas), passe por XP de
## justa com as duas trilhas, cosméticos (frase do arauto), materiais com
## limite diário, terminar timer/baú com gemas, ofertas por gatilho (derrota
## por pouco) com intervalo e validade, migração e as telas.

var _falhas := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_loja/")
	jog.caminho_save = "user://teste_loja/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
	var cfg := jog.cfg_loja()
	var eco: Dictionary = Balanceamento.ler("economia")

	# Compras pelo provedor de teste
	_checa("loja de teste em build de depuracao", jog.loja_de_teste())
	var g := jog.comprar("gemas_medio")
	_checa("pacote de gemas", g["ok"] and g["teste"] and jog.gemas() == 450)
	_checa("produto inexistente", jog.comprar("nada")["erro"] == "produto_inexistente")

	# VIP
	var dur0 := jog.duracao_timer(1000)
	var vagas0 := jog.vagas_treino("campo_treino")
	var rec0 := jog._recuperacao_por_hora()
	jog.comprar("vip_mensal")
	_checa("vip ativo e gemas do mes", jog.vip_ativo() and jog.gemas() == 450 + int(eco["vip"]["gemas_mes"]))
	_checa("vip: timers menores", jog.duracao_timer(1000) == dur0 * (100 - int(eco["vip"]["timer_reducao_pct"])) / 100)
	_checa("vip: segunda vaga de treino", jog.vagas_treino("campo_treino") == vagas0 + 1)
	_checa("vip: folego mais rapido", jog._recuperacao_por_hora() > rec0)
	ServicoTempo.deslocamento += 31 * 86400
	_checa("vip acaba em 30 dias", not jog.vip_ativo())
	ServicoTempo.deslocamento = 0

	# Passe
	var xp_nivel := int(eco["passe"]["xp_nivel"]) if eco["passe"].has("xp_nivel") else int(eco["passe"]["xp_por_nivel"])
	for i in xp_nivel / int(eco["passe"]["xp_por_justa"]) * 15:
		jog.registrar_justa({"equipamento_final": {}, "gasta_folego": false})
	var p := jog.passe()
	_checa("passe: justas sobem o nivel (%d)" % p["nivel"], int(p["nivel"]) == 15)
	_checa("premium bloqueado sem compra", jog.resgatar_passe(1, "premium")["erro"] == "passe_sem_premium")
	var ouro0 := jog.ouro()
	_checa("resgata a gratis", jog.resgatar_passe(1, "gratis")["ok"] and jog.ouro() == ouro0 + int(eco["passe"]["gratis"]["ouro_por_nivel"]))
	_checa("nao resgata duas vezes", jog.resgatar_passe(1, "gratis")["erro"] == "ja_resgatada")
	_checa("nivel acima do atual bloqueado", jog.resgatar_passe(16, "gratis")["erro"] == "nivel_do_passe_bloqueado")
	jog.comprar("passe_premium")
	var r15 := jog.resgatar_passe(15, "premium")
	_checa("premium do nivel 15 da um projeto (%s)" % r15.get("recompensa", {}).get("projeto", ""), r15["ok"] and r15["recompensa"].has("projeto"))
	jog.estado["liga"]["temporada"] = 2
	_checa("temporada nova zera o passe", int(jog.passe()["nivel"]) == 0 and not jog.passe()["premium"])

	# Cosméticos e materiais com gemas
	var gemas0 := jog.gemas()
	_checa("frase do arauto comprada", jog.comprar_com_gemas("frase_trovao")["ok"] and jog.gemas() == gemas0 - 120)
	_checa("nao compra duas vezes", jog.comprar_com_gemas("frase_trovao")["erro"] == "ja_comprado")
	_checa("usa a frase", jog.usar_cosmetico("frase_trovao")["ok"] and jog.estado["loja"]["frase"] == "frase_trovao")
	_checa("cosmetico nao comprado", jog.usar_cosmetico("vitoria_rubra")["erro"] == "cosmetico_bloqueado")
	var lim := int(cfg["materiais"][0]["limite_dia"])
	for i in lim:
		jog.comprar_com_gemas("lingote_ferro")
	_checa("material: limite diario", jog.comprar_com_gemas("lingote_ferro")["erro"] == "limite_diario" and jog.compras_restantes_hoje("lingote_ferro") == 0)
	ServicoTempo.deslocamento += 86400
	_checa("dia novo libera de novo", jog.compras_restantes_hoje("lingote_ferro") == lim)
	ServicoTempo.deslocamento = 0

	# Terminar com gemas
	jog.ganhar_bau("real")
	var bau_id: String = jog.baus()[0]["id"]
	jog.comecar_abrir(bau_id)
	var custo := jog.custo_pular(ServicoTempo.restante(int(jog.bau_abrindo()["abre_em"])))
	var gemas1 := jog.gemas()
	_checa("bau aberto agora com gemas (%d)" % custo, jog.pular_com_gemas(bau_id)["ok"] and jog.bau_pronto(bau_id) and jog.gemas() == gemas1 - custo)
	jog.estado["inventario"]["gemas"] = 0
	jog.treinar_cavaleiro("forca")
	var tid: String = jog.timers()[0]["id"]
	_checa("sem gemas nao pula", jog.pular_com_gemas(tid)["erro"] == "gemas_insuficientes")

	# Ofertas
	jog.estado["cavaleiro"]["nivel"] = 10
	var perto := [{"tipo": "fim", "vencedor": JustaFases.Lado.RIVAL, "motivo": "pontos", "placar_jogador": 5, "placar_rival": 6}]
	jog.concluir_disputa("feira_moinho", 0, perto)
	var nova := jog.oferta_nova()
	_checa("derrota por pouco abre a oferta", nova.get("id", "") == "oferta_revanche")
	jog.marcar_oferta_vista("oferta_revanche")
	_checa("vista nao aparece de novo", jog.oferta_nova().is_empty() and jog.ofertas().size() == 1)
	jog.concluir_disputa("feira_moinho", 0, perto)
	_checa("intervalo: nao repete no mesmo dia", jog.ofertas().size() == 1)
	var gemas2 := jog.gemas()
	_checa("compra a oferta e recebe o conteudo", jog.comprar("oferta_revanche")["ok"] and jog.gemas() == gemas2 + 100 and jog.ofertas().is_empty())
	ServicoTempo.deslocamento += 2 * 86400
	jog.concluir_disputa("feira_moinho", 0, perto)
	ServicoTempo.deslocamento += 4000
	_checa("oferta expira", jog.ofertas().is_empty() and jog.comprar("oferta_revanche")["erro"] == "oferta_expirada")
	ServicoTempo.deslocamento = 0

	# Migração
	var velho := {"versao": 8}
	ServicoJogador.migrar(velho)
	_checa("migracao cria a loja", velho.has("loja") and int(velho["loja"]["vip_ate"]) == 0)

	# Telas
	var tela: TelaLoja = load("res://game/scenes/ui/tela_loja.tscn").instantiate()
	root.add_child(tela)
	await process_frame
	tela.abrir("passe")
	await process_frame
	_checa("loja: 6 abas e as 30 linhas do passe", tela.get_node("Coluna/Abas").get_child_count() == 6
		and tela.get_node("Coluna/Rolagem/Lista").get_child_count() >= int(eco["passe"]["niveis"]))
	for a in ["ofertas", "gemas", "vip", "cosmeticos", "materiais"]:
		tela.aba = a
		tela.montar()
	tela.queue_free()
	var janela: JanelaOferta = load("res://game/scenes/ui/janela_oferta.tscn").instantiate()
	root.add_child(janela)
	await process_frame
	janela.mostrar({"id": "oferta_forja", "preco": "R$ 9,90", "conteudo": {}}, "")
	var toque := InputEventMouseButton.new()
	toque.pressed = true
	janela._gui_input(toque)
	_checa("janela da oferta fecha com um toque", not janela.visible)
	janela.queue_free()

	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_loja/" + arq)
	print("LOJA %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("LOJA %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
