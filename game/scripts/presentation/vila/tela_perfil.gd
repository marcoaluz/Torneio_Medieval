class_name TelaPerfil
extends PanelContainer
## Perfil do jogador, aberto pela casa senhorial. À esquerda o retrato (o
## personagem vestido como está, respirando, no fundo do salão da casa), o
## brasão, nome, casa e título; à direita nível com a barra de experiência,
## liga, renome, ordem e as estatísticas de justa (disputadas, vitórias,
## derrotas, taxa, maior sequência) em cartões. Embaixo, o que já existia no
## painel da casa: o nível dela e melhorar (ouro, tempo, em obra). Só lê do
## serviço Jogador (renome, liga, metas, `estatisticas()`); a melhoria passa
## pelos mesmos comandos de antes.

signal melhorar_pedido(resultado: Dictionary)

const PREDIO := "casa_senhorial"
const COR_DESTAQUE := Color(1, 0.88, 0.55)
const COR_FRACA := Color(0.75, 0.7, 0.62)

var _jog: ServicoJogador
var _retrato: CamadasPersonagem
var _chave := ""

@onready var _fundo: ColorRect = $Coluna/Corpo/Esquerda/Palco/Fundo
@onready var _palco: Control = $Coluna/Corpo/Esquerda/Palco
@onready var _brasao: TextureRect = $Coluna/Corpo/Esquerda/Identidade/Brasao
@onready var _nome: Label = $Coluna/Corpo/Esquerda/Identidade/Textos/Nome
@onready var _casa: Label = $Coluna/Corpo/Esquerda/Identidade/Textos/Casa
@onready var _titulo_atual: Label = $Coluna/Corpo/Esquerda/Titulo
@onready var _direita: VBoxContainer = $Coluna/Corpo/Direita
@onready var _casa_nivel: Label = $Coluna/Rodape/CasaNivel
@onready var _melhorar: Button = $Coluna/Rodape/Melhorar
@onready var _fechar: Button = $Coluna/Rodape/Fechar
@onready var _aviso: Label = $Coluna/Aviso

func _ready() -> void:
	_jog = get_node("/root/Jogador")
	visible = false
	_fechar.text = tr("PAINEL_FECHAR")
	_fechar.pressed.connect(fechar)
	_melhorar.pressed.connect(_ao_melhorar)
	_retrato = CamadasPersonagem.new()
	_retrato.name = "Retrato"
	_retrato.tamanho = "equipamentos"
	_palco.add_child(_retrato)
	_retrato.scale = Vector2(1.0, 1.0)
	_retrato.position = Vector2(_palco.custom_minimum_size.x * 0.5, _palco.custom_minimum_size.y + 4)
	_retrato.tocar("respirar")
	_jog.mudou.connect(func(_s): if visible: atualizar())

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _fechar != null:
		_fechar.text = tr("PAINEL_FECHAR")
		if visible:
			_chave = ""
			atualizar()

func abrir() -> void:
	visible = true
	_aviso.text = ""
	_chave = ""
	atualizar()

func fechar() -> void:
	visible = false

func _process(_delta: float) -> void:
	if visible:
		_atualizar_obra()

## Refaz o que mudou (o retrato e os cartões só quando os dados mudam).
func atualizar() -> void:
	var cav := _jog.cavaleiro()
	var est := _jog.estatisticas()
	var chave := "%s|%s|%s|%s|%s|%s|%s" % [JSON.stringify(cav, "", true), JSON.stringify(est, "", true), _jog.renome(),
		JSON.stringify(_jog.liga_atual(), "", true), JSON.stringify(_jog.visual_das_pecas(), "", true), _jog.titulo(),
		TranslationServer.get_locale()]
	if chave != _chave:
		_chave = chave
		_montar_identidade(cav)
		_montar_direita(cav, est)
	_atualizar_obra()

func _montar_identidade(cav: Dictionary) -> void:
	AparenciaJogador.vestir_camadas(_retrato, _jog)
	_retrato.tocar("respirar", true)
	_brasao.texture = GeradorBrasao.textura(AparenciaJogador.brasao(_jog), Vector2i(36, 46))
	_nome.text = cav["nome"] if cav["nome"] != "" else "—"
	_casa.text = str(_jog.casa()["nome"])  # já vem como "Casa de ..."
	var t := _jog.titulo()
	_titulo_atual.text = tr("TITULO_" + t.to_upper()) if t != "" else tr("PERFIL_SEM_TITULO")
	_titulo_atual.add_theme_color_override("font_color", COR_DESTAQUE if t != "" else COR_FRACA)

func _montar_direita(cav: Dictionary, est: Dictionary) -> void:
	for c in _direita.get_children():
		_direita.remove_child(c)
		c.queue_free()
	# Nível e experiência.
	var tabela: Array = Balanceamento.ler("progressao")["xp_por_nivel"]
	var nivel := int(cav["nivel"])
	_direita.add_child(_rotulo(tr("PERFIL_NIVEL").format({"nivel": nivel}), 18, COR_DESTAQUE))
	var barra := ProgressBar.new()
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(0, 12)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.09, 0.07, 0.06)
	fundo.set_border_width_all(1)
	fundo.border_color = Color(0.45, 0.33, 0.2)
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = COR_DESTAQUE.darkened(0.15)
	barra.add_theme_stylebox_override("background", fundo)
	barra.add_theme_stylebox_override("fill", cheio)
	if nivel >= tabela.size():
		barra.max_value = 1
		barra.value = 1
		_direita.add_child(barra)
		_direita.add_child(_rotulo(tr("PERFIL_NIVEL_MAXIMO"), 11, COR_FRACA))
	else:
		var base := int(tabela[nivel - 1]) if nivel > 1 else 0
		barra.max_value = maxi(int(tabela[nivel]) - base, 1)
		barra.value = clampi(int(cav["xp"]) - base, 0, int(barra.max_value))
		_direita.add_child(barra)
		_direita.add_child(_rotulo(tr("PERFIL_XP_FALTA").format({"xp": _jog.xp_para_proximo(), "nivel": nivel + 1}), 11, COR_FRACA))
	# Liga, renome e ordem.
	var lg := _jog.liga_atual()
	var linhas := GridContainer.new()
	linhas.columns = 2
	linhas.add_theme_constant_override("h_separation", 12)
	linhas.add_theme_constant_override("v_separation", 2)
	_direita.add_child(linhas)
	_par(linhas, tr("PERFIL_LIGA_ROTULO"), tr("PERFIL_LIGA_VALOR").format({"liga": tr("LIGA_" + str(lg["nome"]).to_upper()),
		"divisao": lg["divisao"], "pontos": lg["pontos"]}))
	var f := _jog.faixa_renome()
	_par(linhas, tr("PERFIL_RENOME_ROTULO"), tr("PERFIL_RENOME_VALOR").format({"renome": _jog.renome(), "faixa": tr("FAIXA_" + str(f["nome"]).to_upper())}))
	var ordem := _jog.ordem()
	_par(linhas, tr("PERFIL_ORDEM_ROTULO"), str(ordem["nome"]) if not ordem.is_empty() else tr("PERFIL_SEM_ORDEM"))
	# Estatísticas de justa em cartões.
	_direita.add_child(_rotulo(tr("PERFIL_ESTATISTICAS"), 14, COR_DESTAQUE))
	var grade := GridContainer.new()
	grade.columns = 3
	grade.add_theme_constant_override("h_separation", 6)
	grade.add_theme_constant_override("v_separation", 6)
	_direita.add_child(grade)
	var taxa := "—" if int(est["taxa"]) < 0 else "%d%%" % int(est["taxa"])
	for par: Array in [["disputadas", str(est["disputadas"])], ["vitorias", str(est["vitorias"])], ["derrotas", str(est["derrotas"])],
			["taxa", taxa], ["maior_sequencia", str(est["maior_sequencia"])], ["derrubadas", str(est["derrubadas"])]]:
		grade.add_child(_cartao(par[0], par[1]))

## Cartão de estatística: número grande e o nome embaixo.
func _cartao(id: String, valor: String) -> PanelContainer:
	var c := PanelContainer.new()
	c.name = id
	c.custom_minimum_size = Vector2(104, 56)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	c.add_child(col)
	var v := _rotulo(valor, 22, COR_DESTAQUE)
	v.name = "Valor"
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(v)
	var n := _rotulo(tr("PERFIL_STAT_" + id.to_upper()), 10, COR_FRACA)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(n)
	return c

func _par(grade: GridContainer, rotulo: String, valor: String) -> void:
	grade.add_child(_rotulo(rotulo, 12, COR_FRACA))
	grade.add_child(_rotulo(valor, 12, Color(0.95, 0.9, 0.8)))

func _rotulo(texto: String, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	return l

# ---------------------------------------------- melhoria da casa (como antes)

func _atualizar_obra() -> void:
	_casa_nivel.text = tr("VILA_NIVEL").format({"nivel": _jog.predio_nivel(PREDIO), "teto": _jog.teto_predio(PREDIO)})
	var t := _jog.timer_do_predio(PREDIO, "melhoria")
	var p := _jog.pode_melhorar(PREDIO)
	if not t.is_empty():
		_casa_nivel.text += " · " + tr("VILA_EM_OBRA").format({"tempo": Vila.formatar_tempo(ServicoTempo.restante(int(t["termina_em"])))})
	_melhorar.disabled = not p["ok"]
	if p.has("ouro"):
		_melhorar.text = tr("VILA_MELHORAR").format({"ouro": p["ouro"], "tempo": Vila.formatar_tempo(_jog.duracao_timer(int(p["segundos"])))})
	else:
		_melhorar.text = tr("ERRO_" + str(p["erro"]).to_upper())

func _ao_melhorar() -> void:
	var r := _jog.melhorar_predio(PREDIO)
	_aviso.text = "" if r["ok"] else tr("ERRO_" + str(r["erro"]).to_upper())
	melhorar_pedido.emit(r)
	atualizar()
