class_name TelaConfiguracoes
extends PanelContainer
## Configurações: acessibilidade (Pacote 3.24: idioma, tamanho do texto,
## modo canhoto, vibração) e notificações (3.23: uma chave por tipo e uma que
## desliga todas, lidas de game/data/notificacoes.json; as do servidor
## aparecem marcadas e só valem com o push ligado, NUVEM.md).
## Tudo salvo pelo serviço Jogador (com o save, versionado).

var _jog: ServicoJogador
## Exclusão de conta em dois toques: o primeiro pede a confirmação.
var _excluir_confirmando := false
## Apagar progresso, também em dois toques.
var _apagar_confirmando := false

@onready var _titulo: Label = $Coluna/Titulo
@onready var _lista: VBoxContainer = $Coluna/Rolagem/Lista
@onready var _fechar: Button = $Coluna/Fechar

func _ready() -> void:
	_jog = get_node("/root/Jogador")
	visible = false
	_titulo.text = tr("CONFIG_TITULO")
	_fechar.text = tr("PAINEL_FECHAR")
	_fechar.pressed.connect(func(): visible = false)
	visibility_changed.connect(func(): if not visible: _apagar_confirmando = false; _excluir_confirmando = false)

func abrir() -> void:
	visible = true
	montar()

func montar() -> void:
	for c in _lista.get_children():
		c.queue_free()
	_titulo.text = tr("CONFIG_TITULO")
	_fechar.text = tr("PAINEL_FECHAR")
	_secao(tr("CONFIG_ACESSIBILIDADE"))
	var a: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OpcoesAcessibilidade.DADOS))
	_escolha(tr("CONFIG_IDIOMA"), "idioma", a["idiomas"], func(v): return tr("IDIOMA_" + (str(v).to_upper() if v != "" else "AUTO")))
	_escolha(tr("CONFIG_TEXTO"), "texto", a["ordem_tamanhos"], func(v): return tr("TEXTO_" + str(v).to_upper()))
	_opcao(tr("CONFIG_CANHOTO"), "canhoto")
	_opcao(tr("CONFIG_VIBRACAO"), "vibracao")
	_opcao(tr("CONFIG_BATERIA"), "economia_bateria")
	_secao(tr("CONFIG_SOM"))
	for b: String in ServicoAudio.BARRAMENTOS:
		_volume(tr("CONFIG_VOLUME_" + b.to_upper()), "volume_" + b.to_lower())
	_secao(tr("CONFIG_PROGRESSO"))
	_botao(tr("CONFIG_APAGAR_CONFIRMA") if _apagar_confirmando else tr("CONFIG_APAGAR_PROGRESSO"), apagar_progresso)
	if _apagar_confirmando:
		_botao(tr("CONFIG_EXCLUIR_CANCELAR"), func(): _apagar_confirmando = false; montar())
	_secao(tr("CONFIG_PRIVACIDADE"))
	_opcao(tr("CONFIG_ANUNCIOS_PERSONALIZADOS"), "anuncios_personalizados")
	_botao(tr("CONFIG_VER_POLITICA"), _abrir_politica)
	_botao(tr("CONFIG_EXCLUIR_CONFIRMA") if _excluir_confirmando else tr("CONFIG_EXCLUIR_CONTA"), _excluir)
	if _excluir_confirmando:
		_botao(tr("CONFIG_EXCLUIR_CANCELAR"), func(): _excluir_confirmando = false; montar())
	_secao(tr("CONFIG_NOTIFICACOES"))
	_chave(tr("CONFIG_NOTIF_TODAS"), "todas")
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ServicoNotificacoes.DADOS))
	for tipo: String in cfg["ordem"]:
		var nome := tr("CONFIG_NOTIF_" + tipo.to_upper())
		if cfg["tipos"][tipo]["origem"] == "servidor":
			nome += "  " + tr("CONFIG_PELO_SERVIDOR")
		var b := _chave(nome, tipo)
		b.disabled = not _jog.notificacao_ligada("todas")

func _botao(texto: String, acao: Callable) -> void:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = texto
	b.pressed.connect(acao)
	_lista.add_child(b)

func _abrir_politica() -> void:
	var t: TelaPrivacidade = load("res://game/scenes/ui/tela_privacidade.tscn").instantiate()
	t.revisao = true
	t.aceita.connect(func(_p): montar())
	add_child(t)

## Primeiro toque pede a confirmação; o segundo apaga a conta no servidor e
## o que há neste aparelho, e volta ao título.
func _excluir() -> void:
	if not _excluir_confirmando:
		_excluir_confirmando = true
		montar()
		return
	_excluir_confirmando = false
	var nuvem := get_node_or_null("/root/Nuvem") as ServicoNuvem
	if nuvem:
		var r := await nuvem.excluir_conta()
		if not r["ok"]:
			_titulo.text = tr("CONFIG_EXCLUIR_FALHOU")
			montar()
			return
	_jog.apagar_dados_locais()
	visible = false
	var f := get_node_or_null("/root/Fluxo") as FluxoTelas
	if f:
		f.iniciar_jogo()

## Primeiro toque pede a confirmação; o segundo apaga o progresso (aqui e na
## nuvem, guardando as configurações) e volta para a criação do personagem.
func apagar_progresso() -> void:
	if not _apagar_confirmando:
		_apagar_confirmando = true
		montar()
		return
	_apagar_confirmando = false
	visible = false
	var f := get_node_or_null("/root/Fluxo") as FluxoTelas
	if f:
		f.novo_jogo()

func _opcao(texto: String, chave: String) -> void:
	var b := CheckButton.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = texto
	b.button_pressed = bool(_jog.config_valor(chave))
	b.toggled.connect(func(on: bool): _jog.definir_config(chave, on))
	_lista.add_child(b)

## Volume de um barramento (0 a 100). Grava só ao soltar o dedo (cada
## gravação é uma ação no servidor).
func _volume(texto: String, chave: String) -> void:
	var linha := HBoxContainer.new()
	var l := Label.new()
	l.text = texto
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(l)
	var s := HSlider.new()
	s.focus_mode = Control.FOCUS_NONE
	s.min_value = 0
	s.max_value = 100
	s.step = 10
	s.custom_minimum_size.x = 220
	s.value = float(_jog.config_valor(chave))
	s.drag_ended.connect(func(mudou: bool): if mudou: _jog.definir_config(chave, int(s.value)))
	linha.add_child(s)
	_lista.add_child(linha)

func _escolha(texto: String, chave: String, valores: Array, nome: Callable) -> void:
	var linha := HBoxContainer.new()
	var l := Label.new()
	l.text = texto
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(l)
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	for v: Variant in valores:
		o.add_item(nome.call(v))
	o.selected = valores.find(_jog.config_valor(chave))
	o.item_selected.connect(func(i: int):
		_jog.definir_config(chave, valores[i])
		montar.call_deferred())
	linha.add_child(o)
	_lista.add_child(linha)

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
