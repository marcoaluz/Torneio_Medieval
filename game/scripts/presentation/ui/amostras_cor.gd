class_name AmostrasCor
extends GridContainer
## Grade de amostras de cor (cores da casa, pele, cabelo). Cada amostra é um
## botão pintado com a cor; a escolhida ganha borda clara. Dica (tooltip) com
## o nome traduzido.

signal escolhida(nome: String)

@export var lado_amostra := 26

var selecionada := ""
var _botoes := {}

## `cores` = {nome: Color}, na ordem desejada; `prefixo_texto` para o tr do nome.
func definir(cores: Dictionary, inicial: String, prefixo_texto := "COR_") -> void:
	for b in _botoes.values():
		b.queue_free()
	_botoes.clear()
	for nome: String in cores:
		var b := Button.new()
		b.custom_minimum_size = Vector2(lado_amostra, lado_amostra)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = tr(prefixo_texto + nome.to_upper())
		for estado in ["normal", "hover", "pressed", "focus"]:
			var s := StyleBoxFlat.new()
			s.bg_color = cores[nome]
			s.set_border_width_all(2)
			s.border_color = Color(0.1, 0.08, 0.07)
			b.add_theme_stylebox_override(estado, s)
		b.pressed.connect(func(): escolher(nome))
		add_child(b)
		_botoes[nome] = b
	_marcar(inicial)

func escolher(nome: String) -> void:
	_marcar(nome)
	escolhida.emit(nome)

func _marcar(nome: String) -> void:
	selecionada = nome
	for n: String in _botoes:
		var b: Button = _botoes[n]
		for estado in ["normal", "hover", "pressed", "focus"]:
			var s := b.get_theme_stylebox(estado) as StyleBoxFlat
			s.border_color = Color(1, 0.9, 0.6) if n == nome else Color(0.1, 0.08, 0.07)
