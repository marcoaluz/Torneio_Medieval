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

## Aparência do cavaleiro do jogador a partir dos dados do jogador (se houver).
func vestir_jogador() -> void:
	var jog := get_node_or_null("/root/Jogador") as ServicoJogador
	if jog == null:
		return
	var cav := jog.cavaleiro()
	var cores: Dictionary = jog.casa()["cores"]
	jogador.definir_casa({"principal": cores["principal"], "secundaria": cores["secundaria"], "metal": cores.get("metal", "ferro"),
		"pele": cav.get("pele", "media"), "cabelo": cav.get("cor_cabelo", "castanho")})
	var pecas := jog.visual_das_pecas()
	pecas["pelagem"] = jog.cavalo_ativo().get("pelagem", "alazao")
	pecas["corpo"] = cav.get("corpo", "masculino")
	jogador.camadas().vestir(pecas)
	var b: Dictionary = jog.casa().get("brasao", {})
	if b.is_empty():
		b = {"cor1": cores["principal"], "cor2": cores["secundaria"], "cor_simbolo": cores["secundaria"]}
	jogador.definir_brasao(b)

## Brasão do rival pelo perfil da IA (game/data/crests/brasao.json, "rivais").
func vestir_rival(perfil: String) -> void:
	var rivais: Dictionary = GeradorBrasao.opcoes().get("rivais", {})
	rival.definir_brasao(rivais.get(perfil, {}))

## Coloca os dois cavaleiros parados no começo das pistas (Apresentação).
func posicionar_nas_pontas() -> void:
	jogador.global_position = inicio_jogador.global_position
	rival.global_position = inicio_rival.global_position
