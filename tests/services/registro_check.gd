extends SceneTree
## Registro de erros do jogo (3.10, headless): o Logger do Godot captura
## push_error e os erros viram o evento "erro_jogo" nas métricas, poucos por
## sessão e sem repetir o mesmo arquivo:linha.

var _falhas := 0

func _initialize() -> void:
	await process_frame
	var reg: RegistroErros = root.get_node("Registro")
	var met: ServicoMetricas = root.get_node("Metricas")
	met.ativo = true
	met.fila.clear()
	met.caminho_fila = "user://teste_registro_metricas.json"
	reg.set_process(false)  # o teste coleta na hora que quer
	reg.ligar()
	_checa("headless nao liga sozinho, mas liga sob demanda", reg._logger != null)

	push_error("erro de teste do registro (3.10)")
	await process_frame
	var n := reg.coletar()
	_checa("captura o push_error (%d)" % n, n >= 1)
	var evento: Dictionary = {}
	for e: Dictionary in met.fila:
		if e["evento"] == "erro_jogo" and str(e["dados"]["mensagem"]).contains("erro de teste do registro"):
			evento = e
	_checa("vira o evento erro_jogo com arquivo, linha e mensagem", not evento.is_empty()
		and evento["dados"]["arquivo"] == "registro_check.gd" and int(evento["dados"]["linha"]) > 0)

	# Mesmo lugar de novo: não repete
	var antes := met.fila.size()
	for i in 5:
		push_error("repetido")
	await process_frame
	reg.coletar()
	var repetidos := met.fila.slice(antes).filter(func(e): return e["evento"] == "erro_jogo").size()
	_checa("o mesmo arquivo:linha so uma vez (%d)" % repetidos, repetidos <= 1)

	# Limite por sessão
	reg.enviados = RegistroErros.MAX_POR_SESSAO
	push_error("depois do limite")
	await process_frame
	_checa("respeita o limite por sessao", reg.coletar() == 0)

	met.ativo = false
	DirAccess.remove_absolute("user://teste_registro_metricas.json")
	print("REGISTRO %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("REGISTRO %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
