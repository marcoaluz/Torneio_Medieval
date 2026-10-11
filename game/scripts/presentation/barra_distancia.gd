class_name BarraDistancia
extends Control
## Barra de distância da justa (embaixo da tela): a pista inteira, com o
## ícone do jogador saindo da esquerda e o do rival da direita; eles se
## encontram onde os cavaleiros se encontram (não necessariamente no meio:
## quem corre mais anda mais). O compasso do galope é um brilho na própria
## barra (Pacote 1.3: sem barra separada). Não recebe toques.
## Encaixes para arte: IconeJogador e IconeRival (hoje ColorRect).

## Posição na pista, 0 = ponta esquerda (largada do jogador), 1 = ponta direita.
var posicao_jogador := 0.0:
	set(v):
		posicao_jogador = clampf(v, 0.0, 1.0)
		_posicionar_icones()
var posicao_rival := 1.0:
	set(v):
		posicao_rival = clampf(v, 0.0, 1.0)
		_posicionar_icones()
## 0 a 1: quanto o compasso está aceso agora.
var brilho := 0.0:
	set(v):
		brilho = clampf(v, 0.0, 1.0)
		queue_redraw()

@export var cor_fundo := Color(0.12, 0.1, 0.09, 0.85)
@export var cor_trilho := Color(0.35, 0.28, 0.2, 1)
@export var cor_brilho := Color(1.0, 0.85, 0.45, 1)
@export var cor_acerto := Color(1.0, 0.9, 0.5, 1)
@export var cor_erro := Color(0.75, 0.2, 0.15, 1)
@export var cor_perdido := Color(0.4, 0.4, 0.4, 1)
@export var duracao_lampejo := 0.25

var _lampejo_cor := Color.TRANSPARENT
var _lampejo := 0.0

@onready var icone_jogador: Control = $IconeJogador
@onready var icone_rival: Control = $IconeRival

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_posicionar_icones)
	_posicionar_icones()

## Lampejo de resultado do toque: "no_tempo", "fora_do_tempo", "rapido_demais", "perdido".
func lampejar(resultado: String) -> void:
	match resultado:
		"no_tempo": _lampejo_cor = cor_acerto
		"perdido": _lampejo_cor = cor_perdido
		_: _lampejo_cor = cor_erro
	_lampejo = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	if _lampejo > 0.0:
		_lampejo = maxf(_lampejo - delta / duracao_lampejo, 0.0)
		queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, cor_fundo)
	var trilho := Rect2(Vector2(4, size.y * 0.5 - 2), Vector2(size.x - 8, 4))
	draw_rect(trilho, cor_trilho)
	if brilho > 0.0:
		var c := cor_brilho
		c.a = brilho * 0.8
		draw_rect(r.grow(-1), c, false, 2.0)
		c.a = brilho * 0.5
		draw_rect(trilho.grow(1), c)
	if _lampejo > 0.0:
		var l := _lampejo_cor
		l.a = _lampejo * 0.6
		draw_rect(r, l)

func _posicionar_icones() -> void:
	if not is_node_ready():
		return
	# Os ícones ficam dentro da barra e se tocam pelo nariz quando as
	# posições são iguais (o jogador olha para a direita, o rival para a esquerda).
	var wj := icone_jogador.size.x
	var util := maxf(size.x - wj - icone_rival.size.x, 0.0)
	icone_jogador.position = Vector2(posicao_jogador * util, (size.y - icone_jogador.size.y) * 0.5)
	icone_rival.position = Vector2(wj + posicao_rival * util, (size.y - icone_rival.size.y) * 0.5)
