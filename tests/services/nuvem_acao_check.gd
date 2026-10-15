extends SceneTree
## Cliente chamando a Edge Function `acao` (auditoria A1), headless, contra um
## servidor falso em memória que aplica os comandos com uma segunda cópia do
## ServicoJogador: fila em ordem com id UUID, estado do servidor vencendo,
## fila que sobrevive a fechar o jogo, repetição com o mesmo id quando a
## resposta se perde (o servidor aplica uma vez só), ação recusada desfeita
## pelo estado do servidor, `chamar` sem rede, e uma disputa jogada na arena
## com a semente do servidor cujas entradas gravadas, refeitas como o servidor
## faz (disputa.ts > refazer_justa), dão exatamente os mesmos eventos.

const PASTA := "user://teste_nuvem_acao/"
const UUID := "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"

var _falhas := 0
var _srv: ServicoJogador
var _revisao := 0
var _respostas := {}  ## id -> resposta (idempotência)
var _aplicadas: Array[String] = []  ## tipos aplicados, em ordem
var _ids: Array[String] = []  ## ids recebidos, em ordem (com repetições)
var _rede_fora := false
var _perder_resposta := 0
var _recusar_tipo := ""
var _disputa_srv := {}
var _eventos_servidor: Array = []
var _resultado_servidor := {}

func _initialize() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(PASTA)
	var jog: ServicoJogador = root.get_node("Jogador")
	jog.caminho_save = PASTA + "jogador.json"
	jog.estado = jog.novo_estado()
	_srv = ServicoJogador.new()
	_srv.caminho_save = PASTA + "servidor.json"
	root.add_child(_srv)
	_srv.estado = _srv.novo_estado()

	var nuvem: ServicoNuvem = root.get_node("Nuvem")
	nuvem._cfg = {"url": "https://falso.supabase.co", "chave_publica": "pub_123", "tentativas": 2, "usar_acao": true}
	nuvem.caminho_sessao = PASTA + "sessao.json"
	nuvem.caminho_fila = PASTA + "acoes.json"
	nuvem.fila = []
	nuvem.sessao = {}
	nuvem.transporte = _falso
	await nuvem.entrar()
	_checa("modo servidor ligado", nuvem.usa_acao() and nuvem.conectado())

	# Comando local vira ação; o servidor aplica; fila esvazia
	jog.criar_personagem({"nome": "Isolda", "nome_casa": "Casa Pardal", "corpo": "feminino", "rosto": "1", "cabelo": "1",
		"pele": "clara", "cor_principal": "azul_real", "cor_secundaria": "ouro_velho", "pelagem": "preto"})
	await _esperar_fila(nuvem)
	_checa("criar_personagem chega ao servidor", _aplicadas == ["criar_personagem"] and _srv.cavaleiro()["nome"] == "Isolda")
	var re := RegEx.create_from_string(UUID)
	_checa("id da acao e um UUID v4", _ids.size() == 1 and re.search(_ids[0]) != null)
	_checa("o save nao sobe inteiro no modo servidor", nuvem._envio_em < 0.0)

	# O estado do servidor vence
	_srv.estado["inventario"]["ouro"] = 999
	jog.definir_brasao({"simbolo": "torre"})
	await _esperar_fila(nuvem)
	_checa("estado do servidor substitui o local", int(jog.estado["inventario"]["ouro"]) == 999
		and jog.estado["casa"]["brasao"]["simbolo"] == "torre")

	# Sem rede: fica na fila (em disco), na ordem; depois vai com os MESMOS ids
	_rede_fora = true
	_ids.clear()
	_aplicadas.clear()
	jog.definir_brasao({"simbolo": "cruz"})
	jog.definir_config("vibracao", false)
	await _quadros(5)
	_checa("sem rede a fila guarda as duas acoes", nuvem.fila.size() == 2 and nuvem.estado == "erro")
	var ids_fila: Array = nuvem.fila.map(func(a): return a["id"])
	nuvem.fila = []
	nuvem.carregar_fila()
	_checa("fila sobrevive a fechar o jogo", nuvem.fila.map(func(a): return a["id"]) == ids_fila)
	_rede_fora = false
	nuvem._espera_fila = 0.01
	nuvem._process(0.1)
	await _esperar_fila(nuvem)
	_checa("reenvia na ordem com os mesmos ids", _aplicadas == ["definir_brasao", "definir_config"]
		and _ids.slice(_ids.size() - 2) == ids_fila)

	# Resposta perdida: o cliente repete o id e o servidor não aplica duas vezes
	_perder_resposta = 1
	_aplicadas.clear()
	jog.definir_titulo("")
	await _quadros(3)
	nuvem._espera_fila = 0.01
	nuvem._process(0.1)
	await _esperar_fila(nuvem)
	_checa("repeticao do mesmo id aplica uma vez so", _aplicadas == ["definir_titulo"])

	# Recusada no servidor: some, e o estado dele desfaz o efeito local
	_recusar_tipo = "definir_brasao"
	var recusadas0 := nuvem.recusadas
	jog.definir_brasao({"simbolo": "estrela"})
	_checa("o local muda na hora", jog.estado["casa"]["brasao"]["simbolo"] == "estrela")
	await _esperar_fila(nuvem)
	_checa("recusada: volta ao estado do servidor", jog.estado["casa"]["brasao"]["simbolo"] == "cruz" and nuvem.recusadas == recusadas0 + 1)
	_recusar_tipo = ""

	# chamar sem rede
	_rede_fora = true
	var sem := await nuvem.chamar("iniciar_disputa", ["feira_moinho", 0])
	_checa("chamar sem rede devolve sem_conexao", not sem["ok"] and sem["erro"] == "sem_conexao")
	_rede_fora = false

	# Disputa na arena com a semente do servidor
	_srv.estado["cavaleiro"]["nivel"] = 5  # o torneio exige nível (o servidor decide)
	var ini := await nuvem.chamar("iniciar_disputa", ["feira_moinho", 0])
	_checa("iniciar_disputa traz semente e configuracao", ini["ok"] and int(ini["semente"]) == 4321 and ini.has("cfg"))
	var fluxo: FluxoTelas = root.get_node("Fluxo")
	fluxo.disputa = {"torneio": "feira_moinho", "indice": 0, "servidor": ini}
	fluxo.modo_justa = "disputa"
	var arena: Arena = load("res://game/scenes/arena/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var c: ControladorJusta = arena.get_node("Justa")
	c.set_process(false)
	c.iniciar()
	_checa("arena usa a semente do servidor", c.semente == 4321)
	var quadros := 0
	while not c.justa.terminou() and quadros < 30 * 90:
		_robo(c, quadros)
		c._process(1.0 / 30.0)
		quadros += 1
	var n_mira := c.entradas.filter(func(e): return e[1] == "mirar").size()
	_checa("entradas gravadas (%d, %d de mira)" % [c.entradas.size(), n_mira], c.entradas.size() > 10 and c.entradas.size() <= 400)
	_checa("conclusao vai para a fila", nuvem.fila.size() >= 1 or _aplicadas.has("concluir_disputa_conferida"))
	await _esperar_fila(nuvem)
	_checa("servidor refaz a justa com os mesmos eventos (%d)" % _eventos_servidor.size(),
		_eventos_servidor.size() > 0 and _strs(_eventos_servidor) == _strs(c.eventos_justa))
	_checa("mesmas estrelas no aparelho e no servidor", int(_resultado_servidor.get("estrelas", -1)) == int(c.resultado_disputa.get("estrelas", -2)))
	fluxo.disputa = {}
	arena.queue_free()

	for arq in ["jogador.json", "jogador.json.bak", "servidor.json", "servidor.json.bak", "sessao.json", "acoes.json"]:
		DirAccess.remove_absolute(PASTA + arq)
	print("NUVEM_ACAO %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

## Robô: toca no compasso na Corrida; na 1ª passada mira arrastando e solta,
## nas outras segura arrastando até o choque (golpe automático).
func _robo(c: ControladorJusta, quadro: int) -> void:
	var j := c.justa
	match j.fases.fase:
		JustaFases.Fase.APRESENTACAO, JustaFases.Fase.LARGADA:
			if j.fases.fase == JustaFases.Fase.LARGADA and j.bandeira_baixou and not j.tocou_largada:
				c.tocar()
		JustaFases.Fase.CORRIDA:
			if quadro % 15 == 0:
				c.tocar()
			if quadro % 40 == 0:
				c.ativar_habilidade()
		JustaFases.Fase.MIRA:
			if j.solto:
				return
			if not j.segurando and j.fases.tempo_na_fase_ms >= 300:
				c.segurar_mira()
			elif j.segurando:
				c.arrastar_mira(Vector2(1.5, -1.0) if quadro % 2 == 0 else Vector2(-0.5, 1.2))
				if j.fases.passada == 1 and j.fases.tempo_na_fase_ms >= 1200:
					c.soltar_mira()

func _strs(lista: Array) -> Array:
	return lista.map(func(e): return str(e))

func _quadros(n: int) -> void:
	for i in n:
		await process_frame

func _esperar_fila(nuvem: ServicoNuvem) -> void:
	for i in 300:
		await process_frame
		if nuvem.fila.is_empty() and not nuvem._processando:
			return

# ------------------------------------------------------------ servidor falso

func _falso(metodo: int, url: String, _cab: PackedStringArray, corpo: String) -> Dictionary:
	await process_frame  # resposta chega depois, como na rede
	var caminho := url.trim_prefix("https://falso.supabase.co").get_slice("?", 0)
	if caminho == "/auth/v1/signup":
		return {"codigo": 200, "corpo": JSON.stringify({"access_token": "t1", "refresh_token": "r1", "expires_in": 3600,
			"user": {"id": "u1", "is_anonymous": true}})}
	if _rede_fora:
		return {"codigo": 0, "corpo": ""}
	if caminho == "/rest/v1/save_jogador" and metodo == HTTPClient.METHOD_GET:
		return {"codigo": 200, "corpo": JSON.stringify([{"versao": ServicoJogador.VERSAO, "revisao": _revisao, "dados": _srv.estado}])}
	if caminho != "/functions/v1/acao":
		return {"codigo": 404, "corpo": "{}"}
	var a: Dictionary = ServicoJogador._inteiros(JSON.parse_string(corpo))
	_ids.append(a["id"])
	if _respostas.has(a["id"]):
		var rep: Dictionary = _respostas[a["id"]].duplicate()
		rep.merge({"estado": _srv.estado, "revisao": _revisao, "repetida": true}, true)
		return {"codigo": 200, "corpo": JSON.stringify(rep)}
	var r := _aplicar(a["tipo"], a["args"])
	_respostas[a["id"]] = r
	var corpo_r := r.duplicate()
	if r.get("ok", false):
		_aplicadas.append(a["tipo"])
		_revisao += 1
		corpo_r.merge({"estado": _srv.estado, "revisao": _revisao}, true)
	if _perder_resposta > 0:
		_perder_resposta -= 1
		return {"codigo": 0, "corpo": ""}
	return {"codigo": 200, "corpo": JSON.stringify(corpo_r)}

func _aplicar(tipo: String, args: Array) -> Dictionary:
	if tipo == _recusar_tipo:
		return {"ok": false, "erro": "recusada_de_teste"}
	match tipo:
		"iniciar_disputa":
			var prep := _srv.preparar_disputa(args[0], int(args[1]))
			_disputa_srv = {"torneio": args[0], "indice": int(args[1]), "semente": 4321, "cfg": prep["cfg"],
				"lado_jogador": prep["lado_jogador"], "lado_rival": prep["rival"]["lado"], "perfil_rival": prep["rival"]["perfil"]}
			var r := prep.duplicate(true)
			r.merge({"ok": true, "erro": "", "semente": 4321}, true)
			return r
		"concluir_disputa_conferida":
			var refeita := _refazer(_disputa_srv, args[0])
			_eventos_servidor = refeita["eventos"]
			var justa: Justa = refeita["justa"]
			_srv.registrar_justa({"equipamento_final": justa.equipamento_final(true), "gasta_folego": true})
			_resultado_servidor = _srv.concluir_disputa(_disputa_srv["torneio"], _disputa_srv["indice"], _eventos_servidor)
			return _resultado_servidor
	return _srv.callv("_cmd_" + tipo, args)

## O mesmo que supabase/functions/_shared/servidor/disputa.ts > refazer_justa.
static func _refazer(d: Dictionary, entradas: Array) -> Dictionary:
	var j := Justa.new(d["cfg"], d["lado_jogador"], d["lado_rival"], int(d["semente"]), d["perfil_rival"])
	var eventos: Array = j.iniciar()
	for e: Array in entradas:
		while j.fases.tempo_total_ms < int(e[0]) and not j.terminou():
			eventos.append_array(j.avancar(int(e[0]) - j.fases.tempo_total_ms))
		if j.terminou():
			break
		match str(e[1]):
			"tocar": eventos.append_array(j.tocar())
			"mirar": j.mirar(Vector2i(int(e[2]), int(e[3])))
			"soltar": eventos.append_array(j.soltar())
			"habilidade": eventos.append_array(j.ativar_habilidade())
	var guarda := 0
	while not j.terminou() and guarda < 1000:
		eventos.append_array(j.avancar(1000))
		guarda += 1
	return {"eventos": eventos, "justa": j}

func _checa(nome: String, ok: bool) -> void:
	print("NUVEM_ACAO %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
