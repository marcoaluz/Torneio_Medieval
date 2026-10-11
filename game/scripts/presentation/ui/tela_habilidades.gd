class_name TelaHabilidades
extends PanelContainer
## Habilidades especiais e conjuntos (Pacote 3.16, GDD Habilidades especiais
## e Conjuntos), aberta pelo campo de treino. Mostra os espaços (o segundo
## abre por nível ou liga), as habilidades conhecidas com grupo, ciclo e
## efeito (tirados de impacto.json), e o progresso de cada conjunto (2 peças
## dão bônus; completo libera a habilidade). Usar uma habilidade troca a do
## mesmo grupo. Tudo pelo serviço Jogador.

var _jog: ServicoJogador

@onready var _titulo: Label = $Coluna/Titulo
@onready var _info: Label = $Coluna/Info
@onready var _lista: VBoxContainer = $Coluna/Rolagem/Lista
@onready var _erro: Label = $Coluna/Erro
@onready var _fechar: Button = $Coluna/Fechar

func _ready() -> void:
	_jog = get_node("/root/Jogador")
	visible = false
	_titulo.text = tr("HABS_TITULO")
	_fechar.text = tr("PAINEL_FECHAR")
	_fechar.pressed.connect(func(): visible = false)
	_jog.mudou.connect(func(_s): if visible: montar())

func abrir() -> void:
	_erro.text = ""
	visible = true
	montar()

func montar() -> void:
	for c in _lista.get_children():
		c.queue_free()
	var cfg: Dictionary = Balanceamento.carregar("progressao")["habilidades"]
	var em_uso := _jog.habilidades_em_uso()
	_info.text = tr("HABS_ESPACOS").format({"usados": em_uso.size(), "espacos": _jog.espacos_habilidade(),
		"nivel": int(cfg["segundo_espaco_nivel"]), "liga": tr("LIGA_" + str(cfg["segundo_espaco_liga"]).to_upper())})
	var defs: Dictionary = Balanceamento.carregar("impacto")["habilidades"]
	for h: String in _jog.habilidades_conhecidas():
		var linha := HBoxContainer.new()
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 12)
		l.text = "%s · %s\n%s" % [tr("HABILIDADE_" + h.to_upper()), tr("HABS_GRUPO_" + str(defs[h]["grupo"]).to_upper()), descricao(h)]
		if em_uso.has(h):
			l.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
		linha.add_child(l)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = tr("HABS_TIRAR") if em_uso.has(h) else tr("HABS_USAR")
		b.pressed.connect(func(): alternar(h))
		linha.add_child(b)
		_lista.add_child(linha)
	var t := Label.new()
	t.text = tr("HABS_CONJUNTOS")
	t.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
	_lista.add_child(t)
	var ef := _jog.efeito_conjuntos()
	var conjs: Dictionary = Balanceamento.carregar("itens")["conjuntos"]
	for c: String in conjs:
		if c.begins_with("_"):
			continue
		var bonus: Array[String] = []
		for k: String in conjs[c].get("bonus_2", {}):
			bonus.append("+%d %s" % [int(conjs[c]["bonus_2"][k]), tr("ATRIBUTO_" + k.to_upper())])
		var hab := str(conjs[c].get("habilidade", ""))
		var lc := Label.new()
		lc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lc.add_theme_font_size_override("font_size", 12)
		lc.text = tr("HABS_CONJUNTO_LINHA").format({"conjunto": tr("CONJUNTO_" + c.to_upper()), "n": int(ef["contagem"].get(c, 0)),
			"total": int(ef["total"].get(c, 0)), "bonus": ", ".join(bonus), "habilidade": tr("HABILIDADE_" + hab.to_upper()) if hab != "" else "—"})
		_lista.add_child(lc)

## Efeito em texto, tirado dos dados (ciclo, derrubada, dano, bloqueio).
func descricao(h: String) -> String:
	var d: Dictionary = Balanceamento.carregar("impacto")["habilidades"][h]
	var partes: Array[String] = [tr("HABS_FAMILIA").format({"vence": tr("HABILIDADE_" + str(d["vence"]).to_upper())})]
	if int(d["derrubada_bonus_milesimos"]) > 0:
		partes.append(tr("HABS_EFEITO_DERRUBADA").format({"v": int(d["derrubada_bonus_milesimos"]) / 10}))
	if int(d["dano_bonus_pct"]) > 0:
		partes.append(tr("HABS_EFEITO_DANO").format({"v": int(d["dano_bonus_pct"])}))
	if int(d["bloqueio_milesimos"]) > 0:
		partes.append(tr("HABS_EFEITO_BLOQUEIO").format({"v": int(d["bloqueio_milesimos"]) / 10}))
	return " · ".join(partes)

## Usa ou tira: usar troca a do mesmo grupo; sem espaço, sai a mais antiga.
func alternar(h: String) -> void:
	var defs: Dictionary = Balanceamento.carregar("impacto")["habilidades"]
	var lista := _jog.habilidades_em_uso()
	if lista.has(h):
		lista.erase(h)
	else:
		lista = lista.filter(func(x): return defs[x]["grupo"] != defs[h]["grupo"])
		lista.append(h)
		while lista.size() > _jog.espacos_habilidade():
			lista.pop_front()
	var r := _jog.equipar_habilidades(lista)
	_erro.text = "" if r["ok"] else tr("ERRO_" + str(r["erro"]).to_upper())
	montar()
