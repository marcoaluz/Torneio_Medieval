class_name PredioVila
extends Node2D
## Um prédio da vila (vista de cima, três quartos). Arte provisória desenhada
## por código: paredes e telhado crescem com o estágio (nível). Encaixe para
## a arte real: o nó Sprite (Sprite2D) recebe a folha de estágios
## (game/art/sprites/vila/<nome>.png, um quadro por estágio) quando existir;
## sem ela, desenha o provisório.
## Mostra o nome, o balão do timer quando ocupado, o ícone "!" quando algo
## está pronto e o cadeado quando ainda não foi liberado.

const PASTA_ARTE := "res://game/art/sprites/vila/"

var nome := ""
var tamanho := Vector2(120, 80)
var cor_telhado := Color("5c2a22")
var estagios := 4
var nivel := 1:
	set(v):
		nivel = v
		queue_redraw()
var bloqueado := false:
	set(v):
		bloqueado = v
		queue_redraw()
var pronto := false:
	set(v):
		pronto = v
		queue_redraw()

## Estandarte com o brasão da ordem (só a sede da ordem): mastro ao lado da porta,
## travessa e pano com o brasão desenhado pelo GeradorBrasao. Fica escondido sem
## ordem. `_estandarte_chave` evita refazer a textura quando nada mudou.
const ESTANDARTE_BASE := Vector2(54, 42)  ## pé do mastro, a partir do centro do sprite
const ESTANDARTE_BRASAO := Vector2i(22, 28)
var _estandarte: Node2D
var _estandarte_brasao: TextureRect
var _estandarte_chave := ""

@onready var _nome: Label = $Nome
@onready var _balao: Label = $Balao
@onready var _sprite: Sprite2D = $Sprite

func configurar(n: String, dados: Dictionary) -> void:
	nome = n
	position = Vector2(float(dados["posicao"][0]), float(dados["posicao"][1]))
	tamanho = Vector2(float(dados["tamanho"][0]), float(dados["tamanho"][1]))
	cor_telhado = Color(dados["cor_telhado"])
	estagios = int(dados["estagios"])
	var arte := PASTA_ARTE + n + ".png"
	if ResourceLoader.exists(arte):
		_sprite.texture = load(arte)
		_sprite.hframes = estagios
	_texto_nome()
	_nome.position = Vector2(-80, tamanho.y * 0.5 + 2)
	_balao.position = Vector2(-60, -tamanho.y * 0.5 - 30)

func _texto_nome() -> void:
	if _nome:
		_nome.text = tr("PREDIO_" + nome.to_upper())

## O idioma mudou com a vila aberta (Configurações): refaz a legenda.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_texto_nome()

## Brasão da ordem na fachada ({} esconde). Só vale para a sede da ordem.
func aplicar_brasao(brasao: Dictionary) -> void:
	if nome != "guilda":
		return
	var chave := JSON.stringify(brasao, "", true)
	if chave == _estandarte_chave:
		return
	_estandarte_chave = chave
	if brasao.is_empty():
		if _estandarte:
			_estandarte.visible = false
		return
	if _estandarte == null:
		_montar_estandarte()
	_estandarte_brasao.texture = GeradorBrasao.textura(brasao, ESTANDARTE_BRASAO)
	_estandarte.visible = true

func _montar_estandarte() -> void:
	_estandarte = Node2D.new()
	_estandarte.name = "Estandarte"
	_estandarte.position = ESTANDARTE_BASE
	_estandarte.z_index = 5
	add_child(_estandarte)
	var madeira := Color(0.24, 0.16, 0.1)
	var pano := Color(0.1, 0.07, 0.06)
	var mastro := _retangulo(Rect2(-1, -72, 3, 72), madeira)
	var travessa := _retangulo(Rect2(-17, -70, 34, 3), madeira.lightened(0.1))
	var fundo := _retangulo(Rect2(-14, -67, 28, 38), pano)
	var ponta := _retangulo(Rect2(-14, -29, 28, 3), pano.lightened(0.15))
	for n: ColorRect in [mastro, travessa, fundo, ponta]:
		_estandarte.add_child(n)
	_estandarte_brasao = TextureRect.new()
	_estandarte_brasao.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_estandarte_brasao.position = Vector2(-11, -64)
	_estandarte_brasao.size = Vector2(ESTANDARTE_BRASAO)
	_estandarte_brasao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_estandarte.add_child(_estandarte_brasao)

func _retangulo(r: Rect2, cor: Color) -> ColorRect:
	var c := ColorRect.new()
	c.position = r.position
	c.size = r.size
	c.color = cor
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## Estágio visual (0 a estagios-1) para o nível atual.
func estagio() -> int:
	return clampi(nivel - 1, 0, estagios - 1)

## Mostra o tempo restante no balão ("" esconde).
func mostrar_timer(texto: String) -> void:
	_balao.text = texto
	_balao.visible = texto != ""

func retangulo() -> Rect2:
	return Rect2(position - tamanho * 0.5, tamanho)

func _process(_delta: float) -> void:
	if _sprite.texture:
		_sprite.frame = estagio()
		_sprite.modulate = Color(0.45, 0.45, 0.45) if bloqueado else Color.WHITE

func _draw() -> void:
	if _sprite.texture:
		_desenhar_marcas()
		return
	var e := estagio()
	var w := tamanho.x * (0.7 + 0.3 * float(e + 1) / estagios)
	var h := tamanho.y * (0.7 + 0.3 * float(e + 1) / estagios)
	var parede := Color("8a7a62")
	var telhado := cor_telhado
	if bloqueado:
		parede = parede.darkened(0.55)
		telhado = telhado.darkened(0.55)
	# Sombra no chão
	draw_rect(Rect2(-w * 0.5 + 6, -h * 0.5 + 10, w, h), Color(0, 0, 0, 0.25))
	# Paredes (frente) e telhado (vista de cima, três quartos)
	draw_rect(Rect2(-w * 0.5, -h * 0.1, w, h * 0.6), parede)
	draw_rect(Rect2(-w * 0.5, -h * 0.1, w, 3), parede.lightened(0.2))
	var topo := PackedVector2Array([Vector2(-w * 0.55, -h * 0.1), Vector2(w * 0.55, -h * 0.1),
		Vector2(w * 0.4, -h * 0.5), Vector2(-w * 0.4, -h * 0.5)])
	draw_colored_polygon(topo, telhado)
	draw_line(Vector2(-w * 0.4, -h * 0.5), Vector2(w * 0.4, -h * 0.5), telhado.lightened(0.25), 2)
	# Porta
	draw_rect(Rect2(-6, h * 0.2, 12, h * 0.3), parede.darkened(0.5))
	# Estágios: janelas, segundo andar, torre, bandeira
	for i in mini(e + 1, 4):
		var x := -w * 0.4 + i * w * 0.22
		if absf(x) > 10:
			draw_rect(Rect2(x, h * 0.05, 6, 6), Color(0.95, 0.8, 0.45) if not bloqueado else parede.darkened(0.4))
	if e >= 2:
		draw_rect(Rect2(w * 0.25, -h * 0.75, w * 0.18, h * 0.35), parede.darkened(0.1))
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.22, -h * 0.75), Vector2(w * 0.46, -h * 0.75), Vector2(w * 0.34, -h * 0.95)]), telhado)
	if e >= 3:
		draw_line(Vector2(-w * 0.3, -h * 0.5), Vector2(-w * 0.3, -h * 0.95), Color(0.3, 0.2, 0.12), 2)
		draw_rect(Rect2(-w * 0.3, -h * 0.95, 14, 9), telhado.lightened(0.15))
	_desenhar_marcas()

func _desenhar_marcas() -> void:
	if bloqueado:
		var c := Vector2(0, -6)
		draw_arc(c + Vector2(0, -6), 6, PI, TAU, 12, Color(0.85, 0.82, 0.75), 2)
		draw_rect(Rect2(c.x - 8, c.y - 6, 16, 13), Color(0.85, 0.82, 0.75))
		draw_rect(Rect2(c.x - 1, c.y - 2, 2, 5), Color(0.2, 0.18, 0.16))
	if pronto:
		var p := Vector2(tamanho.x * 0.45, -tamanho.y * 0.6)
		draw_circle(p, 11, Color(1, 0.85, 0.35))
		draw_circle(p, 11, Color(0.3, 0.2, 0.1), false, 2)
		draw_rect(Rect2(p.x - 2, p.y - 7, 4, 9), Color(0.25, 0.15, 0.05))
		draw_rect(Rect2(p.x - 2, p.y + 4, 4, 3), Color(0.25, 0.15, 0.05))
