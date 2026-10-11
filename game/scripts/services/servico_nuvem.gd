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

signal estado_mudou(estado: String)  ## "desligado", "entrando", "conectado", "erro", "enviando"

const CONFIG := "res://game/data/servidor.json"
const SESSAO := "user://sessao.json"

## Callable(metodo: int, url: String, cabecalhos: PackedStringArray, corpo: String)
## -> {codigo: int, corpo: String}. Pode ser corrotina (o padrão usa HTTPRequest).
var transporte: Callable
var caminho_sessao := SESSAO
var estado := "desligado"
## {access_token, refresh_token, expira_em, usuario, anonimo, revisao, pendente}
var sessao := {}

var _cfg: Dictionary
var _jog: ServicoJogador
var _envio_em := -1.0
var _enviando := false

func _ready() -> void:
	_cfg = _ler(CONFIG)
	if not transporte.is_valid():
		transporte = _http
	sessao = _ler(caminho_sessao)
	_jog = get_node_or_null("/root/Jogador")
	if _jog:
		_jog.mudou.connect(func(_s): agendar_envio())

func configurado() -> bool:
	return str(_cfg.get("url", "")) != "" and str(_cfg.get("chave_publica", "")) != ""

func conectado() -> bool:
	return sessao.has("access_token")

## Abertura do jogo: entra (anônimo na primeira vez) e acerta o save.
func iniciar() -> Dictionary:
	if not configurado():
		_mudar("desligado")
		return {"ok": false, "erro": "nuvem_desligada"}
	var r := await entrar()
	if not r["ok"]:
		return r
	return await sincronizar()

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

## Junta mudanças: envia alguns segundos depois da última.
func agendar_envio() -> void:
	if not configurado() or not conectado():
		if configurado():
			sessao["pendente"] = true
		return
	_envio_em = float(_cfg.get("envio_atraso_s", 5))

func _process(delta: float) -> void:
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

static func _ler(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	return v if v is Dictionary else {}
