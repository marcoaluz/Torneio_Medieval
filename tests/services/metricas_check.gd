extends SceneTree
## Métricas (headless): fila guardada e limitada, envio em lote pela Nuvem
## (Supabase falso), nada enviado sem nuvem, e os eventos ligados no jogo
## (tutorial, justa iniciada/terminada, desistência, prédio melhorado).

var _falhas := 0
var _lotes: Array = []

func _initialize() -> void:
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_metricas/")
	jog.caminho_save = "user://teste_metricas/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
	var m: ServicoMetricas = root.get_node("Metricas")
	_checa("desligada em headless por padrao", not m.ativo)
	m.ativo = true
	m.caminho_fila = "user://teste_metricas/metricas.json"
	m.fila = []

	m.registrar("teste", {"a": 1})
	_checa("registra com sessao e horario", m.fila.size() == 1 and m.fila[0]["sessao"] != "" and str(m.fila[0]["criado_em_cliente"]).ends_with("Z"))
	var lida: Variant = JSON.parse_string(FileAccess.get_file_as_string(m.caminho_fila))
	_checa("fila guardada em arquivo", lida is Array and lida.size() == 1)
	for i in ServicoMetricas.LIMITE + 20:
		m.registrar("enchendo", {"i": i})
	_checa("fila limitada (%d)" % m.fila.size(), m.fila.size() == ServicoMetricas.LIMITE and int(m.fila.back()["dados"]["i"]) == ServicoMetricas.LIMITE + 19)

	var nuvem: ServicoNuvem = root.get_node("Nuvem")
	nuvem._cfg = {}
	_checa("sem nuvem nao envia", await m.enviar() == 0)
	nuvem._cfg = {"url": "https://falso.supabase.co", "chave_publica": "pub", "envio_atraso_s": 99, "tentativas": 1}
	nuvem.caminho_sessao = "user://teste_metricas/sessao.json"
	nuvem.sessao = {"access_token": "t", "refresh_token": "r", "expira_em": ServicoTempo.agora() + 3600, "usuario": "u1"}
	nuvem.transporte = _falso
	var enviados := await m.enviar()
	_checa("envia um lote de %d" % ServicoMetricas.LOTE, enviados == ServicoMetricas.LOTE and _lotes.size() == 1
		and m.fila.size() == ServicoMetricas.LIMITE - ServicoMetricas.LOTE)
	_checa("lote com evento e dados", _lotes[0][0].has("evento") and _lotes[0][0].has("dados") and not _lotes[0][0].has("jogador_id"))
	m.fila = []

	# Eventos do jogo
	var fluxo: FluxoTelas = root.get_node("Fluxo")
	fluxo.concluiu("titulo")
	await process_frame
	_checa("tutorial: inicio e passo", _tem(m, "tutorial_inicio") and _tem(m, "tutorial_passo"))
	fluxo.modo_justa = "livre"
	var arena: Arena = load("res://game/scenes/arena/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var c: ControladorJusta = arena.get_node("Justa")
	c.set_process(false)
	c.iniciar(3)
	_checa("justa iniciada", _tem(m, "justa_iniciada"))
	for i in 90:
		c._process(1.0 / 30.0)
	arena.free()
	_checa("sair no meio registra desistencia", _tem(m, "desistencia"))
	var d: Dictionary = m.fila.filter(func(e): return e["evento"] == "desistencia")[0]["dados"]
	_checa("desistencia com a fase", d.has("fase") and d["modo"] == "livre")

	jog.estado["inventario"]["ouro"] = 500
	var vila: Vila = load("res://game/scenes/village/vila.tscn").instantiate()
	root.add_child(vila)
	await process_frame
	vila.melhorar("casa_senhorial")
	_checa("predio melhorado", _tem(m, "predio_melhorado"))

	for arq in ["jogador.json", "jogador.json.bak", "metricas.json", "sessao.json"]:
		DirAccess.remove_absolute("user://teste_metricas/" + arq)
	print("METRICAS %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _tem(m: ServicoMetricas, evento: String) -> bool:
	return m.fila.any(func(e): return e["evento"] == evento)

func _falso(_metodo: int, url: String, _cab: PackedStringArray, corpo: String) -> Dictionary:
	if url.ends_with("/rest/v1/evento_metrica"):
		_lotes.append(JSON.parse_string(corpo))
		return {"codigo": 201, "corpo": ""}
	return {"codigo": 404, "corpo": ""}

func _checa(nome: String, ok: bool) -> void:
	print("METRICAS %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
