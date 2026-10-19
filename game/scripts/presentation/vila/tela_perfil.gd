class_name TelaPerfil
extends PanelContainer
## Perfil do jogador, aberto pela casa senhorial. À esquerda o retrato (o
## personagem vestido como está, respirando, no fundo do salão da casa), o
## brasão, nome, casa e título; à direita nível com a barra de experiência,
## liga, renome, ordem e as estatísticas de justa (disputadas, vitórias,
## derrotas, taxa, maior sequência) em cartões. Embaixo, o que já existia no
## painel da casa: o nível dela e melhorar (ouro, tempo, em obra). Só lê do
## serviço Jogador (renome, liga, metas, `estatisticas()`); a melhoria passa
## pelos mesmos comandos de antes. A aba Troféus é a estante da casa: um
## lugar por campeão do circuito (vazio até vencê-lo); tocar num troféu mostra
## quando foi vencido, as revanches, a peça dele (usar ou tirar) e a revanche
## heroica do dia (pedida a quem hospeda a tela, que abre a ficha).

signal melhorar_pedido(resultado: Dictionary)
## O retrato do topo da vila abre este perfil; daqui, o botão abre os Equipamentos.
signal abrir_equipamentos
## Revanche heroica pedida na estante de troféus.
signal pedir_revanche(campeao: String)

const PREDIO := "casa_senhorial"
const COR_DESTAQUE := Color(1, 0.88, 0.55)
const COR_FRACA := Color(0.75, 0.7, 0.62)
const TEXTO_MIN := 22

var _jog: ServicoJogador
var _retrato: CamadasPersonagem
var _chave := ""
## "estatisticas" ou "trofeus" (a estante).
var aba := "estatisticas"
## Campeão escolhido na estante ("" = nenhum).
var trofeu := ""

@onready var _fundo: ColorRect = $Coluna/Corpo/Esquerda/Palco/Fundo
@onready var _palco: Control = $Coluna/Corpo/Esquerda/Palco
@onready var _brasao: TextureRect = $Coluna/Corpo/Esquerda/Identidade/Brasao
@onready var _nome: Label = $Coluna/Corpo/Esquerda/Identidade/Textos/Nome
@onready var _casa: Label = $Coluna/Corpo/Esquerda/Identidade/Textos/Casa
@onready var _titulo_atual: Label = $Coluna/Corpo/Esquerda/Titulo
@onready var _direita: VBoxContainer = $Coluna/Corpo/Direita
@onready var _esquerda: VBoxContainer = $Coluna/Corpo/Esquerda
@onready var _casa_nivel: Label = $Coluna/Rodape/CasaNivel
@onready var _melhorar: Button = $Coluna/Rodape/Melhorar
@onready var _fechar: Button = $Coluna/Rodape/Fechar
@onready var _equipamentos: Button = $Coluna/Rodape/Equipamentos
@onready var _aviso: Label = $Coluna/Aviso

func _ready() -> void:
	_jog = get_node("/root/Jogador")
	visible = false
	_fechar.text = tr("PAINEL_FECHAR")
	_fechar.pressed.connect(fechar)
	_equipamentos.text = tr("EQUIP_TITULO")
	_equipamentos.pressed.connect(func(): abrir_equipamentos.emit())
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
		_equipamentos.text = tr("EQUIP_TITULO")
		if visible:
			_chave = ""
			atualizar()

func abrir() -> void:
	visible = true
	aba = "estatisticas"
	trofeu = ""
	_aviso.text = ""
	_aviso.visible = false
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
		TranslationServer.get_locale()] + "|%s|%s|%s" % [aba, trofeu, JSON.stringify(_jog.trofeus(), "", true)]
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
	_montar_aba()
	if aba == "trofeus":
		_montar_estante()
		return
	# Nível e experiência.
	var tabela: Array = Balanceamento.ler("progressao")["xp_por_nivel"]
	var nivel := int(cav["nivel"])
	_direita.add_child(_rotulo(tr("PERFIL_NIVEL").format({"nivel": nivel}), 28, COR_DESTAQUE))
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
	linhas.add_theme_constant_override("v_separation", 0)
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

## Botão na coluna da esquerda que troca entre as estatísticas e a estante
## ("Troféus (n)" / "Estatísticas").
func _montar_aba() -> void:
	var b := _esquerda.get_node_or_null("Aba") as Button
	if b == null:
		b = Button.new()
		b.name = "Aba"
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 64)
		b.pressed.connect(func(): aba = "estatisticas" if aba == "trofeus" else "trofeus"; trofeu = ""; atualizar())
		_esquerda.add_child(b)
	b.text = tr("PERFIL_ABA_ESTATISTICAS") if aba == "trofeus" else tr("PERFIL_ABA_TROFEUS").format({"n": _jog.trofeus().size()})

## Estante de troféus: uma prateleira por fileira, um lugar por campeão do
## circuito (na ordem das regiões); vencido mostra o brasão dele, ainda não
## vencido fica escuro com "?". Embaixo, o troféu escolhido.
func _montar_estante() -> void:
	var meus := {}
	for t: Dictionary in _jog.trofeus():
		meus[t["campeao"]] = t
	if meus.is_empty():
		_direita.add_child(_rotulo(tr("TROFEUS_VAZIO"), 14, COR_FRACA))
	var campeoes := _jog.campeoes()
	var por_fileira := 6
	var estante := VBoxContainer.new()
	estante.name = "Estante"
	estante.add_theme_constant_override("separation", 0)
	_direita.add_child(estante)
	for i in range(0, campeoes.size(), por_fileira):
		var fileira := HBoxContainer.new()
		fileira.add_theme_constant_override("separation", 6)
		estante.add_child(fileira)
		for c: String in campeoes.slice(i, i + por_fileira):
			fileira.add_child(_lugar(c, meus.get(c, {})))
		var tabua := ColorRect.new()
		tabua.color = Color(0.36, 0.22, 0.12)
		tabua.custom_minimum_size = Vector2(0, 8)
		estante.add_child(tabua)
	if trofeu != "" and meus.has(trofeu):
		_montar_trofeu(meus[trofeu])
	elif not meus.is_empty():
		_direita.add_child(_rotulo(tr("TROFEUS_TOQUE"), 12, COR_FRACA))

## Lugar da estante: botão de 76×76 com o brasão do campeão (ou "?").
func _lugar(campeao: String, t: Dictionary) -> Button:
	var b := Button.new()
	b.name = campeao
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(76, 76)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if t.is_empty():
		b.text = "?"
		b.disabled = true
		return b
	var rv := _jog.rival_para_justa(campeao)
	b.icon = GeradorBrasao.textura(rv["brasao"], Vector2i(36, 46))
	b.tooltip_text = tr(rv["nome_chave"])
	b.toggle_mode = true
	b.button_pressed = trofeu == campeao
	b.pressed.connect(func(): trofeu = campeao; atualizar())
	return b

## Troféu escolhido: nome e alcunha, onde foi vencido, revanches, a peça e a revanche do dia.
func _montar_trofeu(t: Dictionary) -> void:
	var c: String = t["campeao"]
	var rv := _jog.rival_para_justa(c)
	var caixa := VBoxContainer.new()
	caixa.name = "Trofeu"
	caixa.add_theme_constant_override("separation", 0)
	_direita.add_child(caixa)
	var nome := tr(rv["nome_chave"])
	if str(rv.get("alcunha", "")) != "":
		nome += ", " + tr(rv["alcunha"])
	caixa.add_child(_rotulo(nome, 14, COR_DESTAQUE))
	caixa.add_child(_rotulo(tr("TROFEU_VENCIDO_EM").format({"torneio": tr("TORNEIO_" + str(t["torneio"]).to_upper())}) + "  ·  " +
		tr("TROFEU_REVANCHES").format({"n": int(t["revanches"])}), 12, COR_FRACA))
	var peca := str(t["peca"])
	var defs: Dictionary = Balanceamento.ler("itens")["pecas_trofeu"]
	var botoes := HBoxContainer.new()
	botoes.add_theme_constant_override("separation", 8)
	if peca != "" and defs.has(peca):
		var espaco := str(defs[peca]["espaco"])
		caixa.add_child(_rotulo(tr("TROFEU_PECA").format({"nome": tr("ITEM_" + peca.to_upper()), "espaco": tr("ESPACO_" + espaco.to_upper())}), 12, Color(0.95, 0.9, 0.8)))
		var usar := Button.new()
		usar.name = "UsarPeca"
		usar.focus_mode = Control.FOCUS_NONE
		usar.custom_minimum_size = Vector2(0, 64)
		var em_uso := _jog.peca_trofeu_em_uso(espaco) == peca
		usar.text = tr("TROFEU_TIRAR") if em_uso else tr("TROFEU_USAR")
		usar.pressed.connect(func():
			var r := _jog.usar_peca_trofeu(espaco, "" if em_uso else peca)
			_aviso.text = "" if r["ok"] else tr("ERRO_" + str(r["erro"]).to_upper())
			_aviso.visible = _aviso.text != ""
			_chave = ""
			atualizar())
		botoes.add_child(usar)
	var rev := Button.new()
	rev.name = "Revanche"
	rev.focus_mode = Control.FOCUS_NONE
	rev.custom_minimum_size = Vector2(0, 64)
	var p := _jog.pode_revanche(c)
	rev.text = tr("TROFEU_REVANCHE") if p["ok"] else tr("TROFEU_REVANCHE_AMANHA")
	rev.disabled = not p["ok"]
	rev.pressed.connect(func(): pedir_revanche.emit(c))
	botoes.add_child(rev)
	caixa.add_child(botoes)

## Cartão de estatística: número grande e o nome embaixo.
func _cartao(id: String, valor: String) -> PanelContainer:
	var c := PanelContainer.new()
	c.name = id
	c.custom_minimum_size = Vector2(150, 66)
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
	l.add_theme_font_size_override("font_size", maxi(tamanho, TEXTO_MIN))  # nunca abaixo do mínimo legível no celular
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
	_aviso.visible = _aviso.text != ""
	melhorar_pedido.emit(r)
	atualizar()
