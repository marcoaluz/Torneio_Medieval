extends SceneTree
## Telas sociais (3.20, headless): a TelaSocial monta todas as abas e
## subabas, cria e entra numa ordem pelos botões, manda mensagem rápida,
## denuncia e bloqueia, adiciona amigo por código e mostra o perfil; na vila
## aparecem o botão, a bandeira da ordem e os cavaleiros da ordem na praça.

var _falhas := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_social_ui/")
	jog.caminho_save = "user://teste_social_ui/jogador.json"
	jog.estado = jog.novo_estado()
	jog.criar_personagem({"nome": "Isolda", "nome_casa": "Casa Pardal", "corpo": "feminino", "rosto": "1", "cabelo": "1",
		"pele": "clara", "cor_principal": "azul_real", "cor_secundaria": "ouro_velho", "pelagem": "preto"})
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
	jog.estado["cavaleiro"]["nivel"] = 8
	jog.estado["inventario"]["ouro"] = 2000

	var camada := CanvasLayer.new()
	root.add_child(camada)
	var tela: TelaSocial = load("res://game/scenes/ui/tela_social.tscn").instantiate()
	camada.add_child(tela)
	await process_frame

	# Sem ordem: criar e entrar
	tela.abrir("ordem")
	await process_frame
	var lista: VBoxContainer = tela.get_node("Coluna/Rolagem/Lista")
	_checa("sem ordem: lista as ordens para entrar", _botoes(lista, "Entrar") == 5)
	_checa("sem ordem: campo de nome e botao Criar", tela.get_node("Coluna/Entrada").visible and (tela.get_node("Coluna/Entrada/Acao") as Button).text == "Criar")
	(tela.get_node("Coluna/Entrada/Campo") as LineEdit).text = "Ordem do Corvo"
	(tela.get_node("Coluna/Entrada/Acao") as Button).pressed.emit()
	await process_frame
	_checa("criar pela tela", jog.tem_ordem() and jog.ordem()["nome"] == "Ordem do Corvo")
	_checa("subabas aparecem", (tela.get_node("Coluna/SubAbas") as Control).visible and tela.get_node("Coluna/SubAbas").get_child_count() == 6)

	# Todas as abas e subabas montam sem erro
	var ok_abas := true
	for a: String in TelaSocial.ABAS:
		tela.aba = a
		tela.montar()
		await process_frame
		ok_abas = ok_abas and lista.get_child_count() >= 1
	for s: String in TelaSocial.SUBABAS:
		tela.aba = "ordem"
		tela.sub = s
		tela.montar()
		await process_frame
		ok_abas = ok_abas and lista.get_child_count() >= 1
	_checa("todas as abas e subabas montam", ok_abas)

	# Membros: botoes de cargo para o lider
	tela.aba = "ordem"
	tela.sub = "membros"
	tela.montar()
	await process_frame
	_checa("lider ve promover e expulsar", _botoes(lista, "Promover") >= 1 and _botoes(lista, "Expulsar") >= 1)
	var promover := _achar(lista, "Promover")
	promover.pressed.emit()
	await process_frame
	_checa("promover pelo botao", jog.ordem()["membros"].any(func(m): return m["cargo"] == "oficial"))

	# Ajuda: pedir pelo botao
	jog.treinar_cavaleiro("forca")
	for t: Dictionary in jog.estado["timers"]:
		t["termina_em"] = ServicoTempo.agora() + 3600
	tela.sub = "ajuda"
	tela.montar()
	await process_frame
	_achar(lista, "Pedir ajuda").pressed.emit()
	await process_frame
	_checa("pedir ajuda pelo botao", jog.estado["social"]["pedidos"].size() == 1)
	_achar(lista, "Ajudar (+2)").pressed.emit()
	await process_frame
	_checa("ajudar pelo botao da moeda", jog.moeda_ordem() == 2)

	# Chat: mensagem rapida, denunciar e bloquear
	tela.aba = "chat"
	tela.canal = "ordem"
	jog.chat_atualizar()
	tela.montar()
	await process_frame
	_achar(lista, "Boa justa!").pressed.emit()
	await process_frame
	_checa("mensagem rapida pela tela", jog.chat_mensagens("ordem").any(func(m): return m["de_id"] == "voce" and m["chave"] == "boa_justa"))
	_checa("botoes denunciar e bloquear nas mensagens dos outros", _botoes(lista, "Denunciar") >= 1 and _botoes(lista, "Bloquear") >= 1)
	_achar(lista, "Denunciar").pressed.emit()
	await process_frame
	_checa("denunciar pede o motivo", _botoes(lista, "Ofensa") == 1 and _botoes(lista, "Spam") == 1)
	_achar(lista, "Ofensa").pressed.emit()
	await process_frame
	_checa("denuncia guardada pela tela", jog.denuncias_pendentes().size() == 1)
	var antes := jog.chat_mensagens("ordem").size()
	_achar(lista, "Bloquear").pressed.emit()
	await process_frame
	_checa("bloquear pela tela", jog.bloqueados().size() == 1 and jog.chat_mensagens("ordem").size() < antes)
	(tela.get_node("Coluna/Entrada/Campo") as LineEdit).text = "Boa tarde a todos"
	jog.estado["social"]["chat"]["ultimo_envio"] = 0
	(tela.get_node("Coluna/Entrada/Acao") as Button).pressed.emit()
	await process_frame
	_checa("texto livre pela tela", jog.chat_mensagens("ordem").any(func(m): return m["texto"] == "Boa tarde a todos"))
	tela.canal = "global"
	tela.montar()
	await process_frame
	_checa("chat global monta", lista.get_child_count() >= 2)

	# Amigos por codigo
	tela.aba = "amigos"
	tela.montar()
	await process_frame
	var codigo: String = jog.codigos_de_teste(1)[0]["codigo"]
	(tela.get_node("Coluna/Entrada/Campo") as LineEdit).text = codigo
	(tela.get_node("Coluna/Entrada/Acao") as Button).pressed.emit()
	await process_frame
	_checa("amigo por codigo pela tela", jog.amigos().size() == 1)
	(tela.get_node("Coluna/Entrada/Campo") as LineEdit).text = "TM-ZZZZZZ"
	(tela.get_node("Coluna/Entrada/Acao") as Button).pressed.emit()
	await process_frame
	_checa("codigo desconhecido mostra o erro", (tela.get_node("Coluna/Mensagem") as Label).text == tr("ERRO_CODIGO_NAO_ENCONTRADO"))

	# Perfil de um amigo e o proprio
	tela.abrir("perfil", jog.amigos()[0]["id"])
	await process_frame
	_checa("perfil do amigo mostra retrato, brasao e liga", lista.get_child_count() >= 2 and _tem_texto(lista, "Liga "))
	tela.abrir("perfil", "voce")
	await process_frame
	_checa("perfil proprio mostra o nome", _tem_texto(lista, "Isolda"))

	# Gerir: sair pede confirmacao e o editor de brasao abre
	tela.aba = "ordem"
	tela.sub = "gerir"
	tela.montar()
	await process_frame
	_achar(lista, "Editar brasão").pressed.emit()
	await process_frame
	_checa("editor de brasao da ordem abre por cima", _todos(tela.get_parent()).any(func(c): return c is EditorBrasao and c.alvo_ordem))
	tela._fechar_editor()
	await process_frame
	var antes_ordem: String = jog.ordem()["nome"]
	_achar(lista, "Dissolver a ordem").pressed.emit()
	await process_frame
	_checa("dissolver pede confirmacao", jog.tem_ordem() and jog.ordem()["nome"] == antes_ordem)
	_achar(lista, "Toque de novo para dissolver").pressed.emit()
	await process_frame
	_checa("dissolver depois de confirmar", not jog.tem_ordem())
	camada.queue_free()

	# Vila: botao, bandeira da ordem e cavaleiros na praca
	jog.entrar_ordem(jog.ordens_para_entrar()[1]["id"])
	var vila: Vila = load("res://game/scenes/village/vila.tscn").instantiate()
	root.add_child(vila)
	await process_frame
	await process_frame
	_checa("vila tem o botao da ordem", (vila.get_node("Interface/Topo/Linha/Social") as Button).text.begins_with("Ordem"))
	_checa("bandeira da ordem visivel", vila.vida.bandeira_ordem.visible and vila.vida.bandeira_ordem.texture != null)
	var n := int(jog.cfg_ordem()["praca_max"])
	_checa("cavaleiros da ordem na praca (%d)" % n, vila.vida.cavaleiros_ordem.size() == n)
	var x0 := vila.vida.cavaleiros_ordem[0].position.x
	for i in 20:
		await process_frame
	_checa("cavaleiros passam pela praca", vila.vida.cavaleiros_ordem[0].position.x != x0)
	(vila.get_node("Interface/Topo/Linha/Social") as Button).pressed.emit()
	await process_frame
	_checa("botao abre a tela social", vila.tela_social.visible)
	jog.sair_ordem()
	await process_frame
	_checa("sem ordem: bandeira e cavaleiros somem", not vila.vida.bandeira_ordem.visible and vila.vida.cavaleiros_ordem.is_empty())
	vila.queue_free()

	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_social_ui/" + arq)
	print("SOCIAL_UI %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _botoes(no: Node, texto: String) -> int:
	var n := 0
	for c in _todos(no):
		if c is Button and c.text == texto:
			n += 1
	return n

func _achar(no: Node, texto: String) -> Button:
	for c in _todos(no):
		if c is Button and c.text == texto:
			return c
	push_error("botao nao achado: " + texto)
	return Button.new()

func _tem_texto(no: Node, trecho: String) -> bool:
	for c in _todos(no):
		if c is Label and (c as Label).text.contains(trecho):
			return true
	return false

func _todos(no: Node) -> Array:
	var r: Array = []
	for c in no.get_children():
		r.append(c)
		r.append_array(_todos(c))
	return r

func _checa(nome: String, ok: bool) -> void:
	print("SOCIAL_UI %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
