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
@onready var inicio_jogador: Marker2D = $Pistas/Jogador/Inicio
@onready var fim_jogador: Marker2D = $Pistas/Jogador/Fim
@onready var inicio_rival: Marker2D = $Pistas/Rival/Inicio
@onready var fim_rival: Marker2D = $Pistas/Rival/Fim
@onready var cerca: Node2D = $Cerca

func _ready() -> void:
	jogador.direcao = 1
	jogador.escala = 1.0
	rival.direcao = -1
	rival.escala = escala_rival
	posicionar_nas_pontas()
	camera.plano_aberto(true)

## Coloca os dois cavaleiros parados no começo das pistas (Apresentação).
func posicionar_nas_pontas() -> void:
	jogador.global_position = inicio_jogador.global_position
	rival.global_position = inicio_rival.global_position
