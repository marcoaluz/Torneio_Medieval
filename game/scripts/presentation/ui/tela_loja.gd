class_name TelaLoja
extends PanelContainer
## Loja (Pacote 3.18, GDD Monetização): abas Ofertas, Gemas, VIP, Passe
## (trilha grátis e premium lado a lado), Cosméticos e Materiais (limite por
## dia). Compras com dinheiro usam o provedor de TESTE até a 3.7 (a tela
## avisa); compras com gemas valem de verdade. Tudo pelo serviço Jogador.

var aba := "ofertas"
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

func abrir(qual := "") -> void:
	aba = qual if qual != "" else ("ofertas" if not _jog.ofertas().is_empty() else "gemas")
	_mensagem.text = ""
	visible = true
	montar()

func montar() -> void:
	_titulo.text = tr("LOJA_TITULO")
	_fechar.text = tr("PAINEL_FECHAR")
	_info.text = tr("LOJA_INFO").format({"gemas": _jog.gemas()}) + ("  " + tr("LOJA_VIP_ATE").format({"tempo": Vila.formatar_tempo(int(_jog.estado["loja"]["vip_ate"]) - ServicoTempo.agora())}) if _jog.vip_ativo() else "") \
		+ ("  " + tr("LOJA_TESTE") if _jog.loja_de_teste() else "")
	for c in _abas.get_children():
		c.queue_free()
	for a: String in ["ofertas", "gemas", "vip", "passe", "cosmeticos", "materiais"]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = a == aba
		b.text = tr("LOJA_ABA_" + a.to_upper())
		b.pressed.connect(func(): aba = a; montar())
		_abas.add_child(b)
	for c in _lista.get_children():
		c.queue_free()
	var cfg := _jog.cfg_loja()
	match aba:
		"ofertas":
			var os := _jog.ofertas()
			if os.is_empty():
				_rotulo(tr("LOJA_SEM_OFERTAS"))
			for o: Dictionary in os:
				_linha(tr("OFERTA_" + str(o["id"]).to_upper()) + "\n" + texto_conteudo(o["conteudo"]) + "  ·  " + tr("LOJA_ACABA_EM").format({"tempo": Vila.formatar_tempo(int(o["ate"]) - ServicoTempo.agora())}),
					o["preco"], func(): _resposta(_jog.comprar(o["id"])))
		"gemas":
			for g: Dictionary in cfg["gemas"]:
				_linha(tr("LOJA_GEMAS").format({"n": int(g["gemas"])}), g["preco"], func(): _resposta(_jog.comprar(g["id"])))
		"vip":
			var v: Dictionary = Balanceamento.ler("economia")["vip"]
			_rotulo(tr("LOJA_VIP_BENEFICIOS").format({"timer": int(v["timer_reducao_pct"]), "folego": int(v["folego_recuperacao_extra_pct"]), "gemas": int(v["gemas_mes"])}))
			_linha(tr("LOJA_VIP"), cfg["vip"]["preco"], func(): _resposta(_jog.comprar(cfg["vip"]["id"])))
		"passe":
			_montar_passe()
		"cosmeticos":
			var lj: Dictionary = _jog.estado["loja"]
			for c: Dictionary in cfg["cosmeticos"]:
				var tem: bool = (lj["cosmeticos"] as Array).has(c["id"])
				var em_uso: bool = lj["frase"] == c["id"] or lj["vitoria"] == c["id"]
				var nome := tr("COSMETICO_" + str(c["id"]).to_upper())
				if tem:
					_linha(nome, tr("LOJA_EM_USO") if em_uso else tr("LOJA_USAR"), func(): _resposta(_jog.usar_cosmetico("" if em_uso else c["id"])))
				else:
					_linha(nome, tr("LOJA_PRECO_GEMAS").format({"n": int(c["gemas"])}), func(): _resposta(_jog.comprar_com_gemas(c["id"])))
		"materiais":
			for m: Dictionary in cfg["materiais"]:
				var resta := _jog.compras_restantes_hoje(m["material"])
				var b := _linha("%d %s  ·  %s" % [int(m["quantidade"]), tr("MATERIAL_" + str(m["material"]).to_upper()), tr("LOJA_RESTAM_HOJE").format({"n": resta})],
					tr("LOJA_PRECO_GEMAS").format({"n": int(m["gemas"])}), func(): _resposta(_jog.comprar_com_gemas(m["material"])))
				b.disabled = resta <= 0

func _montar_passe() -> void:
	var p := _jog.passe()
	_rotulo(tr("LOJA_PASSE_INFO").format({"temporada": p["temporada"], "nivel": p["nivel"], "niveis": p["niveis"],
		"xp": int(p["xp"]) % int(p["xp_nivel"]), "xp_nivel": p["xp_nivel"]}), true)
	if not p["premium"]:
		_linha(tr("LOJA_PASSE_PREMIUM"), _jog.cfg_loja()["passe"]["preco"], func(): _resposta(_jog.comprar(_jog.cfg_loja()["passe"]["id"])))
	for n in range(1, int(p["niveis"]) + 1):
		var rec := _jog.recompensa_passe(n)
		var linha := HBoxContainer.new()
		var l := Label.new()
		l.text = "%d" % n
		l.custom_minimum_size = Vector2(28, 0)
		linha.add_child(l)
		for trilha: String in ["gratis", "premium"]:
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.clip_text = true
			var feito: bool = (p["gratis"] if trilha == "gratis" else p["premium_resgatados"]).has(n)
			b.text = ("✓ " if feito else "") + texto_conteudo(rec[trilha])
			b.disabled = feito or n > int(p["nivel"]) or (trilha == "premium" and not p["premium"])
			var nn := n
			b.pressed.connect(func(): _resposta(_jog.resgatar_passe(nn, trilha)))
			linha.add_child(b)
		_lista.add_child(linha)

## Conteúdo em texto ("+100 gemas, Baú de ferro, 10 lingotes...").
func texto_conteudo(c: Dictionary) -> String:
	var partes: Array[String] = []
	for k: String in c:
		match k:
			"gemas": partes.append(tr("LOJA_GEMAS").format({"n": int(c[k])}))
			"ouro": partes.append("+%d %s" % [int(c[k]), tr("MATERIAL_OURO_MOEDAS")])
			"bau": partes.append(tr("BAU_" + str(c[k]).to_upper()))
			"projeto": partes.append(tr("LOJA_PROJETO"))
			_: partes.append("+%d %s" % [int(c[k]), tr("MATERIAL_" + k.to_upper())])
	return ", ".join(partes)

func _linha(texto: String, botao: String, acao: Callable) -> Button:
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
	b.pressed.connect(acao)
	linha.add_child(b)
	_lista.add_child(linha)
	return b

func _rotulo(texto: String, destaque := false) -> void:
	var l := Label.new()
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 12)
	if destaque:
		l.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
	_lista.add_child(l)

func _resposta(r: Dictionary) -> void:
	_mensagem.text = tr("LOJA_FEITO") if r["ok"] else tr("ERRO_" + str(r["erro"]).to_upper())
	montar()
