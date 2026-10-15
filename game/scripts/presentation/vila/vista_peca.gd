class_name VistaPeca
extends Control
## Uma peça de armadura sozinha, num estágio de dano (0 = inteira, 1..3 =
## riscada, amassada, rachada), desenhada com as camadas do personagem (a
## mesma arte e as mesmas cores da casa): elmo, peitoral e escudo pelo tamanho
## do retrato de Equipamentos; a lança pelo da justa. Só a camada da peça fica
## visível, enquadrada e centrada no controle. Sem arte do estágio, as
## camadas já caem na peça inteira (CamadasPersonagem._sem_dano).

const CHAVES := ["pelagem", "caparacao", "corpo", "rosto", "cabelo", "pernas", "peitoral", "sobreveste", "elmo", "cimeira", "escudo", "lanca"]
## Tamanho de camadas por espaço (o retrato não tem lança).
const TAMANHO_DO_ESPACO := {"lanca": "justa"}
const ESCALA_MAX := 2.0

var espaco := ""
var visual := ""
var estagio := 0
var _camadas: CamadasPersonagem

## Mostra a peça (`visual` do conjunto) no estágio de dano, nas cores `casa`.
func _ready() -> void:
	clip_contents = true

func mostrar(novo_espaco: String, novo_visual: String, novo_estagio: int, casa: Dictionary) -> void:
	espaco = novo_espaco
	visual = novo_visual
	estagio = novo_estagio
	var tam: String = TAMANHO_DO_ESPACO.get(espaco, "equipamentos")
	if _camadas == null or _camadas.tamanho != tam:
		if _camadas:
			_camadas.queue_free()
		_camadas = CamadasPersonagem.new()
		_camadas.name = "Camadas"
		_camadas.tamanho = tam
		_camadas.raiz = self
		add_child(_camadas)
	var pecas := {}
	for k: String in CHAVES:
		pecas[k] = "nenhum"
	pecas[espaco] = visual + ("_d%d" % estagio if estagio > 0 else "")
	_camadas.definir_casa(casa)
	_camadas.vestir(pecas)
	_enquadrar()

func camada() -> Sprite2D:
	return _camadas.camada(espaco) if _camadas else null

## Escala e centra a peça no controle a partir dos pixels usados no quadro 0.
func _enquadrar() -> void:
	var s := camada()
	if s == null or s.texture == null:
		return
	var fw := s.texture.get_width() / maxi(s.hframes, 1)
	var img := s.texture.get_image()
	if img == null:
		return
	var usado := img.get_region(Rect2i(0, 0, fw, img.get_height())).get_used_rect()
	if usado.size.x <= 0:
		return
	var caixa := size if size.x > 0 else custom_minimum_size
	var e := minf((caixa.x - 8) / usado.size.x, (caixa.y - 8) / usado.size.y)
	var centro_local := s.position + s.offset + Vector2(usado.position) + Vector2(usado.size) * 0.5
	if e >= 1.0:
		# Pixel nítido: amplia por inteiro, até ESCALA_MAX.
		e = minf(floorf(e), ESCALA_MAX)
		_camadas.scale = Vector2(e, e)
		_camadas.position = (caixa * 0.5 - centro_local * e).round()
		return
	# Peça maior que a caixa (o peitoral vai até as botas): tamanho natural,
	# enquadrando a parte de cima, onde o dano aparece; o resto fica cortado.
	_camadas.scale = Vector2.ONE
	var topo_local := s.position.y + s.offset.y + usado.position.y
	_camadas.position = Vector2(caixa.x * 0.5 - centro_local.x, 4 - topo_local).round()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _camadas:
		_enquadrar()
