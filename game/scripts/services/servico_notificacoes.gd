class_name ServicoNotificacoes
extends Node
## Notificações de timers (autoload "Notificacoes"): treino pronto, cavalo
## descansado, melhoria pronta (GDD: sempre opcionais e configuráveis).
##   - Com o jogo aberto: emite `pronto(timer)` quando um timer termina (a
##     vila mostra o aviso).
##   - Com o jogo indo para segundo plano: agenda as notificações locais do
##     sistema para os horários de término. O Godot não tem notificação local
##     nativa no Android; isso precisa de um plugin (ver docs/ANDROID.md).
##     Sem plugin, só guarda a lista (`agendadas`) e não faz nada.
## Textos: NOTIF_<TIPO> em textos.csv.

signal pronto(timer: Dictionary)

## Opção do jogador (tela de configurações, 3.23).
var ativas := true
## [{id, quando (Unix), chave_texto}], refeita a cada mudança nos dados.
var agendadas: Array = []

var _jog: ServicoJogador
var _avisados := {}
var _acumulado := 0.0
var _plugin: Object

func _ready() -> void:
	_jog = get_node_or_null("/root/Jogador")
	if _jog:
		_jog.mudou.connect(func(_s): reagendar())
	# Nome do singleton do plugin de notificação local, quando instalado.
	for nome in ["LocalNotification", "GodotAndroidNotification"]:
		if Engine.has_singleton(nome):
			_plugin = Engine.get_singleton(nome)
	reagendar()

func reagendar() -> void:
	agendadas.clear()
	if _jog == null:
		return
	for t: Dictionary in _jog.timers():
		if not ServicoTempo.pronto(int(t["termina_em"])):
			agendadas.append({"id": t["id"], "quando": int(t["termina_em"]), "chave_texto": "NOTIF_" + str(t["tipo"]).to_upper()})
	if not _jog.cavalo_ativo().is_empty() and _jog.cavalo_cansado():
		agendadas.append({"id": "descanso", "quando": _jog.descansado_em(), "chave_texto": "NOTIF_CAVALO_DESCANSADO"})

func _process(delta: float) -> void:
	_acumulado += delta
	if _acumulado < 1.0 or _jog == null:
		return
	_acumulado = 0.0
	for t: Dictionary in _jog.timers():
		if ServicoTempo.pronto(int(t["termina_em"])) and not _avisados.has(t["id"]):
			_avisados[t["id"]] = true
			pronto.emit(t)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_enviar_para_o_sistema()

func _enviar_para_o_sistema() -> void:
	if not ativas or _plugin == null:
		return
	var agora := ServicoTempo.agora()
	for n: Dictionary in agendadas:
		var segundos := int(n["quando"]) - agora
		if segundos > 0 and _plugin.has_method("show"):
			_plugin.call("show", tr("JOGO_TITULO"), tr(n["chave_texto"]), segundos, hash(n["id"]))
