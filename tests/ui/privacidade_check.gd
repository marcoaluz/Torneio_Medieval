extends SceneTree
## Privacidade e dados (3.9, headless): aceite da política por versão, anúncios
## personalizados só com consentimento, a tela de política (aceitar e rever) e
## a exclusão de conta (servidor primeiro, depois o aparelho), com um servidor falso.

var _falhas := 0
var _chamadas: Array[String] = []
var _responder := 200

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_privacidade/")
	jog.caminho_save = "user://teste_privacidade/jogador.json"
	jog.estado = jog.novo_estado()

	# Aceite por versão
	_checa("novo jogador nao aceitou", not jog.privacidade_aceita() and jog.versao_politica() >= 1)
	_checa("anuncios personalizados desligados por padrao", not bool(jog.config_valor("anuncios_personalizados")))
	_checa("aceitar guarda a versao e a escolha", jog.aceitar_privacidade(true)["ok"] and jog.privacidade_aceita()
		and bool(jog.config_valor("anuncios_personalizados")))
	jog.estado["config"]["privacidade_aceita"] = jog.versao_politica() - 1
	_checa("versao antiga pede novo aceite", not jog.privacidade_aceita())
	jog.aceitar_privacidade(false)
	var anuncios: ServicoAnuncios = root.get_node("Anuncios")
	_checa("anuncios nao personalizados sem consentimento", not anuncios.personalizados())
	jog.aceitar_privacidade(true)
	_checa("anuncios personalizados com consentimento", anuncios.personalizados())

	# Tela da política
	var camada := CanvasLayer.new()
	root.add_child(camada)
	var t: TelaPrivacidade = load("res://game/scenes/ui/tela_privacidade.tscn").instantiate()
	t.revisao = true
	camada.add_child(t)
	await process_frame
	var texto: Label = t.get_node("Painel/Coluna/Rolagem/Texto")
	_checa("a tela mostra politica e termos", texto.text.contains("1.") and texto.text.contains(tr("TERMOS_TITULO")))
	_checa("rever mostra a escolha atual", (t.get_node("Painel/Coluna/Personalizados") as CheckButton).button_pressed)
	var recebido := []
	t.aceita.connect(func(p): recebido.append(p))
	(t.get_node("Painel/Coluna/Personalizados") as CheckButton).button_pressed = false
	t._ao_aceitar()
	_checa("salvar na revisao avisa e grava a escolha", recebido == [false] and not bool(jog.config_valor("anuncios_personalizados")))
	await process_frame

	# Exclusão de conta
	jog.criar_personagem({"nome": "Isolda", "nome_casa": "Casa Pardal", "corpo": "feminino", "rosto": "1", "cabelo": "1",
		"pele": "clara", "cor_principal": "azul_real", "cor_secundaria": "ouro_velho", "pelagem": "preto"})
	jog.estado["inventario"]["ouro"] = 999
	jog.salvar()
	var nuvem: ServicoNuvem = root.get_node("Nuvem")
	nuvem._cfg = {"url": "https://falso.supabase.co", "chave_publica": "pub_123", "envio_atraso_s": 0.1, "tentativas": 1}
	nuvem.caminho_sessao = "user://teste_privacidade/sessao.json"
	nuvem.caminho_cache_balanceamento = "user://teste_privacidade/balanceamento.json"
	# excluir_conta() limpa a fila de métricas: nunca a do jogo de verdade.
	(root.get_node("Metricas") as ServicoMetricas).caminho_fila = "user://teste_privacidade/metricas.json"
	nuvem.transporte = _falso
	nuvem.sessao = {"access_token": "t", "refresh_token": "r", "expira_em": ServicoTempo.agora() + 3600, "usuario": "u1", "anonimo": true}
	nuvem._salvar_sessao()
	FileAccess.open(nuvem.caminho_cache_balanceamento, FileAccess.WRITE).store_string("{}")

	_responder = 500
	var falha := await nuvem.excluir_conta()
	_checa("servidor falhou: nada e apagado", not falha["ok"] and nuvem.conectado() and FileAccess.file_exists(nuvem.caminho_sessao))
	_responder = 200
	_chamadas.clear()
	var r := await nuvem.excluir_conta()
	_checa("pede ao servidor a exclusao, com a confirmacao", r["ok"] and _chamadas == ["POST /functions/v1/excluir_conta {\"confirmacao\":\"EXCLUIR\"}"])
	_checa("esquece a sessao e os caches", not nuvem.conectado() and not FileAccess.file_exists(nuvem.caminho_sessao)
		and not FileAccess.file_exists(nuvem.caminho_cache_balanceamento))
	jog.apagar_dados_locais()
	_checa("apaga o jogador deste aparelho", not jog.tem_personagem() and jog.ouro() != 999 and not jog.privacidade_aceita()
		and jog.tutorial_passo() == 0)

	# Sem conta na nuvem: só limpa o aparelho
	nuvem._cfg = {}
	nuvem.sessao = {}
	var local := await nuvem.excluir_conta()
	_checa("sem nuvem a exclusao e local", local["ok"])

	# Configurações: dois toques para excluir
	var cfg: TelaConfiguracoes = load("res://game/scenes/ui/tela_configuracoes.tscn").instantiate()
	camada.add_child(cfg)
	await process_frame
	cfg.abrir()
	await process_frame
	var lista: VBoxContainer = cfg.get_node("Coluna/Rolagem/Lista")
	_checa("config tem a secao de privacidade e dados", _tem_botao(lista, tr("CONFIG_EXCLUIR_CONTA")) and _tem_botao(lista, tr("CONFIG_VER_POLITICA")))
	_botao(lista, tr("CONFIG_EXCLUIR_CONTA")).pressed.emit()
	await process_frame
	_checa("primeiro toque pede a confirmacao", _tem_botao(lista, tr("CONFIG_EXCLUIR_CONFIRMA")) and not _tem_botao(lista, tr("CONFIG_EXCLUIR_CONTA")))
	_botao(lista, tr("CONFIG_EXCLUIR_CANCELAR")).pressed.emit()
	await process_frame
	_checa("cancelar volta ao botao normal", _tem_botao(lista, tr("CONFIG_EXCLUIR_CONTA")))

	for arq in ["jogador.json", "jogador.json.bak", "sessao.json", "balanceamento.json"]:
		DirAccess.remove_absolute("user://teste_privacidade/" + arq)
	print("PRIVACIDADE %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _falso(metodo: int, url: String, _cab: PackedStringArray, corpo: String) -> Dictionary:
	var caminho := url.trim_prefix("https://falso.supabase.co")
	_chamadas.append("%s %s%s" % ["POST" if metodo == HTTPClient.METHOD_POST else "GET", caminho, (" " + corpo) if corpo != "" else ""])
	return {"codigo": _responder, "corpo": "{\"ok\":true}"}

func _tem_botao(no: Node, texto: String) -> bool:
	for c in no.get_children():
		if c is Button and (c as Button).text == texto:
			return true
	return false

func _botao(no: Node, texto: String) -> Button:
	for c in no.get_children():
		if c is Button and (c as Button).text == texto:
			return c
	return Button.new()

func _checa(nome: String, ok: bool) -> void:
	print("PRIVACIDADE %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
