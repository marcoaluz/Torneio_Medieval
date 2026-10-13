extends SceneTree
## Ordens, ajuda, doações, torneio semanal, loja da ordem, chat, bloqueio,
## denúncia, amigos e perfil público (3.20, headless). Tudo simulado até o
## servidor: o teste confere o serviço (comandos {ok, erro}), o determinismo
## pela semente do save e a migração do save v10 para o v11.

var _falhas := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_social/")
	jog.caminho_save = "user://teste_social/jogador.json"
	jog.estado = jog.novo_estado()
	jog.criar_personagem({"nome": "Isolda", "nome_casa": "Casa Pardal", "corpo": "feminino", "rosto": "1", "cabelo": "1",
		"pele": "clara", "cor_principal": "azul_real", "cor_secundaria": "ouro_velho", "pelagem": "preto"})
	var cfg := jog.cfg_ordem()

	# --- sem ordem
	_checa("novo save tem social vazio", not jog.tem_ordem() and jog.moeda_ordem() == 0 and jog.amigos().is_empty())
	_checa("nivel baixo nao cria", jog.criar_ordem("Ordem do Corvo")["erro"] == "nivel_baixo")
	jog.estado["cavaleiro"]["nivel"] = int(cfg["nivel_minimo"])
	_checa("sem ouro nao cria", jog.criar_ordem("Ordem do Corvo")["erro"] == "ouro_insuficiente")
	jog.estado["inventario"]["ouro"] = 2000
	_checa("nome ofensivo e curto recusados", jog.criar_ordem("A")["erro"] == "nome_curto" and jog.criar_ordem("123")["erro"] != "")
	var para_entrar := jog.ordens_para_entrar()
	_checa("5 ordens simuladas para entrar, deterministico", para_entrar.size() == 5 and jog.ordens_para_entrar()[0]["nome"] == para_entrar[0]["nome"])

	# --- criar
	var ouro0 := jog.ouro()
	var cr := jog.criar_ordem("  Ordem   do Corvo ")
	_checa("cria a ordem: gasta ouro, e lider", cr["ok"] and jog.tem_ordem() and jog.ouro() == ouro0 - int(cfg["criar"]["ouro"]) and jog.cargo_na_ordem() == "lider")
	var o := jog.ordem()
	_checa("nome limpo, 1 + recrutas membros", o["nome"] == "Ordem do Corvo" and (o["membros"] as Array).size() == 1 + int(cfg["criar"]["recrutas"]))
	_checa("ja tem ordem", jog.criar_ordem("Outra Ordem")["erro"] == "ja_tem_ordem" and jog.entrar_ordem("s0")["erro"] == "ja_tem_ordem")
	_checa("linha do jogador com poder de agora", o["membros"].any(func(m): return m["id"] == "voce" and int(m["poder"]) == jog.poder_jogador()))

	# --- cargos
	var recruta: String = o["membros"].filter(func(m): return m["id"] != "voce")[0]["id"]
	_checa("promove membro a oficial", jog.agir_sobre_membro(recruta, "promover")["ok"] and _cargo(jog, recruta) == "oficial")
	_checa("nao promove oficial", jog.agir_sobre_membro(recruta, "promover")["erro"] == "sem_permissao")
	_checa("rebaixa oficial", jog.agir_sobre_membro(recruta, "rebaixar")["ok"] and _cargo(jog, recruta) == "membro")
	_checa("ninguem age sobre si", jog.agir_sobre_membro("voce", "expulsar")["erro"] == "sem_permissao")
	_checa("expulsa membro", jog.agir_sobre_membro(recruta, "expulsar")["ok"] and _cargo(jog, recruta) == "")
	_checa("membro inexistente", jog.agir_sobre_membro("zzz", "expulsar")["erro"] == "membro_inexistente")
	var b := {"forma": "redondo", "divisao": "partido", "cor1": "verde_floresta", "cor2": "prata", "simbolo": "lua", "posicao": "centro", "cor_simbolo": "ouro_velho"}
	_checa("lider edita o brasao", jog.editar_brasao_ordem(b)["ok"] and jog.ordem()["brasao"]["simbolo"] == "lua")
	_checa("lider renomeia", jog.renomear_ordem("Ordem do Lobo")["ok"] and jog.ordem()["nome"] == "Ordem do Lobo" and jog.renomear_ordem("x")["erro"] == "nome_curto")
	_checa("lider nao sai sem passar a lideranca", jog.sair_ordem()["erro"] == "passe_a_lideranca")
	var outro: String = jog.ordem()["membros"].filter(func(m): return m["id"] != "voce")[0]["id"]
	_checa("passa a lideranca", jog.passar_lideranca(outro)["ok"] and jog.cargo_na_ordem() == "oficial" and _cargo(jog, outro) == "lider")
	_checa("oficial: edita brasao, nao renomeia, nao promove",
		jog.editar_brasao_ordem(b)["ok"] and jog.renomear_ordem("Ordem Nova")["erro"] == "sem_permissao" and jog.passar_lideranca(outro)["erro"] == "sem_permissao")
	_checa("oficial sai", jog.sair_ordem()["ok"] and not jog.tem_ordem())

	# --- entrar numa ordem simulada
	var alvo: Dictionary = jog.ordens_para_entrar()[1]
	_checa("entra numa ordem simulada", jog.entrar_ordem(alvo["id"])["ok"] and jog.ordem()["nome"] == alvo["nome"] and jog.cargo_na_ordem() == "membro")
	_checa("membros = os da ordem + voce, com um lider", (jog.ordem()["membros"] as Array).size() == int(alvo["membros"]) + 1
		and jog.ordem()["membros"].filter(func(m): return m["cargo"] == "lider").size() == 1)
	_checa("membro nao promove nem expulsa", jog.agir_sobre_membro(outro, "expulsar")["erro"] in ["sem_permissao", "membro_inexistente"])
	_checa("membro nao dissolve", jog.dissolver_ordem()["erro"] == "sem_permissao")
	_checa("entrar com id inexistente", jog.sair_ordem()["ok"] and jog.entrar_ordem("xx")["erro"] == "ordem_inexistente")
	jog.entrar_ordem(alvo["id"])

	# --- ajuda nos timers
	jog.estado["inventario"]["ouro"] = 5000
	var tr_ := jog.treinar_cavaleiro("forca")
	_checa("treino iniciado para pedir ajuda", tr_["ok"])
	var ajudaveis := jog.timers_para_pedir_ajuda()
	_checa("treino aparece como ajudavel", ajudaveis.size() >= 1 and not ajudaveis[0]["pedido"])
	var tid: String = ajudaveis[0]["id"]
	# o primeiro dia limita timers a 15 s; alonga o timer para o teste
	for t: Dictionary in jog.estado["timers"]:
		if t["id"] == tid:
			t["termina_em"] = ServicoTempo.agora() + 3600
	_checa("pede ajuda", jog.pedir_ajuda(tid)["ok"] and jog.pedido_do_timer(tid)["ajudantes"].size() == int(cfg["ajuda"]["ajudas_max_por_pedido"]))
	_checa("nao pede duas vezes", jog.pedir_ajuda(tid)["erro"] == "ja_pediu")
	_checa("timer inexistente", jog.pedir_ajuda("zzz")["erro"] == "timer_inexistente")
	_checa("logo depois nada aplicado", jog.atualizar_ajudas() == 0)
	var antes := _termina(jog, tid)
	for p: Dictionary in jog.estado["social"]["pedidos"]:
		p["em"] = int(p["em"]) - 100000  # todos responderam
	var n := jog.atualizar_ajudas()
	var seg := int(cfg["ajuda"]["segundos_por_ajuda"])
	_checa("ajudas aplicadas cortam o timer (%d)" % n, n == int(cfg["ajuda"]["ajudas_max_por_pedido"]) and _termina(jog, tid) == antes - n * seg)
	_checa("sem repetir", jog.atualizar_ajudas() == 0)
	# timer que acaba descarta o pedido
	for t: Dictionary in jog.estado["timers"]:
		if t["id"] == tid:
			t["termina_em"] = ServicoTempo.agora() - 1
	jog.atualizar_ajudas()
	_checa("pedido de timer pronto some", jog.pedido_do_timer(tid).is_empty())

	# --- ajudar os outros (simulado) e moeda
	var pedidos := jog.pedidos_da_ordem()
	_checa("pedidos da ordem (%d), estaveis" % pedidos.size(), pedidos.size() == int(cfg["ajuda"]["pedidos_simulados"]) and jog.pedidos_da_ordem()[0]["id"] == pedidos[0]["id"])
	var aj := jog.ajudar(pedidos[0]["id"])
	_checa("ajudar da moeda", aj["ok"] and int(aj["moeda"]) == int(cfg["ajuda"]["moeda_por_ajuda"]) and jog.moeda_ordem() == int(aj["moeda"]))
	_checa("nao ajuda duas vezes", jog.ajudar(pedidos[0]["id"])["erro"] == "ja_ajudou" and jog.pedidos_da_ordem()[0]["ajudado"])
	jog.estado["social"]["ajuda_moeda"]["moeda"] = int(cfg["ajuda"]["moeda_max_dia"])
	var aj2 := jog.ajudar(pedidos[1]["id"])
	_checa("teto de moeda por dia: ajuda sem moeda", aj2["ok"] and int(aj2["moeda"]) == 0)
	_checa("pedido inexistente", jog.ajudar("zz")["erro"] == "pedido_inexistente")

	# --- doações
	var dons := jog.pedidos_de_doacao()
	_checa("pedidos de doacao", dons.size() == int(cfg["doacao"]["pedidos_simulados"]) and not dons[0]["atendido"])
	var d0: Dictionary = dons[0]
	jog.estado["inventario"]["materiais"][d0["material"]] = 0
	_checa("sem material nao doa", jog.doar(d0["id"])["erro"] == "material_insuficiente")
	jog.estado["inventario"]["materiais"][d0["material"]] = 50
	var moeda0 := jog.moeda_ordem()
	var dr := jog.doar(d0["id"])
	_checa("doa: gasta material e da moeda", dr["ok"] and jog.material(d0["material"]) == 50 - int(d0["quantidade"]) and jog.moeda_ordem() == moeda0 + int(cfg["doacao"]["moeda_por_doacao"]))
	_checa("nao doa duas vezes", jog.doar(d0["id"])["erro"] == "ja_doou")
	jog.estado["social"]["doacoes"]["unidades"] = int(cfg["doacao"]["limite_dia_unidades"])
	jog.estado["inventario"]["materiais"][dons[1]["material"]] = 50
	_checa("limite diario de doacao", jog.doar(dons[1]["id"])["erro"] == "limite_diario" and jog.doacao_restante_hoje() == 0)

	# --- torneio semanal
	var tw := jog.torneio_semana()
	_checa("torneio: posicao entre 1 e %d, sete ordens rivais" % (int(cfg["torneio"]["ordens_simuladas"]) + 1),
		int(tw["posicao"]) >= 1 and int(tw["posicao"]) <= int(cfg["torneio"]["ordens_simuladas"]) + 1 and (tw["ordens"] as Array).size() == int(cfg["torneio"]["ordens_simuladas"]) + 1)
	var vit := [{"tipo": "fim", "vencedor": JustaFases.Lado.JOGADOR, "motivo": "pontos"}]
	jog.procurar_adversario()
	jog.concluir_pvp(vit)
	var tw2 := jog.torneio_semana()
	_checa("vitoria de PvP conta no torneio da ordem", int(tw2["minhas_vitorias"]) == 1 and int(tw2["pontos"]) == int(tw["pontos"]) + 1)
	_checa("sem premio pendente na primeira semana", (tw2["pendente"] as Dictionary).is_empty() and jog.resgatar_torneio()["erro"] == "sem_premio")
	# semana seguinte: o premio fica pendente
	jog.estado["social"]["torneio"]["semana"] = jog.semana_atual() - 1
	jog.estado["social"]["torneio"]["participou"] = true
	var tw3 := jog.torneio_semana()
	_checa("virar a semana guarda o premio", not (tw3["pendente"] as Dictionary).is_empty() and jog.social_alerta())
	var pend: Dictionary = tw3["pendente"]
	var m1 := jog.moeda_ordem()
	var rs := jog.resgatar_torneio()
	_checa("resgata o premio (moeda e bau)", rs["ok"] and jog.moeda_ordem() == m1 + int(pend["moeda"]) and (jog.torneio_semana()["pendente"] as Dictionary).is_empty())
	_checa("vitorias zeradas na semana nova", int(jog.torneio_semana()["minhas_vitorias"]) == 0)

	# --- loja da ordem
	jog.estado["social"]["moeda"] = 0
	var loja := jog.loja_ordem()
	_checa("loja: sem moeda nada pode", loja.size() >= 4 and loja.all(func(i): return not i["pode"] and i["erro"] == "moeda_insuficiente"))
	jog.estado["social"]["moeda"] = 1000
	var aco0 := jog.material("lingote_aco")
	var cp := jog.comprar_da_ordem("lingote_aco")
	_checa("compra material", cp["ok"] and jog.material("lingote_aco") == aco0 + 2 and jog.moeda_ordem() == 1000 - 30)
	jog.comprar_da_ordem("lingote_aco")
	jog.comprar_da_ordem("lingote_aco")
	_checa("limite semanal", jog.comprar_da_ordem("lingote_aco")["erro"] == "limite_semana")
	var pj := jog.comprar_da_ordem("projeto_cavaleiro_andante")
	_checa("compra projeto", pj["ok"] and (jog.estado["inventario"]["projetos"] as Array).has("cavaleiro_andante"))
	jog.estado["social"]["loja"]["compras"].erase("projeto_cavaleiro_andante")
	_checa("projeto repetido recusado", jog.comprar_da_ordem("projeto_cavaleiro_andante")["erro"] == "projeto_ja_tenho")
	_checa("produto inexistente", jog.comprar_da_ordem("zzz")["erro"] == "produto_inexistente")

	# --- chat
	var c0 := jog.chat_atualizar()
	_checa("chat simulado entra (%d)" % c0, c0 > 0 and jog.chat_mensagens("ordem").size() > 0 and jog.chat_mensagens("global").size() > 0)
	_checa("mensagens simuladas usam texto traduzivel", jog.chat_mensagens("ordem")[0]["chave"] != "" and jog.chat_mensagens("ordem")[0]["simulado"])
	var rap: String = jog.mensagens_rapidas()[0]
	var env := jog.chat_enviar("ordem", "", rap)
	_checa("envia mensagem rapida", env["ok"] and jog.chat_mensagens("ordem").back()["de_id"] == "voce" and jog.chat_mensagens("ordem").back()["chave"] == rap)
	_checa("limite de velocidade", jog.chat_enviar("ordem", "oi", "")["erro"] == "enviando_rapido")
	jog.estado["social"]["chat"]["ultimo_envio"] = 0
	_checa("texto livre", jog.chat_enviar("global", "Boa justa, pessoal!", "")["ok"] and jog.chat_mensagens("global").back()["texto"] == "Boa justa, pessoal!")
	jog.estado["social"]["chat"]["ultimo_envio"] = 0
	_checa("vazio, longo e inexistente", jog.chat_enviar("global", "   ", "")["erro"] == "mensagem_vazia"
		and jog.chat_enviar("global", "a".repeat(200), "")["erro"] == "mensagem_longa" and jog.chat_enviar("global", "", "xx")["erro"] == "mensagem_inexistente"
		and jog.chat_enviar("sala", "oi", "")["erro"] == "canal_inexistente")
	var lista_ofensas: Array = JSON.parse_string(FileAccess.get_file_as_string(ServicoNomes.LISTA))["raizes"]
	_checa("filtro de palavroes", jog.chat_enviar("global", "voce e um " + str(lista_ofensas[0]), "")["erro"] == "mensagem_ofensiva")
	jog.estado["social"]["chat"]["ultimo_envio"] = 0
	_checa("sem ordem nao ha chat da ordem", jog.sair_ordem()["ok"] and jog.chat_enviar("ordem", "", rap)["erro"] == "sem_ordem" and jog.chat_mensagens("ordem").is_empty())
	_checa("idioma: global mostra so o idioma atual", _so_idioma(jog.chat_mensagens("global"), "pt"))
	TranslationServer.set_locale("en")
	var so_en := jog.chat_mensagens("global").size()
	TranslationServer.set_locale("pt_BR")
	_checa("em ingles as mensagens em portugues somem", so_en == 0 or _so_idioma(jog.chat_mensagens("global"), "en"))

	# --- bloqueio e denuncia
	jog.entrar_ordem(alvo["id"])
	jog.chat_atualizar()
	var msg: Dictionary = jog.chat_mensagens("ordem").filter(func(m): return m["simulado"])[0]
	var dn := jog.denunciar(msg["de_id"], msg["de_nome"], "ofensa", "texto da mensagem")
	_checa("denuncia guardada para enviar", dn["ok"] and jog.denuncias_pendentes().size() == 1 and not jog.denuncias_pendentes()[0]["enviada"])
	_checa("denuncia repetida e motivo invalido", jog.denunciar(msg["de_id"], msg["de_nome"], "ofensa", "texto da mensagem")["erro"] == "ja_denunciado"
		and jog.denunciar(msg["de_id"], "x", "chato", "")["erro"] == "motivo_invalido" and jog.denunciar("voce", "x", "ofensa")["erro"] == "alvo_invalido")
	var qtd := jog.chat_mensagens("ordem").size()
	_checa("bloquear esconde as mensagens", jog.bloquear(msg["de_id"])["ok"] and jog.esta_bloqueado(msg["de_id"])
		and jog.chat_mensagens("ordem").size() < qtd and not jog.chat_mensagens("ordem").any(func(m): return m["de_id"] == msg["de_id"]))
	_checa("bloqueado some dos pedidos da ordem", not jog.pedidos_da_ordem().any(func(p): return p["membro_id"] == msg["de_id"]))
	_checa("desbloquear volta", jog.desbloquear(msg["de_id"])["ok"] and not jog.esta_bloqueado(msg["de_id"]))
	_checa("nao bloqueia a si", jog.bloquear("voce")["erro"] == "alvo_invalido")

	# --- amigos
	var codigo := jog.meu_codigo()
	_checa("meu codigo estavel e valido", RegraOrdem.codigo_valido(codigo) and jog.meu_codigo() == codigo)
	_checa("codigo invalido, proprio e desconhecido", jog.adicionar_amigo_por_codigo("abc")["erro"] == "codigo_invalido"
		and jog.adicionar_amigo_por_codigo(codigo)["erro"] == "codigo_proprio" and jog.adicionar_amigo_por_codigo("TM-ZZZZZZ")["erro"] == "codigo_nao_encontrado")
	var teste := jog.codigos_de_teste(2)
	var ad := jog.adicionar_amigo_por_codigo(str(teste[0]["codigo"]).to_lower())
	_checa("adiciona por codigo", ad["ok"] and jog.amigos().size() == 1 and jog.amigos()[0]["nome"] == teste[0]["nome"])
	_checa("amigo repetido", jog.adicionar_amigo_por_codigo(str(teste[0]["codigo"]))["erro"] == "ja_amigo")
	var membro: String = jog.ordem()["membros"].filter(func(m): return m["id"] != "voce")[0]["id"]
	_checa("adiciona membro da ordem como amigo", jog.adicionar_amigo_membro(membro)["ok"] and jog.amigos().size() == 2)
	_checa("remover amigo", jog.remover_amigo(jog.amigos()[0]["id"])["ok"] and jog.amigos().size() == 1)
	jog.bloquear(jog.amigos()[0]["id"])
	_checa("bloquear tira dos amigos e impede adicionar", jog.amigos().is_empty() and jog.adicionar_amigo_membro(membro)["erro"] == "bloqueado")
	jog.desbloquear(membro)

	# --- perfil publico
	var eu := jog.perfil_publico("voce")
	_checa("perfil proprio: cavaleiro, cavalo, brasao, liga, titulos", eu["nome"] == "Isolda" and eu["pelagem"] == "preto" and eu["brasao"].has("cor1")
		and eu["liga"]["nome"] == "bronze" and eu["titulos"] is Array and eu["codigo"] == codigo and not eu["simulado"])
	var pm := jog.perfil_publico(membro)
	_checa("perfil de membro simulado: completo e estavel", pm["simulado"] and pm["nome"] != "" and pm["cargo"] != "" and pm["ordem_nome"] == jog.ordem()["nome"]
		and pm["brasao"] is Dictionary and pm["liga"].has("nome") and jog.perfil_publico(membro)["pelagem"] == pm["pelagem"] and RegraOrdem.codigo_valido(pm["codigo"]))
	_checa("perfil de id inexistente", jog.perfil_publico("zzz").is_empty())
	var praca := jog.cavaleiros_da_ordem()
	_checa("cavaleiros da ordem na praca (ate %d)" % int(cfg["praca_max"]), praca.size() == int(cfg["praca_max"]) and praca[0]["brasao"] == jog.ordem()["brasao"])

	# --- persistencia e migracao
	var salvo := jog.estado.duplicate(true)
	jog.salvar()
	jog.estado = jog.novo_estado()
	jog.carregar()
	_checa("save v11 guarda ordem, moeda, amigos e bloqueios", jog.estado["social"]["ordem"]["nome"] == salvo["social"]["ordem"]["nome"]
		and jog.moeda_ordem() == int(salvo["social"]["moeda"]) and jog.amigos().size() == salvo["social"]["amigos"].size())
	var velho := {"versao": 10, "criado_em": 1, "cavaleiro": {}, "casa": {}, "inventario": {"materiais": {}, "projetos": []}}
	var mig := ServicoJogador.migrar(velho)
	_checa("migra v10 -> v11 com social vazio", int(mig["versao"]) == ServicoJogador.VERSAO and mig["social"]["ordem"] == {} and mig["social"]["amigos"] == [])

	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_social/" + arq)
	print("SOCIAL %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _cargo(jog: ServicoJogador, id: String) -> String:
	for m: Dictionary in jog.ordem().get("membros", []):
		if m["id"] == id:
			return str(m["cargo"])
	return ""

func _termina(jog: ServicoJogador, id: String) -> int:
	for t: Dictionary in jog.timers():
		if t["id"] == id:
			return int(t["termina_em"])
	return -1

func _so_idioma(msgs: Array, idioma: String) -> bool:
	return msgs.all(func(m): return m["idioma"] == idioma)

func _checa(nome: String, ok: bool) -> void:
	print("SOCIAL %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
