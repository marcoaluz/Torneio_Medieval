extends Node
## Demonstração para o `driver.sh shot`: a arena com o painel de ajuste aberto.

func _ready() -> void:
	($Arena/PainelAjuste as PainelAjuste).abrir.call_deferred()
