class_name AmbienteVila
extends Node2D
## Ambiente da vila (Pacote 2.6): cor do mundo pela hora do celular (dia,
## entardecer, noite), tochas acesas à noite e clima sorteado uma vez por dia
## (limpo, nublado, chuva, neblina). Só apresentação; números em
## game/data/vila/ambiente.json. A interface (CanvasLayer) não escurece.

const DADOS := "res://game/data/vila/ambiente.json"

## Hora fixa para testes e capturas (0 a 24; < 0 = relógio do celular).
@export var hora_forcada := -1.0
## Clima fixo para testes e capturas ("" = sorteio do dia).
@export var clima_forcado := ""

var clima := "limpo"
var _cfg: Dictionary
var _modulador: CanvasModulate
var _chuva: CPUParticles2D
var _neblina: Node2D
var _acumulado := 1.0

func _ready() -> void:
	_cfg = JSON.parse_string(FileAccess.get_file_as_string(DADOS))
	_modulador = CanvasModulate.new()
	add_child(_modulador)
	clima = clima_forcado if clima_forcado != "" else sortear_clima(_cfg, _dia_de_hoje())
	match clima:
		"chuva": _criar_chuva()
		"neblina": _criar_neblina()
	_aplicar()
	# Som da chuva só com chuva (skill som: o som acompanha o estado visual).
	var audio := get_node_or_null("/root/Audio") as ServicoAudio
	if audio:
		audio.laco("chuva_vila", clima == "chuva")
		tree_exiting.connect(func(): audio.laco("chuva_vila", false))

func _process(delta: float) -> void:
	_acumulado += delta
	if _acumulado >= 1.0:
		_acumulado = 0.0
		_aplicar()

func hora_atual() -> float:
	if hora_forcada >= 0.0:
		return hora_forcada
	var t := Time.get_time_dict_from_system()
	return float(t["hour"]) + float(t["minute"]) / 60.0

func tochas_acesas() -> bool:
	var h := hora_atual()
	var t: Dictionary = _cfg["tochas"]
	return h >= float(t["acende"]) or h < float(t["apaga"])

## Cor do mundo na hora `h`, interpolada entre as marcas, escurecida pelo clima.
func cor_da_hora(h: float) -> Color:
	var marcas: Array = _cfg["cores_por_hora"]
	var cor := Color(marcas[0][1])
	for i in marcas.size() - 1:
		var a: Array = marcas[i]
		var b: Array = marcas[i + 1]
		if h >= float(a[0]) and h <= float(b[0]):
			var k := (h - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001)
			cor = Color(a[1]).lerp(Color(b[1]), k)
			break
	var esc := float(_cfg["clima"]["escurecer"].get(clima, 1.0))
	return Color(cor.r * esc, cor.g * esc, cor.b * esc, 1.0)

## Clima do dia: sorteio com pesos e semente = o dia (fica o mesmo o dia todo).
static func sortear_clima(cfg: Dictionary, dia: int) -> String:
	var pesos: Dictionary = cfg["clima"]["pesos"]
	var total := 0
	for k: String in pesos:
		total += int(pesos[k])
	var rng := RandomNumberGenerator.new()
	rng.seed = dia
	var r := rng.randi_range(0, total - 1)
	for k: String in pesos:
		r -= int(pesos[k])
		if r < 0:
			return k
	return "limpo"

func _aplicar() -> void:
	_modulador.color = cor_da_hora(hora_atual())
	var acesas := tochas_acesas()
	for t in get_tree().get_nodes_in_group("tocha"):
		t.acesa = acesas

static func _dia_de_hoje() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)

func _criar_chuva() -> void:
	var img := Image.create_empty(1, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.75, 0.8, 0.9, 0.6))
	_chuva = CPUParticles2D.new()
	_chuva.texture = ImageTexture.create_from_image(img)
	_chuva.amount = maxi(1, roundi(int(_cfg["clima"]["chuva_gotas"]) * OpcoesAcessibilidade.fator(self)))
	_chuva.lifetime = 0.7
	_chuva.preprocess = 1.0
	_chuva.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_chuva.emission_rect_extents = Vector2(700, 10)
	_chuva.position = Vector2(480, -20)
	_chuva.direction = Vector2(-0.15, 1)
	_chuva.spread = 2.0
	_chuva.gravity = Vector2(0, 600)
	_chuva.initial_velocity_min = 500.0
	_chuva.initial_velocity_max = 650.0
	_chuva.particle_flag_align_y = true
	_chuva.z_index = 50
	add_child(_chuva)

func _criar_neblina() -> void:
	_neblina = NeblinaProvisoria.new()
	_neblina.manchas = int(_cfg["clima"]["neblina_manchas"])
	_neblina.z_index = 49
	add_child(_neblina)

## Neblina provisória: manchas claras e transparentes andando devagar.
class NeblinaProvisoria extends Node2D:
	var manchas := 8
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for i in manchas:
			var h := hash(i * 31 + 7)
			var base := Vector2(float(h % 1280) - 160.0, float((h / 13) % 540))
			var p := base + Vector2(fmod(_t * (6.0 + float(h % 5)), 1400.0), 0.0)
			p.x = fmod(p.x + 160.0, 1440.0) - 240.0
			for r in [140.0, 100.0, 60.0]:
				draw_circle(p, r, Color(0.85, 0.87, 0.9, 0.05))
