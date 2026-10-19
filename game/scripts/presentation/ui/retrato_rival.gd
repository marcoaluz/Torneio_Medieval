class_name RetratoRival
extends Control
## Retrato de um rival (ficha do adversário, duelo do campeão, estante de
## troféus). Com arte, mostra game/art/sprites/retratos/{id}_{expressao}.png
## (cai em {id}_neutro); sem arte, o provisório: quadro com a cor principal
## da casa, borda na secundária, o brasão e a inicial do nome. A lista do que
## falta desenhar está em docs/ARTE_PENDENTE.md.

const PASTA := "res://game/art/sprites/retratos/%s_%s.png"

var _fundo: ColorRect
var _borda: ReferenceRect
var _inicial: Label
var _brasao: TextureRect
var _sprite: TextureRect

func _init() -> void:
	custom_minimum_size = Vector2(128, 128)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo = ColorRect.new()
	_fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fundo)
	_brasao = TextureRect.new()
	_brasao.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_brasao.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_brasao.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_brasao.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_brasao.offset_left = 24
	_brasao.offset_right = -24
	_brasao.offset_top = 14
	_brasao.offset_bottom = -34
	_brasao.modulate = Color(1, 1, 1, 0.55)
	_brasao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_brasao)
	_inicial = Label.new()
	_inicial.theme_type_variation = &"Titulo"
	_inicial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inicial.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_inicial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inicial.offset_bottom = -4
	_inicial.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_inicial.add_theme_constant_override("outline_size", 6)
	add_child(_inicial)
	_sprite = TextureRect.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sprite)
	_borda = ReferenceRect.new()
	_borda.editor_only = false
	_borda.border_width = 3.0
	_borda.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_borda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_borda)

## Mostra o rival: `id` do retrato (pve.json > rivais > retrato, ou o id do
## rival), expressão (neutro, debochado, derrotado...), casa
## {principal, secundaria}, brasão (definição do GeradorBrasao) e nome.
func mostrar(id: String, expressao: String, casa: Dictionary, brasao: Dictionary, nome: String, espelhar := false) -> void:
	var pal: Dictionary = Balanceamento.ler_json(CamadasPersonagem.PALETAS)["cores_casa"]
	var c1 := Color(str(pal.get(casa.get("principal", ""), "4a3a2a")))
	var c2 := Color(str(pal.get(casa.get("secundaria", ""), "b08a3a")))
	_fundo.color = c1.darkened(0.15)
	_borda.border_color = c2
	_inicial.text = nome.substr(0, 1).to_upper() if nome != "" else "?"
	_brasao.texture = GeradorBrasao.textura(brasao, Vector2i(36, 46)) if not brasao.is_empty() else null
	var tex := arte(id, expressao)
	_sprite.texture = tex
	_sprite.flip_h = espelhar
	_inicial.visible = tex == null
	_brasao.visible = tex == null and not brasao.is_empty()

## Textura do retrato ({id}_{expressao}, senão {id}_neutro), ou null se ainda
## não há arte.
static func arte(id: String, expressao: String) -> Texture2D:
	for e in [expressao, "neutro"]:
		var caminho := PASTA % [id, e]
		if id != "" and ResourceLoader.exists(caminho):
			return load(caminho)
	return null

## Tem arte própria (não o provisório)?
func tem_arte() -> bool:
	return _sprite.texture != null
