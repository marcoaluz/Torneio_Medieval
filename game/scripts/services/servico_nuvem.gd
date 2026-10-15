class_name ServicoNuvem
extends Node
## Conta e save na nuvem (autoload "Nuvem", Pacote 2.12). Supabase pela API
## REST (sem SDK): login anônimo no primeiro acesso, renovação do token,
## envio do estado do jogador (com atraso, para juntar mudanças, e novas
## tentativas; o pendente sobrevive a fechar o jogo) e escolha entre o save
## local e o da nuvem pela revisão. Sem url/chave em game/data/servidor.json,
## fica desligado e o jogo segue só com o save local.
## Vincular Google Play Games: plano em docs/NUVEM.md (precisa de plugin
## Android e de uma Edge Function); `vincular_play_games` ainda não existe.
## O transporte HTTP é injetável (`transporte`) para os testes.
##
## Servidor dono da economia (3.2, auditoria A1): com `usar_acao` em
## servidor.json, o save deixa de subir inteiro. Cada comando que deu certo
## aqui (`Jogador.acao_feita`) vira uma ação na fila (`user://acoes.json`,
## sobrevive a fechar o jogo), enviada em ordem à Edge Function `acao` com um
## id único (repetir é seguro: o servidor devolve a mesma resposta). Rede ruim
## = tenta de novo mais tarde, na mesma ordem. Quando a fila esvazia, o estado
## do servidor substitui o local (o servidor vence; ação recusada lá some).
## O que precisa da decisão do servidor antes de jogar (semente da disputa,
## disputa automática) usa `chamar`, que espera a resposta.

signal estado_mudou(estado: String)  ## "desligado", "entrando", "conectado", "erro", "enviando"

const CONFIG := "res://game/data/servidor.json"
const SESSAO := "user://sessao.json"
const FILA := "user://acoes.json"
## Recusas que não adianta repetir (o servidor nunca vai aceitar esta ação).
const RECUSA_DEFINITIVA := [400, 403, 404, 413]

## Callable(metodo: int, url: String, cabecalhos: PackedStringArray, corpo: String)
## -> {codigo: int, corpo: String}. Pode ser corrotina (o padrão usa HTTPRequest).
var transporte: Callable
var caminho_sessao := SESSAO
var caminho_cache_balanceamento := Balanceamento.CACHE_REMOTO
var caminho_fila := FILA
## Ações ainda não confirmadas pelo servidor: [{id, tipo, args}], em ordem.
var fila: Array = []
## Ações recusadas pelo servidor nesta sessão (o estado dele já desfez o efeito).
var recusadas := 0
var estado := "desligado"
## {access_token, refresh_token, expira_em, usuario, anonimo, revisao, pendente}
var sessao := {}

var _cfg: Dictionary
var _jog: ServicoJogador
var _envio_em := -1.0
var _enviando := false
var _processando := false
var _espera_fila := -1.0
var _falhas_fila := 0

func _ready() -> void:
	_cfg = _ler(CONFIG)
	if not transporte.is_valid():
		transporte = _http
	sessao = _ler(caminho_sessao)
	carregar_fila()
	_jog = get_node_or_null("/root/Jogador")
	if _jog:
		_jog.mudou.connect(func(_s): agendar_envio())
		_jog.acao_feita.connect(enfileirar)

func configurado() -> bool:
	return str(_cfg.get("url", "")) != "" and str(_cfg.get("chave_publica", "")) != ""

func conectado() -> bool:
	return sessao.has("access_token")

## O servidor é o dono da economia (Edge Function `acao`)? Ligar só depois de
## publicar as funções e aplicar `economia_so_servidor` (docs/SERVIDOR.md).
func usa_acao() -> bool:
	return configurado() and bool(_cfg.get("usar_acao", false))

# ----------------------------------------------------------- ações (servidor)

## Põe uma ação na fila e tenta enviar já.
func enfileirar(tipo: String, args: Array) -> void:
	if not usa_acao():
		return
	fila.append({"id": novo_id(), "tipo": tipo, "args": args})
	_salvar_fila()
	processar_fila()

## Envia a fila em ordem. Para no primeiro erro de rede (tenta de novo depois,
## com espera crescente). Fila vazia = adota o estado do servidor.
func processar_fila() -> void:
	if _processando or fila.is_empty() or not conectado():
		return
	_processando = true
	_mudar("enviando")
	var ultimo := {}
	var precisa_baixar := false
	while not fila.is_empty():
		var item: Dictionary = fila[0]
		var resp := await _postar_acao(item)
		var codigo := int(resp["codigo"])
		var corpo: Variant = _json(str(resp["corpo"]))
		if codigo == 200 and corpo is Dictionary:
			if corpo.get("ok", false) and corpo.has("estado"):
				ultimo = corpo
				precisa_baixar = false
			else:
				_recusada(item, str(corpo.get("erro", "")))
				precisa_baixar = true
		elif codigo in RECUSA_DEFINITIVA:
			_recusada(item, "http_%d" % codigo)
			precisa_baixar = true
		else:
			# Sem rede, servidor ocupado, limite por minuto ou conflito: a mesma ação, mais tarde.
			_falhas_fila += 1
			_espera_fila = minf(60.0, pow(2.0, _falhas_fila))
			_processando = false
			_mudar("erro")
			return
		fila.pop_front()
		_salvar_fila()
	_falhas_fila = 0
	if precisa_baixar:
		await _adotar_do_servidor()
	elif not ultimo.is_empty() and fila.is_empty():
		_adotar(ultimo["estado"], int(ultimo.get("revisao", 0)))
	_processando = false
	_mudar("conectado")
	if not fila.is_empty():
		processar_fila()  # chegou ação nova enquanto baixava

## Chamada que precisa da resposta do servidor antes de seguir (semente da
## disputa, disputa automática). Esvazia a fila antes (a ordem importa).
## Sem conexão devolve {ok: false, erro: "sem_conexao"}.
func chamar(tipo: String, args: Array) -> Dictionary:
	if not usa_acao() or not conectado():
		return {"ok": false, "erro": "sem_conexao"}
	while _processando:
		await get_tree().process_frame
	await processar_fila()
	if not fila.is_empty():
		return {"ok": false, "erro": "sem_conexao"}
	var item := {"id": novo_id(), "tipo": tipo, "args": args}
	for i in int(_cfg.get("tentativas", 3)):
		var resp := await _postar_acao(item)
		var corpo: Variant = _json(str(resp["corpo"]))
		if int(resp["codigo"]) == 200 and corpo is Dictionary:
			if corpo.has("estado"):
				_adotar(corpo["estado"], int(corpo.get("revisao", 0)))
			corpo.erase("estado")
			return ServicoJogador._inteiros(corpo)
		if int(resp["codigo"]) in RECUSA_DEFINITIVA:
			return {"ok": false, "erro": "nuvem_%d" % int(resp["codigo"])}
		if i + 1 < int(_cfg.get("tentativas", 3)):
			await get_tree().create_timer(1.0 * (i + 1)).timeout
	return {"ok": false, "erro": "sem_conexao"}

func carregar_fila() -> void:
	var f: Variant = null
	if FileAccess.file_exists(caminho_fila):
		f = JSON.parse_string(FileAccess.get_file_as_string(caminho_fila))
	fila = f if f is Array else []

## UUID v4 (o servidor exige: é a chave da idempotência).
static func novo_id() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0F) | 0x40
	b[8] = (b[8] & 0x3F) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]

func _postar_acao(item: Dictionary) -> Dictionary:
	return await _autenticado(HTTPClient.METHOD_POST, _url("/functions/v1/acao"), JSON.stringify(item))

func _recusada(item: Dictionary, erro: String) -> void:
	recusadas += 1
	push_warning("Nuvem: o servidor recusou %s (%s)" % [item.get("tipo", ""), erro])

func _adotar_do_servidor() -> void:
	var b := await baixar_save()
	if b["ok"] and b["existe"] and fila.is_empty():
		_adotar(b["dados"], int(b["revisao"]))

func _adotar(dados: Variant, revisao: int) -> void:
	if _jog == null or not dados is Dictionary:
		return
	_jog.adotar_estado(dados)
	sessao["revisao"] = revisao
	_salvar_sessao()

func _salvar_fila() -> void:
	var f := FileAccess.open(caminho_fila, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(fila))

## Abertura do jogo: entra (anônimo na primeira vez) e acerta o save.
func iniciar() -> Dictionary:
	if not configurado():
		_mudar("desligado")
		return {"ok": false, "erro": "nuvem_desligada"}
	var r := await entrar()
	if not r["ok"]:
		return r
	var s := await sincronizar()
	await baixar_balanceamento()  # vale na próxima abertura; falha não atrapalha
	return s

## Garante uma sessão válida: reaproveita, renova ou cria um anônimo.
func entrar() -> Dictionary:
	_mudar("entrando")
	if sessao.has("access_token") and int(sessao.get("expira_em", 0)) > ServicoTempo.agora() + 60:
		_mudar("conectado")
		return {"ok": true, "erro": ""}
	if sessao.has("refresh_token"):
		var rr := await renovar()
		if rr["ok"]:
			return rr
	return await entrar_anonimo()

func entrar_anonimo() -> Dictionary:
	var resp: Dictionary = await transporte.call(HTTPClient.METHOD_POST, _url("/auth/v1/signup"), _cabecalhos(false),
		JSON.stringify({"data": {}}))
	return _guardar_sessao(resp)

func renovar() -> Dictionary:
	var resp: Dictionary = await transporte.call(HTTPClient.METHOD_POST, _url("/auth/v1/token?grant_type=refresh_token"),
		_cabecalhos(false), JSON.stringify({"refresh_token": sessao.get("refresh_token", "")}))
	return _guardar_sessao(resp)

## Exclusão de conta (3.9): pede ao servidor (Edge Function `excluir_conta`, que
## apaga tudo da conta) e esquece a sessão e os caches deste aparelho. Sem
## conta na nuvem só limpa o aparelho. Quem chama apaga o save local
## (Jogador.apagar_dados_locais) e volta ao título. {ok, erro}.
func excluir_conta() -> Dictionary:
	if configurado() and conectado():
		var resp := await _autenticado(HTTPClient.METHOD_POST, _url("/functions/v1/excluir_conta"), JSON.stringify({"confirmacao": "EXCLUIR"}))
		if int(resp["codigo"]) != 200:
			return {"ok": false, "erro": "nuvem_%d" % int(resp["codigo"])}
	for caminho in [caminho_sessao, caminho_cache_balanceamento]:
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(caminho)
	sessao = {}
	_envio_em = -1.0
	_mudar("desligado" if not configurado() else "entrando")
	var m := get_node_or_null("/root/Metricas") as ServicoMetricas
	if m:
		m.limpar()
	return {"ok": true, "erro": ""}

## Baixa o balanceamento ativo (3.3) e guarda em cache para a próxima abertura
## (Balanceamento.aplicar_cache_remoto). {ok, erro, tabelas}.
func baixar_balanceamento() -> Dictionary:
	var resp := await _autenticado(HTTPClient.METHOD_GET, _url("/rest/v1/balanceamento?select=nome,versao,dados&ativa=eq.true"), "")
	if int(resp["codigo"]) != 200:
		return {"ok": false, "erro": "nuvem_%d" % int(resp["codigo"])}
	var lista: Variant = JSON.parse_string(str(resp["corpo"]))
	if not lista is Array:
		return {"ok": false, "erro": "nuvem_resposta"}
	var tabelas := {}
	var revisoes := {}
	for linha: Variant in lista:
		if linha is Dictionary and linha.get("dados") is Dictionary:
			tabelas[str(linha["nome"])] = linha["dados"]
			revisoes[str(linha["nome"])] = int(linha.get("versao", 0))
	if tabelas.is_empty():
		return {"ok": true, "erro": "", "tabelas": 0}
	var e := Balanceamento.salvar_cache_remoto(tabelas, revisoes, caminho_cache_balanceamento)
	return {"ok": e == OK, "erro": "" if e == OK else error_string(e), "tabelas": tabelas.size()}

## Baixa o save da nuvem: {ok, existe, versao, revisao, dados}.
func baixar_save() -> Dictionary:
	var url := _url("/rest/v1/save_jogador?select=versao,revisao,dados&jogador_id=eq.%s" % sessao.get("usuario", ""))
	var resp := await _autenticado(HTTPClient.METHOD_GET, url, "")
	if int(resp["codigo"]) != 200:
		return {"ok": false, "erro": "nuvem_%d" % int(resp["codigo"])}
	var lista: Variant = JSON.parse_string(str(resp["corpo"]))
	if not lista is Array or lista.is_empty():
		return {"ok": true, "erro": "", "existe": false}
	var linha: Dictionary = lista[0]
	return {"ok": true, "erro": "", "existe": true, "versao": int(linha["versao"]), "revisao": int(linha["revisao"]), "dados": linha["dados"]}

## Envia o estado atual do jogador (cria ou substitui o save da conta).
func enviar_save() -> Dictionary:
	if _jog == null or not conectado():
		return {"ok": false, "erro": "nuvem_desconectada"}
	_enviando = true
	_mudar("enviando")
	var id: String = sessao["usuario"]
	var cav := _jog.cavaleiro()
	var resp_j := await _autenticado(HTTPClient.METHOD_POST, _url("/rest/v1/jogador?on_conflict=id"),
		JSON.stringify({"id": id, "nome": cav.get("nome", ""), "casa": _jog.casa().get("nome", "")}),
		["Prefer: resolution=merge-duplicates,return=minimal"])
	var resp := await _autenticado(HTTPClient.METHOD_POST, _url("/rest/v1/save_jogador?on_conflict=jogador_id"),
		JSON.stringify({"jogador_id": id, "versao": int(_jog.estado["versao"]), "dados": _jog.estado}),
		["Prefer: resolution=merge-duplicates,return=representation"])
	_enviando = false
	if int(resp_j["codigo"]) >= 300 or int(resp["codigo"]) >= 300:
		sessao["pendente"] = true
		_salvar_sessao()
		_mudar("erro")
		return {"ok": false, "erro": "nuvem_%d" % int(resp["codigo"])}
	var linhas: Variant = JSON.parse_string(str(resp["corpo"]))
	if linhas is Array and not linhas.is_empty():
		sessao["revisao"] = int(linhas[0].get("revisao", 0))
	sessao["pendente"] = false
	_salvar_sessao()
	_mudar("conectado")
	return {"ok": true, "erro": ""}

## Escolhe entre o save local e o da nuvem. A nuvem vence quando o local
## ainda não tem personagem (celular novo / reinstalou) ou quando a revisão
## da nuvem é maior que a última que este celular conhece (jogou em outro).
## Senão o local é enviado.
func sincronizar() -> Dictionary:
	if usa_acao():
		# O servidor é o dono: manda o que ficou na fila e fica com o estado dele.
		await processar_fila()
		if not fila.is_empty():
			return {"ok": false, "erro": "sem_conexao"}
		var bs := await baixar_save()
		if not bs["ok"]:
			return bs
		if bs["existe"]:
			_adotar(bs["dados"], int(bs["revisao"]))
			return {"ok": true, "erro": "", "origem": "servidor"}
		return {"ok": true, "erro": "", "origem": "local"}
	var b := await baixar_save()
	if not b["ok"]:
		return b
	if b["existe"] and (not _jog.tem_personagem() or int(b["revisao"]) > int(sessao.get("revisao", 0))):
		_jog.estado = ServicoJogador.migrar(ServicoJogador._inteiros(b["dados"]))
		_jog.salvar()
		sessao["revisao"] = int(b["revisao"])
		_salvar_sessao()
		_jog.mudou.emit("tudo")
		_envio_em = -1.0
		return {"ok": true, "erro": "", "origem": "nuvem"}
	if _jog.tem_personagem() or sessao.get("pendente", false):
		return await enviar_save()
	return {"ok": true, "erro": "", "origem": "local"}

## Push (3.23): registra o token do aparelho (FCM/APNs, entregue pelo plugin
## nativo) com as preferências de notificação, para a Edge Function mandar
## os avisos do servidor (ajuda da ordem, temporada). Ver docs/NUVEM.md.
func registrar_push(token: String, plataforma: String) -> Dictionary:
	if not configurado() or not conectado() or _jog == null:
		return {"ok": false, "erro": "nuvem_desconectada"}
	sessao["push_token"] = token
	sessao["push_plataforma"] = plataforma
	_salvar_sessao()
	var resp := await _autenticado(HTTPClient.METHOD_POST, _url("/rest/v1/dispositivo_push?on_conflict=jogador_id,token"),
		JSON.stringify({"jogador_id": sessao["usuario"], "token": token, "plataforma": plataforma,
			"preferencias": _jog.estado.get("config", {}).get("notificacoes", {})}), ["Prefer: resolution=merge-duplicates,return=minimal"])
	return {"ok": int(resp["codigo"]) < 300, "erro": "" if int(resp["codigo"]) < 300 else "nuvem_%d" % int(resp["codigo"])}

## Junta mudanças: envia alguns segundos depois da última.
func agendar_envio() -> void:
	if usa_acao():
		return  # o save não sobe inteiro: vão as ações (fila)
	if not configurado() or not conectado():
		if configurado():
			sessao["pendente"] = true
		return
	_envio_em = float(_cfg.get("envio_atraso_s", 5))

func _process(delta: float) -> void:
	if _espera_fila > 0.0:
		_espera_fila -= delta
		if _espera_fila <= 0.0:
			processar_fila()
	if _envio_em < 0.0 or _enviando:
		return
	_envio_em -= delta
	if _envio_em <= 0.0:
		_envio_em = -1.0
		_enviar_com_tentativas()

func _enviar_com_tentativas() -> void:
	for i in int(_cfg.get("tentativas", 3)):
		var r := await enviar_save()
		if r["ok"]:
			return
		await get_tree().create_timer(2.0 * (i + 1)).timeout

## Chamada com o token; com 401, renova uma vez e repete.
func _autenticado(metodo: int, url: String, corpo: String, extra: Array = []) -> Dictionary:
	var resp: Dictionary = await transporte.call(metodo, url, _cabecalhos(true, extra), corpo)
	if int(resp["codigo"]) == 401 and sessao.has("refresh_token"):
		var r := await renovar()
		if r["ok"]:
			resp = await transporte.call(metodo, url, _cabecalhos(true, extra), corpo)
	return resp

func _guardar_sessao(resp: Dictionary) -> Dictionary:
	if int(resp["codigo"]) != 200:
		_mudar("erro")
		return {"ok": false, "erro": "nuvem_%d" % int(resp["codigo"])}
	var d: Variant = JSON.parse_string(str(resp["corpo"]))
	if not d is Dictionary or not d.has("access_token"):
		_mudar("erro")
		return {"ok": false, "erro": "nuvem_resposta"}
	var usuario: Dictionary = d.get("user", {})
	sessao["access_token"] = d["access_token"]
	sessao["refresh_token"] = d.get("refresh_token", sessao.get("refresh_token", ""))
	sessao["expira_em"] = ServicoTempo.agora() + int(d.get("expires_in", 3600))
	sessao["usuario"] = usuario.get("id", sessao.get("usuario", ""))
	sessao["anonimo"] = usuario.get("is_anonymous", true)
	_salvar_sessao()
	_mudar("conectado")
	return {"ok": true, "erro": ""}

func _cabecalhos(com_token: bool, extra: Array = []) -> PackedStringArray:
	var h := PackedStringArray(["apikey: " + str(_cfg.get("chave_publica", "")), "Content-Type: application/json"])
	if com_token:
		h.append("Authorization: Bearer " + str(sessao.get("access_token", "")))
	for e in extra:
		h.append(e)
	return h

func _url(caminho: String) -> String:
	return str(_cfg.get("url", "")).trim_suffix("/") + caminho

func _salvar_sessao() -> void:
	var f := FileAccess.open(caminho_sessao, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(sessao))

func _mudar(novo: String) -> void:
	if novo != estado:
		estado = novo
		estado_mudou.emit(novo)

## Transporte padrão: HTTPRequest do Godot.
func _http(metodo: int, url: String, cabecalhos: PackedStringArray, corpo: String) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	var erro := req.request(url, cabecalhos, metodo, corpo)
	if erro != OK:
		req.queue_free()
		return {"codigo": 0, "corpo": ""}
	var r: Array = await req.request_completed
	req.queue_free()
	return {"codigo": int(r[1]), "corpo": (r[3] as PackedByteArray).get_string_from_utf8()}

## JSON da resposta (vazio ou inválido = null, sem erro no console).
static func _json(texto: String) -> Variant:
	if texto.strip_edges() == "":
		return null
	var j := JSON.new()
	return j.data if j.parse(texto) == OK else null

static func _ler(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	return v if v is Dictionary else {}
