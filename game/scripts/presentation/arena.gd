class_name Arena
extends Node2D
## Cena da justa (apresentação): cenário, pistas, cavaleiros e câmera.
## Vista lateral elevada: a cerca corta a tela ao meio; o jogador corre na
## pista de baixo para a direita, o rival na de cima para a esquerda,
## espelhado e um pouco menor. A ordem dos nós é a ordem de desenho:
## fundo, rival, cerca, jogador.
##
## Para trocar a arte: Fundo/Ceu, Fundo/Arquibancada, Fundo/Chao e Cerca são
## encaixes; apague o nó provisório de dentro e ponha o Sprite2D no lugar.

## Escala do rival em relação ao jogador (perspectiva). Ajuste visual, não
## de jogo.
@export_range(0.5, 1.0, 0.05) var escala_rival := 0.85

@onready var jogador: Cavaleiro = $Jogador
@onready var rival: Cavaleiro = $Rival
@onready var camera: CameraArena = $Camera
@onready var arauto: Arauto = $Arauto
@onready var ponta_lanca: Node2D = $PontaLanca
@onready var inicio_jogador: Marker2D = $Pistas/Jogador/Inicio
@onready var fim_jogador: Marker2D = $Pistas/Jogador/Fim
@onready var inicio_rival: Marker2D = $Pistas/Rival/Inicio
@onready var fim_rival: Marker2D = $Pistas/Rival/Fim
@onready var cerca: Node2D = $Cerca

func _ready() -> void:
	jogador.direcao = 1
	jogador.escala = 1.0
	vestir_jogador()
	rival.direcao = -1
	rival.escala = escala_rival
	posicionar_nas_pontas()
	camera.plano_aberto(true)
	# Carrega já as animações (galope etc.) para a corrida não travar (3.25).
	for c: Cavaleiro in [jogador, rival]:
		if c.camadas():
			c.camadas().pre_carregar()

## Aparência do cavaleiro do jogador a partir dos dados do jogador (se houver).
func vestir_jogador() -> void:
	var jog := get_node_or_null("/root/Jogador") as ServicoJogador
	if jog:
		AparenciaJogador.vestir_cavaleiro(jogador, jog)

## Brasão do rival pelo perfil da IA (game/data/crests/brasao.json, "rivais").
func vestir_rival(perfil: String) -> void:
	var rivais: Dictionary = GeradorBrasao.opcoes().get("rivais", {})
	rival.definir_brasao(rivais.get(perfil, {}))

## Ambiente dos desafios especiais (só visual; a regra já mudou nos dados):
## "noite" escurece o mundo (a interface não), "chuva" cria as gotas.
## Cores e quantidades em game/data/arena/ambiente.json.
func aplicar_ambiente(visuais: Array) -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/arena/ambiente.json"))
	var cor := Color.WHITE
	for v: String in visuais:
		if cfg.has(v):
			cor *= Color(cfg[v]["cor_mundo"])
	if cor != Color.WHITE:
		var mod := CanvasModulate.new()
		mod.name = "Ambiente"
		mod.color = cor
		add_child(mod)
	if visuais.has("chuva"):
		var img := Image.create(1, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(cfg["chuva"]["cor_gota"]))
		var gotas := CPUParticles2D.new()
		gotas.name = "Chuva"
		gotas.texture = ImageTexture.create_from_image(img)
		gotas.amount = int(cfg["chuva"]["gotas"])
		gotas.lifetime = 0.7
		gotas.preprocess = 1.0
		gotas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		gotas.emission_rect_extents = Vector2(700, 10)
		gotas.position = Vector2(480, -40)
		gotas.direction = Vector2(-0.15, 1)
		gotas.spread = 2.0
		gotas.gravity = Vector2(0, 600)
		gotas.initial_velocity_min = 500.0
		gotas.initial_velocity_max = 650.0
		gotas.z_index = 50
		add_child(gotas)

## Coloca os dois cavaleiros parados no começo das pistas (Apresentação).
func posicionar_nas_pontas() -> void:
	jogador.global_position = inicio_jogador.global_position
	rival.global_position = inicio_rival.global_position
