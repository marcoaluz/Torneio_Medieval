class_name TelaEquipamentos
extends Control
## Tela de Equipamentos, dentro do armeiro (Pacote 2.8, GDD Equipamentos):
## abas Cavaleiro e Cavalo, retrato grande no centro, espaços de peça em
## volta (game/data/personagem/espacos.json). Tocar num espaço lista as peças
## do inventário daquele espaço; tocar numa peça já mostra no personagem
## (pré-visualização) antes de equipar. Cada peça mostra status, raridade,
## durabilidade e conjunto. Guarda-roupa: usar só a aparência de uma peça
## sobre os status de outra. Tudo pelo serviço Jogador.

signal fechada

const ESPACOS := "res://game/data/personagem/espacos.json"

var aba := "cavaleiro"
var espaco := ""          ## espaço com a lista aberta
var selecionado := ""     ## id da peça em pré-visualização
var _jog: ServicoJogador
var _espacos: Dictionary
var _botoes_espaco := {}

@onready var _esquerda: VBoxContainer = $Esquerda
@onready var _direita: VBoxContainer = $Direita
@onready var _retrato: CamadasPersonagem = $Centro/Retrato
@onready var _retrato_cavalo: CamadasPersonagem = $Centro/RetratoCavalo
@onready var _painel: PanelContainer = $Pecas
@onready var _titulo_pecas: Label = $Pecas/Coluna/Titulo
@onready var _lista: VBoxContainer = $Pecas/Coluna/Rolagem/Lista
@onready var _detalhes: Label = $Pecas/Coluna/Detalhes
@onready var _equipar: Button = $Pecas/Coluna/Botoes/Equipar
@onready var _aparencia: Button = $Pecas/Coluna/Botoes/Aparencia
@onready var _restaurar: Button = $Pecas/Coluna/Botoes/Restaurar
@onready var _consertar: Button = $Pecas/Coluna/Botoes/Consertar

func _ready() -> void:
	_jog = get_node("/root/Jogador")
	_espacos = JSON.parse_string(FileAccess.get_file_as_string(ESPACOS))
	$Titulo.text = tr("EQUIP_TITULO")
	$Abas/Cavaleiro.text = tr("EQUIP_ABA_CAVALEIRO")
	$Abas/Cavalo.text = tr("EQUIP_ABA_CAVALO")
	$Abas/Cavaleiro.pressed.connect(func(): mudar_aba("cavaleiro"))
	$Abas/Cavalo.pressed.connect(func(): mudar_aba("cavalo"))
	$Fechar.text = tr("PAINEL_FECHAR")
	$Fechar.pressed.connect(fechar)
	_equipar.text = tr("EQUIP_EQUIPAR")
	_aparencia.text = tr("EQUIP_SO_APARENCIA")
	_restaurar.text = tr("EQUIP_RESTAURAR_APARENCIA")
	_equipar.pressed.connect(func(): _aplicar(_jog.equipar(selecionado)))
	_aparencia.pressed.connect(func(): _aplicar(_jog.definir_visual(espaco, selecionado)))
	_restaurar.pressed.connect(func(): _aplicar(_jog.definir_visual(espaco, "")))
	_consertar.pressed.connect(_ao_consertar)
	_retrato.tocar("respirar")
	_jog.mudou.connect(func(_s): if visible: montar())
	mudar_aba("cavaleiro")

func abrir() -> void:
	visible = true
	mudar_aba(aba)

func fechar() -> void:
	visible = false
	fechada.emit()

func mudar_aba(nova: String) -> void:
	aba = nova
	espaco = ""
	selecionado = ""
	_painel.visible = false
	_retrato.visible = aba == "cavaleiro"
	_retrato_cavalo.visible = aba == "cavalo"
	montar()

## Remonta os espaços e o personagem a partir dos dados do jogador.
func montar() -> void:
	for col in [_esquerda, _direita]:
		for c in col.get_children():
			c.queue_free()
	_botoes_espaco.clear()
	var modelos: Dictionary = Balanceamento.carregar("itens")["modelos"]
	for e: Dictionary in _espacos[aba]:
		var nome: String = e["espaco"]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(150, 34)
		b.add_theme_font_size_override("font_size", 11)
		var it := _jog.equipado(nome)
		var linha2 := tr("EQUIP_VAZIO") if it.is_empty() else tr("ITEM_" + str(it["modelo"]).to_upper())
		b.text = "%s\n%s" % [tr("ESPACO_" + nome.to_upper()), linha2]
		if not it.is_empty():
			b.add_theme_color_override("font_color", TelaBaus.cor_raridade(modelos[it["modelo"]]["raridade"]))
		b.pressed.connect(func(): abrir_espaco(nome))
		(_esquerda if e["lado"] == "esquerda" else _direita).add_child(b)
		_botoes_espaco[nome] = b
	_vestir_previa({})
	if espaco != "":
		_montar_lista()

## Abre a lista de peças do espaço.
func abrir_espaco(nome: String) -> void:
	espaco = nome
	selecionado = ""
	_painel.visible = true
	_montar_lista()

func _montar_lista() -> void:
	for c in _lista.get_children():
		c.queue_free()
	_titulo_pecas.text = tr("ESPACO_" + espaco.to_upper())
	var modelos: Dictionary = Balanceamento.carregar("itens")["modelos"]
	var equipado_id: String = _jog.estado["equipamento"].get(espaco, "")
	var pecas := _jog.itens().filter(func(it): return modelos.get(it["modelo"], {}).get("espaco", "") == espaco)
	if pecas.is_empty():
		var vazio := Label.new()
		vazio.text = tr("EQUIP_SEM_PECAS")
		_lista.add_child(vazio)
	for it: Dictionary in pecas:
		var m: Dictionary = modelos[it["modelo"]]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var nivel := int(it.get("nivel", 0))
		b.text = "%s%s%s" % [tr("ITEM_" + str(it["modelo"]).to_upper()), " +%d" % nivel if nivel > 0 else "", "  ✓" if it["id"] == equipado_id else ""]
		b.add_theme_color_override("font_color", TelaBaus.cor_raridade(m["raridade"]))
		b.icon = ArteUi.icone_item(it["modelo"])
		b.add_theme_constant_override("icon_max_width", 32)
		b.pressed.connect(func(): selecionar(it["id"]))
		_lista.add_child(b)
	_atualizar_detalhes()

## Pré-visualiza a peça no personagem e mostra os detalhes.
func selecionar(id: String) -> void:
	selecionado = id
	var it := _jog.item(id)
	var visual: String = Balanceamento.carregar("itens")["modelos"][it["modelo"]]["visual"]
	_vestir_previa({espaco: visual})
	_atualizar_detalhes()

func _atualizar_detalhes() -> void:
	_equipar.disabled = selecionado == "" or _jog.estado["equipamento"].get(espaco, "") == selecionado
	_aparencia.disabled = selecionado == ""
	_restaurar.disabled = not _jog.estado["visual"].has(espaco)
	_atualizar_conserto()
	if selecionado == "":
		_detalhes.text = tr("EQUIP_TOQUE_UMA_PECA")
		return
	var it := _jog.item(selecionado)
	var m: Dictionary = Balanceamento.carregar("itens")["modelos"][it["modelo"]]
	var partes: Array[String] = [tr("RARIDADE_" + str(m["raridade"]).to_upper())]
	if int(it.get("nivel", 0)) > 0:
		partes.append(tr("EQUIP_NIVEL").format({"n": int(it["nivel"])}))
	var st := _jog.status_do_item(selecionado)
	for k: String in st:
		partes.append(tr("STATUS_" + k.to_upper()).format({"v": int(st[k])}))
	if int(m["durabilidade_max"]) > 0:
		partes.append(tr("EQUIP_DURABILIDADE").format({"atual": int(it["durabilidade"]), "max": int(m["durabilidade_max"])}))
		var e := _jog.estagio_dano(selecionado)
		if int(it["durabilidade"]) == 0:
			partes.append(tr("DANO_QUEBRADA"))
		elif e > 0:
			partes.append(tr("DANO_%d" % e))
	partes.append(tr("EQUIP_CONJUNTO").format({"conjunto": tr("CONJUNTO_" + str(m["conjunto"]).to_upper()),
		"n": _pecas_do_conjunto_equipadas(str(m["conjunto"]))}))
	_detalhes.text = "\n".join(partes)

## Botão de conserto: custo e tempo; em conserto, o tempo; pronto, concluir.
func _atualizar_conserto() -> void:
	_consertar.visible = selecionado != ""
	if selecionado == "":
		return
	var t := _jog.item_em_conserto(selecionado)
	if not t.is_empty():
		var pronto := ServicoTempo.pronto(int(t["termina_em"]))
		_consertar.disabled = not pronto
		_consertar.text = tr("CONSERTO_CONCLUIR") if pronto else tr("CONSERTO_EM_ANDAMENTO").format(
			{"tempo": Vila.formatar_tempo(ServicoTempo.restante(int(t["termina_em"])))})
		return
	var p := _jog.pode_consertar(selecionado)
	_consertar.disabled = not p["ok"]
	if p.has("ouro"):
		_consertar.text = tr("CONSERTO_CONSERTAR").format({"ouro": p["ouro"], "qtd": p["quantidade"],
			"material": tr("MATERIAL_" + str(p["material"]).to_upper()), "tempo": Vila.formatar_tempo(_jog.duracao_timer(int(p["segundos"])))})
	else:
		_consertar.text = tr("ERRO_" + str(p["erro"]).to_upper())

func _ao_consertar() -> void:
	var t := _jog.item_em_conserto(selecionado)
	var id := selecionado
	var r := _jog.concluir_timer(t["id"]) if not t.is_empty() else _jog.consertar(selecionado)
	_aplicar(r)
	if r["ok"]:
		selecionar(id)

func _pecas_do_conjunto_equipadas(conjunto: String) -> int:
	var modelos: Dictionary = Balanceamento.carregar("itens")["modelos"]
	var n := 0
	for esp: String in _jog.estado["equipamento"]:
		var it := _jog.item(_jog.estado["equipamento"][esp])
		if not it.is_empty() and modelos[it["modelo"]]["conjunto"] == conjunto:
			n += 1
	return n

## Veste o retrato com o visual do jogador mais `troca` (pré-visualização).
func _vestir_previa(troca: Dictionary) -> void:
	AparenciaJogador.vestir_camadas(_retrato, _jog)
	_retrato.vestir(troca)
	var cav := {"pelagem": _jog.cavalo_ativo().get("pelagem", "alazao")}
	for k in ["corpo", "pernas", "peitoral", "sobreveste", "elmo", "cimeira", "escudo", "lanca"]:
		cav[k] = "nenhum"
	cav["caparacao"] = _jog.visual_das_pecas().get("caparacao", "provisorio")
	cav.merge(troca, true)
	_retrato_cavalo.definir_casa(AparenciaJogador.casa(_jog))
	_retrato_cavalo.vestir(cav)

func _aplicar(r: Dictionary) -> void:
	if not r["ok"]:
		_detalhes.text = tr("ERRO_" + str(r["erro"]).to_upper())
		return
	selecionado = ""
	montar()
