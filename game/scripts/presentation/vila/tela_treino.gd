class_name TelaTreino
extends PanelContainer
## Telas do campo de treino e do estábulo (Pacote 2.7), abertas pela vila.
##   Campo de treino: a cena do cavaleiro treinando contra o alvo do atributo
##     escolhido e os cartões dos atributos (CenaCampoTreino); treinar (vagas,
##     custo e tempo pela curva dos dados) e concluir pelo botão da cena.
##   Estábulo: a cena da baia com o cavalo ativo vestido e a troca das peças
##     do cavalo (CenaEstabulo), e ao lado os cavalos (pelagem, atributos,
##     fôlego, estado), usar na justa e treinar (cavalo em treino não corre;
##     o ativo não treina). A tela fica mais larga para caber a cena.
## Tudo pelo serviço Jogador; a tela só mostra e pede.

signal abrir_habilidades

var predio := ""
var _jog: ServicoJogador
var _habilidades: Button
var _acumulado := 0.0

@onready var _titulo: Label = $Coluna/Cabecalho/Titulo
@onready var _info: Label = $Coluna/Cabecalho/Info
@onready var _lista: VBoxContainer = $Coluna/Corpo/Rolagem/Lista
@onready var _cena: CenaEstabulo = $Coluna/Corpo/Cena
@onready var _campo: CenaCampoTreino = $Coluna/Corpo/CenaCampo
@onready var _melhorar: Button = $Coluna/Botoes/Melhorar
@onready var _fechar: Button = $Coluna/Botoes/Fechar
@onready var _erro: Label = $Coluna/Erro

func _ready() -> void:
	_jog = get_node("/root/Jogador")
	visible = false
	_erro.visible = false
	_fechar.text = tr("PAINEL_FECHAR")
	_fechar.pressed.connect(fechar)
	_melhorar.pressed.connect(func(): _mostrar(_jog.melhorar_predio(predio)))
	# Campo de treino: abre as habilidades especiais (3.16).
	_habilidades = Button.new()
	_habilidades.focus_mode = Control.FOCUS_NONE
	_habilidades.text = tr("HABS_ABRIR")
	_habilidades.pressed.connect(func(): abrir_habilidades.emit())
	$Coluna/Botoes.add_child(_habilidades)
	$Coluna/Botoes.move_child(_habilidades, 0)
	_cena.configurar(_jog)
	_cena.resultado.connect(_mostrar)
	_campo.configurar(_jog, _lista)
	_campo.resultado.connect(_mostrar)
	_jog.mudou.connect(func(_s): if visible: montar())

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _habilidades != null:
		_fechar.text = tr("PAINEL_FECHAR")
		_habilidades.text = tr("HABS_ABRIR")
		if visible:
			montar()

func abrir(nome: String) -> void:
	predio = nome
	_erro.text = ""
	_erro.visible = false
	_habilidades.visible = nome == "campo_treino"
	_cena.visible = nome == "estabulo"
	_campo.visible = nome == "campo_treino"
	# Largura para a cena (384) mais a lista ao lado.
	var meia := Vector2(450, 264)
	offset_left = -meia.x
	offset_right = meia.x
	offset_top = -meia.y
	offset_bottom = meia.y
	visible = true
	if nome == "estabulo":
		_cena.reiniciar()
	else:
		for c in _lista.get_children():
			c.queue_free()
		_campo.reiniciar()
	montar()

func fechar() -> void:
	visible = false
	predio = ""

func _process(delta: float) -> void:
	_acumulado += delta
	if visible and _acumulado >= 1.0:
		_acumulado = 0.0
		montar()

func montar() -> void:
	_titulo.text = tr("PREDIO_" + predio.to_upper())
	var em_uso := _jog.treinos_em(predio).size()
	_info.text = tr("TREINO_INFO").format({"nivel": _jog.predio_nivel(predio), "teto": _jog.teto_predio(predio),
		"usadas": em_uso, "vagas": _jog.vagas_treino(predio)})
	var p := _jog.pode_melhorar(predio)
	_melhorar.disabled = not p["ok"]
	_melhorar.text = tr("VILA_MELHORAR").format({"ouro": p.get("ouro", 0), "tempo": Vila.formatar_tempo(_jog.duracao_timer(int(p.get("segundos", 0))))}) \
		if p.has("ouro") else tr("ERRO_" + str(p["erro"]).to_upper())
	if predio == "campo_treino":
		_campo.atualizar()  # cartões na lista, refeitos só quando mudam
	else:
		for c in _lista.get_children():
			c.queue_free()
		_cena.atualizar()
		_montar_estabulo()

## Cavalos do estábulo (GDD A vila > Interface legível no celular): o nome e o
## estado, o fôlego e os atributos GRANDES (nome e valor em 28/22 px, com barra
## até o teto); o cavalo que não está em uso ganha o botão de treinar abaixo de
## cada atributo (≥ 64 px). Nada de atributo escondido em botão desabilitado.
func _montar_estabulo() -> void:
	var cfg := Balanceamento.carregar("treino")
	var ativo: String = _jog.estado["cavalo_ativo"]
	var por_cavalo := {}
	for t: Dictionary in _jog.treinos_em("estabulo"):
		por_cavalo[t["cavalo"]] = t
	var teto := int(cfg["teto_atributo"])
	for c: Dictionary in _jog.cavalos():
		var caixa := VBoxContainer.new()
		caixa.add_theme_constant_override("separation", 4)
		var cab := HBoxContainer.new()
		var nome := Label.new()
		var estado_txt := "CAVALO_ATIVO" if c["id"] == ativo else ("CAVALO_TREINANDO" if por_cavalo.has(c["id"]) else "CAVALO_DESCANSANDO")
		if _jog.cavalo_cansado(c["id"]):
			estado_txt += "_CANSADO"
		nome.text = "%s · %s" % [tr("PELAGEM_" + str(c["pelagem"]).to_upper()), tr(estado_txt)]
		nome.theme_type_variation = &"Destaque"
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cab.add_child(nome)
		if c["id"] != ativo and not por_cavalo.has(c["id"]):
			var usar := Button.new()
			usar.focus_mode = Control.FOCUS_NONE
			usar.text = tr("CAVALO_USAR")
			usar.pressed.connect(func(): _mostrar(_jog.usar_cavalo(c["id"])))
			cab.add_child(usar)
		caixa.add_child(cab)
		var folego := ProgressBar.new()
		folego.max_value = int(cfg["folego_cavalo"]["maximo"])
		folego.value = _jog.folego_cavalo(c["id"])
		folego.custom_minimum_size = Vector2(0, 14)
		folego.show_percentage = false
		caixa.add_child(folego)
		for a: String in cfg["atributos_cavalo"]:
			var linha := HBoxContainer.new()
			var rotulo := Label.new()
			rotulo.text = tr("ATRIBUTO_" + a.to_upper())
			rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			linha.add_child(rotulo)
			var valor := Label.new()
			valor.name = "Valor_" + a
			valor.text = str(int(c["atributos"][a]))
			valor.add_theme_font_size_override("font_size", 28)
			valor.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
			linha.add_child(valor)
			caixa.add_child(linha)
			var barra := ProgressBar.new()
			barra.max_value = teto
			barra.value = int(c["atributos"][a])
			barra.show_percentage = false
			barra.custom_minimum_size = Vector2(0, 14)
			caixa.add_child(barra)
			if c["id"] != ativo and not por_cavalo.has(c["id"]):
				var b := Button.new()
				b.focus_mode = Control.FOCUS_NONE
				b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				b.text = tr("TREINO_TREINAR").format({"ganho": int(cfg["ganho_pontos"]), "ouro": _jog.custo_treino(),
					"tempo": Vila.formatar_tempo(_jog.duracao_timer(_jog.duracao_treino()))})
				b.pressed.connect(func(): _mostrar(_jog.treinar_cavalo(c["id"], a)))
				caixa.add_child(b)
		if por_cavalo.has(c["id"]):
			caixa.add_child(_botao_timer(por_cavalo[c["id"]]))
		_lista.add_child(caixa)
		_lista.add_child(HSeparator.new())

## Botão do treino em andamento: mostra o tempo; pronto, conclui.
func _botao_timer(t: Dictionary) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	if ServicoTempo.pronto(int(t["termina_em"])):
		b.text = tr("TREINO_CONCLUIR")
		b.pressed.connect(func(): _mostrar(_jog.concluir_timer(t["id"])))
	else:
		b.text = Vila.formatar_tempo(ServicoTempo.restante(int(t["termina_em"])))
		b.disabled = true
	return b

func _mostrar(r: Dictionary) -> void:
	_erro.text = "" if r["ok"] else tr("ERRO_" + str(r["erro"]).to_upper())
	_erro.visible = _erro.text != ""
