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

func _ready() -> void:
	_aplicar_orientacao()
	_aplicar_cor_casa()

func visual() -> Node2D:
	return get_node_or_null("Visual")

func brasao() -> Node2D:
	return get_node_or_null("Visual/Cavaleiro/Escudo/Brasao")

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
