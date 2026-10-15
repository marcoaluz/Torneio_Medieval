extends SceneTree
## Som (headless): barramentos do default_bus_layout, volume de cada um pelas
## configurações (0 = mudo), validação do volume no serviço, som sem arquivo
## que não quebra, catálogo coerente (todo som com pasta, barramento que
## existe, prompt e duração; toda fala do arauto nos dois idiomas), um som
## gerado na hora tocando por variações sorteadas, e a arena com o nó Som
## rodando uma justa inteira sem erro.

var _falhas := 0

func _initialize() -> void:
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_audio/")
	jog.caminho_save = "user://teste_audio/jogador.json"
	jog.estado = jog.novo_estado()
	var audio: ServicoAudio = root.get_node("Audio")

	for b: String in ServicoAudio.BARRAMENTOS:
		_checa("barramento %s existe" % b, AudioServer.get_bus_index(b) > 0)

	_checa("volume 40 aceito", jog.definir_config("volume_musica", 40)["ok"])
	var i := AudioServer.get_bus_index("Musica")
	_checa("volume da musica aplicado", absf(AudioServer.get_bus_volume_db(i) - linear_to_db(0.4)) < 0.01)
	jog.definir_config("volume_sfx", 0)
	_checa("volume 0 deixa mudo", AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")))
	jog.definir_config("volume_sfx", 100)
	_checa("volume 100 volta ao normal", not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX"))
		and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))) < 0.01)
	_checa("volume acima de 100 recusado", jog.definir_config("volume_voz", 150)["erro"] == "opcao_invalida")
	_checa("volume que nao e numero recusado", jog.definir_config("volume_voz", "alto")["erro"] == "opcao_invalida")
	_checa("volume quebrado recusado", jog.definir_config("volume_voz", 33.5)["erro"] == "opcao_invalida")

	_checa("som inexistente nao toca", not audio.tocar("nao_existe"))
	audio.laco("nao_existe", true)
	_checa("laco sem arquivo nao fica ligado", not audio.tocando_laco("nao_existe"))
	audio.musica("tema_vila")
	_checa("musica sem arquivo guarda o pedido", audio.musica_atual() == "tema_vila")

	var cat: Dictionary = Balanceamento.ler_json(ServicoAudio.CATALOGO)
	var ruins: Array[String] = []
	for grupo in ["sons", "musicas"]:
		for id: String in cat[grupo]:
			var e: Dictionary = cat[grupo][id]
			if str(e.get("pasta", "")) == "" or AudioServer.get_bus_index(str(e.get("bus", ""))) < 0 \
					or str(e.get("prompt", "")) == "" or float(e.get("duracao_s", 0)) <= 0.0:
				ruins.append(id)
	_checa("catalogo completo (%s)" % ", ".join(ruins), ruins.is_empty())
	var falas_ruins: Array[String] = []
	for id: String in cat["voz"]["falas"]:
		var f: Dictionary = cat["voz"]["falas"][id]
		if str(f.get("pt_BR", "")) == "" or str(f.get("en", "")) == "":
			falas_ruins.append(id)
	_checa("falas do arauto nos dois idiomas", falas_ruins.is_empty())

	# Todo som do catálogo tem arquivo (gerados no ElevenLabs em 2026-10-14).
	var sem_arquivo: Array[String] = []
	for grupo in ["sons", "musicas"]:
		for id: String in cat[grupo]:
			if not audio.existe(id):
				sem_arquivo.append(id)
	_checa("todo som tem arquivo (%s)" % ", ".join(sem_arquivo), sem_arquivo.is_empty())
	var vozes_faltando := 0
	for id: String in cat["voz"]["falas"]:
		for idioma in ["pt_BR", "en"]:
			if not ResourceLoader.exists("res://game/audio/voice/%s/arauto_%s_01.mp3" % [idioma, id]):
				vozes_faltando += 1
	_checa("toda fala do arauto tem arquivo (%d faltando)" % vozes_faltando, vozes_faltando == 0)

	# Variações sorteadas: dois sons gerados na hora no lugar dos arquivos.
	var r := AudioStreamRandomizer.new()
	r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	for n in 3:
		r.add_stream(-1, _tom(220.0 * (n + 1)))
	audio._streams["impacto_escudo"] = r
	_checa("som com variacoes toca", audio.tocar("impacto_escudo") and audio.existe("impacto_escudo"))
	audio._streams["galope"] = _tom(110.0)
	audio.laco("galope", true)
	_checa("laco liga", audio.tocando_laco("galope"))
	audio.laco("galope", false)
	_checa("laco desliga", not audio.tocando_laco("galope"))

	# Botão da interface faz som sozinho.
	var b := Button.new()
	root.add_child(b)
	await process_frame
	audio._streams["botao"] = _tom(880.0)
	b.pressed.emit()
	_checa("botao ganhou som", b.pressed.get_connections().size() >= 1)
	b.queue_free()

	# Arena com o nó Som: justa inteira sem erro, galope desligado no fim.
	audio._streams["torcida_fundo"] = _tom(150.0)
	var arena: Arena = load("res://game/scenes/arena/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	_checa("arena tem o no Som", arena.get_node_or_null("Som") is SomJusta)
	var c: ControladorJusta = arena.get_node("Justa")
	c.set_process(false)
	c.iniciar(7)
	var q := 0
	var galopou := false
	while not c.justa.terminou() and q < 30 * 90:
		if c.fase() == JustaFases.Fase.CORRIDA and q % 15 == 0:
			c.tocar()
		galopou = galopou or audio.tocando_laco("galope")
		c._process(1.0 / 30.0)
		q += 1
	_checa("galope tocou na corrida", galopou)
	_checa("galope parou no fim", not audio.tocando_laco("galope"))
	arena.queue_free()
	await process_frame
	_checa("torcida para ao sair da arena", not audio.tocando_laco("torcida_fundo"))

	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_audio/" + arq)
	print("AUDIO %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

## Um tom curto (0,1 s, 16 bits) para testar sem arquivo.
static func _tom(freq: float) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	var dados := PackedByteArray()
	dados.resize(2205 * 2)
	for k in 2205:
		dados.encode_s16(k * 2, int(sin(TAU * freq * k / 22050.0) * 8000.0))
	w.data = dados
	return w

func _checa(nome: String, ok: bool) -> void:
	print("AUDIO %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
