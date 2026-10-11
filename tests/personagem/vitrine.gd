extends Node2D
## Vitrine do personagem em camadas para o `driver.sh shot`: cavaleiros da
## justa em três pelagens e casas, espelhado e menor como o rival, a pé na
## vila (andando) e o retrato de Equipamentos, nos dois corpos.

const CAVALEIRO := preload("res://game/scenes/arena/cavaleiro.tscn")

func _ready() -> void:
	var casas := [
		["azul_real", "ouro_velho", "ferro", "alazao"],
		["vermelho_sangue", "preto_carvao", "aco_escuro", "preto"],
		["verde_floresta", "branco_osso", "latao", "branco"],
	]
	for i in casas.size():
		var c: Cavaleiro = CAVALEIRO.instantiate()
		c.position = Vector2(110 + i * 170, 200)
		c.casa_principal = casas[i][0]
		c.casa_secundaria = casas[i][1]
		c.casa_metal = casas[i][2]
		add_child(c)
		c.camadas().vestir({"pelagem": casas[i][3], "corpo": "feminino" if i == 1 else "masculino"})
		c.animar("galope")
	var rival: Cavaleiro = CAVALEIRO.instantiate()
	rival.position = Vector2(700, 200)
	rival.direcao = -1
	rival.escala = 0.85
	rival.casa_principal = "purpura"
	add_child(rival)
	for i in 2:
		var v := CamadasPersonagem.new()
		v.tamanho = "vila"
		v.position = Vector2(110 + i * 70, 420)
		add_child(v)
		v.vestir({"corpo": "masculino" if i == 0 else "feminino"})
		v.tocar("andar")
	var e := CamadasPersonagem.new()
	e.tamanho = "equipamentos"
	e.position = Vector2(560, 530)
	add_child(e)
	e.definir_casa({"principal": "vermelho_sangue", "secundaria": "ouro_velho", "pele": "morena", "cabelo": "ruivo"})
	e.vestir({"cabelo": "2"})
	e.tocar("respirar")
