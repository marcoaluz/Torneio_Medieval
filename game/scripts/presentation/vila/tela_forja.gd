class_name TelaForja
extends PanelContainer
## Armeiro e ferreiro (Pacote 3.15, GDD Forja). Armeiro: abas Criar (peças
## dos projetos, com a receita), Melhorar (+1 a +10, chance e custo; teto pelo
## nível do armeiro) e Equipamentos (abre a tela de equipamentos, onde fica o
## conserto). Ferreiro: a bancada (cena) com a peça escolhida lado a lado,
## no estágio de dano de agora e como fica depois do conserto (arte _d1.._d3),
## e as abas Consertar (peças gastas e a fila de conserto, a mesma do armeiro
## e de Equipamentos) e Fundir (sucata em ferro e ferro em aço). Embaixo, a
## oficina: o martelo bate enquanto há peça na forja (ou lingote no forno) e
## "Pegar" recolhe o que ficou pronto. Tudo pelo serviço Jogador.

signal abrir_equipamentos

var predio := "armeiro"
var aba := "criar"
var _jog: ServicoJogador
var _martelo: Tween
var _agora: Button
var _anuncio_b: Button
var _agora_id := ""
var _acumulado := 0.0
var selecionada := ""  ## peça na bancada do ferreiro (id do item)

const FUNDO_FERREIRO := "res://game/art/sprites/ferreiro/fundo.png"

@onready var _titulo: Label = $Coluna/Cabecalho/Titulo
@onready var _abas: HBoxContainer = $Coluna/Cabecalho/Abas
@onready var _materiais: Label = $Coluna/Materiais
@onready var _lista: VBoxContainer = $Coluna/Corpo/Rolagem/Lista
@onready var _cena: VBoxContainer = $Coluna/Corpo/Cena
@onready var _antes: VistaPeca = $Coluna/Corpo/Cena/Palco/Antes
@onready var _depois: VistaPeca = $Coluna/Corpo/Cena/Palco/Depois
@onready var _rotulo_antes: Label = $Coluna/Corpo/Cena/Palco/RotuloAntes
@onready var _rotulo_depois: Label = $Coluna/Corpo/Cena/Palco/RotuloDepois
@onready var _peca: Label = $Coluna/Corpo/Cena/Peca
@onready var _consertar: Button = $Coluna/Corpo/Cena/Consertar
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
	# Cortar 30 min com anúncio (3.19; opcional).
	_anuncio_b = Button.new()
	_anuncio_b.focus_mode = Control.FOCUS_NONE
	_anuncio_b.visible = false
	_anuncio_b.pressed.connect(func():
		var an := get_node_or_null("/root/Anuncios") as ServicoAnuncios
		if an:
			_mostrar(await an.assistir("cortar_timer", _agora_id)))
	$Coluna/Oficina.add_child(_anuncio_b)
	_melhorar_predio.pressed.connect(func(): _mostrar(_jog.melhorar_predio(predio)))
	_consertar.pressed.connect(_ao_consertar)
	if ResourceLoader.exists(FUNDO_FERREIRO):
		($Coluna/Corpo/Cena/Palco/Fundo as TextureRect).texture = load(FUNDO_FERREIRO)
	_jog.mudou.connect(func(_s): if visible: montar())

## Abre no prédio ("armeiro" ou "ferreiro").
func abrir(nome: String) -> void:
	predio = nome
	aba = "criar" if nome == "armeiro" else "consertar"
	_cena.visible = nome == "ferreiro"
	# Ferreiro: mais largo para a bancada (384) e a lista ao lado.
	var meia := Vector2(440, 250) if nome == "ferreiro" else Vector2(330, 230)
	offset_left = -meia.x
	offset_right = meia.x
	offset_top = -meia.y
	offset_bottom = meia.y
	selecionada = ""
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
	var abas: Array = ["criar", "melhorar", "equipamentos"] if predio == "armeiro" else ["consertar", "fundir"]
	for a: String in abas:
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
		"consertar": _montar_consertar()
	if predio == "ferreiro":
		_montar_bancada()
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

# ------------------------------------------------------------ conserto (ferreiro)

## Peças que gastam (durabilidade): as gastas e as que estão no conserto.
func pecas_gastas() -> Array:
	var modelos: Dictionary = Balanceamento.ler("itens")["modelos"]
	return _jog.itens().filter(func(it):
		var maximo := int(modelos[it["modelo"]]["durabilidade_max"])
		return maximo > 0 and (int(it["durabilidade"]) < maximo or not _jog.item_em_conserto(it["id"]).is_empty()))

## Na bancada: a escolhida; sem escolha, a primeira gasta; sem gasta, a primeira
## equipada que gasta (para mostrar como ela está).
func _peca_da_bancada() -> String:
	if selecionada != "" and not _jog.item(selecionada).is_empty():
		return selecionada
	var gastas := pecas_gastas()
	if not gastas.is_empty():
		return gastas[0]["id"]
	var modelos: Dictionary = Balanceamento.ler("itens")["modelos"]
	for esp: String in ["peitoral", "elmo", "escudo", "lanca"]:
		var it := _jog.equipado(esp)
		if not it.is_empty() and int(modelos[it["modelo"]]["durabilidade_max"]) > 0:
			return it["id"]
	return ""

func _montar_consertar() -> void:
	var gastas := pecas_gastas()
	var modelos: Dictionary = Balanceamento.ler("itens")["modelos"]
	var na_bancada := _peca_da_bancada()
	_rotulo(tr("FERREIRO_PECAS_GASTAS"), true)
	if gastas.is_empty():
		_rotulo(tr("FERREIRO_SEM_GASTAS"))
	var equip: Array = _jog.estado["equipamento"].values()
	for it: Dictionary in gastas:
		var b := Button.new()
		b.name = str(it["id"])
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = it["id"] == na_bancada
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = ArteUi.icone_item(it["modelo"])
		b.add_theme_constant_override("icon_max_width", 28)
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_color_override("font_color", TelaBaus.cor_raridade(modelos[it["modelo"]]["raridade"]))
		b.text = "%s%s · %s" % [tr("ITEM_" + str(it["modelo"]).to_upper()), "  ✓" if equip.has(it["id"]) else "", _nome_estagio(it["id"])]
		var id: String = it["id"]
		b.pressed.connect(func(): selecionada = id; montar())
		_lista.add_child(b)
	# A fila de conserto (vagas pelo nível do armeiro, como em Equipamentos).
	var fila: Array = _jog.timers().filter(func(t): return t["tipo"] == "conserto")
	_rotulo(tr("FERREIRO_FILA").format({"usadas": fila.size(), "vagas": _jog.vagas_conserto()}), true)
	if fila.is_empty():
		_rotulo(tr("FERREIRO_FILA_VAZIA"))
	for t: Dictionary in fila:
		var linha := HBoxContainer.new()
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 12)
		l.text = tr("ITEM_" + str(_jog.item(t["item"]).get("modelo", "")).to_upper())
		linha.add_child(l)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		if ServicoTempo.pronto(int(t["termina_em"])):
			b.text = tr("CONSERTO_CONCLUIR")
			var tid: String = t["id"]
			b.pressed.connect(func(): _mostrar(_jog.concluir_timer(tid)))
		else:
			b.text = Vila.formatar_tempo(ServicoTempo.restante(int(t["termina_em"])))
			b.disabled = true
		linha.add_child(b)
		_lista.add_child(linha)

## "Riscada", "Quebrada", "Inteira"...
func _nome_estagio(id: String) -> String:
	var it := _jog.item(id)
	if int(it.get("durabilidade", 1)) == 0:
		return tr("FERREIRO_QUEBRADA")
	var e := _jog.estagio_dano(id)
	return tr("DANO_%d" % e) if e > 0 else tr("FERREIRO_INTEIRA")

## A bancada: a peça como está e como fica depois do conserto, lado a lado.
func _montar_bancada() -> void:
	var id := _peca_da_bancada()
	var vazio := id == ""
	_antes.visible = not vazio
	_depois.visible = not vazio
	$Coluna/Corpo/Cena/Palco/Seta.visible = not vazio
	if vazio:
		_rotulo_antes.text = ""
		_rotulo_depois.text = ""
		_peca.text = tr("FERREIRO_SEM_PECA")
		_consertar.visible = false
		return
	var it := _jog.item(id)
	var m: Dictionary = Balanceamento.ler("itens")["modelos"][it["modelo"]]
	var casa := AparenciaJogador.casa(_jog)
	var e := _jog.estagio_dano(id)
	if _antes.espaco != m["espaco"] or _antes.visual != m["visual"] or _antes.estagio != e:
		_antes.mostrar(m["espaco"], m["visual"], e, casa)
	if _depois.espaco != m["espaco"] or _depois.visual != m["visual"]:
		_depois.mostrar(m["espaco"], m["visual"], 0, casa)
	_antes.modulate = Color(0.75, 0.75, 0.75) if int(it["durabilidade"]) == 0 else Color.WHITE
	var maximo := int(m["durabilidade_max"])
	_rotulo_antes.text = "%s\n%d/%d" % [_nome_estagio(id), int(it["durabilidade"]), maximo]
	_rotulo_depois.text = "%s\n%d/%d" % [tr("FERREIRO_DEPOIS"), maximo, maximo]
	_peca.text = tr("ITEM_" + str(it["modelo"]).to_upper())
	_consertar.visible = true
	var t := _jog.item_em_conserto(id)
	if not t.is_empty():
		var pronto := ServicoTempo.pronto(int(t["termina_em"]))
		_consertar.disabled = not pronto
		_consertar.text = tr("CONSERTO_CONCLUIR") if pronto else tr("FERREIRO_EM_CONSERTO").format(
			{"tempo": Vila.formatar_tempo(ServicoTempo.restante(int(t["termina_em"])))})
		return
	var p := _jog.pode_consertar(id)
	_consertar.disabled = not p["ok"]
	if p.has("ouro"):
		_consertar.text = tr("CONSERTO_CONSERTAR").format({"ouro": p["ouro"], "qtd": p["quantidade"],
			"material": tr("MATERIAL_" + str(p["material"]).to_upper()), "tempo": Vila.formatar_tempo(_jog.duracao_timer(int(p["segundos"])))})
	else:
		_consertar.text = tr("ERRO_" + str(p["erro"]).to_upper())

func _ao_consertar() -> void:
	var id := _peca_da_bancada()
	if id == "":
		return
	selecionada = id
	var t := _jog.item_em_conserto(id)
	_mostrar(_jog.concluir_timer(t["id"]) if not t.is_empty() else _jog.consertar(id))

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
		_anuncio_b.visible = false
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
	_anuncio_b.visible = not pronto and _jog.pode_recompensa_anuncio("cortar_timer", t["id"])["ok"]
	_anuncio_b.text = TelaBaus.texto_anuncio(_jog, "ANUNCIO_CORTAR")
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
