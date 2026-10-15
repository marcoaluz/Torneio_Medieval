class_name CenaEstabulo
extends VBoxContainer
## Cena do estábulo (dentro da TelaTreino quando o prédio é o estábulo): a baia
## desenhada (game/art/sprites/estabulo/fundo.png) com o cavalo ativo do jogador
## na pelagem dele e com as peças do cavalo vestidas por cima (as mesmas
## camadas da justa). Embaixo, os espaços do cavalo (espacos.json > cavalo) e as
## peças do inventário do espaço escolhido, o mesmo inventário da aba Cavalo de
## Equipamentos. Tocar numa peça equipa pelo serviço Jogador; quando o visual
## do cavalo muda, ele reage (bufa, sapateia e dá um pulinho).

signal resultado(r: Dictionary)

const FUNDO := "res://game/art/sprites/estabulo/fundo.png"
const REACAO_S := 0.7

var espaco := "caparacao"  ## espaço com as peças à mostra
var _jog: ServicoJogador
var _espacos: Array = []
var _chave_visual := ""
var _chave_pecas := ""
var _base_cavalo := Vector2.ZERO
var _reacao: Tween

@onready var _fundo: TextureRect = $Palco/Fundo
@onready var _cavalo: CamadasPersonagem = $Palco/Cavalo
@onready var _botoes_espaco: HBoxContainer = $Espacos
@onready var _pecas: HBoxContainer = $RolagemPecas/Pecas

func _ready() -> void:
	_espacos = JSON.parse_string(FileAccess.get_file_as_string(TelaEquipamentos.ESPACOS))["cavalo"]
	_base_cavalo = _cavalo.position
	if ResourceLoader.exists(FUNDO):
		_fundo.texture = load(FUNDO)

func configurar(jog: ServicoJogador) -> void:
	_jog = jog

## Ao abrir: mostra o estado atual sem reagir (a reação é só para a troca feita aqui).
func reiniciar() -> void:
	_chave_visual = ""
	_chave_pecas = ""
	atualizar()

## Chamado pela tela a cada mudança (e a cada segundo): só refaz o que mudou.
func atualizar() -> void:
	if _jog == null:
		return
	var chave := "%s|%s" % [_jog.cavalo_ativo().get("pelagem", ""), JSON.stringify(_jog.visual_das_pecas(), "", true)]
	if chave != _chave_visual:
		var trocou := _chave_visual != ""
		_chave_visual = chave
		AparenciaJogador.vestir_cavalo(_cavalo, _jog)
		if trocou:
			reagir()
	var chave_pecas := "%s|%s|%s|%s" % [espaco, JSON.stringify(_jog.estado["equipamento"], "", true),
		_jog.itens().map(func(it): return "%s:%s" % [it["id"], it.get("nivel", 0)]), TranslationServer.get_locale()]
	if chave_pecas != _chave_pecas:
		_chave_pecas = chave_pecas
		_montar_espacos()
		_montar_pecas()

func escolher_espaco(nome: String) -> void:
	espaco = nome
	atualizar()

## O cavalo reage à troca: bufa, sapateia (alguns quadros do galope) e dá um pulinho.
func reagir() -> void:
	var audio := get_node_or_null("/root/Audio") as ServicoAudio
	if audio:
		audio.tocar("cavalo_bufando")
	if _reacao and _reacao.is_valid():
		_reacao.kill()
	_cavalo.position = _base_cavalo
	_cavalo.tocar("galope")
	_reacao = create_tween()
	_reacao.tween_property(_cavalo, "position", _base_cavalo + Vector2(0, -6), REACAO_S * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_reacao.tween_property(_cavalo, "position", _base_cavalo, REACAO_S * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_reacao.tween_interval(REACAO_S * 0.5)
	_reacao.tween_callback(func(): _cavalo.tocar("parado"))

func reagindo() -> bool:
	return _reacao != null and _reacao.is_valid() and _reacao.is_running()

func _montar_espacos() -> void:
	for c in _botoes_espaco.get_children():
		_botoes_espaco.remove_child(c)  # já fora: os novos usam o mesmo nome
		c.queue_free()
	for e: Dictionary in _espacos:
		var nome: String = e["espaco"]
		var b := Button.new()
		b.name = nome
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = nome == espaco
		b.custom_minimum_size = Vector2(53, 42)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = tr("ESPACO_" + nome.to_upper())
		var it := _jog.equipado(nome)
		if not it.is_empty():
			b.icon = ArteUi.icone_item(it["modelo"])
			b.expand_icon = true
		else:
			b.text = tr("ESPACO_" + nome.to_upper())
			b.add_theme_font_size_override("font_size", 8)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(func(): escolher_espaco(nome))
		_botoes_espaco.add_child(b)
		_margens_curtas(b)  # depois de entrar na árvore, para pegar a moldura do tema

## Moldura do tema com pouca margem interna: o nome do espaço cabe no botão estreito.
func _margens_curtas(b: Button) -> void:
	for estado in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := b.get_theme_stylebox(estado, "Button")
		if sb:
			sb = sb.duplicate()
			sb.content_margin_left = 3
			sb.content_margin_right = 3
			sb.content_margin_top = 3
			sb.content_margin_bottom = 3
			b.add_theme_stylebox_override(estado, sb)

func _montar_pecas() -> void:
	for c in _pecas.get_children():
		_pecas.remove_child(c)  # já fora: os novos usam o mesmo nome
		c.queue_free()
	var modelos: Dictionary = Balanceamento.ler("itens")["modelos"]
	var equipado_id: String = _jog.estado["equipamento"].get(espaco, "")
	var titulo := Label.new()
	titulo.text = tr("ESPACO_" + espaco.to_upper()) + ":"
	titulo.add_theme_font_size_override("font_size", 11)
	_pecas.add_child(titulo)
	var lista := _jog.itens().filter(func(it): return modelos.get(it["modelo"], {}).get("espaco", "") == espaco)
	if lista.is_empty():
		var vazio := Label.new()
		vazio.text = tr("EQUIP_SEM_PECAS")
		vazio.add_theme_font_size_override("font_size", 11)
		_pecas.add_child(vazio)
	for it: Dictionary in lista:
		var m: Dictionary = modelos[it["modelo"]]
		var b := Button.new()
		b.name = str(it["id"])
		b.focus_mode = Control.FOCUS_NONE
		b.icon = ArteUi.icone_item(it["modelo"])
		b.add_theme_constant_override("icon_max_width", 28)
		b.add_theme_font_size_override("font_size", 10)
		var nivel := int(it.get("nivel", 0))
		b.text = "%s%s%s" % [tr("ITEM_" + str(it["modelo"]).to_upper()), " +%d" % nivel if nivel > 0 else "", " ✓" if it["id"] == equipado_id else ""]
		b.add_theme_color_override("font_color", TelaBaus.cor_raridade(m["raridade"]))
		b.disabled = it["id"] == equipado_id
		b.pressed.connect(func(): resultado.emit(_jog.equipar(it["id"])))
		_pecas.add_child(b)
