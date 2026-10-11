extends SceneTree
## Notificações (3.23, headless): tipos novos (forja, forno, baú) agendados,
## cada tipo desligável e a chave "todas", aviso no jogo do baú pronto (só se
## ligado), migração v6 -> v7, tela de configurações e o registro do push
## na nuvem (Supabase falso) com as preferências.

var _falhas := 0
var _enviado := {}

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_notif/")
	jog.caminho_save = "user://teste_notif/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
	var notif: ServicoNotificacoes = root.get_node("Notificacoes")

	_checa("timer da forja vira tipo forja", notif.tipo_do_timer("forja") == "forja" and notif.tipo_do_timer("fundicao") == "forja" and notif.tipo_do_timer("treino_cavalo") == "treino")
	jog.estado["cavaleiro"]["nivel"] = 10
	jog.estado["inventario"]["materiais"]["sucata"] = 8
	jog.fundir("lingote_ferro", 2)
	jog.ganhar_bau("ferro")
	jog.comecar_abrir(jog.baus()[0]["id"])
	notif.reagendar()
	var tipos: Array = notif.agendadas.map(func(n): return n["tipo"])
	_checa("agenda forno e bau", tipos.has("forja") and tipos.has("bau"))
	_checa("textos dos avisos existem", notif.agendadas.all(func(n): return tr(n["chave_texto"]) != n["chave_texto"]))
	jog.definir_notificacao("bau", false)
	_checa("desligar o bau tira o aviso", not notif.agendadas.any(func(n): return n["tipo"] == "bau") and notif.agendadas.any(func(n): return n["tipo"] == "forja"))
	jog.definir_notificacao("todas", false)
	_checa("desligar todas tira tudo", notif.agendadas.is_empty() and not jog.notificacao_ligada("forja"))
	jog.definir_notificacao("todas", true)
	jog.definir_notificacao("bau", true)

	# Aviso no jogo do baú pronto
	var recebidos: Array = []
	notif.pronto.connect(func(a): recebidos.append(a["tipo"]))
	ServicoTempo.deslocamento += 99999
	notif._acumulado = 1.0
	notif._process(0.0)
	_checa("aviso do bau e do forno no jogo", recebidos.has("bau") and recebidos.has("fundicao"))
	ServicoTempo.deslocamento = 0

	# Desligado: não avisa
	jog.estado["baus"]["espacos"] = []
	jog.ganhar_bau("madeira")
	jog.comecar_abrir(jog.baus()[0]["id"])
	jog.definir_notificacao("bau", false)
	recebidos.clear()
	ServicoTempo.deslocamento += 99999
	notif._acumulado = 1.0
	notif._process(0.0)
	_checa("bau desligado nao avisa", not recebidos.has("bau"))
	ServicoTempo.deslocamento = 0
	jog.definir_notificacao("bau", true)

	# Migração
	var velho := {"versao": 6}
	ServicoJogador.migrar(velho)
	_checa("migracao cria config", velho.has("config") and velho["config"]["notificacoes"] == {})

	# Tela
	var tela: TelaConfiguracoes = load("res://game/scenes/ui/tela_configuracoes.tscn").instantiate()
	root.add_child(tela)
	await process_frame
	tela.abrir()
	await process_frame
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ServicoNotificacoes.DADOS))
	# As três primeiras chaves são de acessibilidade (canhoto, vibração, bateria; 3.24/3.25).
	var chaves: Array = tela.get_node("Coluna/Rolagem/Lista").get_children().filter(func(c): return c is CheckButton).slice(3)
	_checa("uma chave por tipo e a geral (%d)" % chaves.size(), chaves.size() == dados["ordem"].size() + 1)
	(chaves[2] as CheckButton).button_pressed = false
	_checa("a chave muda a preferencia", not jog.notificacao_ligada(dados["ordem"][1]))
	tela.queue_free()

	# Push: registra o token com as preferências
	var nuvem: ServicoNuvem = root.get_node("Nuvem")
	nuvem._cfg = {"url": "https://falso.supabase.co", "chave_publica": "pub", "envio_atraso_s": 99, "tentativas": 1}
	nuvem.caminho_sessao = "user://teste_notif/sessao.json"
	nuvem.sessao = {"access_token": "t", "refresh_token": "r", "expira_em": ServicoTempo.agora() + 3600, "usuario": "u1"}
	nuvem.transporte = _falso
	var rp := await nuvem.registrar_push("token_de_teste_123", "android")
	_checa("push registrado com as preferencias", rp["ok"] and _enviado.get("token", "") == "token_de_teste_123"
		and _enviado["preferencias"].get(dados["ordem"][1], true) == false)

	for arq in ["jogador.json", "jogador.json.bak", "sessao.json"]:
		DirAccess.remove_absolute("user://teste_notif/" + arq)
	print("NOTIF %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _falso(_metodo: int, url: String, _cab: PackedStringArray, corpo: String) -> Dictionary:
	if url.contains("/rest/v1/dispositivo_push"):
		_enviado = JSON.parse_string(corpo)
		return {"codigo": 201, "corpo": ""}
	return {"codigo": 404, "corpo": ""}

func _checa(nome: String, ok: bool) -> void:
	print("NOTIF %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
