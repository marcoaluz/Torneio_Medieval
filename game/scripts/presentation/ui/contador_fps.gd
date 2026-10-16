class_name ContadorFps
extends CanvasLayer
## Painel de depuração, só em build de desenvolvimento (some na exportação de
## release): contador de FPS no canto da tela e o botão "Novo jogo", que apaga
## o progresso (como Configurações > Apagar progresso) e volta para a criação.
## O botão pede um segundo toque para confirmar. Fica acima de tudo (layer
## alto); só o botão recebe toque. Carregado como autoload "Depuracao".

const CONFIRMA_S := 3.0  ## tempo para o segundo toque

@onready var _rotulo: Label = $Rotulo

var novo_jogo: Button
var _acumulado := 0.0
var _confirmando := false

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	novo_jogo = Button.new()
	novo_jogo.name = "NovoJogo"
	novo_jogo.focus_mode = Control.FOCUS_NONE
	novo_jogo.add_theme_font_size_override("font_size", 10)
	novo_jogo.anchor_top = 1.0
	novo_jogo.anchor_bottom = 1.0
	novo_jogo.offset_left = 64.0
	novo_jogo.offset_top = -20.0
	novo_jogo.offset_bottom = -2.0
	novo_jogo.modulate.a = 0.75
	novo_jogo.pressed.connect(pedir_novo_jogo)
	add_child(novo_jogo)
	_texto_do_botao()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and novo_jogo:
		_texto_do_botao()

## Primeiro toque pede confirmação (some em CONFIRMA_S); o segundo começa do zero.
func pedir_novo_jogo() -> void:
	if not _confirmando:
		_confirmando = true
		_texto_do_botao()
		get_tree().create_timer(CONFIRMA_S).timeout.connect(func():
			_confirmando = false
			_texto_do_botao())
		return
	_confirmando = false
	_texto_do_botao()
	var f := get_node_or_null("/root/Fluxo") as FluxoTelas
	if f:
		f.novo_jogo()

func _texto_do_botao() -> void:
	novo_jogo.text = tr("DEPURACAO_NOVO_JOGO_CONFIRMA" if _confirmando else "DEPURACAO_NOVO_JOGO")

func _process(delta: float) -> void:
	_acumulado += delta
	if _acumulado < 0.25:
		return
	_acumulado = 0.0
	_rotulo.text = tr("DEPURACAO_FPS").format({"fps": Engine.get_frames_per_second()})
