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
## Largada, galopa na Corrida.

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
signal passada_terminou(passada: int, pontos_jogador: int, pontos_rival: int, derrubado: JustaFases.Lado)
signal justa_terminou(vencedor: JustaFases.Lado, motivo: String, placar_jogador: int, placar_rival: int)

@export var arena: Arena
@export var barra: BarraDistancia
@export var iniciar_sozinho := true
## Velocidade dos cavaleiros na Mira e no Impacto em relação à Corrida
## (câmera lenta). Ajuste visual: o tempo de jogo da Mira não muda.
@export_range(0.05, 1.0, 0.05) var camera_lenta := 0.3
## Zoom do close do Impacto: precisa caber os dois cavaleiros inteiros.
@export var zoom_impacto := 1.5

var justa: Justa
## Atributos dos cavalos. Até a 2.4 (dados do jogador), o cavalo padrão dos dados.
var cavalo_jogador: Dictionary
var cavalo_rival: Dictionary
## Semente da justa (no servidor, Parte 3, quem sorteia é ele).
var semente := 0

var _resto_ms := 0.0
var _px_por_mil := 0.0
var _fim_corrida_j := 0.0  ## distâncias em px no fim da Corrida (para a Mira)
var _fim_corrida_r := 0.0
var _encontro_j := 0.0
var _encontro_r := 0.0

func _ready() -> void:
	if iniciar_sozinho:
		iniciar.call_deferred()

## Começa uma justa nova com os dados de game/data/balance/.
## `semente_fixa` < 0 sorteia uma.
func iniciar(semente_fixa := -1) -> void:
	var cj := Balanceamento.carregar("justa")
	var cg := Balanceamento.carregar("galope")
	var erro := Justa.validar(cj, cg)
	if erro != "":
		push_error("ControladorJusta: " + erro)
		set_process(false)
		return
	if cavalo_jogador.is_empty():
		cavalo_jogador = cg["cavalo_padrao"]
	if cavalo_rival.is_empty():
		cavalo_rival = cg["cavalo_padrao"]
	semente = semente_fixa if semente_fixa >= 0 else randi()
	justa = Justa.new(cj, cg, cavalo_jogador, cavalo_rival, semente)
	var vao := absf(arena.inicio_rival.global_position.x - arena.inicio_jogador.global_position.x)
	_px_por_mil = vao / float(justa.distancia_total_mil())
	_resto_ms = 0.0
	set_process(true)
	_despachar(justa.iniciar())

## Toque do jogador (qualquer ponto da tela).
func tocar() -> void:
	if justa and not justa.terminou():
		_despachar(justa.tocar())

## Resultado da passada atual (vem da regra do impacto, prompt 1.5).
func registrar_resultado(pontos_jogador: int, pontos_rival: int, derrubado := JustaFases.Lado.NENHUM) -> bool:
	return justa != null and justa.fases.registrar_resultado(pontos_jogador, pontos_rival, derrubado)

func fase() -> JustaFases.Fase:
	return justa.fases.fase if justa else JustaFases.Fase.FIM

func _process(delta: float) -> void:
	if justa == null or justa.terminou():
		return
	_resto_ms += delta * 1000.0
	var ms := int(_resto_ms)
	_resto_ms -= ms
	_despachar(justa.avancar(ms))
	_atualizar_visual()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		tocar()
		get_viewport().set_input_as_handled()

func _despachar(eventos: Array[Dictionary]) -> void:
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
			"passada":
				passada_terminou.emit(p, e["pontos_jogador"], e["pontos_rival"], e["derrubado"])
			"fim":
				justa_terminou.emit(e["vencedor"], e["motivo"], e["placar_jogador"], e["placar_rival"])

func _ao_entrar_na_fase(nova: JustaFases.Fase) -> void:
	var cam := arena.camera
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
		JustaFases.Fase.IMPACTO:
			var meio := (arena.jogador.centro() + arena.rival.centro()) * 0.5
			cam.focar(meio, zoom_impacto)
	_atualizar_visual()

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
	if justa == null:
		return
	var d := distancias_px()
	arena.jogador.global_position = arena.inicio_jogador.global_position + Vector2(d.x, 0)
	arena.rival.global_position = arena.inicio_rival.global_position - Vector2(d.y, 0)
	if barra == null:
		return
	var total := justa.distancia_total_mil() * _px_por_mil
	barra.posicao_jogador = d.x / total
	barra.posicao_rival = 1.0 - d.y / total
	barra.brilho = _brilho_do_compasso()

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
