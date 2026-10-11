class_name VidaVila
extends Node2D
## Vila viva (Pacote 2.6, GDD Vila viva): o que acontece em cada prédio,
## conforme ele está ocupado (timer do Jogador em andamento) ou ocioso.
##   Campo de treino: o cavaleiro do jogador, com a armadura atual, galopando
##     contra o estafermo (ocupado) ou a pé, parado ao lado (ocioso).
##   Estábulo: o cavalo do jogador escovado pelo cavalariço / comendo feno,
##     alternando; deitado quando cansado.
##   Armeiro e ferreiro: martelando com faíscas (ocupado) ou parados.
##   Casa senhorial: a bandeira com o brasão da casa no alto.
##   Arena: o arauto parado.
##   Tochas em frente aos prédios (AmbienteVila acende à noite).
## Arte provisória (camadas provisórias e desenhos por código).

const CAVALEIRO := preload("res://game/scenes/arena/cavaleiro.tscn")
const FAISCAS := preload("res://game/scenes/arena/efeitos/faiscas.tscn")

var vila: Vila
var _jog: ServicoJogador
var _cfg: Dictionary
var _t := 0.0
var _proxima_martelada := 0.0

## Elementos criados (os testes olham estes).
var cavaleiro_treino: Cavaleiro
var cavaleiro_a_pe: CamadasPersonagem
var estafermo: Estafermo
var cavalo: CamadasPersonagem
var cavalarico: CamadasPersonagem
var feno: Node2D
var armeiro: CamadasPersonagem
var ferreira: CamadasPersonagem
var mestre_armas: CamadasPersonagem
var arauto: CamadasPersonagem
var bandeira: Sprite2D
var estado_estabulo := "escovado"

func configurar(v: Vila, jog: ServicoJogador) -> void:
	vila = v
	_jog = jog
	_cfg = JSON.parse_string(FileAccess.get_file_as_string(AmbienteVila.DADOS))["vida"]
	_montar()
	atualizar()

func _montar() -> void:
	var p := func(nome: String) -> Vector2: return vila.predios[nome].position
	# Campo de treino
	var ct: Vector2 = p.call("campo_treino")
	estafermo = Estafermo.new()
	estafermo.position = ct + Vector2(0, 88)
	add_child(estafermo)
	cavaleiro_treino = CAVALEIRO.instantiate()
	cavaleiro_treino.scale = Vector2(0.38, 0.38)
	cavaleiro_treino.position = ct + Vector2(-60, 96)
	add_child(cavaleiro_treino)
	cavaleiro_a_pe = _figura(ct + Vector2(-40, 96), {})
	mestre_armas = _figura(ct + Vector2(55, 88), {"principal": "verde_floresta", "secundaria": "preto_carvao"}, true)
	# Estábulo
	var es: Vector2 = p.call("estabulo")
	cavalo = CamadasPersonagem.new()
	cavalo.tamanho = "justa"
	cavalo.scale = Vector2(0.4, 0.4)
	cavalo.position = es + Vector2(10, 92)
	add_child(cavalo)
	feno = Feno.new()
	feno.position = es + Vector2(42, 92)
	add_child(feno)
	cavalarico = _figura(es + Vector2(-26, 92), {"principal": "preto_carvao", "secundaria": "ouro_velho"}, true)
	# Armeiro e ferreiro
	armeiro = _figura(p.call("armeiro") + Vector2(-30, 84), {"principal": "azul_real", "secundaria": "prata"}, true)
	ferreira = _figura(p.call("ferreiro") + Vector2(-26, 82), {"principal": "vermelho_sangue", "secundaria": "preto_carvao"}, true)
	var bigorna := Bigorna.new()
	bigorna.position = p.call("armeiro") + Vector2(-8, 84)
	add_child(bigorna)
	var forja := Bigorna.new()
	forja.position = p.call("ferreiro") + Vector2(-4, 82)
	add_child(forja)
	# Arena e casa senhorial
	arauto = _figura(p.call("arena") + Vector2(-70, 96), {"principal": "ouro_velho", "secundaria": "vermelho_sangue"}, true)
	var cs: Vector2 = p.call("casa_senhorial")
	var mastro := Mastro.new()
	mastro.position = cs + Vector2(64, -20)
	add_child(mastro)
	bandeira = Sprite2D.new()
	bandeira.centered = false
	bandeira.position = mastro.position + Vector2(1, -58)
	add_child(bandeira)
	# Tochas em frente aos prédios
	for nome: String in vila.predios:
		var t := Tocha.new()
		t.position = vila.predios[nome].position + Vector2(vila.predios[nome].tamanho.x * 0.5 + 8, 36)
		add_child(t)

## Figura a pé (camadas da vila); NPC sem elmo nem escudo.
func _figura(pos: Vector2, casa: Dictionary, npc := false) -> CamadasPersonagem:
	var f := CamadasPersonagem.new()
	f.tamanho = "vila"
	f.position = pos
	f.scale = Vector2(0.75, 0.75)
	add_child(f)
	if npc:
		f.definir_casa(casa)
		f.vestir({"elmo": "nenhum", "escudo": "nenhum"})
	return f

## Recalcula quem aparece e o que faz, pelos dados do jogador.
func atualizar() -> void:
	var treinando := ocupado("campo_treino")
	AparenciaJogador.vestir_cavaleiro(cavaleiro_treino, _jog)
	AparenciaJogador.vestir_camadas(cavaleiro_a_pe, _jog)
	cavaleiro_treino.visible = treinando
	cavaleiro_a_pe.visible = not treinando
	mestre_armas.visible = not treinando
	if treinando:
		cavaleiro_treino.animar("galope")
	# Estábulo
	var pecas_cavalo := {"pelagem": _jog.cavalo_ativo().get("pelagem", "alazao")}
	for k in ["caparacao", "corpo", "pernas", "peitoral", "sobreveste", "elmo", "cimeira", "escudo", "lanca"]:
		pecas_cavalo[k] = "nenhum"
	cavalo.vestir(pecas_cavalo)
	var cansado := _jog.cavalo_cansado()
	estado_estabulo = "deitado" if cansado else ("escovado" if int(_t / float(_cfg["estabulo_troca_s"])) % 2 == 0 else "comendo")
	cavalo.rotation_degrees = 0.0
	cavalo.scale = Vector2(0.4, 0.4) if not cansado else Vector2(0.4, 0.26)
	cavalarico.visible = estado_estabulo == "escovado"
	feno.visible = estado_estabulo == "comendo"
	# Bandeira da casa
	bandeira.texture = GeradorBrasao.textura(AparenciaJogador.brasao(_jog), Vector2i(14, 20), false)

func ocupado(nome: String) -> bool:
	var t := _jog.timer_do_predio(nome)
	return not t.is_empty() and not ServicoTempo.pronto(int(t["termina_em"]))

func _process(delta: float) -> void:
	_t += delta
	if cavaleiro_treino and cavaleiro_treino.visible:
		# Ida e volta passando pelo estafermo; o braço gira na passada.
		var volta := float(_cfg["treino_volta_s"])
		var fase := fmod(_t, volta) / volta
		var ida := fase < 0.5
		var k := fase * 2.0 if ida else (1.0 - fase) * 2.0
		var ct: Vector2 = vila.predios["campo_treino"].position
		cavaleiro_treino.position = ct + Vector2(lerpf(-70, 70, k), 96)
		cavaleiro_treino.direcao = 1 if ida else -1
		if absf(k - 0.5) < 0.03:
			estafermo.girar()
	var es_antes := estado_estabulo
	if not _jog.cavalo_cansado():
		estado_estabulo = "escovado" if int(_t / float(_cfg["estabulo_troca_s"])) % 2 == 0 else "comendo"
		if es_antes != estado_estabulo:
			cavalarico.visible = estado_estabulo == "escovado"
			feno.visible = estado_estabulo == "comendo"
	if cavalarico and cavalarico.visible:
		cavalarico.position.y = vila.predios["estabulo"].position.y + 92 + sin(_t * 6.0) * 1.5
	_martelar(delta)

## Armeiro e ferreiro martelam (faíscas) quando o prédio está ocupado.
func _martelar(delta: float) -> void:
	_proxima_martelada -= delta
	if _proxima_martelada > 0.0:
		return
	_proxima_martelada = float(_cfg["martelo_s"])
	for par: Array in [["armeiro", armeiro], ["ferreiro", ferreira]]:
		var npc: CamadasPersonagem = par[1]
		if ocupado(par[0]):
			npc.tocar("andar")
			var f := FAISCAS.instantiate() as CPUParticles2D
			f.amount = 6
			f.direction = Vector2(0, -1)
			add_child(f)
			f.global_position = npc.global_position + Vector2(20, -8)
			f.emitting = true
			f.finished.connect(f.queue_free)
		else:
			npc.tocar("parado")

## Estafermo provisório: poste com braço que gira quando a lança acerta.
class Estafermo extends Node2D:
	var angulo := 0.0
	var _vel := 0.0

	func girar() -> void:
		_vel = 14.0

	func _process(delta: float) -> void:
		if _vel > 0.0:
			angulo += _vel * delta
			_vel = maxf(_vel - 10.0 * delta, 0.0)
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-2, -34, 4, 34), Color(0.35, 0.24, 0.14))
		var braco := Vector2(cos(angulo), sin(angulo) * 0.3) * 16
		draw_line(Vector2(0, -32) - braco, Vector2(0, -32) + braco, Color(0.4, 0.28, 0.16), 3)
		draw_rect(Rect2((Vector2(0, -32) + braco) - Vector2(4, 5), Vector2(8, 10)), Color(0.6, 0.5, 0.3))
		draw_circle(Vector2(0, -32) - braco, 3, Color(0.3, 0.3, 0.32))

class Feno extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-9, -8, 18, 8), Color(0.75, 0.62, 0.3))
		draw_rect(Rect2(-9, -8, 18, 2), Color(0.85, 0.72, 0.4))

class Bigorna extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-7, -8, 14, 4), Color(0.32, 0.32, 0.36))
		draw_rect(Rect2(-3, -4, 6, 4), Color(0.26, 0.26, 0.3))

class Mastro extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-1, -60, 2, 60), Color(0.3, 0.22, 0.14))
