class_name TelaForja
extends PanelContainer
## Armeiro e ferreiro (Pacote 3.15, GDD Forja). Armeiro: abas Criar (peças
## dos projetos, com a receita), Melhorar (+1 a +10, chance e custo; teto pelo
## nível do armeiro) e Equipamentos (abre a tela de equipamentos, onde fica o
## conserto). Ferreiro: fundir sucata em ferro e ferro em aço. Embaixo, a
## oficina: o martelo bate enquanto há peça na forja (ou lingote no forno) e
## "Pegar" recolhe o que ficou pronto. Tudo pelo serviço Jogador.

signal abrir_equipamentos

var predio := "armeiro"
var aba := "criar"
var _jog: ServicoJogador
var _martelo: Tween
var _agora: Button
var _agora_id := ""
var _acumulado := 0.0

@onready var _titulo: Label = $Coluna/Cabecalho/Titulo
@onready var _abas: HBoxContainer = $Coluna/Cabecalho/Abas
@onready var _materiais: Label = $Coluna/Materiais
@onready var _lista: VBoxContainer = $Coluna/Rolagem/Lista
@onready var _bigorna: Control = $Coluna/Oficina/Bigorna
@onready var _status: Label = $Coluna/Oficina/Status
@onready var _pegar: Button = $Coluna/Oficina/Pegar
@onready var _mensagem: Label = $Coluna/Mensagem
@onready var _melhorar_predio: Button = $Coluna/Botoes/Melhorar
@onready var _fechar: Button = $Coluna/Botoes/Fechar

const FAISCAS := preload("res://game/scenes/arena/efeitos/faiscas.tscn")

func _ready() -> void:
	_jog = get_node("/root/Jogador")
	visible = false
	_fechar.text = tr("PAINEL_FECHAR")
	_pegar.text = tr("FORJA_PEGAR")
	_fechar.pressed.connect(func(): visible = false; _parar_martelo())
	_pegar.pressed.connect(_pegar_pronto)
	# Terminar com gemas (3.18).
	_agora = Button.new()
	_agora.focus_mode = Control.FOCUS_NONE
	_agora.visible = false
	_agora.pressed.connect(func(): _mostrar(_jog.pular_com_gemas(_agora_id)))
	$Coluna/Oficina.add_child(_agora)
	_melhorar_predio.pressed.connect(func(): _mostrar(_jog.melhorar_predio(predio)))
	_jog.mudou.connect(func(_s): if visible: montar())

## Abre no prédio ("armeiro" ou "ferreiro").
func abrir(nome: String) -> void:
	predio = nome
	aba = "criar" if nome == "armeiro" else "fundir"
	_mensagem.text = ""
	visible = true
	montar()

func _process(delta: float) -> void:
	if not visible:
		return
	_acumulado += delta
	if _acumulado >= 1.0:
		_acumulado = 0.0
		_montar_oficina()

func montar() -> void:
	_titulo.text = tr("FORJA_TITULO_" + predio.to_upper())
	for c in _abas.get_children():
		c.queue_free()
	if predio == "armeiro":
		for a: String in ["criar", "melhorar", "equipamentos"]:
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.toggle_mode = true
			b.button_pressed = a == aba
			b.text = tr("FORJA_ABA_" + a.to_upper())
			b.pressed.connect(func():
				if a == "equipamentos":
					visible = false
					_parar_martelo()
					abrir_equipamentos.emit()
					return
				aba = a
				montar())
			_abas.add_child(b)
	_materiais.text = tr("FORJA_MATERIAIS").format({"lista": texto_materiais()})
	for c in _lista.get_children():
		c.queue_free()
	match aba:
		"criar": _montar_criar()
		"melhorar": _montar_melhorar()
		"fundir": _montar_fundir()
	var p := _jog.pode_melhorar(predio)
	_melhorar_predio.disabled = not p["ok"]
	_melhorar_predio.text = tr("VILA_MELHORAR").format({"ouro": p.get("ouro", 0), "tempo": Vila.formatar_tempo(_jog.duracao_timer(int(p.get("segundos", 0))))}) \
		if p.has("ouro") else tr("ERRO_" + str(p["erro"]).to_upper())
	_montar_oficina()

func texto_materiais() -> String:
	var partes: Array[String] = ["%d %s" % [_jog.ouro(), tr("MATERIAL_OURO_MOEDAS")]]
	var mats := _jog.materiais()
	var nomes := mats.keys()
	nomes.sort()
	for m: String in nomes:
		if int(mats[m]) > 0:
			partes.append("%d %s" % [int(mats[m]), tr("MATERIAL_" + m.to_upper())])
	return ", ".join(partes)

func _montar_criar() -> void:
	var projetos := _jog.projetos()
	if projetos.is_empty():
		_rotulo(tr("FORJA_SEM_PROJETOS"))
		return
	for conj: String in projetos:
		_rotulo(tr("FORJA_PROJETO").format({"conjunto": tr("CONJUNTO_" + conj.to_upper())}), true)
		for m: String in _jog.pecas_do_projeto(conj):
			var rec := _jog.receita(m)
			var linha := HBoxContainer.new()
			var l := Label.new()
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.add_theme_font_size_override("font_size", 12)
			l.text = "%s\n%s" % [tr("ITEM_" + m.to_upper()), tr("FORJA_RECEITA").format({"custo": _custo(rec["materiais"]),
				"ouro": int(rec["ouro"]), "tempo": Vila.formatar_tempo(_jog.duracao_timer(int(rec["segundos"])))})]
			l.add_theme_color_override("font_color", TelaBaus.cor_raridade(Balanceamento.carregar("itens")["modelos"][m]["raridade"]))
			linha.add_child(l)
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.text = tr("FORJA_FORJAR")
			var pf := _jog.pode_forjar(m)
			if pf["erro"] == "material_insuficiente":
				_jog.disparar_oferta("projeto_sem_material")
			b.disabled = not pf["ok"]
			b.tooltip_text = "" if pf["ok"] else tr("ERRO_" + str(pf["erro"]).to_upper())
			b.pressed.connect(func(): _mostrar(_jog.forjar(m)))
			linha.add_child(b)
			_lista.add_child(linha)

func _montar_melhorar() -> void:
	var itens := _jog.itens()
	# Equipadas primeiro.
	var equip: Array = _jog.estado["equipamento"].values()
	itens.sort_custom(func(a, b): return equip.has(a["id"]) and not equip.has(b["id"]))
	for it: Dictionary in itens:
		var c := _jog.custo_melhoria(it["id"])
		var nome := tr("ITEM_" + str(it["modelo"]).to_upper()) + ("  ✓" if equip.has(it["id"]) else "")
		var linha := HBoxContainer.new()
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 12)
		if c["maximo"]:
			l.text = tr("FORJA_MELHORAR_MAX").format({"item": nome, "nivel": c["nivel"]})
		elif int(c["nivel"]) >= int(c["teto"]):
			l.text = tr("FORJA_MELHORAR_TETO").format({"item": nome, "nivel": c["nivel"], "teto": c["teto"]})
		else:
			l.text = tr("FORJA_MELHORAR_LINHA").format({"item": nome, "nivel": c["nivel"], "proximo": int(c["nivel"]) + 1, "chance": c["chance"],
				"custo": _custo({"fragmentos": c["fragmentos"], "lingote_ferro": c["lingotes"]}) + " · %d %s" % [c["ouro"], tr("MATERIAL_OURO_MOEDAS")]})
		linha.add_child(l)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = tr("FORJA_ABA_MELHORAR")
		b.disabled = not _jog.pode_melhorar_peca(it["id"])["ok"]
		var id: String = it["id"]
		b.pressed.connect(func(): melhorar(id))
		linha.add_child(b)
		_lista.add_child(linha)

func _montar_fundir() -> void:
	var f := _jog.cfg_forja()
	for produto: String in ["lingote_ferro", "lingote_aco"]:
		var por := int(f["lingote_por_sucata"] if produto == "lingote_ferro" else f["aco_por_ferro"])
		var maximo := _jog.maximo_fundir(produto)
		var qtds: Array[int] = [1, 5]
		if maximo > 5:
			qtds.append(maximo)
		for qtd: int in qtds:
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.text = tr("FORJA_FUNDIR_" + ("FERRO" if produto == "lingote_ferro" else "ACO")).format({"qtd": qtd, "custo": qtd * por,
				"tempo": Vila.formatar_tempo(_jog.duracao_timer(qtd * int(f["fundir_segundos_por_lingote"])))})
			b.disabled = not _jog.pode_fundir(produto, qtd)["ok"]
			b.pressed.connect(func(): _mostrar(_jog.fundir(produto, qtd)))
			_lista.add_child(b)

## Tenta melhorar e conta o resultado (deu certo ou falhou sem perder a peça).
func melhorar(id: String) -> void:
	var nome := tr("ITEM_" + str(_jog.item(id)["modelo"]).to_upper())
	var r := _jog.melhorar_peca(id)
	if not r["ok"]:
		_mostrar(r)
		return
	_mensagem.text = tr("FORJA_MELHOROU").format({"item": nome, "nivel": r["nivel"]}) if r["sucesso"] else tr("FORJA_FALHOU").format({"nivel": r["nivel"]})
	_golpe()
	montar()

## O que está na forja ou no forno, com o tempo, e o martelo batendo.
func _montar_oficina() -> void:
	var tipo := "forja" if predio == "armeiro" else "fundicao"
	var ts: Array = _jog.timers().filter(func(t): return t["tipo"] == tipo)
	_pegar.visible = false
	if ts.is_empty():
		_agora.visible = false
		_status.text = tr("FORJA_LIVRE" if tipo == "forja" else "FORJA_FORNO_LIVRE")
		_parar_martelo()
		return
	var t: Dictionary = ts[0]
	var pronto := ServicoTempo.pronto(int(t["termina_em"]))
	if tipo == "forja":
		var item := tr("ITEM_" + str(t["modelo"]).to_upper())
		_status.text = tr("FORJA_PRONTA").format({"item": item}) if pronto else tr("FORJA_EM_ANDAMENTO").format({"item": item,
			"tempo": Vila.formatar_tempo(ServicoTempo.restante(int(t["termina_em"])))})
	else:
		var mat := tr("MATERIAL_" + str(t["produto"]).to_upper())
		_status.text = tr("FORJA_FUNDIDO_PRONTO").format({"qtd": t["quantidade"], "material": mat}) if pronto else tr("FORJA_FUNDINDO").format(
			{"qtd": t["quantidade"], "material": mat, "tempo": Vila.formatar_tempo(ServicoTempo.restante(int(t["termina_em"])))})
	_pegar.visible = pronto
	_agora.visible = not pronto
	_agora.text = tr("LOJA_TERMINAR_AGORA").format({"n": _jog.custo_pular(ServicoTempo.restante(int(t["termina_em"])))})
	_agora_id = t["id"]
	if pronto:
		_parar_martelo()
	else:
		_bater_martelo()

func _pegar_pronto() -> void:
	var tipo := "forja" if predio == "armeiro" else "fundicao"
	for t: Dictionary in _jog.timers():
		if t["tipo"] == tipo and ServicoTempo.pronto(int(t["termina_em"])):
			var r := _jog.concluir_timer(t["id"])
			if r["ok"] and r.has("item"):
				var partes: Array[String] = []
				for k: String in r["status"]:
					partes.append(tr("STATUS_" + k.to_upper()).format({"v": int(r["status"][k])}))
				_mensagem.text = tr("FORJA_GANHOU").format({"item": tr("ITEM_" + str(r["modelo"]).to_upper()), "status": ", ".join(partes)})
			elif r["ok"]:
				_mensagem.text = "+%d %s" % [r["quantidade"], tr("MATERIAL_" + str(r["produto"]).to_upper())]
			montar()
			return

## Martelo em loop (Tween): sobe e bate, com faíscas a cada golpe.
func _bater_martelo() -> void:
	if _martelo and _martelo.is_valid():
		return
	var m: Control = _bigorna.get_node("Martelo")
	_martelo = create_tween().set_loops()
	_martelo.tween_property(m, "rotation_degrees", 50.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_martelo.tween_property(m, "rotation_degrees", -10.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_martelo.tween_callback(_faiscas)

func _parar_martelo() -> void:
	if _martelo:
		_martelo.kill()
		_martelo = null
	if is_node_ready():
		(_bigorna.get_node("Martelo") as Control).rotation_degrees = 0.0

func _golpe() -> void:
	var m: Control = _bigorna.get_node("Martelo")
	var t := create_tween()
	t.tween_property(m, "rotation_degrees", 50.0, 0.15)
	t.tween_property(m, "rotation_degrees", -10.0, 0.08)
	t.tween_callback(_faiscas)
	t.tween_property(m, "rotation_degrees", 0.0, 0.1)

func _faiscas() -> void:
	var f := FAISCAS.instantiate() as CPUParticles2D
	f.amount = 8
	f.direction = Vector2(0, -1)
	_bigorna.add_child(f)
	f.position = Vector2(46, 22)
	f.emitting = true
	f.finished.connect(f.queue_free)

func _custo(mats: Dictionary) -> String:
	var partes: Array[String] = []
	for m: String in mats:
		if int(mats[m]) > 0:
			partes.append("%d %s" % [int(mats[m]), tr("MATERIAL_" + m.to_upper())])
	return ", ".join(partes)

func _rotulo(texto: String, destaque := false) -> void:
	var l := Label.new()
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if destaque:
		l.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
	_lista.add_child(l)

func _mostrar(r: Dictionary) -> void:
	_mensagem.text = "" if r["ok"] else tr("ERRO_" + str(r["erro"]).to_upper())
	if r["ok"]:
		_golpe()
	montar()
