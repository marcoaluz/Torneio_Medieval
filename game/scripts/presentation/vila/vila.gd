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
@onready var tela_equipamentos: TelaEquipamentos = $Interface/TelaEquipamentos
@onready var tela_torneios: TelaTorneios = $Interface/TelaTorneios
@onready var tela_baus: TelaBaus = $Interface/TelaBaus
@onready var _botao_baus: Button = $Interface/Topo/Linha/Baus

func _ready() -> void:
	_jog = get_node("/root/Jogador")
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
	_fechar.text = tr("PAINEL_FECHAR")
	_acao.pressed.connect(func(): fechar_painel(); tela_torneios.abrir(); abrir_justa.emit())
	_botao_baus.pressed.connect(func(): fechar_painel(); tela_baus.abrir())
	_jog.mudou.connect(func(_s): atualizar(); vida.atualizar())
	vida.configurar(self, _jog)
	var notif := get_node_or_null("/root/Notificacoes") as ServicoNotificacoes
	if notif:
		notif.pronto.connect(func(t): mostrar_letreiro(tr("NOTIF_" + str(t["tipo"]).to_upper())))
	atualizar()

## Atualiza prédios e topo a partir dos dados (e o painel aberto).
func atualizar() -> void:
	var cav := _jog.cavaleiro()
	_topo_nome.text = tr("VILA_TOPO").format({"nome": cav["nome"] if cav["nome"] != "" else "—",
		"nivel": cav["nivel"], "casa": _jog.casa()["nome"]})
	_topo_ouro.text = tr("VILA_OURO").format({"ouro": _jog.ouro()})
	var prontos := _jog.baus().filter(func(b): return _jog.bau_pronto(b["id"])).size()
	_botao_baus.text = tr("VILA_BAUS").format({"n": _jog.baus().size(), "max": int(_jog.cfg_baus()["espacos"])}) + (" !" if prontos > 0 else "")
	for nome: String in predios:
		var p: PredioVila = predios[nome]
		p.bloqueado = not _jog.predio_liberado(nome)
		p.nivel = maxi(_jog.predio_nivel(nome), 1)
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
	if tela_equipamentos.visible or tela_treino.visible or tela_torneios.visible:
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
	if nome == "armeiro":
		fechar_painel()
		tela_equipamentos.abrir()
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
