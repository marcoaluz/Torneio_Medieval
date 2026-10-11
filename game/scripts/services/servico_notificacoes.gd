class_name ServicoNotificacoes
extends Node
## Notificações (autoload "Notificacoes"; GDD: sempre opcionais e
## configuráveis; Pacote 2.7 e 3.23). Tipos em game/data/notificacoes.json:
## treino, cavalo descansado, baú aberto, forja/forno, conserto, obra da vila
## (locais) e ajuda da ordem, temporada terminando (push pelo servidor).
##   - Com o jogo aberto: emite `pronto(aviso)` quando algo termina (a vila
##     mostra o aviso). aviso = o timer, ou {tipo: "bau", id}.
##   - Com o jogo indo para segundo plano: agenda as notificações locais do
##     sistema para os horários de término. O Godot não tem notificação local
##     nativa no Android; isso precisa de um plugin (ver docs/ANDROID.md).
##     Sem plugin, só guarda a lista (`agendadas`) e não faz nada.
##   - Cada tipo pode ser desligado (Jogador.definir_notificacao); a chave
##     "todas" desliga tudo. Os tipos do servidor só valem com push (NUVEM.md).
## Textos: NOTIF_<TIPO> em textos.csv.

signal pronto(aviso: Dictionary)

const DADOS := "res://game/data/notificacoes.json"

## [{id, quando (Unix), chave_texto, tipo}], refeita a cada mudança nos dados.
var agendadas: Array = []

var _jog: ServicoJogador
var _cfg: Dictionary
var _avisados := {}
var _acumulado := 0.0
var _plugin: Object

func _ready() -> void:
	_cfg = Balanceamento.ler_json(DADOS)
	_jog = get_node_or_null("/root/Jogador")
	if _jog:
		_jog.mudou.connect(func(_s): reagendar())
	# Nome do singleton do plugin de notificação local, quando instalado.
	for nome in ["LocalNotification", "GodotAndroidNotification"]:
		if Engine.has_singleton(nome):
			_plugin = Engine.get_singleton(nome)
	reagendar()

## Tipo de notificação de um tipo de timer ("" se nenhum).
func tipo_do_timer(tipo_timer: String) -> String:
	for t: String in _cfg["tipos"]:
		if (_cfg["tipos"][t]["timers"] as Array).has(tipo_timer):
			return t
	return ""

func ligada(tipo: String) -> bool:
	return _jog == null or _jog.notificacao_ligada(tipo)

func reagendar() -> void:
	agendadas.clear()
	if _jog == null:
		return
	for t: Dictionary in _jog.timers():
		var tipo := tipo_do_timer(str(t["tipo"]))
		if tipo != "" and ligada(tipo) and not ServicoTempo.pronto(int(t["termina_em"])):
			agendadas.append({"id": t["id"], "quando": int(t["termina_em"]), "chave_texto": "NOTIF_" + str(t["tipo"]).to_upper(), "tipo": tipo})
	if ligada("cavalo_descansado") and not _jog.cavalo_ativo().is_empty() and _jog.cavalo_cansado():
		agendadas.append({"id": "descanso", "quando": _jog.descansado_em(), "chave_texto": "NOTIF_CAVALO_DESCANSADO", "tipo": "cavalo_descansado"})
	var b := _jog.bau_abrindo()
	if ligada("bau") and not b.is_empty() and not ServicoTempo.pronto(int(b["abre_em"])):
		agendadas.append({"id": b["id"], "quando": int(b["abre_em"]), "chave_texto": "NOTIF_BAU", "tipo": "bau"})

func _process(delta: float) -> void:
	_acumulado += delta
	if _acumulado < 1.0 or _jog == null:
		return
	_acumulado = 0.0
	for t: Dictionary in _jog.timers():
		if ServicoTempo.pronto(int(t["termina_em"])) and not _avisados.has(t["id"]):
			_avisados[t["id"]] = true
			if ligada(tipo_do_timer(str(t["tipo"]))):
				pronto.emit(t)
	var b := _jog.bau_abrindo()
	if not b.is_empty() and ServicoTempo.pronto(int(b["abre_em"])) and not _avisados.has(b["id"]):
		_avisados[b["id"]] = true
		if ligada("bau"):
			pronto.emit({"tipo": "bau", "id": b["id"]})

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_enviar_para_o_sistema()

func _enviar_para_o_sistema() -> void:
	if _plugin == null or not ligada("todas"):
		return
	var agora := ServicoTempo.agora()
	for n: Dictionary in agendadas:
		var segundos := int(n["quando"]) - agora
		if segundos > 0 and _plugin.has_method("show"):
			_plugin.call("show", tr("JOGO_TITULO"), tr(n["chave_texto"]), segundos, hash(n["id"]))
