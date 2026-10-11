class_name ControladorJusta
extends Node
## Liga a regra da justa (Justa, pura) à cena da arena: passa o tempo, manda
## os toques, emite os sinais, troca o plano da câmera, move os cavaleiros,
## a bandeira do arauto e a barra de distância.
## Som, efeitos e interface só escutam os sinais; nada aqui decide resultado.
##
## Câmera por fase (GDD, tabela de fases):
##   Apresentação, Largada: plano aberto, cavaleiros parados nas pontas
##   Corrida: segue o jogador (a velocidade vem do galope)
##   Mira: zoom no peito do rival, cavaleiros em câmera lenta
##   Impacto: close lateral no ponto de encontro
## Toque na tela inteira, com uma mão: pula a Apresentação, larga na
## Largada, galopa na Corrida. Na Mira: segura, arrasta a ponta da lança
## sobre o rival (arrasto relativo, o dedo não cobre o alvo) e solta para
## golpear. A zona sob a ponta brilha de leve no próprio rival.

## Qualquer troca de fase. `anterior` é JustaFases.Fase.FIM no começo.
signal fase_mudou(fase: JustaFases.Fase, anterior: JustaFases.Fase, passada: int)
## Atalhos por fase, para quem só quer uma delas (som da trombeta, etc.).
signal apresentacao_comecou(passada: int)
signal largada_comecou(passada: int)
signal corrida_comecou(passada: int)
signal mira_comecou(passada: int)
signal impacto_comecou(passada: int)
signal bandeira_baixou(passada: int)
## qualidade: "perfeita", "boa" ou "ruim"; queimada = tocou antes da bandeira.
signal largada_avaliada(passada: int, qualidade: String, reacao_ms: int, queimada: bool)
## resultado: "no_tempo", "fora_do_tempo", "rapido_demais" ou "perdido".
signal toque_galope(resultado: String, desvio_ms: int, velocidade: int, folego: int)
signal corrida_terminou(passada: int, velocidade_jogador: int, ritmo_milesimos: int)
## O jogador soltou o dedo na Mira (o golpe sai no choque).
signal golpe_solto(passada: int)
## Golpe avaliado no choque: zona "capacete", "peito", "escudo", "cavalo" ou "erro".
signal golpe_avaliado(passada: int, zona: String, automatico: bool, sem_golpe: bool)
## Choque resolvido pela regra do impacto. `jogador`/`rival` = resultado do
## golpe daquele lado (ver Impacto): zona_final, pontos, falta, bloqueado,
## derrubou, dano... `derrubado`/`desclassificado` são JustaFases.Lado.
signal impacto_resolvido(passada: int, jogador: Dictionary, rival: Dictionary, derrubado: JustaFases.Lado, desclassificado: JustaFases.Lado)
## Habilidade ativa acionada ("jogador" ou "rival").
signal habilidade_ativada(passada: int, lado: String, nome: String)
signal passada_terminou(passada: int, pontos_jogador: int, pontos_rival: int, derrubado: JustaFases.Lado)
signal justa_terminou(vencedor: JustaFases.Lado, motivo: String, placar_jogador: int, placar_rival: int)

@export var arena: Arena
@export var barra: BarraDistancia
## Interface (para não tratar como jogo o toque que cai no botão).
@export var interface: InterfaceJusta
## Painel de ajuste (só em desenvolvimento; some no release).
@export var painel: PainelAjuste
## Segundos depois do fim até um toque começar outra justa.
@export var espera_para_recomecar := 1.0
@export var iniciar_sozinho := true
## Perfil da IA do rival (game/data/balance/ia_rival.json); vazio = rival sem IA.
@export var perfil_rival := "equilibrado"
## Velocidade dos cavaleiros na Mira e no Impacto em relação à Corrida
## (câmera lenta). Ajuste visual: o tempo de jogo da Mira não muda.
@export_range(0.05, 1.0, 0.05) var camera_lenta := 0.3
## Zoom do close do Impacto: precisa caber os dois cavaleiros inteiros.
@export var zoom_impacto := 1.5
## Quanto a ponta anda por px de arrasto aparente na tela (1 = acompanha o dedo).
@export var sensibilidade_mira := 1.0

var justa: Justa
## Atributos de cada lado: {cavaleiro, cavalo, equipamento, habilidade}.
## O jogador vem dos dados do jogador (autoload Jogador); o rival, por enquanto,
## de game/data/balance/padrao.json (perfis de rival da região: 2.10).
var lado_jogador: Dictionary
var lado_rival: Dictionary
## Semente da justa (no servidor, Parte 3, quem sorteia é ele).
var semente := 0

## Todos os eventos da justa atual (estrelas do PvE, envio ao servidor).
var eventos_justa: Array[Dictionary] = []
## Chave de tradução do nome do rival e do jogador (vazio = "Você").
var nome_rival := ""
var nome_jogador := ""
## "livre", "disputa" (PvE), "exibicao" (início do jogo: dois veteranos da IA,
## câmera da arquibancada, arauto explicando) ou "tutorial" (primeira justa,
## rival fraco, dicas por fase). Vem do Fluxo.
var modo := "livre"
## Disputa do PvE desta justa ({} = livre) e o resultado dela no Jogador.
var disputa := {}
var resultado_disputa := {}
## Disputa do PvE: provocação do campeão (chave de texto), desafios do
## torneio e se o cavalo do jogador cansa (cavalo emprestado não).
var provocacao := ""
var desafios: Array = []
var _gasta_folego := true

var _resto_ms := 0.0
var _desistencia_registrada := false
var _px_por_mil := 0.0
var _fim_corrida_j := 0.0  ## distâncias em px no fim da Corrida (para a Mira)
var _fim_corrida_r := 0.0
var _encontro_j := 0.0
var _encontro_r := 0.0
var _cfg: Dictionary
var _base_mira := Vector2.ZERO  ## ponta sem a oscilação, décimos de px do quadro do rival
var _tempo_mira := 0.0
var _tempo_desde_fim := 0.0

func _ready() -> void:
	if iniciar_sozinho:
		iniciar.call_deferred()

## Começa uma justa nova com os dados de game/data/balance/.
## `semente_fixa` < 0 sorteia uma.
func iniciar(semente_fixa := -1) -> void:
	_cfg = Justa.carregar_configuracao()
	var erro := Justa.validar(_cfg)
	var padrao := Balanceamento.carregar("padrao")
	if erro == "" and not (padrao.has("cavaleiro") and padrao.has("cavalo")):
		erro = "padrao.json sem cavaleiro/cavalo"
	if erro != "":
		push_error("ControladorJusta: " + erro)
		set_process(false)
		return
	if lado_jogador.is_empty():
		var jog := get_node_or_null("/root/Jogador") as ServicoJogador
		lado_jogador = jog.lado_para_justa() if jog else Justa.lado_padrao(padrao)
	if lado_rival.is_empty():
		lado_rival = Justa.lado_padrao(padrao)
	var perfil := {}
	var perfil_jogador := {}
	var fluxo := get_node_or_null("/root/Fluxo") as FluxoTelas
	var jog_d := get_node_or_null("/root/Jogador") as ServicoJogador
	modo = fluxo.modo_justa if fluxo else "livre"
	disputa = fluxo.disputa.duplicate() if fluxo and fluxo.em_disputa() else {}
	resultado_disputa = {}
	nome_rival = "RIVAL_" + perfil_rival.to_upper() if perfil_rival != "" else ""
	nome_jogador = ""
	var rv := {}
	provocacao = ""
	desafios = []
	_gasta_folego = true
	match modo:
		"disputa":
			if not disputa.is_empty() and jog_d:
				var prep := jog_d.preparar_disputa(disputa["torneio"], int(disputa["indice"]))
				_cfg = prep["cfg"]
				lado_jogador = prep["lado_jogador"]
				rv = prep["rival"]
				provocacao = rv.get("provocacao", "")
				desafios = prep["desafios"]
				_gasta_folego = prep["gasta_folego"]
				arena.aplicar_ambiente(prep["visuais"])
		"tutorial":
			if jog_d:
				rv = jog_d.rival_tutorial()
				rv["nome_chave"] = "RIVAL_TUTORIAL"
		"exibicao":
			# Dois veteranos da IA; o jogador assiste da arquibancada.
			var ex: Dictionary = Balanceamento.carregar("inicio")["tutorial"]["exibicao"]
			var perfis_ex: Dictionary = Balanceamento.carregar("ia_rival")["perfis"]
			lado_jogador = Justa.lado_padrao(padrao)
			lado_rival = Justa.lado_padrao(padrao)
			perfil_rival = ex["perfil_vermelho"]
			perfil_jogador = perfis_ex[ex["perfil_azul"]]
			semente_fixa = int(ex["semente"])
			nome_jogador = "EXIBICAO_AZUL"
			nome_rival = "EXIBICAO_VERMELHO"
			arena.jogador.definir_casa({"principal": "azul_real", "secundaria": "prata"})
			arena.jogador.camadas().vestir({"pelagem": "branco", "corpo": "masculino", "elmo": "vigia", "peitoral": "vigia", "escudo": "vigia", "lanca": "vigia"})
			arena.jogador.definir_brasao({"cor1": "azul_real", "cor2": "prata", "simbolo": "cruz", "cor_simbolo": "prata"})
	if not rv.is_empty():
		lado_rival = rv["lado"]
		perfil_rival = rv["perfil_nome"]
		nome_rival = rv["nome_chave"]
		arena.rival.definir_casa(rv["casa"])
	if perfil_rival != "":
		var ia_cfg := Balanceamento.carregar("ia_rival")
		var e_ia := IaRival.validar(ia_cfg)
		if e_ia != "" or not ia_cfg["perfis"].has(perfil_rival):
			push_error("ControladorJusta: perfil de IA \"%s\" inválido: %s" % [perfil_rival, e_ia])
			set_process(false)
			return
		perfil = rv["perfil"] if rv.has("perfil") else ia_cfg["perfis"][perfil_rival]
	if rv.is_empty():
		arena.vestir_rival(perfil_rival)
	else:
		arena.rival.definir_brasao(rv["brasao"])
	eventos_justa.clear()
	semente = semente_fixa if semente_fixa >= 0 else randi()
	justa = Justa.new(_cfg, lado_jogador, lado_rival, semente, perfil, perfil_jogador)
	var vao := absf(arena.inicio_rival.global_position.x - arena.inicio_jogador.global_position.x)
	_px_por_mil = vao / float(justa.distancia_total_mil())
	_resto_ms = 0.0
	_tempo_desde_fim = 0.0
	set_process(true)
	_metrica("justa_iniciada", {"modo": modo, "rival": nome_rival, "disputa": disputa})
	_despachar(justa.iniciar())

## Toque do jogador (qualquer ponto da tela).
func tocar() -> void:
	if justa and not justa.terminou():
		_despachar(justa.tocar())

## Mira: começa a segurar (toque na tela).
func segurar_mira() -> void:
	if fase() == JustaFases.Fase.MIRA and not justa.solto:
		justa.mirar(_ponto_mira())

## Mira: arrasto do dedo, em px da tela. Converte para o quadro do rival
## (desfaz zoom, escala e espelho) e move a ponta.
func arrastar_mira(delta_tela: Vector2) -> void:
	if fase() != JustaFases.Fase.MIRA or justa.solto or not justa.segurando:
		return
	var mundo := delta_tela / arena.camera.zoom * sensibilidade_mira
	# affine_inverse: basis_xform_inv só serve para base sem escala (usa a transposta).
	var quadro := arena.rival.visual().global_transform.affine_inverse().basis_xform(mundo)
	_base_mira = Vector2(Mira.limitar(_cfg["mira"], Vector2i((_base_mira + quadro * 10.0).round())))
	justa.mirar(_ponto_mira())

## Mira: solta o dedo (golpeia).
func soltar_mira() -> void:
	if fase() == JustaFases.Fase.MIRA:
		_despachar(justa.soltar())

## Ponta da lança em coordenadas do mundo (para desenhar).
func ponta_no_mundo() -> Vector2:
	return arena.rival.visual().to_global(Vector2(justa.ponta) / 10.0)

## Painel de ajuste: troca o conteúdo da configuração `arquivo` no lugar, para
## a justa em andamento já ler os números novos (o que é calculado no começo
## da justa, como durações das fases, vale ao recomeçar).
func aplicar_ajuste(arquivo: String, dados: Dictionary) -> void:
	if not _cfg.has(arquivo):
		return
	var alvo: Dictionary = _cfg[arquivo]
	alvo.clear()
	alvo.merge(dados.duplicate(true))

## Botão de habilidade (Corrida): liga a habilidade ativa nesta passada.
func ativar_habilidade() -> void:
	if justa and not justa.terminou():
		_despachar(justa.ativar_habilidade())

func fase() -> JustaFases.Fase:
	return justa.fases.fase if justa else JustaFases.Fase.FIM

## Desistência: sair da cena ou fechar o jogo com a justa em andamento.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_EXIT_TREE, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED]:
		if justa != null and not justa.terminou() and modo != "exibicao" and not _desistencia_registrada:
			_desistencia_registrada = true
			_metrica("desistencia", {"modo": modo, "fase": JustaFases.NOMES_FASE[justa.fases.fase],
				"passada": justa.fases.passada, "rival": nome_rival})

func _metrica(evento: String, dados := {}) -> void:
	var m := get_node_or_null("/root/Metricas") as ServicoMetricas
	if m:
		m.registrar(evento, dados)

func _process(delta: float) -> void:
	if justa == null:
		return
	if justa.terminou():
		_tempo_desde_fim += delta
		return
	_resto_ms += delta * 1000.0
	var ms := int(_resto_ms)
	_resto_ms -= ms
	if fase() == JustaFases.Fase.MIRA:
		_tempo_mira += delta
		if justa.segurando:
			justa.mirar(_ponto_mira())
	_despachar(justa.avancar(ms))
	_atualizar_visual()

func _unhandled_input(event: InputEvent) -> void:
	if justa == null:
		return
	if event is InputEventScreenTouch and interface and interface.contem_ponto(event.position):
		return
	if event is InputEventScreenTouch and is_instance_valid(painel) and painel.contem_ponto(event.position):
		return
	if justa.terminou():
		if event is InputEventScreenTouch and event.pressed and _tempo_desde_fim >= espera_para_recomecar:
			get_viewport().set_input_as_handled()
			var fluxo := get_node_or_null("/root/Fluxo") as FluxoTelas
			match modo:
				"disputa":
					if fluxo:
						fluxo.ir_para_vila()
				"exibicao":
					if fluxo:
						fluxo.concluiu("exibicao")
				"tutorial":
					if fluxo:
						fluxo.concluiu("primeira_justa")
				_:
					iniciar()
		return
	if modo == "exibicao":
		return  # na exibição o jogador só assiste
	if fase() == JustaFases.Fase.MIRA:
		if event is InputEventScreenTouch:
			if event.pressed:
				segurar_mira()
			else:
				soltar_mira()
			get_viewport().set_input_as_handled()
		elif event is InputEventScreenDrag:
			arrastar_mira(event.relative)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		tocar()
		get_viewport().set_input_as_handled()

## Ponta com a oscilação da mão (dados: mira.oscilacao), em décimos de px.
func _ponto_mira() -> Vector2i:
	var o: Dictionary = _cfg["mira"]["oscilacao"]
	var a := float(o["amplitude_px"]) * 10.0
	var fx := float(o["frequencia_x_milesimos"]) / 1000.0
	var fy := float(o["frequencia_y_milesimos"]) / 1000.0
	var osc := Vector2(sin(_tempo_mira * TAU * fx), sin(_tempo_mira * TAU * fy + 1.3)) * a
	return Mira.limitar(_cfg["mira"], Vector2i((_base_mira + osc).round()))

func _despachar(eventos: Array[Dictionary]) -> void:
	eventos_justa.append_array(eventos)
	for e in eventos:
		var p: int = e.get("passada", 0)
		match e["tipo"]:
			"fase":
				_ao_entrar_na_fase(e["fase"])
				fase_mudou.emit(e["fase"], e["anterior"], p)
				match e["fase"]:
					JustaFases.Fase.APRESENTACAO: apresentacao_comecou.emit(p)
					JustaFases.Fase.LARGADA: largada_comecou.emit(p)
					JustaFases.Fase.CORRIDA: corrida_comecou.emit(p)
					JustaFases.Fase.MIRA: mira_comecou.emit(p)
					JustaFases.Fase.IMPACTO: impacto_comecou.emit(p)
			"bandeira":
				arena.arauto.baixar()
				bandeira_baixou.emit(p)
			"largada":
				largada_avaliada.emit(p, e["qualidade"], e["reacao_ms"], e["queimada"])
			"toque":
				if barra:
					barra.lampejar(e["resultado"])
				toque_galope.emit(e["resultado"], e["desvio_ms"], e["velocidade"], e["folego"])
			"corrida_fim":
				_ao_fim_da_corrida(e)
				corrida_terminou.emit(p, e["velocidade_jogador"], e["ritmo_jogador_milesimos"])
			"soltou":
				golpe_solto.emit(p)
			"golpe":
				golpe_avaliado.emit(p, e["zona"], e["automatico"], e["sem_golpe"])
			"impacto":
				impacto_resolvido.emit(p, e["jogador"], e["rival"], e["derrubado"], e["desclassificado"])
			"habilidade":
				habilidade_ativada.emit(p, e["lado"], e["nome"])
			"passada":
				passada_terminou.emit(p, e["pontos_jogador"], e["pontos_rival"], e["derrubado"])
			"fim":
				_metrica("justa_terminada", {"modo": modo, "rival": nome_rival, "vencedor": JustaFases.NOMES_LADO[e["vencedor"]],
					"motivo": e["motivo"], "placar": [e["placar_jogador"], e["placar_rival"]], "passadas": justa.fases.passada,
					"ms": justa.fases.tempo_total_ms, "estrelas": resultado_disputa.get("estrelas", -1)})
				_registrar_no_jogador(e)
				justa_terminou.emit(e["vencedor"], e["motivo"], e["placar_jogador"], e["placar_rival"])

func _ao_entrar_na_fase(nova: JustaFases.Fase) -> void:
	var cam := arena.camera
	_animar_cavaleiros(nova)
	if modo == "exibicao":
		# Vista da arquibancada: plano aberto o tempo todo.
		if nova == JustaFases.Fase.APRESENTACAO:
			arena.posicionar_nas_pontas()
			arena.arauto.levantar()
			cam.plano_aberto(true)
		elif nova == JustaFases.Fase.LARGADA:
			arena.arauto.levantar()
		_atualizar_visual()
		return
	match nova:
		JustaFases.Fase.APRESENTACAO:
			arena.posicionar_nas_pontas()
			arena.arauto.levantar()
			cam.plano_aberto(true)
		JustaFases.Fase.LARGADA:
			arena.arauto.levantar()
			cam.plano_aberto()
		JustaFases.Fase.FIM:
			cam.plano_aberto()
		JustaFases.Fase.CORRIDA:
			cam.seguir(arena.jogador)
		JustaFases.Fase.MIRA:
			cam.focar_alvo(arena.rival.get_node("Visual/Cavaleiro/Peito"))
			_base_mira = Vector2(Mira.ponta_inicial(_cfg["mira"]))
			_tempo_mira = 0.0
		JustaFases.Fase.IMPACTO:
			var meio := (arena.jogador.centro() + arena.rival.centro()) * 0.5
			cam.focar(meio, zoom_impacto)
	_atualizar_visual()

## Fim da justa: avisa o serviço Jogador (fôlego do cavalo; recompensas e
## desgaste nos prompts seguintes). Na Parte 3 vira o envio dos toques ao
## servidor, que recalcula e paga.
func _registrar_no_jogador(e: Dictionary) -> void:
	if modo == "exibicao":
		return  # a exibição não mexe nos dados do jogador
	var jog := get_node_or_null("/root/Jogador") as ServicoJogador
	if jog and not disputa.is_empty():
		resultado_disputa = jog.concluir_disputa(disputa["torneio"], int(disputa["indice"]), eventos_justa)
		var fluxo := get_node_or_null("/root/Fluxo") as FluxoTelas
		if fluxo:
			fluxo.ultimo_resultado = resultado_disputa
	if jog:
		jog.registrar_justa({"vencedor": JustaFases.NOMES_LADO[e["vencedor"]], "motivo": e["motivo"],
			"placar_jogador": e["placar_jogador"], "placar_rival": e["placar_rival"],
			"equipamento_final": justa.equipamento_final(true), "perfil_rival": perfil_rival, "semente": semente,
			"gasta_folego": _gasta_folego})

## Galope na Corrida (no ritmo da velocidade) e em câmera lenta na Mira e no
## Impacto; parado nas pontas e no fim.
func _animar_cavaleiros(f: JustaFases.Fase) -> void:
	for lado: Array in [[arena.jogador, justa.jogador], [arena.rival, justa.rival]]:
		var cav: Cavaleiro = lado[0]
		var g: Galope = lado[1]
		var ritmo := float(g.velocidade) / maxf(float(g.velocidade_nominal), 1.0)
		match f:
			JustaFases.Fase.CORRIDA:
				cav.animar("galope", ritmo)
			JustaFases.Fase.MIRA, JustaFases.Fase.IMPACTO:
				cav.animar("galope", ritmo * camera_lenta)
			_:
				cav.animar("parado")

## No fim da Corrida, divide o que falta até o encontro na proporção das
## velocidades: a Mira (câmera lenta) leva cada um até o ponto de encontro.
func _ao_fim_da_corrida(e: Dictionary) -> void:
	_fim_corrida_j = e["distancia_jogador_mil"] * _px_por_mil
	_fim_corrida_r = e["distancia_rival_mil"] * _px_por_mil
	var falta := justa.distancia_total_mil() * _px_por_mil - _fim_corrida_j - _fim_corrida_r
	var vj := float(e["velocidade_jogador"])
	var vr := float(e["velocidade_rival"])
	var parte_j := 0.5 if vj + vr <= 0.0 else vj / (vj + vr)
	_encontro_j = _fim_corrida_j + falta * parte_j
	_encontro_r = _fim_corrida_r + falta * (1.0 - parte_j)

## Distâncias percorridas (px) pelo jogador (x) e pelo rival (y) desde as pontas.
func distancias_px() -> Vector2:
	var f := justa.fases
	match f.fase:
		JustaFases.Fase.CORRIDA:
			return Vector2(justa.jogador.distancia_mil, justa.rival.distancia_mil) * _px_por_mil
		JustaFases.Fase.MIRA:
			var k := float(f.tempo_na_fase_ms) / f.duracao_ms(JustaFases.Fase.MIRA)
			return Vector2(lerpf(_fim_corrida_j, _encontro_j, k), lerpf(_fim_corrida_r, _encontro_r, k))
		JustaFases.Fase.IMPACTO:
			# Seguem devagar depois do choque, na velocidade da câmera lenta.
			var t := f.tempo_na_fase_ms / 1000.0
			return Vector2(_encontro_j + justa.jogador.velocidade * _px_por_mil * camera_lenta * t,
				_encontro_r + justa.rival.velocidade * _px_por_mil * camera_lenta * t)
	return Vector2.ZERO

func _atualizar_visual() -> void:
	if justa == null or justa.terminou():
		return  # no fim, os cavaleiros ficam onde pararam
	var d := distancias_px()
	arena.jogador.global_position = arena.inicio_jogador.global_position + Vector2(d.x, 0)
	arena.rival.global_position = arena.inicio_rival.global_position - Vector2(d.y, 0)
	_atualizar_mira()
	if barra == null:
		return
	var total := justa.distancia_total_mil() * _px_por_mil
	barra.posicao_jogador = d.x / total
	barra.posicao_rival = 1.0 - d.y / total
	barra.brilho = _brilho_do_compasso()

## Ponta da lança e brilho leve na zona sob ela, só na Mira.
func _atualizar_mira() -> void:
	var na_mira := justa.fases.fase == JustaFases.Fase.MIRA
	arena.ponta_lanca.visible = na_mira
	if not na_mira:
		arena.rival.realcar("")
		return
	arena.ponta_lanca.global_position = ponta_no_mundo()
	arena.rival.realcar(Mira.zona_no_ponto(_cfg["mira"], justa.ponta, justa.precisao_jogador, justa.bonus_precisao_pct()))

## 1 dentro da janela da batida mais próxima, caindo até 0 a uma janela
## de distância dela; 0 fora da Corrida. A janela visível já inclui o
## Temperamento do cavalo.
func _brilho_do_compasso() -> float:
	if justa.fases.fase != JustaFases.Fase.CORRIDA:
		return 0.0
	var g := justa.jogador
	var p := g.compasso_ms()
	var k := (g.t_ms + p / 2) / p
	if k < 1:
		return 0.0
	var desvio := absi(g.t_ms - k * p)
	if desvio <= g.janela_ms:
		return 1.0
	return clampf(1.0 - float(desvio - g.janela_ms) / g.janela_ms, 0.0, 1.0)
