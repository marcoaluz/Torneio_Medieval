@tool
class_name Cavaleiro
extends Node2D
## Cavaleiro montado da justa (apresentação). A origem é o chão entre as patas
## do cavalo; a arte é desenhada olhando para a direita, num quadro de 160×160.
##
## Encaixes para os sprites (hoje com RetanguloProvisorio dentro):
##   Visual/Cavalo, Visual/Cavalo/Manta, Visual/Cavaleiro/Peito,
##   Visual/Cavaleiro/Capacete, Visual/Cavaleiro/Escudo, Visual/Lanca.
## Capacete, Peito e Escudo também são os alvos da mira (pontuação do GDD).
## O espelhamento e a escala ficam em Visual; o Brasao desfaz o espelhamento
## para o símbolo nunca sair invertido (GDD: brasão aplicado depois do espelho).

const COR_REALCE := Color(1.35, 1.3, 1.15)
const COR_REALCE_FALTA := Color(1.3, 0.85, 0.8)

## 1 = corre para a direita (jogador), -1 = para a esquerda (rival).
@export_enum("Esquerda:-1", "Direita:1") var direcao := 1:
	set(v):
		direcao = v
		_aplicar_orientacao()
## Escala do desenho; o rival usa um pouco menos de 1 (está mais longe).
@export_range(0.5, 1.5, 0.05) var escala := 1.0:
	set(v):
		escala = v
		_aplicar_orientacao()
## Cor da casa nos retângulos provisórios (grupo "provisorio_cor_casa").
## Com os sprites, a cor passa a vir do shader de paleta.
@export var cor_casa := Color("2c3a5a"):
	set(v):
		cor_casa = v
		_aplicar_cor_casa()

var caido := false
var _posicao_lanca := Vector2.ZERO

func _ready() -> void:
	_aplicar_orientacao()
	_aplicar_cor_casa()
	var lanca := get_node_or_null("Visual/Lanca") as Node2D
	if lanca:
		_posicao_lanca = lanca.position

func visual() -> Node2D:
	return get_node_or_null("Visual")

func brasao() -> Node2D:
	return get_node_or_null("Visual/Cavaleiro/Escudo/Brasao")

## Centro do quadro de 160×160 (cavalo e cavaleiro), já com a escala.
func centro() -> Vector2:
	return global_position + Vector2(0, -80 * escala)

## Brilho leve na zona sob a ponta da lança: "capacete", "peito", "escudo",
## "cavalo" (falta, puxa para o vermelho) ou "" para apagar.
## Sinal no próprio cavaleiro, sem círculo na tela (GDD).
func realcar(zona: String) -> void:
	var nos := {"capacete": "Visual/Cavaleiro/Capacete", "peito": "Visual/Cavaleiro/Peito",
		"escudo": "Visual/Cavaleiro/Escudo", "cavalo": "Visual/Cavalo"}
	for z: String in nos:
		var no := get_node_or_null(nos[z]) as CanvasItem
		if no == null:
			continue
		if z != zona:
			no.modulate = Color.WHITE
		elif z == "cavalo":
			no.modulate = COR_REALCE_FALTA
		else:
			no.modulate = COR_REALCE

## Derrubada: o cavaleiro (Visual/Cavaleiro, com a lança) cai para trás,
## saindo do cavalo. `giro_graus` e `distancia` em px do quadro.
func cair(duracao: float, giro_graus: float, distancia: float) -> void:
	var corpo := get_node_or_null("Visual/Cavaleiro") as Node2D
	var lanca := get_node_or_null("Visual/Lanca") as Node2D
	if corpo == null:
		return
	caido = true
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(corpo, "rotation_degrees", -giro_graus, duracao)
	t.tween_property(corpo, "position", Vector2(-distancia, distancia * 0.6), duracao)
	if lanca:
		t.tween_property(lanca, "rotation_degrees", -giro_graus * 0.6, duracao)
		t.tween_property(lanca, "position", lanca.position + Vector2(-distancia, distancia * 0.6), duracao)

## A lança estilhaça no contato: fica curta até a próxima passada.
func quebrar_lanca(escala: float) -> void:
	var lanca := get_node_or_null("Visual/Lanca") as Node2D
	if lanca:
		lanca.scale.x = escala

## Volta tudo ao normal (começo de passada).
func restaurar() -> void:
	caido = false
	var corpo := get_node_or_null("Visual/Cavaleiro") as Node2D
	if corpo:
		corpo.rotation = 0.0
		corpo.position = Vector2.ZERO
	var lanca := get_node_or_null("Visual/Lanca") as Node2D
	if lanca:
		lanca.rotation = 0.0
		lanca.scale = Vector2.ONE
		lanca.position = _posicao_lanca
	realcar("")

## Nó que representa uma zona do alvo: "capacete", "peito", "escudo" ou "cavalo".
func no_da_zona(zona: String) -> Node2D:
	match zona:
		"capacete": return get_node_or_null("Visual/Cavaleiro/Capacete")
		"peito": return get_node_or_null("Visual/Cavaleiro/Peito")
		"escudo": return get_node_or_null("Visual/Cavaleiro/Escudo")
		"cavalo": return get_node_or_null("Visual/Cavalo/Manta")
	return null

## Posição global de um alvo da mira: "Capacete", "Peito" ou "Escudo".
func ponto_alvo(nome: String) -> Vector2:
	var no := get_node("Visual/Cavaleiro/" + nome) as Node2D
	return no.global_position

func _aplicar_orientacao() -> void:
	var v := visual()
	if v == null:
		return
	v.scale = Vector2(direcao * escala, escala)
	var b := brasao()
	if b != null:
		b.scale.x = direcao

func _aplicar_cor_casa() -> void:
	if not is_inside_tree():
		return
	for no in find_children("*", "RetanguloProvisorio", true, false):
		if no.is_in_group("provisorio_cor_casa"):
			no.cor = cor_casa
