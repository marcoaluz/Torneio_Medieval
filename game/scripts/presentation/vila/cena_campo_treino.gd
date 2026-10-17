class_name CenaCampoTreino
extends VBoxContainer
## Cena do campo de treino (dentro da TelaTreino quando o prédio é o campo):
## o cavaleiro do jogador, montado e vestido, passa a galope pelo campo
## (game/art/sprites/campo_treino/) contra o alvo do atributo escolhido:
##   força      -> estafermo: a lança acerta a bandeirola e o braço gira;
##   precisão   -> argola: a lança baixa, fisga a argola e a leva;
##   equilíbrio -> tronco: o cavalo salta o obstáculo.
## Do lado, um cartão por atributo (alvo, valor, barra até o teto, o que faz
## na justa e o treino em andamento) escolhe o alvo; tocar no campo chama mais
## uma passada. Embaixo, o botão de treinar o atributo escolhido (ou o tempo
## que falta, ou concluir). Tudo pelo serviço Jogador; a tela só mostra e pede.

signal resultado(r: Dictionary)

const PASTA := "res://game/art/sprites/campo_treino/"
const TELA := "campo_treino"  ## dono dos efeitos no Audio (param ao sair da tela)
const CAVALEIRO := preload("res://game/scenes/arena/cavaleiro.tscn")
const FAISCAS := preload("res://game/scenes/arena/efeitos/faiscas.tscn")
const ALVO_ARTE := {"forca": "estafermo_braco", "precisao": "argola", "equilibrio": "tronco"}
const CHAO := 192.0                ## linha do chão no palco (384x216)
const ALVO_X := 262.0              ## onde fica o alvo
const PASSADA_S := 2.4             ## tempo de uma passada de ponta a ponta
const PAUSA_S := 0.7               ## entre passadas automáticas
const INICIO_X := -230.0
const FIM_X := 470.0
## Ponta da lança a partir do nó Visual/Lanca (arte da justa, olhando à direita).
const PONTA_NA_LANCA := Vector2(186, -4)
const LANCA_BAIXA_GRAUS := 4.0    ## a argola fica mais baixa: a lança desce
const PULO_ALTURA := 36.0
const PULO_LARGURA := 150.0
const ESTAFERMO_PINO := Vector2(56, 15)  ## pino no meio do braço (arte)

var atributo := "forca"
var _jog: ServicoJogador
var _cartoes: VBoxContainer
var _chave_cartoes := ""
var _cav: Cavaleiro
var _alvo: Node2D
var _braco: Sprite2D
var _argola: Sprite2D
var _t := -1.0        ## tempo na passada atual (-1 = parado)
var _espera := 0.0
var _acertou := false
var _giro := 0.0
var _giro_vel := 0.0
var _carregando_argola := false

@onready var _palco: Control = $Palco
@onready var _cena: Node2D = $Palco/Cena
@onready var _treinar: Button = $Treinar
@onready var _status: Label = $Status

func _ready() -> void:
	if ResourceLoader.exists(PASTA + "fundo.png"):
		($Palco/Fundo as TextureRect).texture = load(PASTA + "fundo.png")
	_palco.gui_input.connect(_ao_tocar_palco)
	_treinar.pressed.connect(_ao_treinar)

func configurar(jog: ServicoJogador, cartoes: VBoxContainer) -> void:
	_jog = jog
	_cartoes = cartoes

## Ao abrir: cavaleiro vestido com o visual de agora e o alvo do atributo.
func reiniciar() -> void:
	if _cav == null:
		_cav = CAVALEIRO.instantiate()
		_cena.add_child(_cav)
	AparenciaJogador.vestir_cavaleiro(_cav, _jog)
	_chave_cartoes = ""
	escolher(atributo, false)
	atualizar()

## Troca o alvo e já chama uma passada.
func escolher(novo: String, passar := true) -> void:
	atributo = novo
	_montar_alvo()
	_chave_cartoes = ""
	if passar:
		passar_agora()
	if _jog:
		atualizar()

func passar_agora() -> void:
	_t = 0.0
	_acertou = false
	_espera = 0.0
	if _cav:
		_cav.animar("galope")
		_cav.position = Vector2(INICIO_X, CHAO)
		_lanca_baixa(atributo == "precisao")
	var audio := get_node_or_null("/root/Audio") as ServicoAudio
	if audio:
		audio.tocar("galope", 0.0, TELA)

func passando() -> bool:
	return _t >= 0.0

func _process(delta: float) -> void:
	if not is_visible_in_tree() or _cav == null:
		return
	_animar_estafermo(delta)
	if _t < 0.0:
		_espera += delta
		if _espera >= PAUSA_S:
			passar_agora()
		return
	_t += delta
	var k := _t / PASSADA_S
	var x := lerpf(INICIO_X, FIM_X, k)
	var y := CHAO
	if atributo == "equilibrio":
		var d := (x - ALVO_X) / (PULO_LARGURA * 0.5)
		if absf(d) < 1.0:
			y -= cos(d * PI * 0.5) * PULO_ALTURA
		if not _acertou and x >= ALVO_X:
			_acertou = true
			_acerto(Vector2(ALVO_X, CHAO - 34))
	_cav.position = Vector2(x, y).round()
	if atributo != "equilibrio" and not _acertou:
		var ponta := _ponta_no_palco()
		var alvo := _ponto_do_alvo()
		if ponta.x >= alvo.x:
			_acertou = true
			_acerto(alvo)
	if _carregando_argola and _argola:
		_argola.position = _cena.to_local(_ponta_global()) - _alvo.position
	if k >= 1.0:
		_t = -1.0
		_espera = 0.0
		_cav.animar("parado")
		if _carregando_argola:
			_carregando_argola = false
			_montar_alvo()

func _acerto(ponto: Vector2) -> void:
	var audio := get_node_or_null("/root/Audio") as ServicoAudio
	match atributo:
		"forca":
			_giro_vel = 16.0
			if audio:
				audio.tocar("campo_treino", 0.0, TELA)
		"precisao":
			_carregando_argola = true
			if audio:
				audio.tocar("toque_no_tempo", 0.0, TELA)
		"equilibrio":
			if audio:
				audio.tocar("cavalo_bufando", 0.0, TELA)
	var f := FAISCAS.instantiate() as CPUParticles2D
	f.amount = 10 if atributo == "forca" else 6
	_cena.add_child(f)
	f.position = ponto
	f.emitting = true
	f.finished.connect(f.queue_free)

## Estafermo: o braço gira em torno do poste (de lado, o braço encurta e vira).
func _animar_estafermo(delta: float) -> void:
	if _braco == null:
		return
	if _giro_vel > 0.0:
		_giro += _giro_vel * delta
		_giro_vel = maxf(_giro_vel - 9.0 * delta, 0.0)
	elif absf(fmod(_giro, TAU)) > 0.05:
		_giro = lerpf(_giro, roundf(_giro / TAU) * TAU, minf(delta * 4.0, 1.0))
	var c := cos(_giro)
	_braco.scale.x = c if absf(c) > 0.08 else 0.08 * signf(c + 0.0001)

func _lanca_baixa(baixa: bool) -> void:
	var l := _cav.get_node_or_null("Visual/Lanca") as Node2D
	if l:
		l.rotation_degrees = LANCA_BAIXA_GRAUS if baixa else 0.0

func _ponta_global() -> Vector2:
	var l := _cav.get_node("Visual/Lanca") as Node2D
	return l.to_global(PONTA_NA_LANCA)

func _ponta_no_palco() -> Vector2:
	return _cena.to_local(_ponta_global())

## Onde a lança acerta: a bandeirola do estafermo ou a argola.
func _ponto_do_alvo() -> Vector2:
	if atributo == "forca" and _braco:
		return _cena.to_local(_braco.to_global(Vector2(-ESTAFERMO_PINO.x + 28, 0)))
	if atributo == "precisao" and _argola:
		return _cena.to_local(_argola.global_position)
	return Vector2(ALVO_X, CHAO)

func _montar_alvo() -> void:
	if _alvo:
		_alvo.queue_free()
	_braco = null
	_argola = null
	_giro = 0.0
	_giro_vel = 0.0
	_alvo = Node2D.new()
	_alvo.name = "Alvo"
	_alvo.position = Vector2(ALVO_X, CHAO)
	_cena.add_child(_alvo)
	_cena.move_child(_alvo, 0)  # atrás do cavaleiro
	match atributo:
		"forca":
			var poste := _sprite("estafermo_poste")
			poste.offset = Vector2(-32, -108)
			_alvo.add_child(poste)
			_braco = _sprite("estafermo_braco")
			_braco.offset = -ESTAFERMO_PINO
			_braco.position = Vector2(-1, -100)
			_alvo.add_child(_braco)
		"precisao":
			var forca := _sprite("argola_poste")
			forca.offset = Vector2(-20, -109)
			_alvo.add_child(forca)
			_argola = _sprite("argola")
			_argola.position = Vector2(33, -82)
			_alvo.add_child(_argola)
		"equilibrio":
			var tronco := _sprite("tronco")
			tronco.offset = Vector2(-48, -37)
			_alvo.add_child(tronco)

func _sprite(nome: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = nome
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(PASTA + nome + ".png"):
		s.texture = load(PASTA + nome + ".png")
	s.centered = nome == "argola"
	return s

func _ao_tocar_palco(ev: InputEvent) -> void:
	var toque: bool = (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT)
	if toque and not passando():
		passar_agora()

# ---------------------------------------------------------------- dados

## Treino em andamento de um atributo ({} se não tem).
func _treino_de(a: String) -> Dictionary:
	for t: Dictionary in _jog.treinos_em("campo_treino"):
		if t.get("atributo", "") == a:
			return t
	return {}

## Cartões e botão (a cada mudança e a cada segundo; os cartões só se refazem
## quando algo neles muda).
func atualizar() -> void:
	if _jog == null:
		return
	var cfg := Balanceamento.ler("treino")
	var atr: Dictionary = _jog.cavaleiro()["atributos"]
	var partes: Array = [atributo, TranslationServer.get_locale(), JSON.stringify(atr)]
	for a: String in cfg["atributos_cavaleiro"]:
		var t := _treino_de(a)
		partes.append("" if t.is_empty() else "%s:%s" % [t["id"], ServicoTempo.restante(int(t["termina_em"]))])
	var chave := "|".join(partes)
	if chave != _chave_cartoes:
		_chave_cartoes = chave
		_montar_cartoes()
	_atualizar_botao()

func _montar_cartoes() -> void:
	if _cartoes == null:
		return
	for c in _cartoes.get_children():
		_cartoes.remove_child(c)  # já fora: os novos usam o mesmo nome
		c.queue_free()
	var cfg := Balanceamento.ler("treino")
	var teto := int(cfg["teto_atributo"])
	var atr: Dictionary = _jog.cavaleiro()["atributos"]
	for a: String in cfg["atributos_cavaleiro"]:
		var b := Button.new()
		b.name = a
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = a == atributo
		b.custom_minimum_size = Vector2(0, 166)
		b.self_modulate = Color.WHITE if a == atributo else Color(0.7, 0.7, 0.7)  # o escolhido salta à vista
		b.pressed.connect(func(): escolher(a))
		var linha := HBoxContainer.new()
		linha.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
		linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		linha.add_theme_constant_override("separation", 10)
		b.add_child(linha)
		var icone := TextureRect.new()
		icone.texture = load(PASTA + ALVO_ARTE[a] + ".png") if ResourceLoader.exists(PASTA + ALVO_ARTE[a] + ".png") else null
		icone.custom_minimum_size = Vector2(64, 64)
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		linha.add_child(icone)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 1)
		linha.add_child(col)
		var topo := Label.new()
		topo.text = "%s   %d / %d" % [tr("ATRIBUTO_" + a.to_upper()), int(atr[a]), teto]
		topo.add_theme_font_size_override("font_size", 28)
		topo.add_theme_color_override("font_color", Color(1, 0.88, 0.55) if a == atributo else Color(0.95, 0.9, 0.8))
		topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(topo)
		var barra := ProgressBar.new()
		barra.max_value = teto
		barra.value = int(atr[a])
		barra.show_percentage = false
		barra.custom_minimum_size = Vector2(0, 12)
		barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(barra)
		var desc := Label.new()
		var t := _treino_de(a)
		if t.is_empty():
			desc.text = tr("TREINO_DESC_" + a.to_upper())
		elif ServicoTempo.pronto(int(t["termina_em"])):
			desc.text = tr("TREINO_PRONTO_CARTAO")
			desc.add_theme_color_override("font_color", Color(0.7, 0.95, 0.6))
		else:
			desc.text = tr("TREINO_EM_ANDAMENTO").format({"tempo": Vila.formatar_tempo(ServicoTempo.restante(int(t["termina_em"])))})
			desc.add_theme_color_override("font_color", Color(1, 0.8, 0.45))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(desc)
		_cartoes.add_child(b)

func _atualizar_botao() -> void:
	var cfg := Balanceamento.ler("treino")
	var nome := tr("ATRIBUTO_" + atributo.to_upper())
	var t := _treino_de(atributo)
	_treinar.disabled = false
	if not t.is_empty():
		if ServicoTempo.pronto(int(t["termina_em"])):
			_treinar.text = tr("TREINO_CONCLUIR_ATRIBUTO").format({"atributo": nome, "ganho": int(cfg["ganho_pontos"])})
		else:
			_treinar.text = tr("TREINO_EM_ANDAMENTO").format({"tempo": Vila.formatar_tempo(ServicoTempo.restante(int(t["termina_em"])))})
			_treinar.disabled = true
	else:
		_treinar.text = tr("TREINO_TREINAR_ATRIBUTO").format({"atributo": nome, "ganho": int(cfg["ganho_pontos"]),
			"ouro": _jog.custo_treino(), "tempo": Vila.formatar_tempo(_jog.duracao_timer(_jog.duracao_treino()))})
		if int(_jog.cavaleiro()["atributos"][atributo]) >= int(cfg["teto_atributo"]):
			_treinar.text = tr("ERRO_ATRIBUTO_NO_TETO")
			_treinar.disabled = true
		elif _jog.treinos_em("campo_treino").size() >= _jog.vagas_treino("campo_treino"):
			_treinar.text = tr("ERRO_SEM_VAGA")
			_treinar.disabled = true
		elif _jog.ouro() < _jog.custo_treino():
			_treinar.disabled = true
	_status.text = tr("TREINO_TOQUE_CAMPO")

func _ao_treinar() -> void:
	var t := _treino_de(atributo)
	var r: Dictionary
	var ganho := int(Balanceamento.ler("treino")["ganho_pontos"])
	if not t.is_empty():
		r = _jog.concluir_timer(t["id"])
		if r["ok"]:
			_flutuar("+%d %s" % [ganho, tr("ATRIBUTO_" + atributo.to_upper())], Color(0.7, 0.95, 0.6))
			var audio := get_node_or_null("/root/Audio") as ServicoAudio
			if audio:
				audio.tocar("treino_pronto")
	else:
		r = _jog.treinar_cavaleiro(atributo)
		if r["ok"]:
			_flutuar(tr("TREINO_COMECOU"), Color(1, 0.88, 0.55))
			passar_agora()
	resultado.emit(r)

## Texto que sobe e some no meio do campo.
func _flutuar(texto: String, cor: Color) -> void:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.04))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(480, 40)
	l.position = Vector2(0, 40)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palco.add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", 6.0, 1.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(l, "modulate:a", 0.0, 1.4).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)
