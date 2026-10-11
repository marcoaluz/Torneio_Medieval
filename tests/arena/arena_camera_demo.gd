extends Node
## Demonstração dos planos da câmera para o `driver.sh shot`. Escolha o plano
## pela variável de ambiente TM_CAMERA: aberto (padrão), seguir ou focar.
## "seguir" põe o jogador correndo pela pista; "focar" dá zoom no peito do rival.
## Os números daqui são só de teste.

@onready var arena: Arena = $Arena

func _ready() -> void:
	var plano := OS.get_environment("TM_CAMERA")
	print("DEMO plano=%s" % (plano if plano != "" else "aberto"))
	match plano:
		"seguir":
			arena.jogador.global_position.x = 300.0
			arena.camera.seguir(arena.jogador)
		"focar":
			arena.camera.focar(arena.rival.ponto_alvo("Peito"))

func _process(delta: float) -> void:
	if arena.camera.plano == CameraArena.Plano.SEGUIR:
		arena.jogador.global_position.x += 220.0 * delta
