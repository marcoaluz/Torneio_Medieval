class_name ArteUi
## Peças da interface geradas no PixelLab (tools/gerar_ui.py): textura e caixa
## esticável (9-slice) a partir de game/art/ui/<nome>.png e das bordas de
## game/art/ui/ui.json. Sem o arquivo, devolve null e quem chama mantém o
## desenho antigo.

const PASTA := "res://game/art/ui/"

static func textura(nome: String) -> Texture2D:
	var arq := PASTA + nome + ".png"
	return load(arq) if ResourceLoader.exists(arq) else null

## Caixa esticável: bordas do ui.json (ou `borda`), conteúdo com `margem` px.
## `esticar`: o meio estica (trilho, faixa uniforme) em vez de repetir.
static func caixa(nome: String, margem := Vector2(10, 6), borda := -1, espelhar := false, esticar := false) -> StyleBoxTexture:
	var tex := textura(nome + ("_espelhada" if espelhar else ""))
	if tex == null:
		return null
	var info: Dictionary = Balanceamento.ler_json(PASTA + "ui.json").get(nome, {})
	var b := float(borda if borda >= 0 else int(info.get("borda", 8)))
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.texture_margin_left = b
	s.texture_margin_right = b
	s.texture_margin_top = b
	s.texture_margin_bottom = b
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH if esticar else StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	s.content_margin_left = margem.x
	s.content_margin_right = margem.x
	s.content_margin_top = margem.y
	s.content_margin_bottom = margem.y
	return s

## Ícone da peça pelo modelo do item (tools/gerar_icones_itens.py); null sem arte.
static func icone_item(modelo: String) -> Texture2D:
	var m: Dictionary = Balanceamento.ler("itens")["modelos"].get(modelo, {})
	if m.is_empty():
		return null
	var arq := "res://game/art/sprites/icones/%s_%s.png" % [m["espaco"], m["visual"]]
	return load(arq) if ResourceLoader.exists(arq) else null

