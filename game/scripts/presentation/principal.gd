extends Node
## Cena principal: só pergunta ao Fluxo para onde ir (título, passo do
## tutorial salvo ou vila).

func _ready() -> void:
	var f := get_node_or_null("/root/Fluxo") as FluxoTelas
	if f:
		f.iniciar_jogo.call_deferred()
