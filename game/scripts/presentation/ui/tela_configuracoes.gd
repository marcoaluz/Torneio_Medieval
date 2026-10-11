class_name TelaConfiguracoes
extends PanelContainer
## Configurações (Pacote 3.23): notificações, uma chave por tipo (e uma que
## desliga todas), lidas de game/data/notificacoes.json. As do servidor
## (ordem, temporada) aparecem marcadas; só valem com o push ligado (NUVEM.md).
## Tudo salvo pelo serviço Jogador (com o save, versionado).

var _jog: ServicoJogador

@onready var _titulo: Label = $Coluna/Titulo
@onready var _lista: VBoxContainer = $Coluna/Rolagem/Lista
@onready var _fechar: Button = $Coluna/Fechar

func _ready() -> void:
	_jog = get_node("/root/Jogador")
	visible = false
	_titulo.text = tr("CONFIG_TITULO")
	_fechar.text = tr("PAINEL_FECHAR")
	_fechar.pressed.connect(func(): visible = false)

func abrir() -> void:
	visible = true
	montar()

func montar() -> void:
	for c in _lista.get_children():
		c.queue_free()
	_secao(tr("CONFIG_NOTIFICACOES"))
	_chave(tr("CONFIG_NOTIF_TODAS"), "todas")
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ServicoNotificacoes.DADOS))
	for tipo: String in cfg["ordem"]:
		var nome := tr("CONFIG_NOTIF_" + tipo.to_upper())
		if cfg["tipos"][tipo]["origem"] == "servidor":
			nome += "  " + tr("CONFIG_PELO_SERVIDOR")
		var b := _chave(nome, tipo)
		b.disabled = not _jog.notificacao_ligada("todas")

func _secao(texto: String) -> void:
	var l := Label.new()
	l.text = texto
	l.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
	_lista.add_child(l)

func _chave(texto: String, tipo: String) -> CheckButton:
	var b := CheckButton.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = texto
	b.button_pressed = _jog.notificacao_ligada(tipo) if tipo != "todas" else _jog.notificacao_ligada("todas")
	b.toggled.connect(func(on: bool):
		_jog.definir_notificacao(tipo, on)
		montar())
	_lista.add_child(b)
	return b
