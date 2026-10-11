class_name TelaTreino
extends PanelContainer
## Telas do campo de treino e do estábulo (Pacote 2.7), abertas pela vila.
##   Campo de treino: atributos do cavaleiro, treinar (vagas, custo e tempo
##     pela curva dos dados) e treinos em andamento.
##   Estábulo: os cavalos (pelagem, atributos, fôlego, estado), usar na justa
##     e treinar (cavalo em treino não corre; o ativo não treina).
## Tudo pelo serviço Jogador; a tela só mostra e pede.

var predio := ""
var _jog: ServicoJogador
var _acumulado := 0.0

@onready var _titulo: Label = $Coluna/Titulo
@onready var _info: Label = $Coluna/Info
@onready var _lista: VBoxContainer = $Coluna/Rolagem/Lista
@onready var _melhorar: Button = $Coluna/Botoes/Melhorar
@onready var _fechar: Button = $Coluna/Botoes/Fechar
@onready var _erro: Label = $Coluna/Erro

func _ready() -> void:
	_jog = get_node("/root/Jogador")
	visible = false
	_fechar.text = tr("PAINEL_FECHAR")
	_fechar.pressed.connect(fechar)
	_melhorar.pressed.connect(func(): _mostrar(_jog.melhorar_predio(predio)))
	_jog.mudou.connect(func(_s): if visible: montar())

func abrir(nome: String) -> void:
	predio = nome
	_erro.text = ""
	visible = true
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
	for c in _lista.get_children():
		c.queue_free()
	_titulo.text = tr("PREDIO_" + predio.to_upper())
	var em_uso := _jog.treinos_em(predio).size()
	_info.text = tr("TREINO_INFO").format({"nivel": _jog.predio_nivel(predio), "teto": _jog.teto_predio(predio),
		"usadas": em_uso, "vagas": _jog.vagas_treino(predio)})
	var p := _jog.pode_melhorar(predio)
	_melhorar.disabled = not p["ok"]
	_melhorar.text = tr("VILA_MELHORAR").format({"ouro": p.get("ouro", 0), "tempo": Vila.formatar_tempo(_jog.duracao_timer(int(p.get("segundos", 0))))}) \
		if p.has("ouro") else tr("ERRO_" + str(p["erro"]).to_upper())
	if predio == "campo_treino":
		_montar_campo()
	else:
		_montar_estabulo()

func _montar_campo() -> void:
	var cfg := Balanceamento.carregar("treino")
	var atr: Dictionary = _jog.cavaleiro()["atributos"]
	var treinando := {}
	for t: Dictionary in _jog.treinos_em("campo_treino"):
		treinando[t["atributo"]] = t
	for a: String in cfg["atributos_cavaleiro"]:
		var linha := HBoxContainer.new()
		var l := Label.new()
		l.text = tr("ATRIBUTO_" + a.to_upper()) + ": %d" % int(atr[a])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_child(l)
		if treinando.has(a):
			linha.add_child(_botao_timer(treinando[a]))
		else:
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.text = tr("TREINO_TREINAR").format({"ganho": int(cfg["ganho_pontos"]), "ouro": _jog.custo_treino(),
				"tempo": Vila.formatar_tempo(_jog.duracao_timer(_jog.duracao_treino()))})
			b.pressed.connect(func(): _mostrar(_jog.treinar_cavaleiro(a)))
			linha.add_child(b)
		_lista.add_child(linha)

func _montar_estabulo() -> void:
	var cfg := Balanceamento.carregar("treino")
	var ativo: String = _jog.estado["cavalo_ativo"]
	var por_cavalo := {}
	for t: Dictionary in _jog.treinos_em("estabulo"):
		por_cavalo[t["cavalo"]] = t
	for c: Dictionary in _jog.cavalos():
		var caixa := VBoxContainer.new()
		var cab := HBoxContainer.new()
		var nome := Label.new()
		var estado_txt := "CAVALO_ATIVO" if c["id"] == ativo else ("CAVALO_TREINANDO" if por_cavalo.has(c["id"]) else "CAVALO_DESCANSANDO")
		if _jog.cavalo_cansado(c["id"]):
			estado_txt += "_CANSADO"
		nome.text = "%s · %s" % [tr("PELAGEM_" + str(c["pelagem"]).to_upper()), tr(estado_txt)]
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		folego.custom_minimum_size = Vector2(0, 8)
		folego.show_percentage = false
		caixa.add_child(folego)
		var linha := HBoxContainer.new()
		for a: String in cfg["atributos_cavalo"]:
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 11)
			b.text = "%s %d" % [tr("ATRIBUTO_" + a.to_upper()), int(c["atributos"][a])]
			b.disabled = c["id"] == ativo or por_cavalo.has(c["id"])
			b.tooltip_text = tr("TREINO_TREINAR").format({"ganho": int(cfg["ganho_pontos"]), "ouro": _jog.custo_treino(),
				"tempo": Vila.formatar_tempo(_jog.duracao_timer(_jog.duracao_treino()))})
			b.pressed.connect(func(): _mostrar(_jog.treinar_cavalo(c["id"], a)))
			linha.add_child(b)
		if por_cavalo.has(c["id"]):
			linha.add_child(_botao_timer(por_cavalo[c["id"]]))
		caixa.add_child(linha)
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
