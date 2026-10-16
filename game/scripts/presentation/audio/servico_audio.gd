class_name ServicoAudio
extends Node
## Gerenciador único do som (autoload "Audio", skill `som`). Ninguém toca som
## por nó próprio: toda cena pede aqui pelo nome (`impacto_escudo`), e o
## serviço acha os arquivos numerados do catálogo game/data/audio/sons.json
## (<pasta>/<id>_01.<ext>, _02...). Várias variações viram um
## AudioStreamRandomizer (sorteia sem repetir seguido e varia o tom). Sem
## arquivo, o som não toca e nada quebra.
##
## Canais (GDD A vila > Som dos prédios):
##   música     — uma trilha por vez, com passagem suave (musica()).
##   ambiente   — laços que pertencem a uma tela (laco()): só tocam enquanto
##                ela é a de cima; outra tela por cima para o laço e, ao
##                fechar, ele volta. Fechar a tela para o laço com fade curto.
##   efeitos    — sons avulsos (tocar()) que pertencem à tela de cima quando
##                tocaram: fechar a tela corta os que ainda soam (martelo,
##                galope do treino). Efeito nunca toca em laço.
##   interface  — sons do barramento UI (botões, moedas): não pertencem a
##                tela nenhuma e nunca são cortados.
## Telas: a cena principal chama trocar_cena() (vila, arena) e cada tela
## aberta por cima chama entrar_tela()/sair_tela() — a vila faz isso sozinha
## pela visibilidade de cada tela, então qualquer caminho de fechar vale.
##
## Barramentos: Master > Musica, SFX, Voz, Ambiente, UI (default_bus_layout.tres),
## com o volume de cada um nas configurações (volume_<barramento>, 0 a 100).
## Todo botão da interface faz o som "botao" (meta "sem_som" desliga).

const CATALOGO := "res://game/data/audio/sons.json"
const RAIZ := "res://game/audio/"
const BARRAMENTOS := ["Musica", "SFX", "Voz", "Ambiente", "UI"]
const SEM_DONO := ["UI"]  ## barramentos do canal de interface
const POLIFONIA := 12
const MAX_VARIACOES := 9
const SILENCIO_DB := -40.0

var _cat: Dictionary
var _streams := {}  ## chave -> AudioStream (null = sem arquivo); "<id>@laco" = versão em laço
var _pool: Array[AudioStreamPlayer] = []
var _proximo := 0
var _pilha: Array[String] = [""]  ## telas abertas; a última é a de cima ("" = cena sem nome)
var _ambiente := {}  ## tela -> Array[String] de laços pedidos
var _lacos := {}  ## id -> AudioStreamPlayer tocando (só os da tela de cima)
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

# --- Telas -------------------------------------------------------------------

## Nova cena principal (vila, arena...): para tudo o que as telas anteriores
## tocavam (ambiente e efeitos, com fade) e começa a pilha nela.
func trocar_cena(tela: String) -> void:
	for t in _pilha.duplicate():
		_parar_tela(t)
	_ambiente.clear()
	_pilha = [tela]

## Uma tela abriu por cima: o ambiente e os efeitos da tela de baixo param
## (fade curto) e o ambiente desta começa. `ambiente` vazio usa o do catálogo
## (sons.json > telas).
func entrar_tela(tela: String, ambiente: Array = []) -> void:
	if tela_atual() == tela:
		return
	if _pilha.has(tela):
		_pilha.erase(tela)
	_parar_tela(tela_atual())
	_pilha.append(tela)
	var lista: Array = ambiente if not ambiente.is_empty() else _cat.get("telas", {}).get(tela, [])
	_ambiente[tela] = lista.duplicate()
	_ligar_ambiente()

## A tela fechou: o que ela tocava para (fade curto) e o ambiente da tela de
## baixo volta.
func sair_tela(tela: String) -> void:
	if tela == "" or not _pilha.has(tela) or _pilha.size() <= 1 and _pilha[0] == tela:
		return
	var era_atual := tela_atual() == tela
	if era_atual:
		_parar_tela(tela)
	_pilha.erase(tela)
	_ambiente.erase(tela)
	if era_atual:
		_ligar_ambiente()

func tela_atual() -> String:
	return _pilha.back()

func telas_abertas() -> Array[String]:
	return _pilha.duplicate()

# --- Efeitos ------------------------------------------------------------------

## Toca um efeito (uma variação sorteada, nunca em laço). Pertence à `tela`
## ("" = a de cima), menos os de interface. Devolve false se não há arquivo
## ou se a tela pedida não é a de cima (tela fechada não faz som).
func tocar(id: String, volume_db := 0.0, tela := "") -> bool:
	var e := _entrada(id)
	var s := _stream(id)
	if s == null:
		return false
	var bus := str(e.get("bus", "SFX"))
	var dono := "" if bus in SEM_DONO else (tela if tela != "" else tela_atual())
	if dono != "" and dono != tela_atual():
		return false
	var p := _pool[_proximo]
	_proximo = (_proximo + 1) % _pool.size()
	_soltar(p)
	p.stream = s
	p.bus = bus
	p.volume_db = float(e.get("volume_db", 0.0)) + volume_db
	p.set_meta("dono", dono)
	p.play()
	return true

## Efeitos da tela ainda soando (para testes e depuração).
func efeitos_tocando(tela: String) -> int:
	return _pool.filter(func(p: AudioStreamPlayer): return p.playing and str(p.get_meta("dono", "")) == tela).size()

# --- Ambiente -----------------------------------------------------------------

## Liga ou desliga um laço da `tela` ("" = a de cima): galope, torcida, chuva,
## forja. Só soa enquanto a tela é a de cima.
func laco(id: String, ligado: bool, tela := "") -> void:
	var dono := tela if tela != "" else tela_atual()
	var lista: Array = _ambiente.get(dono, [])
	if ligado and not lista.has(id):
		lista.append(id)
	elif not ligado:
		lista.erase(id)
	_ambiente[dono] = lista
	if dono == tela_atual():
		_ligar_ambiente()

func tocando_laco(id: String) -> bool:
	return _lacos.has(id)

## Deixa tocando exatamente o ambiente da tela de cima.
func _ligar_ambiente() -> void:
	var quer: Array = _ambiente.get(tela_atual(), [])
	for id: String in _lacos.keys():
		if not quer.has(id):
			_desligar_laco(id)
	for id: String in quer:
		if _lacos.has(id):
			continue
		var s := _stream(id, true)
		if s == null:
			continue
		var e := _entrada(id)
		var p := AudioStreamPlayer.new()
		p.stream = s
		p.bus = str(e.get("bus", "Ambiente"))
		p.volume_db = float(e.get("volume_db", 0.0))
		add_child(p)
		p.play()
		_lacos[id] = p

func _desligar_laco(id: String) -> void:
	var p: AudioStreamPlayer = _lacos[id]
	_lacos.erase(id)
	_apagar(p, func(): p.queue_free())

## Para o ambiente e os efeitos de uma tela (fade curto).
func _parar_tela(tela: String) -> void:
	if tela == tela_atual():
		for id: String in _lacos.keys():
			_desligar_laco(id)
	for p in _pool:
		if p.playing and str(p.get_meta("dono", "")) == tela and tela != "":
			p.set_meta("dono", "")
			_apagar(p, p.stop)

## Abaixa o volume até o silêncio em fade_tela_s e chama `depois`.
func _apagar(p: AudioStreamPlayer, depois: Callable) -> void:
	var t := create_tween()
	t.tween_property(p, "volume_db", SILENCIO_DB, float(_cat.get("fade_tela_s", 0.3)))
	t.tween_callback(depois)
	p.set_meta("fade", t)

## Libera um tocador do conjunto para outro som (cancela fade pendente).
func _soltar(p: AudioStreamPlayer) -> void:
	if p.has_meta("fade"):
		var t: Tween = p.get_meta("fade")
		if t and t.is_valid():
			t.kill()
		p.remove_meta("fade")
	p.stop()

# --- Música e voz -------------------------------------------------------------

## Troca a música com uma passagem suave. "" para.
func musica(id: String, passagem_s := 1.0) -> void:
	if id == _musica_id:
		return
	_musica_id = id
	if _tween_musica:
		_tween_musica.kill()
	_tween_musica = create_tween()
	if _musica.playing:
		_tween_musica.tween_property(_musica, "volume_db", SILENCIO_DB, passagem_s * 0.5)
	_tween_musica.tween_callback(func():
		_musica.stop()
		var s := _stream(id, bool(_entrada(id).get("loop", false))) if id != "" else null
		if s == null:
			return
		_musica.stream = s
		_musica.volume_db = SILENCIO_DB
		_musica.play()
		var alvo := float(_entrada(id).get("volume_db", 0.0))
		create_tween().tween_property(_musica, "volume_db", alvo, passagem_s * 0.5))

func musica_atual() -> String:
	return _musica_id

## Fala do arauto no idioma do jogo (voice/<idioma>/arauto_<id>_NN). Efeito
## da tela de cima.
func voz(id: String) -> bool:
	var v: Dictionary = _cat["voz"]
	if not v["falas"].has(id):
		return false
	var idioma := "pt_BR" if TranslationServer.get_locale().begins_with("pt") else "en"
	var chave := "voz:%s:%s" % [idioma, id]
	if not _streams.has(chave):
		_streams[chave] = _montar("%s/%s" % [v["pasta"], idioma], "arauto_" + id, 0.0, false)
	var s: AudioStream = _streams[chave]
	if s == null:
		return false
	var p := _pool[_proximo]
	_proximo = (_proximo + 1) % _pool.size()
	_soltar(p)
	p.stream = s
	p.bus = str(v["bus"])
	p.volume_db = 0.0
	p.set_meta("dono", tela_atual())
	p.play()
	return true

# --- Volume e catálogo --------------------------------------------------------

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

## O som em versão de efeito (sem laço) ou de laço (`laco`), cada uma em
## cópia própria: ligar o laço num recurso compartilhado fazia todo efeito com
## o mesmo arquivo tocar para sempre.
func _stream(id: String, em_laco := false) -> AudioStream:
	var chave := id + ("@laco" if em_laco else "")
	if not _streams.has(chave):
		var e := _entrada(id)
		_streams[chave] = null if e.is_empty() else _montar(str(e["pasta"]), id, float(e.get("tom", 0.0)), em_laco)
	# Um efeito trocado à mão (testes) vale também para o laço.
	if em_laco and _streams[chave] == null and _streams.get(id) != null:
		_streams[chave] = _com_laco(_streams[id], true)
	return _streams[chave]

## Junta as variações numeradas que existirem. ResourceLoader.exists vale
## também no jogo exportado (onde a pasta só lista os .import).
func _montar(pasta: String, nome: String, tom: float, em_laco: bool) -> AudioStream:
	var achados: Array[AudioStream] = []
	for n in range(1, MAX_VARIACOES + 1):
		for ext: String in _cat["formatos"]["extensoes"]:
			var caminho := "%s%s/%s_%02d.%s" % [RAIZ, pasta, nome, n, ext]
			if ResourceLoader.exists(caminho):
				achados.append(_com_laco(load(caminho), em_laco))
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

## Cópia do arquivo com o laço ligado ou desligado (o original, em cache do
## Godot, fica intacto).
static func _com_laco(s: AudioStream, ligado: bool) -> AudioStream:
	if s is AudioStreamRandomizer:
		var r := (s as AudioStreamRandomizer).duplicate() as AudioStreamRandomizer
		for i in r.streams_count:
			r.set_stream(i, _com_laco(r.get_stream(i), ligado))
		return r
	if s is AudioStreamMP3 or s is AudioStreamOggVorbis:
		if bool(s.get("loop")) == ligado:
			return s
		var c := s.duplicate()
		c.set("loop", ligado)
		return c
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		if (w.loop_mode != AudioStreamWAV.LOOP_DISABLED) == ligado:
			return s
		var c := w.duplicate() as AudioStreamWAV
		if ligado:
			c.loop_mode = AudioStreamWAV.LOOP_FORWARD
			c.loop_begin = 0
			c.loop_end = c.data.size() / ((2 if c.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if c.stereo else 1))
		else:
			c.loop_mode = AudioStreamWAV.LOOP_DISABLED
		return c
	return s

func _ao_adicionar_no(no: Node) -> void:
	if no is BaseButton and not no.has_meta("sem_som"):
		(no as BaseButton).pressed.connect(func(): tocar("botao"))
