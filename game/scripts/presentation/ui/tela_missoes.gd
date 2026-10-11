class_name TelaMissoes
extends PanelContainer
## Missões e glória (Pacote 3.21): abas Diárias, Semanais, Login (7 primeiros
## dias), Conquistas (com os títulos para escolher; o arauto anuncia o título
## antes da justa). No topo, o renome e a faixa (que mexe com a torcida e
## abre convites). Tudo pelo serviço Jogador.

var aba := "diarias"
var _jog: ServicoJogador

@onready var _titulo: Label = $Coluna/Titulo
@onready var _renome: Label = $Coluna/Renome
@onready var _abas: HBoxContainer = $Coluna/Abas
@onready var _lista: VBoxContainer = $Coluna/Rolagem/Lista
@onready var _mensagem: Label = $Coluna/Mensagem
@onready var _fechar: Button = $Coluna/Fechar

func _ready() -> void:
	_jog = get_node("/root/Jogador")
	visible = false
	_titulo.text = tr("METAS_TITULO")
	_fechar.text = tr("PAINEL_FECHAR")
	_fechar.pressed.connect(func(): visible = false)
	_jog.mudou.connect(func(_s): if visible: montar())

func abrir(qual := "diarias") -> void:
	aba = qual
	_mensagem.text = ""
	visible = true
	montar()

func montar() -> void:
	var f := _jog.faixa_renome()
	_renome.text = tr("METAS_RENOME").format({"renome": _jog.renome(), "faixa": tr("FAIXA_" + str(f["nome"]).to_upper())}) \
		+ ("" if int(f["proxima"]) < 0 else "  " + tr("METAS_PROXIMA_FAIXA").format({"falta": int(f["proxima"]) - _jog.renome()}))
	for c in _abas.get_children():
		c.queue_free()
	for a: String in ["diarias", "semanais", "login", "conquistas"]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = a == aba
		b.text = tr("METAS_ABA_" + a.to_upper())
		b.pressed.connect(func(): aba = a; montar())
		_abas.add_child(b)
	for c in _lista.get_children():
		c.queue_free()
	match aba:
		"diarias", "semanais": _montar_missoes(aba)
		"login": _montar_login()
		"conquistas": _montar_conquistas()

func _montar_missoes(tipo: String) -> void:
	for m: Dictionary in _jog.missoes()[tipo]:
		var texto := "%s  (%d/%d)\n%s" % [tr("MISSAO_" + str(m["id"]).to_upper()), int(m["progresso"]), int(m["meta"]), texto_recompensa(m["recompensa"])]
		var b := _linha(texto, tr("METAS_RESGATADA") if m["resgatada"] else tr("METAS_RESGATAR"), not m["pronta"])
		var id: String = m["id"]
		b.pressed.connect(func(): _resposta(_jog.resgatar_missao(id)))

func _montar_login() -> void:
	var h := _jog.login_hoje()
	var tabela: Array = _jog.cfg_metas()["login"]
	var feitos := int(_jog.estado["metas"]["login"]["dias"])
	for i in tabela.size():
		var estado_txt := tr("METAS_RESGATADA") if i < feitos else (tr("METAS_RESGATAR") if i == feitos else tr("METAS_DEPOIS"))
		var b := _linha("%s\n%s" % [tr("METAS_LOGIN_DIA").format({"n": i + 1}), texto_recompensa(tabela[i])], estado_txt,
			not (i == feitos and h["pode"]))
		b.pressed.connect(func(): _resposta(_jog.resgatar_login()))

func _montar_conquistas() -> void:
	for c: Dictionary in _jog.conquistas():
		var extra := ""
		if c.has("titulo"):
			extra = "  ·  " + tr("METAS_TITULO_DA").format({"titulo": tr("TITULO_" + str(c["titulo"]).to_upper())})
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 12)
		l.text = "%s %s  (%d/%d)%s\n%s" % ["✓" if c["feita"] else "·", tr("CONQUISTA_" + str(c["id"]).to_upper()), int(c["progresso"]),
			int(c["meta"]), extra, texto_recompensa(c.get("recompensa", {}))]
		if c["feita"]:
			l.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
		_lista.add_child(l)
	var t := Label.new()
	t.text = tr("METAS_TITULOS")
	t.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
	_lista.add_child(t)
	var nenhum := _linha(tr("METAS_SEM_TITULO"), tr("METAS_USANDO") if _jog.titulo() == "" else tr("METAS_USAR"), _jog.titulo() == "")
	nenhum.pressed.connect(func(): _resposta(_jog.definir_titulo("")))
	for ti: String in _jog.titulos():
		var b := _linha(tr("TITULO_" + ti.to_upper()), tr("METAS_USANDO") if _jog.titulo() == ti else tr("METAS_USAR"), _jog.titulo() == ti)
		b.pressed.connect(func(): _resposta(_jog.definir_titulo(ti)))

## Recompensa em texto: "+30 ouro, +1 chave, baú de ferro".
func texto_recompensa(r: Dictionary) -> String:
	var partes: Array[String] = []
	if r.has("ouro"):
		partes.append("+%d %s" % [int(r["ouro"]), tr("MATERIAL_OURO_MOEDAS")])
	if r.has("xp"):
		partes.append("+%d XP" % int(r["xp"]))
	if r.has("fragmentos"):
		partes.append("+%d %s" % [int(r["fragmentos"]), tr("MATERIAL_FRAGMENTOS")])
	if r.has("chaves"):
		partes.append(tr("METAS_CHAVES").format({"n": int(r["chaves"])}))
	if r.has("bau"):
		partes.append(tr("BAU_" + str(r["bau"]).to_upper()))
	return ", ".join(partes)

func _linha(texto: String, botao: String, desabilitado: bool) -> Button:
	var linha := HBoxContainer.new()
	var l := Label.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 12)
	l.text = texto
	linha.add_child(l)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = botao
	b.disabled = desabilitado
	linha.add_child(b)
	_lista.add_child(linha)
	return b

func _resposta(r: Dictionary) -> void:
	if not r["ok"]:
		_mensagem.text = tr("ERRO_" + str(r["erro"]).to_upper())
	else:
		_mensagem.text = texto_recompensa(r.get("recompensa", {}))
	montar()
