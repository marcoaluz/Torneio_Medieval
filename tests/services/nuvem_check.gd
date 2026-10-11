extends SceneTree
## Conta e save na nuvem (headless) contra um Supabase falso em memória
## (o transporte HTTP é injetado): login anônimo, sessão reaproveitada,
## renovação com 401, envio do save com revisão, celular novo baixando o save
## da conta, revisão maior na nuvem vencendo, RLS simulado (só o próprio
## jogador) e o modo desligado sem configuração.

var _falhas := 0
## "Banco" falso: usuários, tokens válidos, saves por jogador.
var _usuarios := 0
var _tokens := {}
var _saves := {}
var _expirar_token := ""
var _chamadas: Array[String] = []

func _initialize() -> void:
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_nuvem/")
	jog.caminho_save = "user://teste_nuvem/jogador.json"
	jog.estado = jog.novo_estado()
	var nuvem: ServicoNuvem = root.get_node("Nuvem")

	# Desligado sem configuração
	nuvem._cfg = {}
	var off := await nuvem.iniciar()
	_checa("sem configuracao fica desligado", off["erro"] == "nuvem_desligada" and nuvem.estado == "desligado")

	nuvem._cfg = {"url": "https://falso.supabase.co", "chave_publica": "pub_123", "envio_atraso_s": 0.1, "tentativas": 2}
	nuvem.caminho_sessao = "user://teste_nuvem/sessao.json"
	nuvem.sessao = {}
	nuvem.transporte = _falso

	var r := await nuvem.iniciar()
	_checa("primeiro acesso entra anonimo", r["ok"] and nuvem.conectado() and nuvem.sessao["anonimo"] and _chamadas.has("POST /auth/v1/signup"))
	_checa("sem personagem e sem save na nuvem nao envia nada", r.get("origem", "") == "local" and _saves.is_empty())

	jog.criar_personagem({"nome": "Isolda", "nome_casa": "Casa Pardal", "corpo": "feminino", "rosto": "1", "cabelo": "1",
		"pele": "clara", "cor_principal": "azul_real", "cor_secundaria": "ouro_velho", "pelagem": "preto"})
	var env := await nuvem.enviar_save()
	var uid: String = nuvem.sessao["usuario"]
	_checa("envia o save da conta", env["ok"] and _saves.has(uid) and _saves[uid]["dados"]["cavaleiro"]["nome"] == "Isolda")
	_checa("revisao guardada (1)", int(nuvem.sessao["revisao"]) == 1)
	_checa("chave publica e token nos cabecalhos", _chamadas.has("POST /rest/v1/save_jogador"))

	_chamadas.clear()
	await nuvem.entrar()
	_checa("sessao valida e reaproveitada", _chamadas.is_empty())

	# Token expirado: 401, renova e repete
	_expirar_token = nuvem.sessao["access_token"]
	_chamadas.clear()
	var env2 := await nuvem.enviar_save()
	_checa("401 renova o token e repete", env2["ok"] and _chamadas.has("POST /auth/v1/token") and int(nuvem.sessao["revisao"]) == 2)

	# Celular novo: sessão da mesma conta, save local vazio -> baixa da nuvem
	var sessao_conta := nuvem.sessao.duplicate()
	jog.estado = jog.novo_estado()
	nuvem.sessao = sessao_conta.duplicate()
	nuvem.sessao["revisao"] = 0
	var s := await nuvem.sincronizar()
	_checa("celular novo baixa o save da conta", s.get("origem", "") == "nuvem" and jog.cavaleiro()["nome"] == "Isolda" and jog.cavalo_ativo()["pelagem"] == "preto")
	_checa("tipos inteiros depois de baixar", typeof(jog.estado["versao"]) == TYPE_INT)

	# Jogou em outro celular: revisão na nuvem maior vence
	_saves[uid]["dados"]["cavaleiro"]["nome"] = "Isolda II"
	_saves[uid]["revisao"] = int(_saves[uid]["revisao"]) + 5
	var s2 := await nuvem.sincronizar()
	_checa("revisao maior na nuvem vence", s2.get("origem", "") == "nuvem" and jog.cavaleiro()["nome"] == "Isolda II")
	var s3 := await nuvem.sincronizar()
	_checa("mesma revisao: o local e enviado", s3.get("origem", "") != "nuvem")

	# Envio agendado depois de uma mudança
	_chamadas.clear()
	jog.definir_brasao({"simbolo": "torre"})
	for i in 30:
		await process_frame
		nuvem._process(0.05)
	_checa("mudanca no jogo agenda o envio", _chamadas.has("POST /rest/v1/save_jogador"))

	# RLS simulado: outro usuário não lê o save
	var outro := ServicoNuvem.new()
	root.add_child(outro)
	outro._cfg = nuvem._cfg
	outro.caminho_sessao = "user://teste_nuvem/sessao_outro.json"
	outro.sessao = {}
	outro.transporte = _falso
	await outro.entrar_anonimo()
	var lido := await outro.baixar_save()
	_checa("outro jogador nao ve o save (RLS)", lido["ok"] and not lido["existe"] and outro.sessao["usuario"] != uid)

	for arq in ["jogador.json", "jogador.json.bak", "sessao.json", "sessao_outro.json"]:
		DirAccess.remove_absolute("user://teste_nuvem/" + arq)
	print("NUVEM %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

## Supabase falso: auth (signup anônimo, refresh) e PostgREST (jogador,
## save_jogador) com RLS pelo token.
func _falso(metodo: int, url: String, cabecalhos: PackedStringArray, corpo: String) -> Dictionary:
	var caminho := url.trim_prefix("https://falso.supabase.co").get_slice("?", 0)
	var nome_metodo := "GET" if metodo == HTTPClient.METHOD_GET else "POST"
	_chamadas.append("%s %s" % [nome_metodo, caminho])
	if not ("apikey: pub_123" in cabecalhos):
		return {"codigo": 401, "corpo": "{}"}
	var token := ""
	for c in cabecalhos:
		if c.begins_with("Authorization: Bearer "):
			token = c.trim_prefix("Authorization: Bearer ")
	match caminho:
		"/auth/v1/signup":
			_usuarios += 1
			return _sessao("u%d" % _usuarios, "r%d" % _usuarios)
		"/auth/v1/token":
			var rt: String = JSON.parse_string(corpo)["refresh_token"]
			return _sessao("u" + rt.trim_prefix("r"), rt)
	if not _tokens.has(token) or token == _expirar_token:
		_expirar_token = "" if token == _expirar_token else _expirar_token
		return {"codigo": 401, "corpo": "{}"}
	var uid: String = _tokens[token]
	match caminho:
		"/rest/v1/jogador":
			return {"codigo": 201, "corpo": ""}
		"/rest/v1/save_jogador":
			if metodo == HTTPClient.METHOD_GET:
				var alvo := url.get_slice("jogador_id=eq.", 1)
				if alvo != uid or not _saves.has(uid):
					return {"codigo": 200, "corpo": "[]"}
				return {"codigo": 200, "corpo": JSON.stringify([_saves[uid]])}
			var linha: Dictionary = JSON.parse_string(corpo)
			if linha["jogador_id"] != uid:
				return {"codigo": 403, "corpo": "{}"}
			var rev := int(_saves.get(uid, {}).get("revisao", 0)) + 1
			_saves[uid] = {"versao": linha["versao"], "revisao": rev, "dados": linha["dados"]}
			return {"codigo": 201, "corpo": JSON.stringify([_saves[uid]])}
	return {"codigo": 404, "corpo": "{}"}

func _sessao(uid: String, refresh: String) -> Dictionary:
	var token := "t_%s_%d" % [uid, _tokens.size()]
	_tokens[token] = uid
	return {"codigo": 200, "corpo": JSON.stringify({"access_token": token, "refresh_token": refresh, "expires_in": 3600,
		"user": {"id": uid, "is_anonymous": true}})}

func _checa(nome: String, ok: bool) -> void:
	print("NUVEM %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
