class_name RetratoCabeca
extends TextureRect
## Cabeça e ombros do cavaleiro, com o elmo que usa: as mesmas camadas do
## tamanho de Equipamentos num SubViewport, cortadas na cabeça (como a
## plaquinha da justa, só que maior para ler no celular). Não recebe toques:
## quem o usa (o botão do topo da vila) trata o toque.

## Lado do retrato (px de tela).
const LADO := 76
## Centro da cabeça a partir da origem (pés) do quadro de Equipamentos (256).
const CABECA := Vector2(2, -210)

var _vista: SubViewport
var _camadas: CamadasPersonagem

func _init() -> void:
	custom_minimum_size = Vector2(LADO, LADO)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Veste com o que o jogador usa agora (cores da casa, pele, cabelo, peças).
func vestir(jog: ServicoJogador) -> void:
	if _vista == null:
		_vista = SubViewport.new()
		_vista.size = Vector2i(LADO, LADO)
		_vista.transparent_bg = true
		_vista.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		_vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_vista)
		_camadas = CamadasPersonagem.new()
		_camadas.name = "Camadas"
		_camadas.tamanho = "equipamentos"
		_camadas.position = Vector2(LADO * 0.5, LADO * 0.5) - CABECA
		_vista.add_child(_camadas)
		texture = _vista.get_texture()
	AparenciaJogador.vestir_camadas(_camadas, jog)
	var pecas := _camadas.pecas.duplicate()
	pecas["escudo"] = "nenhum"  # o escudo na frente cobriria o rosto
	_camadas.vestir(pecas)
	_camadas.tocar("parado", true)

func tem_retrato() -> bool:
	return _vista != null
