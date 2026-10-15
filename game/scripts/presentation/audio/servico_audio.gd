class_name ServicoAudio
extends Node
## Som do jogo (autoload "Audio", skill `som`). Recebe o nome do som
## (`impacto_escudo`) e acha os arquivos numerados no catálogo
## game/data/audio/sons.json (<pasta>/<id>_01.<ext>, _02...). Várias
## variações viram um AudioStreamRandomizer (sorteia sem repetir seguido e
## varia o tom). Sem arquivo, o som não toca e nada quebra: a arte sonora
## chega aos poucos (ElevenLabs, tools/gerar_sons.py).
##
## Barramentos: Master > Musica, SFX, Voz, Ambiente, UI (default_bus_layout.tres),
## com o volume de cada um nas configurações (volume_<barramento>, 0 a 100).
## Quem toca liga por sinal (som_justa.gd na arena); a regra não sabe de som.
## Todo botão da interface faz o som "botao" (meta "sem_som" desliga).

const CATALOGO := "res://game/data/audio/sons.json"
const RAIZ := "res://game/audio/"
const BARRAMENTOS := ["Musica", "SFX", "Voz", "Ambiente", "UI"]
const POLIFONIA := 12
const MAX_VARIACOES := 9

var _cat: Dictionary
var _streams := {}  ## chave -> AudioStream (null = sem arquivo)
var _pool: Array[AudioStreamPlayer] = []
var _proximo := 0
var _lacos := {}  ## id -> AudioStreamPlayer tocando em loop
var _musica: AudioStreamPlayer
var _musica_id := ""
var _tween_musica: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cat = Balanceamento.ler_json(CATALOGO)
	for i in POLIFONIA:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_musica = AudioStreamPlayer.new()
	_musica.bus = "Musica"
	add_child(_musica)
	aplicar_volumes()
	var jog := get_node_or_null("/root/Jogador") as ServicoJogador
	if jog:
		jog.mudou.connect(func(secao: String): if secao in ["config", "tudo"]: aplicar_volumes())
	get_tree().node_added.connect(_ao_adicionar_no)

## Toca um efeito (uma variação sorteada). Devolve false se não há arquivo.
func tocar(id: String, volume_db := 0.0) -> bool:
	var e := _entrada(id)
	var s := _stream(id)
	if s == null:
		return false
	var p := _pool[_proximo]
	_proximo = (_proximo + 1) % _pool.size()
	p.stop()
	p.stream = s
	p.bus = str(e.get("bus", "SFX"))
	p.volume_db = float(e.get("volume_db", 0.0)) + volume_db
	p.play()
	return true

## Liga ou desliga um som em loop (galope, torcida, forja, chuva).
func laco(id: String, ligado: bool) -> void:
	if not ligado:
		if _lacos.has(id):
			(_lacos[id] as AudioStreamPlayer).queue_free()
			_lacos.erase(id)
		return
	if _lacos.has(id):
		return
	var s := _stream(id)
	if s == null:
		return
	var e := _entrada(id)
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = str(e.get("bus", "Ambiente"))
	p.volume_db = float(e.get("volume_db", 0.0))
	add_child(p)
	p.play()
	_lacos[id] = p

func tocando_laco(id: String) -> bool:
	return _lacos.has(id)

## Troca a música com uma passagem suave. "" para.
func musica(id: String, passagem_s := 1.0) -> void:
	if id == _musica_id:
		return
	_musica_id = id
	if _tween_musica:
		_tween_musica.kill()
	_tween_musica = create_tween()
	if _musica.playing:
		_tween_musica.tween_property(_musica, "volume_db", -40.0, passagem_s * 0.5)
	_tween_musica.tween_callback(func():
		_musica.stop()
		var s := _stream(id) if id != "" else null
		if s == null:
			return
		_musica.stream = s
		_musica.volume_db = -40.0
		_musica.play()
		var alvo := float(_entrada(id).get("volume_db", 0.0))
		create_tween().tween_property(_musica, "volume_db", alvo, passagem_s * 0.5))

func musica_atual() -> String:
	return _musica_id

## Fala do arauto no idioma do jogo (voice/<idioma>/arauto_<id>_NN).
func voz(id: String) -> bool:
	var v: Dictionary = _cat["voz"]
	if not v["falas"].has(id):
		return false
	var idioma := "pt_BR" if TranslationServer.get_locale().begins_with("pt") else "en"
	var chave := "voz:%s:%s" % [idioma, id]
	if not _streams.has(chave):
		_streams[chave] = _montar("%s/%s" % [v["pasta"], idioma], "arauto_" + id, 0.0)
	var s: AudioStream = _streams[chave]
	if s == null:
		return false
	var p := _pool[_proximo]
	_proximo = (_proximo + 1) % _pool.size()
	p.stop()
	p.stream = s
	p.bus = str(v["bus"])
	p.volume_db = 0.0
	p.play()
	return true

## Volume de cada barramento pelas configurações do jogador (0 = mudo).
func aplicar_volumes() -> void:
	var jog := get_node_or_null("/root/Jogador") as ServicoJogador
	for b: String in BARRAMENTOS:
		var i := AudioServer.get_bus_index(b)
		if i < 0:
			continue
		var v := 100.0
		if jog:
			v = float(jog.config_valor("volume_" + b.to_lower()))
		AudioServer.set_bus_mute(i, v <= 0.0)
		AudioServer.set_bus_volume_db(i, linear_to_db(clampf(v, 1.0, 100.0) / 100.0))

## O som tem arquivo? (para testes e para a tela saber o que já chegou)
func existe(id: String) -> bool:
	return _stream(id) != null

func _entrada(id: String) -> Dictionary:
	if _cat["sons"].has(id):
		return _cat["sons"][id]
	return _cat["musicas"].get(id, {})

func _stream(id: String) -> AudioStream:
	if not _streams.has(id):
		var e := _entrada(id)
		_streams[id] = null if e.is_empty() else _montar(str(e["pasta"]), id, float(e.get("tom", 0.0)), e.get("loop", false))
	return _streams[id]

## Junta as variações numeradas que existirem. ResourceLoader.exists vale
## também no jogo exportado (onde a pasta só lista os .import).
func _montar(pasta: String, nome: String, tom: float, loop := false) -> AudioStream:
	var achados: Array[AudioStream] = []
	for n in range(1, MAX_VARIACOES + 1):
		for ext: String in _cat["formatos"]["extensoes"]:
			var caminho := "%s%s/%s_%02d.%s" % [RAIZ, pasta, nome, n, ext]
			if ResourceLoader.exists(caminho):
				var s: AudioStream = load(caminho)
				if loop:
					_ligar_loop(s)
				achados.append(s)
				break
	if achados.is_empty():
		return null
	if achados.size() == 1 and tom <= 0.0:
		return achados[0]
	var r := AudioStreamRandomizer.new()
	r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS if achados.size() > 2 else AudioStreamRandomizer.PLAYBACK_RANDOM
	r.random_pitch = 1.0 + tom
	for s in achados:
		r.add_stream(-1, s)
	return r

static func _ligar_loop(s: AudioStream) -> void:
	if s is AudioStreamMP3 or s is AudioStreamOggVorbis:
		s.set("loop", true)
	elif s is AudioStreamWAV and (s as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / (2 * (2 if w.stereo else 1))

func _ao_adicionar_no(no: Node) -> void:
	if no is BaseButton and not no.has_meta("sem_som"):
		(no as BaseButton).pressed.connect(func(): tocar("botao"))
