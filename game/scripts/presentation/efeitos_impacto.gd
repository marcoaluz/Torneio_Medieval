class_name EfeitosImpacto
extends Node
## Sensação de impacto da justa (Pacote 1.8): hit-stop, tremor de câmera
## proporcional à força, lascas de madeira da lança, faíscas no metal, peça de
## armadura voando quando o dano é alto, vibração opcional do celular e o
## cavaleiro caindo na derrubada. Só escuta os sinais do ControladorJusta;
## intensidades em game/data/balance/sensacao.json.

const LASCAS := preload("res://game/scenes/arena/efeitos/lascas.tscn")
const FAISCAS := preload("res://game/scenes/arena/efeitos/faiscas.tscn")

@export var controlador: ControladorJusta
## Vibração do celular (opcional; a opção do jogador entra nas configurações).
@export var vibrar := true

var _cfg: Dictionary
var _hit_stop_ativo := false

func _ready() -> void:
	_cfg = Balanceamento.carregar("sensacao")
	if controlador:
		controlador.impacto_resolvido.connect(_ao_impacto)
		controlador.habilidade_ativada.connect(_ao_ativar_habilidade)
		controlador.justa_terminou.connect(func(v, _m, _a, _b): if v == JustaFases.Lado.JOGADOR: reagir_torcida(true))
		controlador.apresentacao_comecou.connect(_ao_comecar_passada)

## Força de um golpe, de 0 a 1 (dano / referência; derrubada = 1).
func forca_do_golpe(res: Dictionary) -> float:
	if res["derrubou"]:
		return 1.0
	var dano := 0
	for peca: String in res["dano"]:
		dano += int(res["dano"][peca])
	return clampf(float(dano) / float(_cfg["dano_referencia"]), 0.0, 1.0)

func _ao_comecar_passada(_p: int) -> void:
	var a := controlador.arena
	a.jogador.restaurar()
	a.rival.restaurar()

func _ao_impacto(_p: int, jog: Dictionary, riv: Dictionary, _d: JustaFases.Lado, _q: JustaFases.Lado) -> void:
	var a := controlador.arena
	# jog = golpe do jogador NO rival; riv = golpe do rival NO jogador.
	# Passiva que disparou (GDD): o escudo do defensor pisca.
	if str(jog.get("habilidade_bloqueio", "")) != "":
		_piscar_escudo(a.rival)
	if str(riv.get("habilidade_bloqueio", "")) != "":
		_piscar_escudo(a.jogador)
	var fj := _golpe(jog, a.jogador, a.rival)
	var fr := _golpe(riv, a.rival, a.jogador)
	if int(jog["pontos"]) > 0 or jog["derrubou"]:
		reagir_torcida(jog["derrubou"])
	var forca := maxf(fj, fr)
	if forca <= 0.0:
		return
	var t: Dictionary = _cfg["tremor"]
	var trauma := lerpf(float(t["trauma_min"]), float(t["trauma_max"]), forca)
	if jog["derrubou"] or riv["derrubou"]:
		trauma = float(t["trauma_derrubada"])
	a.camera.tremer(trauma)
	_vibrar(forca)
	_hit_stop(forca)

## Ativa (GDD): brilho e rastro no cavaleiro que acionou.
func _ao_ativar_habilidade(_p: int, lado: String, _nome: String) -> void:
	var a := controlador.arena
	var c: Cavaleiro = a.jogador if lado == "jogador" else a.rival
	var h: Dictionary = _cfg["habilidade"]
	var t := c.create_tween()
	t.tween_property(c.visual(), "modulate", Color(h["cor_brilho"]), float(h["brilho_s"]) * 0.25)
	t.tween_property(c.visual(), "modulate", Color.WHITE, float(h["brilho_s"]) * 0.75)
	var r := CPUParticles2D.new()
	r.name = "Rastro"
	r.amount = int(h["rastro_quantidade"])
	r.lifetime = float(h["rastro_s"])
	r.local_coords = false
	r.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	r.emission_rect_extents = Vector2(20, 40)
	r.gravity = Vector2.ZERO
	r.initial_velocity_min = 0.0
	r.initial_velocity_max = 10.0
	r.scale_amount_min = 2.0
	r.scale_amount_max = 4.0
	r.color = Color(h["cor_rastro"])
	r.position = Vector2(0, -90)
	c.add_child(r)
	r.emitting = true
	get_tree().create_timer(float(h["rastro_s"]) * 2.0).timeout.connect(func():
		if is_instance_valid(r):
			r.emitting = false
			r.queue_free())

## Torcida (3.21): a arquibancada pula e solta flâmulas; quanto maior o
## renome do jogador, mais forte (metas.json > renome).
func reagir_torcida(forte: bool) -> void:
	var jog := get_node_or_null("/root/Jogador") as ServicoJogador
	if jog == null or controlador.modo == "exibicao":
		return
	var t: Dictionary = Balanceamento.carregar("metas")["renome"]["torcida"]
	var nivel := int(jog.faixa_renome()["torcida"]) + (1 if forte else 0)
	var arq: Node2D = controlador.arena.get_node("Fundo/Arquibancada")
	var y0 := arq.position.y
	var tw := arq.create_tween()
	for i in int(t["pulos"]):
		tw.tween_property(arq, "position:y", y0 - float(t["pulo_px_por_nivel"]) * nivel, 0.08)
		tw.tween_property(arq, "position:y", y0, 0.1)
	var f := CPUParticles2D.new()
	f.name = "Flamulas"
	f.one_shot = true
	f.explosiveness = 0.8
	f.amount = maxi(1, roundi(int(t["flamulas_por_nivel"]) * nivel * OpcoesAcessibilidade.fator(self)))
	f.lifetime = 1.4
	f.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	f.emission_rect_extents = Vector2(600, 20)
	f.position = Vector2(480, 120)
	f.direction = Vector2(0, -1)
	f.spread = 40.0
	f.initial_velocity_min = 80.0
	f.initial_velocity_max = 160.0
	f.gravity = Vector2(0, 200)
	f.scale_amount_min = 2.0
	f.scale_amount_max = 4.0
	f.color_ramp = null
	f.hue_variation_min = -1.0
	f.hue_variation_max = 1.0
	f.color = Color(controlador.arena.jogador.cor_casa)
	# Cor da comemoração comprada na loja (cosmético, 3.18).
	var vit := str(jog.estado.get("loja", {}).get("vitoria", ""))
	for c: Dictionary in Balanceamento.ler("loja")["cosmeticos"]:
		if c["id"] == vit and c.has("cor"):
			f.color = Color(c["cor"])
	arq.add_child(f)
	f.emitting = true
	f.finished.connect(f.queue_free)

func _piscar_escudo(c: Cavaleiro) -> void:
	var no := c.no_da_zona("escudo")
	if no == null:
		return
	var h: Dictionary = _cfg["habilidade"]
	var t := no.create_tween().set_loops(int(h["escudo_piscadas"]))
	t.tween_property(no, "modulate", Color(h["cor_escudo"]), 0.06)
	t.tween_property(no, "modulate", Color.WHITE, 0.06)

## Efeitos de um golpe de `atacante` em `alvo`. Devolve a força (0 se não houve contato).
func _golpe(res: Dictionary, atacante: Cavaleiro, alvo: Cavaleiro) -> float:
	var zona: String = res["zona_final"]
	if zona == Mira.ERRO:
		return 0.0
	var forca := forca_do_golpe(res)
	var no := alvo.no_da_zona(zona)
	var ponto := no.global_position if no else alvo.centro()
	var direcao := Vector2(float(atacante.direcao), -0.3)
	atacante.quebrar_lanca(float(_cfg["lanca_quebrada_escala"]))
	var l: Dictionary = _cfg["lascas"]
	_particulas(LASCAS, ponto, direcao, int(lerpf(float(l["quantidade_min"]), float(l["quantidade_max"]), forca)))
	var f: Dictionary = _cfg["faiscas"]
	if f["zonas"].has(zona):
		_particulas(FAISCAS, ponto, direcao, int(lerpf(float(f["quantidade_min"]), float(f["quantidade_max"]), forca)))
	var pv: Dictionary = _cfg["peca_voando"]
	for peca: String in res["dano"]:
		if int(res["dano"][peca]) >= int(pv["dano_minimo"]) and no:
			_peca_voando(no, atacante.direcao)
	if res["derrubou"]:
		var q: Dictionary = _cfg["queda"]
		alvo.cair(float(q["duracao_ms"]) / 1000.0, float(q["giro_graus"]), float(q["distancia_px"]))
	return forca

func _particulas(cena: PackedScene, ponto: Vector2, direcao: Vector2, quantidade: int) -> void:
	quantidade = maxi(1, roundi(quantidade * OpcoesAcessibilidade.fator(self)))
	var p := cena.instantiate() as CPUParticles2D
	p.amount = maxi(quantidade, 1)
	p.direction = direcao
	controlador.arena.add_child(p)
	p.global_position = ponto
	p.emitting = true
	p.finished.connect(p.queue_free)

## Copia o desenho da peça atingida e joga para longe, girando e sumindo.
func _peca_voando(no: Node2D, direcao: int) -> void:
	var pv: Dictionary = _cfg["peca_voando"]
	var copia := no.duplicate() as Node2D
	controlador.arena.add_child(copia)
	copia.global_transform = no.global_transform
	copia.z_index = 15
	for filho in copia.get_children():
		if filho.name == "Brasao":
			filho.queue_free()
	var dur := float(pv["duracao_ms"]) / 1000.0
	var destino := copia.global_position + Vector2(float(direcao) * float(pv["distancia_px"]), 0.0)
	var t := create_tween().set_parallel(true)
	t.tween_property(copia, "global_position:x", destino.x, dur)
	t.tween_property(copia, "global_position:y", copia.global_position.y - float(pv["altura_px"]), dur * 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(copia, "global_position:y", copia.global_position.y + float(pv["altura_px"]), dur * 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(dur * 0.4)
	t.tween_property(copia, "rotation", copia.rotation + TAU * float(direcao), dur)
	t.tween_property(copia, "modulate:a", 0.0, dur * 0.3).set_delay(dur * 0.7)
	t.chain().tween_callback(copia.queue_free)

## Congela o jogo por alguns ms (o timer ignora a escala de tempo).
func _hit_stop(forca: float) -> void:
	if _hit_stop_ativo:
		return
	var h: Dictionary = _cfg["hit_stop"]
	var ms := lerpf(float(h["ms_min"]), float(h["ms_max"]), forca)
	_hit_stop_ativo = true
	Engine.time_scale = float(h["escala_tempo"])
	await get_tree().create_timer(ms / 1000.0, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stop_ativo = false

func _vibrar(forca: float) -> void:
	var ac := get_node_or_null("/root/Acessibilidade") as OpcoesAcessibilidade
	if not vibrar or (ac and not ac.vibracao()):
		return
	var v: Dictionary = _cfg["vibracao"]
	Input.vibrate_handheld(int(lerpf(float(v["ms_min"]), float(v["ms_max"]), forca)))

func hit_stop_ativo() -> bool:
	return _hit_stop_ativo
