class_name Vila
extends Node2D
## Tela principal: a vila vista de cima, sem andar livre (Pacote 2.5, GDD A
## vila). Tocar num prédio abre a tela dele (por enquanto um painel comum com
## nível, estado e melhoria; cada prédio ganha a tela própria nos prompts
## seguintes). Prédio com algo pronto: tocar conclui. Prédio bloqueado mostra
## o nível que libera. Tudo que muda dados passa pelo serviço Jogador.

signal abrir_justa

const CENA_PREDIO := preload("res://game/scenes/village/predio_vila.tscn")

var predios := {}  ## nome -> PredioVila
var aberto := ""   ## prédio com o painel aberto

var _jog: ServicoJogador
@onready var vida: VidaVila = $Vida
@onready var ambiente: AmbienteVila = $Ambiente
var _acumulado := 0.0

@onready var _topo_nome: Label = $Interface/Topo/Linha/Nome
@onready var _topo_ouro: Label = $Interface/Topo/Linha/Ouro
@onready var _painel: PanelContainer = $Interface/Painel
@onready var _titulo: Label = $Interface/Painel/Coluna/Titulo
@onready var _nivel: Label = $Interface/Painel/Coluna/Nivel
@onready var _estado: Label = $Interface/Painel/Coluna/Estado
@onready var _melhorar: Button = $Interface/Painel/Coluna/Botoes/Melhorar
@onready var _acao: Button = $Interface/Painel/Coluna/Botoes/Acao
@onready var _fechar: Button = $Interface/Painel/Coluna/Botoes/Fechar
@onready var _letreiro: Label = $Interface/Letreiro
@onready var tela_treino: TelaTreino = $Interface/TelaTreino
@onready var tela_perfil: TelaPerfil = $Interface/TelaPerfil
## Tela de Equipamentos criada só na primeira vez que é usada (3.25: os
## retratos grandes custavam ~80 ms na abertura da vila).
const CENA_EQUIPAMENTOS := preload("res://game/scenes/ui/tela_equipamentos.tscn")
var _tela_equipamentos: TelaEquipamentos
var tela_equipamentos: TelaEquipamentos:
	get:
		if _tela_equipamentos == null:
			_tela_equipamentos = CENA_EQUIPAMENTOS.instantiate()
			_tela_equipamentos.visible = false
			$Interface.add_child(_tela_equipamentos)
			_som_da_tela(_tela_equipamentos)
			$Interface.move_child(_tela_equipamentos, $Interface/TelaTreino.get_index() + 1)
		return _tela_equipamentos
@onready var tela_torneios: TelaTorneios = $Interface/TelaTorneios
@onready var tela_baus: TelaBaus = $Interface/TelaBaus
@onready var tela_forja: TelaForja = $Interface/TelaForja
@onready var tela_habilidades: TelaHabilidades = $Interface/TelaHabilidades
@onready var tela_missoes: TelaMissoes = $Interface/TelaMissoes
@onready var _botao_missoes: Button = $Interface/Topo/Linha/Missoes
@onready var cena_historia: CenaHistoria = $Interface/CenaHistoria
@onready var tela_configuracoes: TelaConfiguracoes = $Interface/TelaConfiguracoes
@onready var tela_liga: TelaLiga = $Interface/TelaLiga
@onready var tela_loja: TelaLoja = $Interface/TelaLoja
@onready var tela_social: TelaSocial = $Interface/TelaSocial
@onready var _botao_social: Button = $Interface/Topo/Linha/Social
@onready var janela_oferta: JanelaOferta = $Interface/JanelaOferta
@onready var _botao_baus: Button = $Interface/Topo/Linha/Baus

## A vila é a cena principal do som: o que a cena anterior tocava para antes
## de os filhos (ambiente, chuva) pedirem o seu.
func _enter_tree() -> void:
	var audio := get_node_or_null("/root/Audio") as ServicoAudio
	if audio:
		audio.trocar_cena("vila")

func _ready() -> void:
	_jog = get_node("/root/Jogador")
	var audio := get_node_or_null("/root/Audio") as ServicoAudio
	if audio:
		audio.musica("tema_vila")
	var vila := Balanceamento.carregar("vila")
	for nome: String in vila["ordem"]:
		var p: PredioVila = CENA_PREDIO.instantiate()
		$Predios.add_child(p)
		p.configurar(nome, vila["predios"][nome])
		predios[nome] = p
	_painel.visible = false
	_letreiro.text = ""
	_melhorar.pressed.connect(func(): melhorar(aberto))
	_fechar.pressed.connect(fechar_painel)
	tela_perfil.melhorar_pedido.connect(func(r): if r["ok"]: _registrar_melhoria("casa_senhorial", r))
	_fechar.text = tr("PAINEL_FECHAR")
	_acao.pressed.connect(func(): fechar_painel(); tela_torneios.abrir(); abrir_justa.emit())
	_botao_baus.pressed.connect(func(): fechar_painel(); tela_baus.abrir())
	($Interface/Topo/Linha/Config as Button).text = tr("VILA_CONFIG")
	_botao_social.pressed.connect(func(): fechar_painel(); tela_social.abrir())
	($Interface/Topo/Linha/Config as Button).pressed.connect(func(): fechar_painel(); tela_configuracoes.abrir())
	_botao_missoes.pressed.connect(func(): fechar_painel(); tela_missoes.abrir("login" if _jog.login_hoje()["pode"] else "diarias"))
	tela_forja.abrir_equipamentos.connect(func(): tela_equipamentos.abrir())
	tela_treino.abrir_habilidades.connect(func(): tela_treino.fechar(); tela_habilidades.abrir())
	janela_oferta.ver.connect(func(_id): fechar_painel(); tela_loja.abrir("ofertas"))
	_icones_do_topo()
	_chao_com_arte()
	for t in $Interface.get_children():
		_som_da_tela(t)
	_jog.mudou.connect(func(_s): atualizar(); vida.atualizar())
	vida.configurar(self, _jog)
	cena_historia.terminou.connect(_ao_terminar_cena)
	tocar_historia.call_deferred()
	var notif := get_node_or_null("/root/Notificacoes") as ServicoNotificacoes
	if notif:
		notif.pronto.connect(func(t): mostrar_letreiro(tr("NOTIF_" + str(t["tipo"]).to_upper())))
	atualizar()

## Textos fixos (montados uma vez no _ready) refeitos quando o idioma muda com a
## vila aberta; o resto é refeito por atualizar().
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_fechar.text = tr("PAINEL_FECHAR")
		atualizar()

## Som das telas (GDD A vila > Som dos prédios): toda tela aberta por cima da
## vila avisa o Audio pela visibilidade, então qualquer caminho de abrir ou
## fechar (botão, outra tela, troca de prédio) para o ambiente e os efeitos da
## tela que saiu e devolve o da vila. O nome é o do prédio nas telas de prédio.
func _som_da_tela(t: Node) -> void:
	var audio := get_node_or_null("/root/Audio") as ServicoAudio
	if audio == null or not (t is Control) or not (str(t.name).begins_with("Tela") or t.name == "CenaHistoria"):
		return
	var aberta := {"nome": ""}
	(t as Control).visibility_changed.connect(func():
		if (t as Control).visible:
			aberta["nome"] = nome_da_tela_som(t)
			audio.entrar_tela(aberta["nome"])
		elif aberta["nome"] != "":
			audio.sair_tela(aberta["nome"])
			aberta["nome"] = "")
	if (t as Control).visible:
		aberta["nome"] = nome_da_tela_som(t)
		audio.entrar_tela(aberta["nome"])

## Nome da tela para o som: o prédio (treino, forja) ou o nó em snake_case.
static func nome_da_tela_som(t: Node) -> String:
	if t is TelaTreino or t is TelaForja:
		return str(t.get("predio"))
	return str(t.name).to_snake_case()

## Chão da vila com arte (ChaoVila); trilhas até a frente de cada prédio.
func _chao_com_arte() -> void:
	var chao := ChaoVila.new()
	chao.name = "Arte"
	$Chao.add_child(chao)
	$Chao.move_child(chao, 0)
	var destinos := []
	for p: PredioVila in $Predios.get_children():
		destinos.append(p.position + Vector2(0, p.tamanho.y * 0.45))
	if chao.montar(destinos):
		for f in $Chao.get_children():
			if f.is_in_group("provisorio"):
				f.visible = false
	else:
		chao.queue_free()

var _recursos := {}  ## ouro/gemas/renome -> Label do número (com ícone ao lado)

## Ícones da interface (tools/gerar_ui.py) no topo: ouro, gemas e renome com o
## número ao lado, e nos botões. Sem a arte, fica o texto de antes.
func _icones_do_topo() -> void:
	var tex_ouro := ArteUi.textura("icone_ouro")
	if tex_ouro == null:
		return
	var linha := _topo_ouro.get_parent()
	var caixa := HBoxContainer.new()
	caixa.name = "Recursos"
	caixa.add_theme_constant_override("separation", 4)
	linha.add_child(caixa)
	linha.move_child(caixa, _topo_ouro.get_index())
	_topo_ouro.visible = false
	for par in [["ouro", "icone_ouro", "VILA_OURO_DICA"], ["gemas", "icone_gema", "VILA_GEMAS_DICA"], ["renome", "icone_renome", "VILA_RENOME_DICA"]]:
		var ic := TextureRect.new()
		ic.texture = ArteUi.textura(par[1])
		ic.custom_minimum_size = Vector2(28, 28)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.tooltip_text = tr(par[2])
		caixa.add_child(ic)
		var l := Label.new()
		l.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
		l.custom_minimum_size.x = 44
		caixa.add_child(l)
		_recursos[par[0]] = l
	for b in [[_botao_missoes, "icone_missoes"], [_botao_social, "icone_ordem"], [_botao_baus, "icone_bau"],
			[$Interface/Topo/Linha/Config as Button, "icone_config"]]:
		var bt: Button = b[0]
		bt.icon = ArteUi.textura(b[1])
		bt.expand_icon = false
	($Interface/Topo/Linha/Config as Button).text = ""

## Atualiza prédios e topo a partir dos dados (e o painel aberto).
func atualizar() -> void:
	var cav := _jog.cavaleiro()
	_topo_nome.text = tr("VILA_TOPO").format({"nome": cav["nome"] if cav["nome"] != "" else "—",
		"nivel": cav["nivel"], "casa": _jog.casa()["nome"]})
	if _recursos.is_empty():
		_topo_ouro.text = tr("VILA_OURO").format({"ouro": _jog.ouro()}) + "  ·  " + tr("VILA_GEMAS").format({"gemas": _jog.gemas()}) \
			+ "  ·  " + tr("VILA_RENOME").format({"renome": _jog.renome()}) + ("  ·  VIP" if _jog.vip_ativo() else "")
	else:
		_recursos["ouro"].text = str(_jog.ouro())
		_recursos["gemas"].text = str(_jog.gemas())
		_recursos["renome"].text = str(_jog.renome()) + ("   VIP" if _jog.vip_ativo() else "")
	# Oferta nova (GDD: janela que fecha com um toque, sem bloquear).
	if not janela_oferta.visible and not cena_historia.visible:
		var of := _jog.oferta_nova()
		if not of.is_empty():
			janela_oferta.mostrar(of, tela_loja.texto_conteudo(of["conteudo"]))
	var m := _jog.missoes()
	var prontas: int = (m["diarias"] + m["semanais"]).filter(func(x): return x["pronta"]).size() + (1 if _jog.login_hoje()["pode"] else 0)
	_botao_missoes.text = tr("VILA_MISSOES") + (" !" if prontas > 0 else "")
	for c: String in _jog.conquistas_novas():
		mostrar_letreiro(tr("VILA_CONQUISTA").format({"conquista": tr("CONQUISTA_" + c.to_upper())}))
	_botao_social.text = tr("VILA_SOCIAL") + (" !" if _jog.social_alerta() else "")
	_jog.atualizar_ajudas()
	var prontos := _jog.baus().filter(func(b): return _jog.bau_pronto(b["id"])).size()
	_botao_baus.text = tr("VILA_BAUS").format({"n": _jog.baus().size(), "max": int(_jog.cfg_baus()["espacos"])}) + (" !" if prontos > 0 else "")
	for nome: String in predios:
		var p: PredioVila = predios[nome]
		p.bloqueado = not _jog.predio_liberado(nome)
		p.nivel = maxi(_jog.predio_nivel(nome), 1)
		if nome == "guilda":
			p.aplicar_brasao(_jog.brasao_da_ordem())  # {} sem ordem: estandarte some
		# Balão: o timer que termina primeiro; "!" se algum já terminou.
		var ts := _jog.timers_do_predio(nome)
		ts.sort_custom(func(a, b): return int(a["termina_em"]) < int(b["termina_em"]))
		p.pronto = not ts.is_empty() and ServicoTempo.pronto(int(ts[0]["termina_em"]))
		p.mostrar_timer("" if ts.is_empty() or p.pronto else formatar_tempo(ServicoTempo.restante(int(ts[0]["termina_em"]))))
	if aberto != "":
		_preencher_painel(aberto)

func _process(delta: float) -> void:
	_acumulado += delta
	if _acumulado >= 0.25:
		_acumulado = 0.0
		atualizar()

func _unhandled_input(event: InputEvent) -> void:
	if (_tela_equipamentos and _tela_equipamentos.visible) or tela_treino.visible or tela_torneios.visible:
		return
	if event is InputEventScreenTouch and event.pressed:
		var nome := predio_em(get_canvas_transform().affine_inverse() * event.position)
		if nome != "":
			tocar_predio(nome)
			get_viewport().set_input_as_handled()

## Prédio sob um ponto do mundo ("" se nenhum). O de baixo na tela ganha.
func predio_em(ponto: Vector2) -> String:
	var achado := ""
	var y := -INF
	for nome: String in predios:
		var p: PredioVila = predios[nome]
		if p.retangulo().has_point(ponto) and p.position.y > y:
			achado = nome
			y = p.position.y
	return achado

## Toca a próxima cena de história pendente (3.22), se houver.
func tocar_historia() -> void:
	var id := _jog.proxima_cena()
	if id != "" and not cena_historia.visible:
		fechar_painel()
		cena_historia.tocar(id)

## Ao terminar uma cena: avisa os companheiros que entraram e toca a próxima.
func _ao_terminar_cena(id: String) -> void:
	var h := _jog.cfg_historia()
	for c: String in h["companheiros"]:
		if h["companheiros"][c]["entra_na_cena"] == id:
			mostrar_letreiro(tr("VILA_COMPANHEIRO_ENTROU").format({"nome": tr(h["personagens"][c]["nome"])}))
	tocar_historia()

func tocar_predio(nome: String) -> void:
	if not _jog.predio_liberado(nome):
		var nivel := int(Balanceamento.carregar("vila")["predios"][nome]["libera_nivel"])
		mostrar_letreiro(tr("VILA_BLOQUEADO").format({"predio": tr("PREDIO_" + nome.to_upper()), "nivel": nivel}))
		return
	var t := _jog.timer_do_predio(nome, "melhoria")
	if not t.is_empty() and ServicoTempo.pronto(int(t["termina_em"])):
		if _jog.concluir_timer(t["id"])["ok"]:
			mostrar_letreiro(tr("VILA_MELHORIA_PRONTA").format({"predio": tr("PREDIO_" + nome.to_upper()), "nivel": t["nivel_novo"]}))
		return
	if nome in ["armeiro", "ferreiro"]:
		fechar_painel()
		tela_forja.abrir(nome)
		return
	if nome == "casa_senhorial":
		fechar_painel()
		tela_perfil.abrir()
		return
	if nome == "salao_liga":
		fechar_painel()
		tela_liga.abrir()
		return
	if nome == "guilda":
		fechar_painel()
		tela_social.abrir("ordem")
		return
	if nome == "loja":
		fechar_painel()
		tela_loja.abrir()
		return
	if nome in ["campo_treino", "estabulo"]:
		fechar_painel()
		tela_treino.abrir(nome)
		return
	abrir_painel(nome)

func abrir_painel(nome: String) -> void:
	aberto = nome
	_preencher_painel(nome)
	_painel.visible = true

func fechar_painel() -> void:
	aberto = ""
	_painel.visible = false

func melhorar(nome: String) -> void:
	var r := _jog.melhorar_predio(nome)
	if not r["ok"]:
		mostrar_letreiro(tr("ERRO_" + str(r["erro"]).to_upper()))
		return
	_registrar_melhoria(nome, r)

func _registrar_melhoria(nome: String, r: Dictionary) -> void:
	var m := get_node_or_null("/root/Metricas") as ServicoMetricas
	if m:
		m.registrar("predio_melhorado", {"predio": nome, "para_nivel": _jog.predio_nivel(nome) + 1, "ouro": r.get("ouro", 0)})

func _preencher_painel(nome: String) -> void:
	_titulo.text = tr("PREDIO_" + nome.to_upper())
	_nivel.text = tr("VILA_NIVEL").format({"nivel": _jog.predio_nivel(nome), "teto": _jog.teto_predio(nome)})
	var t := _jog.timer_do_predio(nome, "melhoria")
	var p := _jog.pode_melhorar(nome)
	if not t.is_empty():
		_estado.text = tr("VILA_EM_OBRA").format({"tempo": formatar_tempo(ServicoTempo.restante(int(t["termina_em"])))})
	else:
		_estado.text = tr("PREDIO_DESC_" + nome.to_upper())
	_melhorar.disabled = not p["ok"]
	if p.has("ouro"):
		_melhorar.text = tr("VILA_MELHORAR").format({"ouro": p["ouro"], "tempo": formatar_tempo(_jog.duracao_timer(int(p["segundos"])))})
	else:
		_melhorar.text = tr("ERRO_" + str(p["erro"]).to_upper())
	_acao.visible = nome == "arena"
	_acao.text = tr("VILA_JUSTAR")

func mostrar_letreiro(texto: String) -> void:
	_letreiro.text = texto
	get_tree().create_timer(2.0).timeout.connect(func(): if _letreiro.text == texto: _letreiro.text = "")

## "45 s", "3:07", "1 h 05 min" conforme o tamanho (formatos em textos.csv).
static func formatar_tempo(segundos: int) -> String:
	if segundos < 60:
		return TranslationServer.translate("TEMPO_SEGUNDOS").format({"s": segundos})
	if segundos < 3600:
		return TranslationServer.translate("TEMPO_MINUTOS").format({"m": segundos / 60, "s": "%02d" % (segundos % 60)})
	return TranslationServer.translate("TEMPO_HORAS").format({"h": segundos / 3600, "m": "%02d" % ((segundos % 3600) / 60)})
