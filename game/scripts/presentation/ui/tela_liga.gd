class_name TelaLiga
extends PanelContainer
## Salão da liga (Pacote 3.17, GDD PvP, ligas e temporadas). Abas:
##   Liga: liga, divisão e pontos; procurar adversário (mostra o cavaleiro
##     dele antes da justa) e justar; últimas partidas.
##   Defesa: a configuração de defesa (equipamento, cavalo e habilidades
##     salvos) e o histórico de defesas.
##   Ranking: jogadores e ordens. Temporada: tempo e recompensas por liga.
##   Campeonato: chave de fim de semana.
## Até o servidor, adversários, defesas, ranking e campeonato são simulados
## (a tela avisa). Tudo pelo serviço Jogador. Justar pede a ficha do
## adversário a quem hospeda a tela (a vila); sem ninguém ouvindo, vai direto.

## A vila mostra a ficha do adversário e, ao lutar, chama Fluxo.justar_pvp.
signal pedir_justa

var aba := "liga"
var ranking := "jogadores"
var _jog: ServicoJogador

@onready var _titulo: Label = $Coluna/Titulo
@onready var _info: Label = $Coluna/Info
@onready var _abas: HBoxContainer = $Coluna/Abas
@onready var _lista: VBoxContainer = $Coluna/Rolagem/Lista
@onready var _mensagem: Label = $Coluna/Mensagem
@onready var _fechar: Button = $Coluna/Fechar

func _ready() -> void:
	_jog = get_node("/root/Jogador")
	visible = false
	_fechar.pressed.connect(func(): visible = false)
	_jog.mudou.connect(func(_s): if visible: montar())

func abrir(qual := "liga") -> void:
	aba = qual
	visible = true
	var r := _jog.atualizar_liga()
	var msgs: Array[String] = []
	if not (r["temporada_fechada"] as Dictionary).is_empty():
		var f: Dictionary = r["temporada_fechada"]
		msgs.append(tr("LIGA_TEMPORADA_FECHOU").format({"n": f["temporada"], "liga": tr("LIGA_" + str(f["liga"]).to_upper()), "bau": tr("BAU_" + str(f["bau"]).to_upper())}))
	if int(r["defesas_novas"]) > 0:
		msgs.append(tr("LIGA_DEFESAS_NOVAS").format({"n": r["defesas_novas"]}))
	_mensagem.text = "  ".join(msgs)
	montar()

func montar() -> void:
	_titulo.text = tr("LIGA_TITULO")
	_fechar.text = tr("PAINEL_FECHAR")
	var pos := _jog.liga_atual()
	_info.text = tr("LIGA_POSICAO").format({"liga": tr("LIGA_" + str(pos["nome"]).to_upper()), "divisao": pos["divisao"], "pontos": pos["pontos"],
		"poder": _jog.poder_jogador()}) + ("" if int(pos["para_subir"]) < 0 else "  " + tr("LIGA_PARA_SUBIR").format({"n": pos["para_subir"]}))
	for c in _abas.get_children():
		c.queue_free()
	for a: String in ["liga", "defesa", "ranking", "temporada", "campeonato"]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = a == aba
		b.text = tr("LIGA_ABA_" + a.to_upper())
		b.pressed.connect(func(): aba = a; montar())
		_abas.add_child(b)
	for c in _lista.get_children():
		c.queue_free()
	match aba:
		"liga": _montar_liga()
		"defesa": _montar_defesa()
		"ranking": _montar_ranking()
		"temporada": _montar_temporada()
		"campeonato": _montar_campeonato()

func _montar_liga() -> void:
	var a := _jog.adversario()
	if a.is_empty():
		_botao(tr("LIGA_PROCURAR"), func(): _jog.procurar_adversario(); montar())
	else:
		_rotulo(tr("LIGA_ADVERSARIO").format({"nome": a["nome"], "poder": a["poder"], "pontos": a["pontos"]}) + "  " + tr("LIGA_SIMULADO"), true)
		var hab: Array = a["lado"]["habilidades"].map(func(h): return tr("HABILIDADE_" + str(h).to_upper()))
		_rotulo(tr("LIGA_ADVERSARIO_EQUIP").format({"raridade": tr("RARIDADE_" + str(a["raridade"]).to_upper()), "nivel": a["nivel_pecas"],
			"habilidades": ", ".join(hab)}))
		var linha := HBoxContainer.new()
		_lista.add_child(linha)
		var j := Button.new()
		j.focus_mode = Control.FOCUS_NONE
		j.text = tr("LIGA_JUSTAR")
		j.pressed.connect(_justar)
		linha.add_child(j)
		var o := Button.new()
		o.focus_mode = Control.FOCUS_NONE
		o.text = tr("LIGA_OUTRO")
		o.pressed.connect(func(): _jog.procurar_adversario(); montar())
		linha.add_child(o)
	_rotulo(tr("LIGA_PARTIDAS"), true)
	for p: Dictionary in (_jog.estado["liga"]["partidas"] as Array).slice(0, 6):
		_rotulo(tr("LIGA_PARTIDA_VENCEU" if p["venceu"] else "LIGA_PARTIDA_PERDEU").format({"nome": p["adversario"], "pontos": "%+d" % int(p["pontos"])}))

func _montar_defesa() -> void:
	var d := _jog.defesa()
	if d.is_empty():
		_rotulo(tr("LIGA_SEM_DEFESA"))
	else:
		var pecas: Array[String] = []
		for esp: String in d["equipamento"]:
			var it := _jog.item(d["equipamento"][esp])
			if not it.is_empty():
				pecas.append(tr("ITEM_" + str(it["modelo"]).to_upper()) + (" +%d" % int(it["nivel"]) if int(it.get("nivel", 0)) > 0 else ""))
		_rotulo(tr("LIGA_DEFESA_ATUAL").format({"pecas": ", ".join(pecas),
			"habilidades": ", ".join((d["habilidades"] as Array).map(func(h): return tr("HABILIDADE_" + str(h).to_upper())))}))
	_botao(tr("LIGA_SALVAR_DEFESA"), func(): _jog.salvar_defesa(); _mensagem.text = tr("LIGA_DEFESA_SALVA"); montar())
	_rotulo(tr("LIGA_HISTORICO_DEFESAS") + "  " + tr("LIGA_SIMULADO"), true)
	for x: Dictionary in _jog.estado["liga"]["defesas"]:
		_rotulo(tr("LIGA_DEFENDEU" if x["defendeu"] else "LIGA_NAO_DEFENDEU").format({"nome": x["atacante"], "pontos": "%+d" % int(x["pontos"])}))

func _montar_ranking() -> void:
	var linha := HBoxContainer.new()
	_lista.add_child(linha)
	for r: String in ["jogadores", "ordens"]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = r == ranking
		b.text = tr("LIGA_RANKING_" + r.to_upper())
		b.pressed.connect(func(): ranking = r; montar())
		linha.add_child(b)
	_rotulo(tr("LIGA_SIMULADO"))
	var lista := _jog.ranking_jogadores() if ranking == "jogadores" else _jog.ranking_ordens()
	for x: Dictionary in lista:
		var l := _rotulo("%d. %s — %d" % [int(x["posicao"]), x["nome"], int(x["pontos"])])
		if x.get("voce", false):
			l.add_theme_color_override("font_color", Color(1, 0.88, 0.55))

func _montar_temporada() -> void:
	var t := _jog.temporada()
	_rotulo(tr("LIGA_TEMPORADA").format({"n": t["numero"], "tempo": Vila.formatar_tempo(int(t["restante_s"]))}), true)
	var minha := str(_jog.liga_atual()["nome"])
	for r: Dictionary in t["recompensas"]:
		var l := _rotulo(tr("LIGA_RECOMPENSA_LINHA").format({"liga": tr("LIGA_" + str(r["liga"]).to_upper()), "bau": tr("BAU_" + str(r["bau"]).to_upper())}))
		if r["liga"] == minha:
			l.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
	_rotulo(tr("LIGA_REINICIO").format({"pct": int(_jog.cfg_ligas()["reinicio_pct"])}))

func _montar_campeonato() -> void:
	var c := _jog.campeonato()
	_rotulo(tr("LIGA_CAMPEONATO_ABERTO" if c["aberto"] else "LIGA_CAMPEONATO_FECHADO") + "  " + tr("LIGA_SIMULADO"), true)
	for i in (c["chave"] as Array).size() / 2:
		_rotulo("%s  ×  %s" % [c["chave"][i * 2], c["chave"][i * 2 + 1]])
	for i in (c["premios"] as Array).size():
		_rotulo(tr("LIGA_PREMIO_RODADA").format({"n": i + 1, "premio": _texto_premio(c["premios"][i])}))
	if c["eliminado"]:
		_rotulo(tr("LIGA_ELIMINADO"))
	elif int(c["rodada"]) >= int(c["rodadas"]):
		_rotulo(tr("LIGA_CAMPEAO_DO_FIM_DE_SEMANA"))
	else:
		var b := _botao(tr("LIGA_JOGAR_RODADA").format({"n": int(c["rodada"]) + 1}), func():
			var r := _jog.jogar_campeonato()
			if r["ok"]:
				_justar()
			else:
				_mensagem.text = tr("ERRO_" + str(r["erro"]).to_upper()))
		b.disabled = not c["aberto"]

## Justar no PvP: a ficha do adversário antes (pela vila); sem vila, direto.
func _justar() -> void:
	if pedir_justa.get_connections().is_empty():
		(get_node("/root/Fluxo") as FluxoTelas).justar_pvp()
	else:
		pedir_justa.emit()

func _texto_premio(p: Dictionary) -> String:
	var partes: Array[String] = []
	if p.has("ouro"):
		partes.append("+%d %s" % [int(p["ouro"]), tr("MATERIAL_OURO_MOEDAS")])
	if p.has("bau"):
		partes.append(tr("BAU_" + str(p["bau"]).to_upper()))
	return ", ".join(partes)

func _rotulo(texto: String, destaque := false) -> Label:
	var l := Label.new()
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if destaque:
		l.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
	_lista.add_child(l)
	return l

func _botao(texto: String, acao: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = texto
	b.pressed.connect(acao)
	_lista.add_child(b)
	return b
