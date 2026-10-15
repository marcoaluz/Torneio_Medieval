class_name TelaTitulo
extends Control
## Tela de título (início do jogo): Começar, ou pular o tutorial para quem
## já jogou (reinstalou). Avisa o Fluxo.

func _ready() -> void:
	$Coluna/Titulo.text = tr("JOGO_TITULO")
	$Coluna/Comecar.text = tr("INICIO_COMECAR")
	$Coluna/Pular.text = tr("INICIO_PULAR_TUTORIAL")
	$Coluna/Comecar.pressed.connect(comecar)
	$Coluna/Pular.pressed.connect(pular)
	_arte_de_fundo()

## Arte de abertura (PixelLab, 480x270 em 2x): cobre a tela; o título vai para a
## faixa escura do alto e os botões para baixo, longe do choque das lanças.
func _arte_de_fundo() -> void:
	var arq := "res://game/art/sprites/titulo/arte.png"
	if not ResourceLoader.exists(arq):
		return
	var arte := TextureRect.new()
	arte.name = "Arte"
	arte.texture = load(arq)
	arte.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arte.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arte.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	arte.set_anchors_preset(Control.PRESET_FULL_RECT)
	arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(arte)
	move_child(arte, $Fundo.get_index() + 1)
	var col := $Coluna as VBoxContainer
	col.anchor_top = 0.0
	col.anchor_bottom = 1.0
	col.offset_top = 6.0
	col.offset_bottom = -24.0
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	# O título fica no alto; um espaçador empurra os botões para baixo.
	var espaco := Control.new()
	espaco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	espaco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(espaco)
	col.move_child(espaco, $Coluna/Titulo.get_index() + 1)

const CENA_PRIVACIDADE := preload("res://game/scenes/ui/tela_privacidade.tscn")

func comecar() -> void:
	_com_privacidade(func():
		var f := get_node_or_null("/root/Fluxo") as FluxoTelas
		if f:
			f.concluiu("titulo"))

func pular() -> void:
	_com_privacidade(func():
		var f := get_node_or_null("/root/Fluxo") as FluxoTelas
		if f:
			f.pular_tutorial())

## Política de privacidade e termos (3.9): precisa do aceite da versão atual
## antes de começar; depois disso segue direto.
func _com_privacidade(depois: Callable) -> void:
	var jog := get_node_or_null("/root/Jogador") as ServicoJogador
	if jog == null or jog.privacidade_aceita():
		depois.call()
		return
	var t: TelaPrivacidade = CENA_PRIVACIDADE.instantiate()
	t.aceita.connect(func(_p): depois.call())
	add_child(t)
