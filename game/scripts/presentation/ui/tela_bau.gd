class_name TelaBau
extends Control
## Primeiro baú do início do jogo (GDD: abre na hora, com a primeira peça de
## armadura, que já aparece equipada). A recompensa do tutorial é dada pelo
## serviço Jogador (uma vez só); a tela mostra o baú abrindo, a peça e o
## cavaleiro já com ela. O sistema de baús completo é da 3.14.

var resultado := {}

@onready var _bau: Node2D = $Bau
@onready var _texto: Label = $Coluna/Texto
@onready var _seguir: Button = $Coluna/Seguir
@onready var _retrato: CamadasPersonagem = $Retrato

func _ready() -> void:
	$Titulo.text = tr("BAU_TITULO")
	_seguir.text = tr("BAU_SEGUIR")
	_seguir.visible = false
	_retrato.visible = false
	_texto.text = tr("BAU_TOQUE_PARA_ABRIR")
	_seguir.pressed.connect(func():
		var f := get_node_or_null("/root/Fluxo") as FluxoTelas
		if f:
			f.concluiu("bau"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and resultado.is_empty():
		abrir()

## Abre o baú: entrega a recompensa e mostra a peça equipada.
func abrir() -> void:
	var jog := get_node_or_null("/root/Jogador") as ServicoJogador
	if jog == null or not resultado.is_empty():
		return
	resultado = jog.recompensa_tutorial()
	var modelo: String = jog.item(resultado["item"]).get("modelo", "")
	var raridade: String = Balanceamento.carregar("itens")["modelos"].get(modelo, {}).get("raridade", "comum")
	_texto.text = tr("BAU_GANHOU").format({"item": tr("ITEM_" + modelo.to_upper()), "raridade": tr("RARIDADE_" + raridade.to_upper())})
	var t := create_tween()
	t.tween_property(_bau.get_node("Tampa"), "rotation_degrees", -110.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AparenciaJogador.vestir_camadas(_retrato, jog)
	_retrato.tocar("respirar")
	_retrato.visible = true
	_seguir.visible = true
