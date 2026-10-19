class_name TelaTorneios
extends PanelContainer
## Circuito PvE na arena da vila (Pacote 2.10 e 3.13): as regiões abertas
## (setas para trocar), os torneios da região com liberação, progresso e
## desafios especiais; escolhido um, a chave de rivais com as estrelas de cada
## disputa e os botões Justar (manual) e Automático (3 estrelas, nunca o
## campeão). Também há a justa livre (treino, sem recompensa). Campeão já
## vencido ganha o botão da revanche heroica (uma por dia). Justar e Revanche
## pedem a ficha do adversário a quem hospeda a tela (a vila); sem ninguém
## ouvindo, vão direto para a arena.

## A vila mostra a ficha do adversário e chama justar_direto ao lutar.
signal pedir_justa(torneio: String, indice: int)
## O mesmo para a revanche heroica (revanche_direto).
signal pedir_revanche(campeao: String)

var torneio := ""
## Região mostrada ("" = a atual do jogador).
var regiao := ""
var _jog: ServicoJogador

@onready var _titulo: Label = $Coluna/Cabecalho/Titulo
@onready var _anterior: Button = $Coluna/Cabecalho/Anterior
@onready var _proxima: Button = $Coluna/Cabecalho/Proxima
@onready var _lista: VBoxContainer = $Coluna/Rolagem/Lista
@onready var _info: Label = $Coluna/Info
@onready var _voltar: Button = $Coluna/Botoes/Voltar
@onready var _livre: Button = $Coluna/Botoes/Livre
@onready var _fechar: Button = $Coluna/Botoes/Fechar

func _ready() -> void:
	_jog = get_node("/root/Jogador")
	visible = false
	_voltar.text = tr("PVE_VOLTAR")
	_anterior.text = tr("PVE_REGIAO_ANTERIOR")
	_proxima.text = tr("PVE_REGIAO_PROXIMA")
	_anterior.pressed.connect(func(): _trocar_regiao(-1))
	_proxima.pressed.connect(func(): _trocar_regiao(1))
	_livre.text = tr("PVE_JUSTA_LIVRE")
	_fechar.text = tr("PAINEL_FECHAR")
	_voltar.pressed.connect(func(): torneio = ""; montar())
	_livre.pressed.connect(func(): (get_node("/root/Fluxo") as FluxoTelas).justa_livre())
	_fechar.pressed.connect(func(): visible = false)
	_jog.mudou.connect(func(_s): if visible: montar())

func abrir() -> void:
	torneio = ""
	regiao = _jog.estado["pve"]["regiao"]
	_info.text = ""
	visible = true
	montar()

func montar() -> void:
	for c in _lista.get_children():
		c.queue_free()
	_voltar.visible = torneio != ""
	if regiao == "":
		regiao = _jog.estado["pve"]["regiao"]
	var abertas := _jog.regioes_liberadas()
	_anterior.visible = torneio == ""
	_proxima.visible = torneio == ""
	_anterior.disabled = abertas.find(regiao) <= 0
	_proxima.disabled = abertas.find(regiao) >= abertas.size() - 1
	if torneio == "":
		_montar_regiao()
	else:
		_montar_chave()

func _montar_regiao() -> void:
	var dados := _jog.pve()
	_titulo.text = tr("REGIAO_" + regiao.to_upper())
	for t: String in dados["regioes"][regiao]["torneios"]:
		var p := _jog.progresso_torneio(t)
		var total: int = (dados["torneios"][t]["rivais"] as Array).size()
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var estado_txt := tr("PVE_CONCLUIDO") if p["concluido"] else tr("PVE_PROGRESSO").format({"feitas": p["proxima"], "total": total})
		if p["falhou"]:
			estado_txt = tr("PVE_CHANCE_PERDIDA")
		if not _jog.torneio_liberado(t):
			var nivel_min := int(dados["torneios"][t]["nivel_minimo"])
			var renome_min := int(dados["torneios"][t].get("renome_minimo", 0))
			if int(_jog.cavaleiro()["nivel"]) < nivel_min:
				estado_txt = tr("PVE_BLOQUEADO").format({"nivel": nivel_min})
			elif _jog.renome() < renome_min:
				estado_txt = tr("PVE_CONVITE").format({"renome": renome_min})
			else:
				estado_txt = tr("PVE_BLOQUEADO_ANTERIOR")
			b.disabled = true
		var nome := tr("TORNEIO_" + t.to_upper())
		if dados["torneios"][t].get("opcional", false):
			nome += "  [%s]" % tr("PVE_OPCIONAL")
		b.text = "%s  ·  %s  ·  %s" % [nome, estado_txt, _estrelas_total(t)]
		b.pressed.connect(func(): torneio = t; montar())
		_lista.add_child(b)

func _montar_chave() -> void:
	var dados := _jog.pve()
	var t: Dictionary = dados["torneios"][torneio]
	var p := _jog.progresso_torneio(torneio)
	_titulo.text = tr("TORNEIO_" + torneio.to_upper())
	for i in (t["rivais"] as Array).size():
		var rid: String = t["rivais"][i]
		var r: Dictionary = dados["rivais"][rid]
		var linha := HBoxContainer.new()
		var nome := Label.new()
		var marca := ""
		if r.get("campeao", false):
			marca = "  " + tr("PVE_CAMPEAO")
		elif r.get("nemesis", false):
			marca = "  " + tr("PVE_NEMESIS")
		var e := int(p["estrelas"].get(str(i), 0))
		nome.text = "%d. %s%s  %s" % [i + 1, tr("RIVAL_" + rid.to_upper()), marca, "★".repeat(e) + "☆".repeat(3 - e)]
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_child(nome)
		var justar := Button.new()
		justar.focus_mode = Control.FOCUS_NONE
		justar.text = tr("VILA_JUSTAR")
		justar.disabled = not _jog.pode_disputar(torneio, i)["ok"]
		var idx := i
		justar.pressed.connect(func(): _justar(idx))
		linha.add_child(justar)
		var auto := Button.new()
		auto.focus_mode = Control.FOCUS_NONE
		auto.text = tr("PVE_AUTOMATICO")
		auto.disabled = not _jog.pode_automatico(torneio, i)["ok"]
		auto.pressed.connect(func(): automatico(idx))
		linha.add_child(auto)
		if r.get("campeao", false) and _jog.trofeus().any(func(tf): return tf["campeao"] == rid):
			var rev := Button.new()
			rev.name = "Revanche"
			rev.focus_mode = Control.FOCUS_NONE
			var pr := _jog.pode_revanche(rid)
			rev.text = tr("TROFEU_REVANCHE") if pr["ok"] else tr("TROFEU_REVANCHE_AMANHA")
			rev.disabled = not pr["ok"]
			rev.pressed.connect(func(): revanche(rid))
			linha.add_child(rev)
		_lista.add_child(linha)
	var info: Array[String] = [tr("PVE_RECOMPENSA_TORNEIO").format({"ouro": int(t["recompensa"]["ouro"]), "xp": int(t["recompensa"]["xp"])})]
	for d: String in _jog.desafios_do_torneio(torneio):
		info.append(tr("DESAFIO_" + d.to_upper()))
	_info.text = "  ·  ".join(info)

func _trocar_regiao(passo: int) -> void:
	var abertas := _jog.regioes_liberadas()
	regiao = abertas[clampi(abertas.find(regiao) + passo, 0, abertas.size() - 1)]
	montar()

## Justar: a ficha do adversário antes (pela vila); sem vila, direto.
func _justar(indice: int) -> void:
	if pedir_justa.get_connections().is_empty():
		justar_direto(indice)
	else:
		pedir_justa.emit(torneio, indice)

## Abre a arena (com o servidor ligado, pede a semente antes; sem rede, avisa).
func justar_direto(indice: int) -> void:
	var r: Dictionary = await (get_node("/root/Fluxo") as FluxoTelas).justar(torneio, indice)
	if not r["ok"]:
		_info.text = tr("ERRO_" + str(r["erro"]).to_upper())

## Revanche heroica contra o campeão (a ficha antes, pela vila).
func revanche(campeao: String) -> void:
	if pedir_revanche.get_connections().is_empty():
		revanche_direto(campeao)
	else:
		pedir_revanche.emit(campeao)

func revanche_direto(campeao: String) -> void:
	var r: Dictionary = await (get_node("/root/Fluxo") as FluxoTelas).justar_revanche(campeao)
	if not r["ok"]:
		_info.text = tr("ERRO_" + str(r["erro"]).to_upper())

## Disputa no automático (mesma regra, IA de precisão média pelo jogador).
## Com o servidor ligado, ele sorteia a semente e decide; aqui só mostra.
func automatico(indice: int) -> void:
	var nuvem := get_node_or_null("/root/Nuvem") as ServicoNuvem
	var r: Dictionary
	if nuvem and nuvem.usa_acao():
		r = await nuvem.chamar("disputa_automatica", [torneio, indice])
	else:
		r = _jog.disputa_automatica(torneio, indice, randi())
	if not r["ok"]:
		_info.text = tr("ERRO_" + str(r["erro"]).to_upper())
		return
	if r["venceu"]:
		_info.text = tr("PVE_AUTO_VENCEU").format({"estrelas": r["estrelas"], "ouro": r["ouro"], "xp": r["xp"]})
	else:
		_info.text = tr("PVE_AUTO_PERDEU")

func _estrelas_total(t: String) -> String:
	var p := _jog.progresso_torneio(t)
	var soma := 0
	for k: String in p["estrelas"]:
		soma += int(p["estrelas"][k])
	var maximo: int = (_jog.pve()["torneios"][t]["rivais"] as Array).size() * 3
	return "★ %d/%d" % [soma, maximo]
