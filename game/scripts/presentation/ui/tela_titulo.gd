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

const CENA_PRIVACIDADE := preload("res://game/scenes/ui/tela_privacidade.tscn")

func comecar() -> void:
	_com_privacidade(func():
		var f := get_node_or_null("/root/Fluxo") as FluxoTelas
		if f:
			f.concluiu("titulo"))

func pular() -> void:
	_com_privacidade(func():
		var f := get_node_or_null("/root/Fluxo") as FluxoTelas
		if f:
			f.pular_tutorial())

## Política de privacidade e termos (3.9): precisa do aceite da versão atual
## antes de começar; depois disso segue direto.
func _com_privacidade(depois: Callable) -> void:
	var jog := get_node_or_null("/root/Jogador") as ServicoJogador
	if jog == null or jog.privacidade_aceita():
		depois.call()
		return
	var t: TelaPrivacidade = CENA_PRIVACIDADE.instantiate()
	t.aceita.connect(func(_p): depois.call())
	add_child(t)
