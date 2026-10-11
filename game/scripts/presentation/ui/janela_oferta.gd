class_name JanelaOferta
extends Control
## Janela de oferta (Pacote 3.18, GDD: compra no momento de emoção, sem
## bloquear). Aparece na vila quando o serviço tem uma oferta nova; um toque
## em qualquer lugar fora do quadro (ou no ×) fecha; "Ver" abre a loja.

signal ver(id: String)

var oferta := {}

@onready var _texto: Label = $Quadro/Coluna/Texto
@onready var _ver: Button = $Quadro/Coluna/Botoes/Ver
@onready var _fechar: Button = $Quadro/Coluna/Botoes/Fechar

func _ready() -> void:
	visible = false
	_fechar.text = "×"
	_ver.pressed.connect(func(): fechar(); ver.emit(oferta.get("id", "")))
	_fechar.pressed.connect(fechar)

func mostrar(o: Dictionary, texto_conteudo: String) -> void:
	oferta = o
	_ver.text = tr("OFERTA_VER")
	_texto.text = "%s\n%s\n%s" % [tr("OFERTA_" + str(o["id"]).to_upper()), texto_conteudo, o["preco"]]
	visible = true
	var jog := get_node_or_null("/root/Jogador") as ServicoJogador
	if jog:
		jog.marcar_oferta_vista(o["id"])

func fechar() -> void:
	visible = false

func _gui_input(event: InputEvent) -> void:
	if visible and ((event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)):
		fechar()
		accept_event()
