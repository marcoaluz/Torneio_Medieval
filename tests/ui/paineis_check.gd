extends SceneTree
## Um painel por vez na vila: abrir outro esconde o aberto (e ele volta
## quando o novo fecha), o fundo escuro cobre o topo e fica abaixo de todo
## painel, e a oferta só aparece com tudo fechado (save em user://teste_paineis/).

var _falhas := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_paineis/")
	jog.caminho_save = "user://teste_paineis/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
	jog.estado["cavaleiro"]["nivel"] = 12
	jog.estado["historia"]["vistas"] = jog.cfg_historia()["ordem"].duplicate()
	var vila: Vila = load("res://game/scenes/village/vila.tscn").instantiate()
	root.add_child(vila)
	await _q(3)
	var ger := vila.paineis
	var fundo := ger.fundo
	var interface := vila.get_node("Interface")
	_checa("sem painel: fundo escondido", not fundo.visible and ger.nenhum_aberto())
	var topo := interface.get_node("Topo")
	_checa("o fundo fica acima do topo e abaixo dos paineis", fundo.get_index() > topo.get_index() and
		ger.paineis.all(func(p): return p.get_index() > fundo.get_index()))
	vila.tela_baus.abrir()
	await _q(2)
	_checa("painel aberto: fundo escuro", fundo.visible and ger.abertos() == [vila.tela_baus])
	vila.tela_loja.abrir()
	await _q(2)
	_checa("abrir outro esconde o primeiro", ger.abertos() == [vila.tela_loja] and not vila.tela_baus.visible)
	vila.tela_loja.visible = false
	await _q(2)
	_checa("fechar devolve o que estava embaixo", vila.tela_baus.visible and ger.abertos() == [vila.tela_baus])
	vila.tela_baus.visible = false
	await _q(2)
	_checa("tudo fechado: sem fundo", not fundo.visible and ger.nenhum_aberto())
	# Fechar um e abrir outro no mesmo quadro (como os botões fazem) não traz o antigo de volta.
	vila.tela_baus.abrir()
	await _q(1)
	vila.tela_baus.visible = false
	vila.tela_missoes.abrir("diarias")
	await _q(3)
	_checa("trocar de tela no mesmo quadro", ger.abertos() == [vila.tela_missoes])
	vila.tela_missoes.visible = false
	await _q(2)
	# Painel de prédio, Equipamentos pela forja.
	vila.tocar_predio("armeiro")
	await _q(2)
	_checa("painel do armeiro aberto", ger.abertos() == [vila.tela_forja])
	vila.tela_equipamentos.abrir()
	await _q(2)
	_checa("equipamentos por cima da forja: so ele", ger.abertos() == [vila.tela_equipamentos])
	vila.tela_equipamentos.fechar()
	await _q(2)
	_checa("fechar equipamentos volta para a forja", ger.abertos() == [vila.tela_forja])
	vila.tela_forja.visible = false
	await _q(2)
	# Oferta: só com tudo fechado.
	vila.tela_baus.abrir()
	jog.disparar_oferta("derrota_por_pouco")
	jog.estado["liga"]["ultima_oferta"] = {}
	await _q(2)
	_checa("oferta nao aparece com painel aberto", not vila.janela_oferta.visible)
	vila.tela_baus.visible = false
	await _q(3)
	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_paineis/" + arq)
	print("PAINEIS %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _q(n: int) -> void:
	for i in n:
		await process_frame

func _checa(nome: String, ok: bool) -> void:
	print("PAINEIS %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
