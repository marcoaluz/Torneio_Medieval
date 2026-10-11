class_name TelaTitulo
extends Control
## Tela de título (início do jogo): Começar, ou pular o tutorial para quem
## já jogou (reinstalou). Avisa o Fluxo.

func _ready() -> void:
	$Coluna/Titulo.text = tr("JOGO_TITULO")
	$Coluna/Comecar.text = tr("INICIO_COMECAR")
	$Coluna/Pular.text = tr("INICIO_PULAR_TUTORIAL")
	$Coluna/Comecar.pressed.connect(comecar)
	$Coluna/Pular.pressed.connect(pular)

func comecar() -> void:
	var f := get_node_or_null("/root/Fluxo") as FluxoTelas
	if f:
		f.concluiu("titulo")

func pular() -> void:
	var f := get_node_or_null("/root/Fluxo") as FluxoTelas
	if f:
		f.pular_tutorial()
