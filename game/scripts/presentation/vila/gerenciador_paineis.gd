class_name GerenciadorPaineis
extends Node
## Um painel por vez na vila (GDD A vila > Interface legível no celular):
## qualquer tela, painel de prédio, ficha ou duelo aberto por cima da vila
## esconde a que estava aberta (ela volta quando a nova fecha) e escurece
## tudo atrás, o topo inclusive. O fundo escuro fica logo acima do topo e
## abaixo de todo painel, então nada do topo nem da vila aparece por cima de
## um painel. A janela de oferta não é painel: a vila só a mostra com tudo
## fechado (`nenhum_aberto`) e `todos_fechados` avisa quando dá.

signal todos_fechados

## Filhos de Interface que não são painéis.
const FORA := [&"Topo", &"Letreiro", &"Fundo", &"JanelaOferta"]
const COR_FUNDO := Color(0.03, 0.02, 0.03, 0.78)

var fundo: ColorRect
var paineis: Array[Control] = []
var _pilha: Array[Control] = []
var _escondendo := false

func configurar(interface: CanvasLayer) -> void:
	fundo = ColorRect.new()
	fundo.name = "Fundo"
	fundo.color = COR_FUNDO
	fundo.visible = false
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interface.add_child(fundo)
	var topo := interface.get_node_or_null("Topo")
	interface.move_child(fundo, (topo.get_index() + 1) if topo else 0)
	for c in interface.get_children():
		registrar(c)

## Passa a gerenciar o painel `c` (as telas criadas depois chamam isto).
func registrar(c: Node) -> void:
	if not (c is Control) or c.name in FORA or paineis.has(c):
		return
	paineis.append(c)
	(c as Control).visibility_changed.connect(_mudou.bind(c))
	if (c as Control).visible:
		_mudou(c)

func abertos() -> Array[Control]:
	var r: Array[Control] = []
	for p in paineis:
		if is_instance_valid(p) and p.visible:
			r.append(p)
	return r

## Fecha tudo de uma vez (sem devolver o que estava embaixo).
func fechar_todos() -> void:
	_pilha.clear()
	_escondendo = true
	for p in abertos():
		p.visible = false
	_escondendo = false
	fundo.visible = false

func nenhum_aberto() -> bool:
	return abertos().is_empty()

func _mudou(c: Control) -> void:
	if _escondendo:
		return
	if c.visible:
		# Abriu: o que estava aberto sai (e volta depois), o fundo aparece.
		_escondendo = true
		for p in abertos():
			if p != c:
				p.visible = false
				if not _pilha.has(p):
					_pilha.append(p)
		_escondendo = false
		_pilha.erase(c)
		# Painel visível mais acima: o fundo fica sempre abaixo de todos.
	else:
		_pilha.erase(c)
		_depois.call_deferred()
	fundo.visible = not abertos().is_empty()

## Fechou o de cima: o que ele escondeu volta, a não ser que outro tenha
## aberto no lugar (aí a pilha é de outra conversa e se descarta).
func _depois() -> void:
	if not abertos().is_empty():
		_pilha.clear()
	elif not _pilha.is_empty():
		var q: Control = _pilha.pop_back()
		_pilha.clear()
		if is_instance_valid(q):
			q.visible = true
	fundo.visible = not abertos().is_empty()
	if abertos().is_empty():
		todos_fechados.emit()
