extends Node
## Cena principal: entra na nuvem (se configurada; acerta o save entre
## celular e conta) e pergunta ao Fluxo para onde ir (título, passo do
## tutorial salvo ou vila). Sem rede, segue com o save local.

func _ready() -> void:
	_abrir.call_deferred()

func _abrir() -> void:
	var nuvem := get_node_or_null("/root/Nuvem") as ServicoNuvem
	if nuvem and nuvem.configurado():
		await nuvem.iniciar()
	var f := get_node_or_null("/root/Fluxo") as FluxoTelas
	if f:
		f.iniciar_jogo()
