class_name ControladorJusta
extends Node
## Liga a regra das fases (JustaFases, pura) à cena da arena: passa o tempo,
## emite os sinais, troca o plano da câmera e move os cavaleiros.
## Som, efeitos e interface só escutam os sinais; nada aqui decide resultado.
##
## Câmera por fase (GDD, tabela de fases):
##   Apresentação, Largada: plano aberto, cavaleiros parados nas pontas
##   Corrida: segue o jogador
##   Mira: zoom no peito do rival, cavaleiros em câmera lenta
##   Impacto: close lateral no ponto de encontro

## Qualquer troca de fase. `anterior` é JustaFases.Fase.FIM no começo.
signal fase_mudou(fase: JustaFases.Fase, anterior: JustaFases.Fase, passada: int)
## Atalhos por fase, para quem só quer uma delas (som da trombeta, etc.).
signal apresentacao_comecou(passada: int)
signal largada_comecou(passada: int)
signal corrida_comecou(passada: int)
signal mira_comecou(passada: int)
signal impacto_comecou(passada: int)
signal passada_terminou(passada: int, pontos_jogador: int, pontos_rival: int, derrubado: JustaFases.Lado)
signal justa_terminou(vencedor: JustaFases.Lado, motivo: String, placar_jogador: int, placar_rival: int)

@export var arena: Arena
@export var iniciar_sozinho := true
## Velocidade dos cavaleiros na Mira e no Impacto em relação à Corrida
## (câmera lenta). Ajuste visual: o tempo de jogo da Mira não muda.
@export_range(0.05, 1.0, 0.05) var camera_lenta := 0.3
## Zoom do close do Impacto: precisa caber os dois cavaleiros inteiros.
@export var zoom_impacto := 1.5

var justa: JustaFases
var _resto_ms := 0.0

func _ready() -> void:
	if iniciar_sozinho:
		iniciar.call_deferred()

## Começa uma justa nova com os dados de game/data/balance/justa.json.
func iniciar() -> void:
	var config := Balanceamento.carregar("justa")
	var erro := JustaFases.validar(config)
	if erro != "":
		push_error("ControladorJusta: justa.json inválido: " + erro)
		set_process(false)
		return
	justa = JustaFases.new(config)
	_resto_ms = 0.0
	set_process(true)
	_despachar(justa.iniciar())

## Pula a Apresentação (toque na tela). Fora dela não faz nada.
func pular() -> void:
	if justa:
		_despachar(justa.pular())

## Resultado da passada atual (vem da regra do impacto, prompt 1.5).
func registrar_resultado(pontos_jogador: int, pontos_rival: int, derrubado := JustaFases.Lado.NENHUM) -> bool:
	return justa != null and justa.registrar_resultado(pontos_jogador, pontos_rival, derrubado)

func _process(delta: float) -> void:
	if justa == null or justa.terminou():
		return
	_resto_ms += delta * 1000.0
	var ms := int(_resto_ms)
	_resto_ms -= ms
	_despachar(justa.avancar(ms))
	_posicionar_cavaleiros()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and justa and justa.fase == JustaFases.Fase.APRESENTACAO:
		pular()
		get_viewport().set_input_as_handled()

func _despachar(eventos: Array[Dictionary]) -> void:
	for e in eventos:
		match e["tipo"]:
			"fase":
				_ao_entrar_na_fase(e["fase"])
				fase_mudou.emit(e["fase"], e["anterior"], e["passada"])
				match e["fase"]:
					JustaFases.Fase.APRESENTACAO: apresentacao_comecou.emit(e["passada"])
					JustaFases.Fase.LARGADA: largada_comecou.emit(e["passada"])
					JustaFases.Fase.CORRIDA: corrida_comecou.emit(e["passada"])
					JustaFases.Fase.MIRA: mira_comecou.emit(e["passada"])
					JustaFases.Fase.IMPACTO: impacto_comecou.emit(e["passada"])
			"passada":
				passada_terminou.emit(e["passada"], e["pontos_jogador"], e["pontos_rival"], e["derrubado"])
			"fim":
				justa_terminou.emit(e["vencedor"], e["motivo"], e["placar_jogador"], e["placar_rival"])

func _ao_entrar_na_fase(fase: JustaFases.Fase) -> void:
	_posicionar_cavaleiros()
	var cam := arena.camera
	match fase:
		JustaFases.Fase.APRESENTACAO:
			arena.posicionar_nas_pontas()
			cam.plano_aberto(true)
		JustaFases.Fase.LARGADA, JustaFases.Fase.FIM:
			cam.plano_aberto()
		JustaFases.Fase.CORRIDA:
			cam.seguir(arena.jogador)
		JustaFases.Fase.MIRA:
			cam.focar_alvo(arena.rival.get_node("Visual/Cavaleiro/Peito"))
		JustaFases.Fase.IMPACTO:
			var meio := (arena.jogador.centro() + arena.rival.centro()) * 0.5
			cam.focar(meio, zoom_impacto)

## Distância percorrida desde a ponta, pela fase e pelo tempo dentro dela.
## A velocidade é a que faz os dois se encontrarem no meio exatamente no fim
## da Mira (a Corrida em velocidade cheia, a Mira em câmera lenta).
## Na 1.3 a velocidade passa a vir do galope.
func distancia_percorrida() -> float:
	var encontro := absf(arena.inicio_rival.global_position.x - arena.inicio_jogador.global_position.x) * 0.5
	var corrida := float(justa.duracao_ms(JustaFases.Fase.CORRIDA))
	var mira := float(justa.duracao_ms(JustaFases.Fase.MIRA))
	var v := encontro / (corrida + camera_lenta * mira)
	var t := float(justa.tempo_na_fase_ms)
	match justa.fase:
		JustaFases.Fase.CORRIDA:
			return v * t
		JustaFases.Fase.MIRA:
			return v * (corrida + camera_lenta * t)
		JustaFases.Fase.IMPACTO:
			return encontro + v * camera_lenta * t
	return 0.0

func _posicionar_cavaleiros() -> void:
	if justa == null or justa.terminou():
		return
	var d := distancia_percorrida()
	arena.jogador.global_position = arena.inicio_jogador.global_position + Vector2(d, 0)
	arena.rival.global_position = arena.inicio_rival.global_position - Vector2(d, 0)
