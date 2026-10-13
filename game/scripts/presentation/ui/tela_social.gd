class_name TelaSocial
extends PanelContainer
## Telas sociais (Pacote 3.20, GDD Funções sociais). Abas:
##   Ordem: criar ou entrar numa ordem; com ordem, subabas Membros (cargos),
##     Ajuda (pedir nos seus timers e ajudar os outros), Doações, Torneio
##     semanal, Loja da ordem e Gerir (brasão, nome, sair, dissolver).
##   Chat: ordem e global, mensagens rápidas, texto livre filtrado, denunciar
##     e bloquear.
##   Amigos: seu código, adicionar por código, lista e bloqueados.
##   Perfil: o seu ou o de outro jogador (cavaleiro, cavalo, brasão, liga e
##     títulos).
## Até o servidor (3.8) ordens, membros, pedidos, chat e rivais do torneio são
## SIMULADOS (a tela avisa). Tudo que muda passa pelo serviço Jogador.

const CENA_BRASAO := preload("res://game/scenes/ui/editor_brasao.tscn")
const ABAS := ["ordem", "chat", "amigos", "perfil"]
const SUBABAS := ["membros", "ajuda", "doacoes", "torneio", "loja", "gerir"]
const COR_DESTAQUE := Color(1, 0.88, 0.55)
const MENSAGENS_NA_TELA := 12

var aba := "ordem"
var sub := "membros"
var canal := "ordem"
var perfil_id := "voce"

var _jog: ServicoJogador
var _confirmar := ""
var _denunciando := {}
var _entrada_acao := Callable()
var _entrada_dono := ""
var _editor: Control
var _relogio := 0.0

@onready var _titulo: Label = $Coluna/Titulo
@onready var _info: Label = $Coluna/Info
@onready var _abas: HBoxContainer = $Coluna/Abas
@onready var _subabas: HBoxContainer = $Coluna/SubAbas
@onready var _lista: VBoxContainer = $Coluna/Rolagem/Lista
@onready var _mensagem: Label = $Coluna/Mensagem
@onready var _entrada: HBoxContainer = $Coluna/Entrada
@onready var _campo: LineEdit = $Coluna/Entrada/Campo
@onready var _acao: Button = $Coluna/Entrada/Acao
@onready var _fechar: Button = $Coluna/Fechar

func _ready() -> void:
	_jog = get_node("/root/Jogador")
	visible = false
	_fechar.pressed.connect(fechar)
	_acao.pressed.connect(_enviar_entrada)
	_campo.text_submitted.connect(func(_t): _enviar_entrada())
	_jog.mudou.connect(func(_s): if visible and _editor == null: montar())

func abrir(qual := "ordem", id := "") -> void:
	aba = qual
	if id != "":
		perfil_id = id
	visible = true
	_mensagem.text = ""
	_confirmar = ""
	_jog.atualizar_ajudas()
	_jog.chat_atualizar()
	montar()

func fechar() -> void:
	_fechar_editor()
	visible = false

func _process(delta: float) -> void:
	if not visible:
		return
	_relogio += delta
	if _relogio >= 5.0:
		_relogio = 0.0
		if aba == "chat" and _jog.chat_atualizar() > 0:
			return
		if _jog.atualizar_ajudas() > 0:
			return

# ------------------------------------------------------------------ estrutura

func montar() -> void:
	_titulo.text = tr("SOCIAL_TITULO")
	_fechar.text = tr("PAINEL_FECHAR")
	for c in _abas.get_children():
		c.queue_free()
	for a: String in ABAS:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = a == aba
		b.text = tr("SOCIAL_ABA_" + a.to_upper())
		b.pressed.connect(func(): aba = a; _confirmar = ""; _denunciando = {}; _mensagem.text = ""; montar())
		_abas.add_child(b)
	for c in _subabas.get_children():
		c.queue_free()
	_subabas.visible = aba == "ordem" and _jog.tem_ordem()
	if _subabas.visible:
		for s: String in SUBABAS:
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.toggle_mode = true
			b.button_pressed = s == sub
			b.text = tr("ORDEM_SUB_" + s.to_upper())
			b.pressed.connect(func(): sub = s; _confirmar = ""; montar())
			_subabas.add_child(b)
	for c in _lista.get_children():
		c.queue_free()
	_sem_entrada()
	_info.text = _texto_info()
	match aba:
		"ordem": _montar_ordem()
		"chat": _montar_chat()
		"amigos": _montar_amigos()
		"perfil": _montar_perfil()

func _texto_info() -> String:
	if not _jog.tem_ordem():
		return tr("ORDEM_SEM_ORDEM")
	var o := _jog.ordem()
	return tr("ORDEM_CABECALHO").format({"nome": o["nome"], "cargo": tr("CARGO_" + str(o["cargo"]).to_upper()),
		"membros": (o["membros"] as Array).size(), "max": int(_jog.cfg_ordem()["membros_max"])}) 		+ "  ·  " + tr("ORDEM_MOEDA").format({"moeda": _jog.moeda_ordem()})

# ------------------------------------------------------------------- ordem

func _montar_ordem() -> void:
	if not _jog.tem_ordem():
		_montar_sem_ordem()
		return
	match sub:
		"membros": _sub_membros()
		"ajuda": _sub_ajuda()
		"doacoes": _sub_doacoes()
		"torneio": _sub_torneio()
		"loja": _sub_loja()
		"gerir": _sub_gerir()

func _montar_sem_ordem() -> void:
	var cfg := _jog.cfg_ordem()
	_rotulo(tr("SOCIAL_SIMULADO"))
	var nivel := int(cfg["nivel_minimo"])
	if int(_jog.cavaleiro()["nivel"]) < nivel:
		_rotulo(tr("ORDEM_NIVEL_MINIMO").format({"nivel": nivel}), true)
	_rotulo(tr("ORDEM_CRIAR_TITULO"), true)
	_rotulo(tr("ORDEM_CRIAR_INFO").format({"ouro": int(cfg["criar"]["ouro"])}))
	_entrada_com(tr("ORDEM_NOME_PLACEHOLDER"), tr("ORDEM_CRIAR"), func(texto):
		var r := _jog.criar_ordem(texto)
		if r["ok"]:
			sub = "membros"
			_limpar_campo()
		else:
			_erro(r))
	_rotulo(tr("ORDEM_ENTRAR_TITULO"), true)
	for o: Dictionary in _jog.ordens_para_entrar():
		var l := _linha()
		l.add_child(_marca(o["brasao"]))
		var t := _texto(tr("ORDEM_LINHA").format({"nome": o["nome"], "membros": o["membros"], "max": int(cfg["membros_max"]), "poder": o["poder"]}))
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_child(t)
		var b := _botao_em(l, tr("ORDEM_ENTRAR"), func():
			var r := _jog.entrar_ordem(o["id"])
			if r["ok"]:
				sub = "membros"
			else:
				_erro(r))
		b.disabled = int(_jog.cavaleiro()["nivel"]) < nivel

func _sub_membros() -> void:
	var o := _jog.ordem()
	_rotulo(tr("SOCIAL_SIMULADO"))
	var meu: String = o["cargo"]
	var ordem_cargos := {"lider": 0, "oficial": 1, "membro": 2}
	var membros: Array = o["membros"]
	membros.sort_custom(func(a, b): return int(ordem_cargos[a["cargo"]]) < int(ordem_cargos[b["cargo"]]) or (a["cargo"] == b["cargo"] and int(a["poder"]) > int(b["poder"])))
	var cfg := _jog.cfg_ordem()
	for m: Dictionary in membros:
		var l := _linha()
		var t := _texto(tr("ORDEM_MEMBRO_LINHA").format({"nome": m["nome"], "cargo": tr("CARGO_" + str(m["cargo"]).to_upper()),
			"poder": m["poder"], "pontos": m["pontos"]}) + ("  ·  " + tr("JUSTA_NOME_JOGADOR") if m["id"] == "voce" else ""))
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if m["id"] == "voce":
			t.add_theme_color_override("font_color", COR_DESTAQUE)
		l.add_child(t)
		if m["id"] == "voce":
			continue
		_botao_em(l, tr("SOCIAL_VER_PERFIL"), func(): perfil_id = m["id"]; aba = "perfil"; montar())
		if not _jog.amigos().any(func(a): return a["id"] == "f%d" % int(m["n"])):
			_botao_em(l, tr("AMIGOS_ADICIONAR_CURTO"), func():
				var r := _jog.adicionar_amigo(m["id"])
				_mensagem.text = tr("AMIGOS_ADICIONADO").format({"nome": m["nome"]}) if r["ok"] else tr("ERRO_" + str(r["erro"]).to_upper()))
		for acao: String in ["promover", "rebaixar", "expulsar"]:
			if RegraOrdem.pode_sobre(meu, m["cargo"], acao, cfg):
				_botao_em(l, tr("ORDEM_" + acao.to_upper()), func():
					var r := _jog.agir_sobre_membro(m["id"], acao)
					if not r["ok"]:
						_erro(r))

func _sub_ajuda() -> void:
	var cfg: Dictionary = _jog.cfg_ordem()["ajuda"]
	_rotulo(tr("SOCIAL_SIMULADO"))
	_rotulo(tr("ORDEM_AJUDA_MEUS"), true)
	var meus := _jog.timers_para_pedir_ajuda()
	if meus.is_empty():
		_rotulo(tr("ORDEM_AJUDA_NENHUM_TIMER"))
	for t: Dictionary in meus:
		var l := _linha()
		var texto := tr("ORDEM_AJUDA_TIMER").format({"tipo": tr("AJUDA_TIPO_" + str(t["tipo"]).to_upper()), "tempo": Vila.formatar_tempo(int(t["restante_s"]))})
		var p := _jog.pedido_do_timer(t["id"])
		var x := _texto(texto + ("  ·  " + tr("ORDEM_AJUDA_PEDIDO").format({"n": p["aplicadas"], "max": (p["atrasos"] as Array).size()}) if not p.is_empty() else ""))
		x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_child(x)
		if p.is_empty():
			_botao_em(l, tr("ORDEM_AJUDA_PEDIR"), func():
				var r := _jog.pedir_ajuda(t["id"])
				if not r["ok"]:
					_erro(r))
	_rotulo(tr("ORDEM_AJUDA_DOS_MEMBROS"), true)
	var pedidos := _jog.pedidos_da_ordem()
	if pedidos.is_empty():
		_rotulo(tr("ORDEM_AJUDA_NENHUM_PEDIDO"))
	for p: Dictionary in pedidos:
		var l := _linha()
		var t := _texto(tr("ORDEM_AJUDA_PEDIDO_MEMBRO").format({"nome": p["nome"], "tipo": tr("AJUDA_TIPO_" + str(p["tipo"]).to_upper())}))
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_child(t)
		var b := _botao_em(l, tr("ORDEM_AJUDADO") if p["ajudado"] else tr("ORDEM_AJUDAR").format({"moeda": int(cfg["moeda_por_ajuda"])}), func():
			var r := _jog.ajudar(p["id"])
			if r["ok"]:
				_mensagem.text = tr("ORDEM_AJUDOU").format({"moeda": r["moeda"]})
			else:
				_erro(r))
		b.disabled = p["ajudado"]

func _sub_doacoes() -> void:
	var cfg: Dictionary = _jog.cfg_ordem()["doacao"]
	_rotulo(tr("SOCIAL_SIMULADO"))
	_rotulo(tr("ORDEM_DOACAO_RESTANTE").format({"n": _jog.doacao_restante_hoje(), "max": int(cfg["limite_dia_unidades"])}), true)
	for p: Dictionary in _jog.pedidos_de_doacao():
		var l := _linha()
		var t := _texto(tr("ORDEM_DOACAO_PEDIDO").format({"nome": p["nome"], "quantidade": p["quantidade"], "material": tr("MATERIAL_" + str(p["material"]).to_upper()),
			"tenho": _jog.material(p["material"])}))
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_child(t)
		var b := _botao_em(l, tr("ORDEM_DOADO") if p["atendido"] else tr("ORDEM_DOAR").format({"moeda": int(cfg["moeda_por_doacao"])}), func():
			var r := _jog.doar(p["id"])
			if r["ok"]:
				_mensagem.text = tr("ORDEM_DOOU").format({"moeda": r["moeda"]})
			else:
				_erro(r))
		b.disabled = p["atendido"]

func _sub_torneio() -> void:
	var t := _jog.torneio_semana()
	_rotulo(tr("SOCIAL_SIMULADO"))
	_rotulo(tr("ORDEM_TORNEIO_TITULO"), true)
	if not (t["pendente"] as Dictionary).is_empty():
		var p: Dictionary = t["pendente"]
		var l := _linha()
		var x := _texto(tr("ORDEM_TORNEIO_PENDENTE").format({"posicao": p["posicao"], "premio": _texto_premio(p)}))
		x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		x.add_theme_color_override("font_color", COR_DESTAQUE)
		l.add_child(x)
		_botao_em(l, tr("ORDEM_TORNEIO_RESGATAR"), func():
			var r := _jog.resgatar_torneio()
			if r["ok"]:
				_mensagem.text = tr("ORDEM_TORNEIO_RESGATADO").format({"premio": _texto_premio({"moeda": r["moeda"], "bau": r["bau_ganho"].get("tipo", "") if r["bau_ganho"] is Dictionary else ""})})
			else:
				_erro(r))
	_rotulo(tr("ORDEM_TORNEIO_SUA").format({"pontos": t["pontos"], "minhas": t["minhas_vitorias"], "posicao": t["posicao"]}))
	_rotulo(tr("ORDEM_TORNEIO_FIM").format({"tempo": Vila.formatar_tempo(int(t["restante_s"]))}))
	_rotulo(tr("ORDEM_TORNEIO_PREMIO").format({"premio": _texto_premio(t["premio"])}))
	var i := 1
	for o: Dictionary in t["ordens"]:
		var l := _rotulo(tr("ORDEM_TORNEIO_LINHA").format({"pos": i, "nome": o["nome"], "pontos": o["pontos"]}))
		if o["voce"]:
			l.add_theme_color_override("font_color", COR_DESTAQUE)
		i += 1

func _texto_premio(p: Dictionary) -> String:
	var partes: Array[String] = []
	if int(p.get("moeda", 0)) > 0:
		partes.append(tr("ORDEM_MOEDAS_N").format({"n": int(p["moeda"])}))
	if str(p.get("bau", "")) != "":
		partes.append(tr("BAU_" + str(p["bau"]).to_upper()))
	return ", ".join(partes) if not partes.is_empty() else "—"

func _sub_loja() -> void:
	_rotulo(tr("ORDEM_LOJA_AVISO"))
	for it: Dictionary in _jog.loja_ordem():
		var l := _linha()
		var t := _texto(tr("ORDEM_LOJA_ITEM").format({"nome": tr("ORDEM_ITEM_" + str(it["id"]).to_upper()), "moeda": it["moeda"], "restantes": maxi(0, int(it["restantes"]))}))
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_child(t)
		var b := _botao_em(l, tr("ORDEM_COMPRAR") if it["erro"] == "" else tr("ERRO_" + str(it["erro"]).to_upper()), func():
			var r := _jog.comprar_da_ordem(it["id"])
			if not r["ok"]:
				_erro(r))
		b.disabled = not it["pode"]

func _sub_gerir() -> void:
	var o := _jog.ordem()
	_rotulo(tr("SOCIAL_SIMULADO"))
	var l := _linha()
	l.add_child(_marca(o["brasao"]))
	var b_ed := _botao_em(l, tr("ORDEM_EDITAR_BRASAO"), _abrir_editor_brasao)
	b_ed.disabled = not _jog.pode_na_ordem("editar_brasao")
	if _jog.pode_na_ordem("editar_nome"):
		_rotulo(tr("ORDEM_RENOMEAR"), true)
		_entrada_com(tr("ORDEM_NOME_PLACEHOLDER"), tr("ORDEM_RENOMEAR_ACAO"), func(texto):
			var r := _jog.renomear_ordem(texto)
			if r["ok"]:
				_limpar_campo()
			else:
				_erro(r))
	var sair := _botao(tr("ORDEM_CONFIRMAR_SAIR") if _confirmar == "sair" else tr("ORDEM_SAIR"), func():
		if _confirmar != "sair":
			_confirmar = "sair"
			montar()
			return
		_confirmar = ""
		var r := _jog.sair_ordem()
		if not r["ok"]:
			_erro(r))
	if _jog.pode_na_ordem("dissolver"):
		sair.tooltip_text = tr("ORDEM_SAIR_DICA")
		_botao(tr("ORDEM_CONFIRMAR_DISSOLVER") if _confirmar == "dissolver" else tr("ORDEM_DISSOLVER"), func():
			if _confirmar != "dissolver":
				_confirmar = "dissolver"
				montar()
				return
			_confirmar = ""
			var r := _jog.dissolver_ordem()
			if not r["ok"]:
				_erro(r))
	if _jog.pode_na_ordem("passar_lideranca"):
		_rotulo(tr("ORDEM_PASSAR_LIDERANCA_INFO"), true)
		for m: Dictionary in o["membros"]:
			if m["id"] == "voce" or m["cargo"] == "lider":
				continue
			var x := _linha()
			var t := _texto(m["nome"])
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			x.add_child(t)
			_botao_em(x, tr("ORDEM_PASSAR_LIDERANCA"), func():
				var r := _jog.passar_lideranca(m["id"])
				if not r["ok"]:
					_erro(r))

func _abrir_editor_brasao() -> void:
	if _editor != null:
		return
	var env := Control.new()
	env.set_anchors_preset(Control.PRESET_FULL_RECT)
	env.mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo := ColorRect.new()
	fundo.color = Color(0.07, 0.06, 0.05, 1)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	env.add_child(fundo)
	var ed: EditorBrasao = CENA_BRASAO.instantiate()
	ed.alvo_ordem = true
	env.add_child(ed)
	var cancelar := Button.new()
	cancelar.theme = theme
	cancelar.focus_mode = Control.FOCUS_NONE
	cancelar.text = tr("ORDEM_CANCELAR")
	cancelar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	cancelar.offset_left = -130
	cancelar.offset_top = -44
	cancelar.offset_right = -16
	cancelar.offset_bottom = -12
	env.add_child(cancelar)
	ed.brasao_definido.connect(func(b: Dictionary):
		var r := _jog.editar_brasao_ordem(b)
		_fechar_editor()
		if not r["ok"]:
			_erro(r))
	cancelar.pressed.connect(_fechar_editor)
	get_parent().add_child(env)
	_editor = env

func _fechar_editor() -> void:
	if _editor != null:
		_editor.queue_free()
		_editor = null
		if visible:
			montar()

# -------------------------------------------------------------------- chat

func _montar_chat() -> void:
	var linha := _linha()
	for c: String in ["ordem", "global"]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = c == canal
		b.text = tr("CHAT_CANAL_" + c.to_upper())
		b.pressed.connect(func(): canal = c; _denunciando = {}; montar())
		linha.add_child(b)
	_rotulo(tr("SOCIAL_SIMULADO"))
	if canal == "ordem" and not _jog.tem_ordem():
		_rotulo(tr("CHAT_SEM_ORDEM"), true)
		return
	_entrada_com(tr("CHAT_PLACEHOLDER"), tr("CHAT_ENVIAR"), func(texto):
		var r := _jog.chat_enviar(canal, texto, "")
		if r["ok"]:
			_limpar_campo()
		else:
			_erro(r))
	_campo.max_length = int(_jog.cfg_ordem()["chat"]["texto_max"])
	if not _denunciando.is_empty():
		_rotulo(tr("CHAT_DENUNCIAR_MOTIVO").format({"nome": _denunciando["nome"]}), true)
		var mot := _linha_fluxo()
		for m: String in _jog.cfg_ordem()["chat"]["motivos_denuncia"]:
			_botao_em(mot, tr("DENUNCIA_" + m.to_upper()), func():
				var r := _jog.denunciar(_denunciando["id"], _denunciando["nome"], m, _denunciando["trecho"])
				_denunciando = {}
				_mensagem.text = tr("CHAT_DENUNCIA_GUARDADA") if r["ok"] else tr("ERRO_" + str(r["erro"]).to_upper())
				montar())
		_botao_em(mot, tr("ORDEM_CANCELAR"), func(): _denunciando = {}; montar())
	var rap := _linha_fluxo()
	for id: String in _jog.mensagens_rapidas():
		var b := _botao_em(rap, tr("MSG_" + id.to_upper()), func():
			var r := _jog.chat_enviar(canal, "", id)
			if not r["ok"]:
				_erro(r))
		b.add_theme_font_size_override("font_size", 11)
	var msgs := _jog.chat_mensagens(canal)
	if msgs.is_empty():
		_rotulo(tr("CHAT_VAZIO"))
	for m: Dictionary in msgs.slice(maxi(0, msgs.size() - MENSAGENS_NA_TELA)):
		var l := _linha()
		var texto := tr("MSG_" + str(m["chave"]).to_upper()) if m["chave"] != "" else str(m["texto"])
		var t := _texto("%s: %s" % [m["de_nome"], texto])
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if m["de_id"] == "voce":
			t.add_theme_color_override("font_color", COR_DESTAQUE)
		l.add_child(t)
		if m["de_id"] != "voce":
			_botao_em(l, tr("CHAT_DENUNCIAR"), func(): _denunciando = {"id": m["de_id"], "nome": m["de_nome"], "trecho": texto}; montar())
			_botao_em(l, tr("CHAT_BLOQUEAR"), func():
				_jog.bloquear(m["de_id"])
				_mensagem.text = tr("CHAT_BLOQUEADO").format({"nome": m["de_nome"]}))

# ------------------------------------------------------------------ amigos

func _montar_amigos() -> void:
	_rotulo(tr("SOCIAL_SIMULADO"))
	_rotulo(tr("AMIGOS_MEU_CODIGO").format({"codigo": _jog.meu_codigo()}), true)
	_entrada_com(tr("AMIGOS_PLACEHOLDER"), tr("AMIGOS_ADICIONAR"), func(texto):
		var r := _jog.adicionar_amigo_por_codigo(texto)
		if r["ok"]:
			_limpar_campo()
			_mensagem.text = tr("AMIGOS_ADICIONADO").format({"nome": _jog.amigos().back()["nome"]})
		else:
			_erro(r))
	_campo.max_length = 12
	if OS.is_debug_build():
		var cods: Array[String] = []
		for c: Dictionary in _jog.codigos_de_teste(3):
			cods.append("%s (%s)" % [c["codigo"], c["nome"]])
		_rotulo(tr("AMIGOS_CODIGOS_TESTE").format({"lista": ", ".join(cods)}))
	var amigos := _jog.amigos()
	_rotulo(tr("AMIGOS_LISTA").format({"n": amigos.size(), "max": int(_jog.cfg_ordem()["amigos"]["max"])}), true)
	if amigos.is_empty():
		_rotulo(tr("AMIGOS_NENHUM"))
	for a: Dictionary in amigos:
		var l := _linha()
		var t := _texto(a["nome"])
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_child(t)
		_botao_em(l, tr("SOCIAL_VER_PERFIL"), func(): perfil_id = a["id"]; aba = "perfil"; montar())
		_botao_em(l, tr("AMIGOS_REMOVER"), func(): _jog.remover_amigo(a["id"]))
	var bloq := _jog.bloqueados()
	if not bloq.is_empty():
		_rotulo(tr("AMIGOS_BLOQUEADOS"), true)
	for id: String in bloq:
		var l := _linha()
		var t := _texto(_nome_de(id))
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_child(t)
		_botao_em(l, tr("AMIGOS_DESBLOQUEAR"), func(): _jog.desbloquear(id))

## Nome para mostrar de um id bloqueado (membro da ordem ou jogador simulado).
func _nome_de(id: String) -> String:
	var p := _jog.perfil_publico(id)
	if not p.is_empty():
		return str(p["nome"])
	for m: Dictionary in _jog.ordem().get("membros", []):
		if m["id"] == id:
			return str(m["nome"])
	return id

# ------------------------------------------------------------------ perfil

func _montar_perfil() -> void:
	var p := _jog.perfil_publico(perfil_id)
	if p.is_empty():
		perfil_id = "voce"
		p = _jog.perfil_publico("voce")
	if p["simulado"]:
		_rotulo(tr("SOCIAL_SIMULADO"))
	var topo := _linha()
	_retrato(p, topo)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(col)
	col.add_child(_marca_com_nome(p))
	var linhas: Array[String] = [
		tr("PERFIL_LINHA_1").format({"nome": p["nome"], "nivel": p["nivel"], "casa": p["casa_nome"]}),
		tr("PERFIL_LIGA").format({"liga": tr("LIGA_" + str(p["liga"]["nome"]).to_upper()), "divisao": p["liga"]["divisao"], "pontos": p["liga"]["pontos"], "poder": p["poder"]}),
		tr("PERFIL_MELHOR").format({"liga": tr("LIGA_" + str(p["melhor_liga"]).to_upper()) if str(p["melhor_liga"]) != "" else "—"}),
		tr("PERFIL_CAVALO").format({"pelagem": tr("PELAGEM_" + str(p["pelagem"]).to_upper())}),
		tr("PERFIL_RENOME").format({"renome": p["renome"]})]
	if str(p["ordem_nome"]) != "":
		linhas.append(tr("PERFIL_ORDEM").format({"ordem": p["ordem_nome"], "cargo": tr("CARGO_" + str(p["cargo"]).to_upper()) if str(p["cargo"]) != "" else "—"}))
	var titulos: Array = (p["titulos"] as Array).map(func(t): return tr("TITULO_" + str(t).to_upper()))
	linhas.append(tr("PERFIL_TITULOS").format({"lista": ", ".join(titulos) if not titulos.is_empty() else tr("PERFIL_SEM_TITULOS")}))
	var mel: Dictionary = p["melhores"]
	linhas.append(tr("PERFIL_MELHORES").format({"vitorias": mel["vitorias"], "tres": mel["tres_estrelas"], "der": mel["derrubadas"], "reg": mel["regioes"]}))
	linhas.append(tr("PERFIL_CODIGO").format({"codigo": p.get("codigo", "")}))
	for t in linhas:
		col.add_child(_texto(t))
	if str(p["titulo"]) != "":
		var tt := _texto(tr("TITULO_" + str(p["titulo"]).to_upper()))
		tt.add_theme_color_override("font_color", COR_DESTAQUE)
		col.add_child(tt)
	var acoes := _linha()
	if perfil_id != "voce":
		if p["amigo"]:
			_botao_em(acoes, tr("AMIGOS_REMOVER"), func(): _jog.remover_amigo(p["id"]))
		else:
			_botao_em(acoes, tr("AMIGOS_ADICIONAR_CURTO"), func():
				var r := _jog.adicionar_amigo(p["id"])
				_mensagem.text = tr("AMIGOS_ADICIONADO").format({"nome": p["nome"]}) if r["ok"] else tr("ERRO_" + str(r["erro"]).to_upper()))
		_botao_em(acoes, tr("CHAT_BLOQUEAR"), func():
			_jog.bloquear(p["id"])
			perfil_id = "voce"
			montar())
		_botao_em(acoes, tr("SOCIAL_MEU_PERFIL"), func(): perfil_id = "voce"; montar())

## Retrato: o cavaleiro a pé e o cavalo, no estilo provisório da vila.
func _retrato(p: Dictionary, pai: Control) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(270, 150)
	pai.add_child(c)  # na árvore antes de vestir: as camadas carregam os dados no _ready
	var f := CamadasPersonagem.new()
	f.tamanho = "vila"
	f.position = Vector2(60, 140)
	f.scale = Vector2(1.5, 1.5)
	c.add_child(f)
	if p["id"] == "voce":
		AparenciaJogador.vestir_camadas(f, _jog)
	else:
		f.definir_casa(p["casa"])
		f.vestir({"corpo": p["corpo"], "rosto": p["rosto"], "cabelo": p["cabelo"], "elmo": "nenhum", "escudo": "nenhum"})
	f.tocar("parado")
	var cav := CamadasPersonagem.new()
	cav.tamanho = "justa"
	cav.position = Vector2(190, 144)
	cav.scale = Vector2(0.8, 0.8)
	c.add_child(cav)
	var pecas := {"pelagem": p["pelagem"]}
	for k in ["caparacao", "corpo", "pernas", "peitoral", "sobreveste", "elmo", "cimeira", "escudo", "lanca"]:
		pecas[k] = "nenhum"
	cav.vestir(pecas)

func _marca_com_nome(p: Dictionary) -> Control:
	var l := HBoxContainer.new()
	l.add_child(_marca(p["brasao"], Vector2i(28, 36)))
	return l

# ---------------------------------------------------------------- utilitários

func _erro(r: Dictionary) -> void:
	_mensagem.text = tr("ERRO_" + str(r["erro"]).to_upper())

## Linha de entrada (campo + botão) embaixo da lista. `acao` recebe o texto.
func _entrada_com(dica: String, texto_botao: String, acao: Callable) -> void:
	var dono := "%s/%s/%s" % [aba, sub, canal]
	if dono != _entrada_dono:
		_campo.text = ""
		_entrada_dono = dono
	_campo.placeholder_text = dica
	_campo.max_length = 0
	_acao.text = texto_botao
	_entrada_acao = acao
	_entrada.visible = true

func _sem_entrada() -> void:
	_entrada.visible = false
	_entrada_acao = Callable()

func _limpar_campo() -> void:
	_campo.text = ""

func _enviar_entrada() -> void:
	if _entrada_acao.is_valid():
		_entrada_acao.call(_campo.text)

func _linha() -> HBoxContainer:
	var l := HBoxContainer.new()
	l.add_theme_constant_override("separation", 6)
	_lista.add_child(l)
	return l

## Linha que quebra quando não cabe (botões de mensagem rápida, motivos).
func _linha_fluxo() -> HFlowContainer:
	var l := HFlowContainer.new()
	l.add_theme_constant_override("h_separation", 4)
	l.add_theme_constant_override("v_separation", 3)
	_lista.add_child(l)
	return l

func _texto(texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 12)
	return l

func _rotulo(texto: String, destaque := false) -> Label:
	var l := _texto(texto)
	if destaque:
		l.add_theme_color_override("font_color", COR_DESTAQUE)
	_lista.add_child(l)
	return l

func _botao(texto: String, acao: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = texto
	b.pressed.connect(acao)
	_lista.add_child(b)
	return b

func _botao_em(pai: Control, texto: String, acao: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = texto
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(acao)
	pai.add_child(b)
	return b

## Brasão pequeno (bandeirinha) para listas.
func _marca(brasao: Dictionary, tamanho := Vector2i(20, 26)) -> TextureRect:
	var r := TextureRect.new()
	r.texture = GeradorBrasao.textura(brasao, tamanho, true)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.custom_minimum_size = Vector2(tamanho)
	r.stretch_mode = TextureRect.STRETCH_KEEP
	return r
