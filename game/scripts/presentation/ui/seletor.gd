class_name Seletor
extends HBoxContainer
## Seletor "‹ valor ›" para listas curtas (corpo, rosto, cabelo, pelagem...).
## `opcoes` = [{valor, texto}]; o texto já vem traduzido por quem monta.

signal mudou(valor: String)

var opcoes: Array = []
var indice := 0

var _anterior: Button
var _rotulo: Label
var _proximo: Button

func _init() -> void:
	_anterior = Button.new()
	_anterior.text = "‹"
	_anterior.focus_mode = Control.FOCUS_NONE
	_anterior.custom_minimum_size = Vector2(32, 0)
	_rotulo = Label.new()
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_proximo = Button.new()
	_proximo.text = "›"
	_proximo.focus_mode = Control.FOCUS_NONE
	_proximo.custom_minimum_size = Vector2(32, 0)
	add_child(_anterior)
	add_child(_rotulo)
	add_child(_proximo)
	_anterior.pressed.connect(func(): passo(-1))
	_proximo.pressed.connect(func(): passo(1))

func definir_opcoes(lista: Array, valor_inicial := "") -> void:
	opcoes = lista
	indice = 0
	for i in opcoes.size():
		if opcoes[i]["valor"] == valor_inicial:
			indice = i
	_mostrar()

func valor() -> String:
	return opcoes[indice]["valor"] if not opcoes.is_empty() else ""

func escolher(v: String) -> void:
	for i in opcoes.size():
		if opcoes[i]["valor"] == v:
			indice = i
			_mostrar()
			mudou.emit(valor())
			return

func passo(delta: int) -> void:
	if opcoes.is_empty():
		return
	indice = posmod(indice + delta, opcoes.size())
	_mostrar()
	mudou.emit(valor())

func _mostrar() -> void:
	_rotulo.text = opcoes[indice]["texto"] if not opcoes.is_empty() else ""
	var varias := opcoes.size() > 1
	_anterior.disabled = not varias
	_proximo.disabled = not varias
