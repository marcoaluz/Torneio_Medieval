class_name CamadasPersonagem
extends Node2D
## Personagem em camadas (cavaleiro e cavalo): monta uma camada (Sprite2D com
## folha de quadros) por espaço de equipamento a partir de
## game/data/personagem/camadas.json, toca a mesma animação em todas, no mesmo
## quadro, e aplica as cores da casa pelo shader de paleta.
##
## Serve aos três tamanhos (justa 160, vila 96, equipamentos 256): só muda o
## `tamanho`, que escolhe o quadro, as animações e a lista de camadas.
## Na justa as camadas vão para os encaixes do cavaleiro (Visual/Cavalo,
## Visual/Cavaleiro/Peito...), que também são as zonas da mira e os pontos
## dos efeitos. O brasão (nó Brasao, se houver) é posicionado a cada quadro
## pelos pontos de encaixe (pontos.json) e desfaz o espelhamento à parte.

const SHADER := preload("res://game/art/shaders/paleta_casa.gdshader")
const DADOS := "res://game/data/personagem/camadas.json"
const PONTOS := "res://game/data/personagem/pontos.json"
const PALETAS := "res://game/data/personagem/paletas.json"

signal quadro_mudou(animacao: String, quadro: int)

@export_enum("justa", "vila", "equipamentos") var tamanho := "justa"
## Raiz onde procurar os encaixes (vazio = o pai deste nó).
@export var raiz: Node
@export var animacao := "parado"
## Multiplica o fps da animação (galope mais rápido, câmera lenta...).
@export var velocidade := 1.0

## Peça escolhida por chave do arquivo ({pelagem}, {peitoral}...).
var pecas := {}
## Cores por material (Color), na ordem de camadas.json/materiais.
var cores: Array[Color] = []
var quadro := 0

var _dados: Dictionary
var _tam: Dictionary
var _pontos: Dictionary
var _camadas: Array[Sprite2D] = []
var _tempo := 0.0
var _nos_pontos := {}  ## nome do ponto -> nó que o segue

func _ready() -> void:
	_dados = _ler_json(DADOS)
	_pontos = _ler_json(PONTOS)
	_tam = _dados["tamanhos"][tamanho]
	pecas = (_dados["pecas_padrao"] as Dictionary).duplicate()
	if cores.is_empty():
		definir_casa(_ler_json(PALETAS)["casa_padrao"])
	if raiz == null:
		raiz = get_parent()
	if raiz:
		var nos: Dictionary = _dados.get("pontos_nos", {})
		for ponto: String in nos:
			var n := raiz.get_node_or_null(nos[ponto]) as Node2D
			if n:
				_nos_pontos[ponto] = n
	montar()

## (Re)cria as camadas com as peças atuais.
func montar() -> void:
	for c in _camadas:
		c.queue_free()
	_camadas.clear()
	for def: Dictionary in _tam["camadas"]:
		var s := Sprite2D.new()
		s.name = "Camada_" + def["nome"]
		s.centered = false
		s.set_meta("def", def)
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		s.material = mat
		var encaixe: Node2D = self
		if def.has("encaixe") and raiz and raiz.has_node(def["encaixe"]):
			encaixe = raiz.get_node(def["encaixe"])
		encaixe.add_child(s)
		# Primeiras no encaixe (atrás dos nós que já estão lá, como o Brasao).
		encaixe.move_child(s, _camadas.filter(func(o): return o.get_parent() == encaixe).size())
		_camadas.append(s)
		_alinhar(s, encaixe, def)
	_aplicar_cores()
	tocar(animacao, true)

## Troca peças ({"peitoral": "ferro_negro", "pelagem": "preto"}) e remonta as texturas.
func vestir(novas: Dictionary) -> void:
	pecas.merge(novas, true)
	tocar(animacao, true)

## Cores da casa a partir de nomes de paletas.json ({principal, secundaria,
## metal, neutro, pele, cabelo}).
func definir_casa(casa: Dictionary) -> void:
	var pal := _ler_json(PALETAS)
	var busca := {"principal": "cores_casa", "secundaria": "cores_casa", "metal": "metais",
		"neutro": "neutros", "pele": "peles", "cabelo": "cabelos"}
	cores.clear()
	cores.append(Color.WHITE)  # original
	for m: String in ["principal", "secundaria", "metal", "neutro", "pele", "cabelo"]:
		var nome: String = casa.get(m, pal["casa_padrao"][m])
		cores.append(Color(pal[busca[m]].get(nome, "ff00ff")))
	_aplicar_cores()

func tocar(nome: String, forcar := false) -> void:
	if nome == animacao and not forcar:
		return
	if not _tam["animacoes"].has(nome):
		push_error("CamadasPersonagem: animação \"%s\" não existe em %s" % [nome, tamanho])
		return
	animacao = nome
	quadro = 0
	_tempo = 0.0
	var n := int(_tam["animacoes"][nome]["quadros"])
	for s in _camadas:
		var def: Dictionary = s.get_meta("def")
		var base := _base_com_arte(def, nome)
		var tex := load(base + ".png") as Texture2D if ResourceLoader.exists(base + ".png") else null
		s.texture = tex
		s.visible = tex != null
		s.hframes = n
		var mat := s.material as ShaderMaterial
		var tem_mascara := ResourceLoader.exists(base + "_mascara.png")
		mat.set_shader_parameter("usa_mascara", tem_mascara)
		mat.set_shader_parameter("mascara", load(base + "_mascara.png") if tem_mascara else null)
	_mostrar_quadro()

## Carrega antes as texturas de todas as animações deste tamanho (3.25): sem
## isso, a primeira troca de animação (ex.: parado -> galope na corrida) lê
## os PNGs no meio do jogo e trava um quadro. Guarda as referências para o
## cache não soltar.
var _reservadas: Array[Resource] = []

func pre_carregar() -> void:
	var guardar := animacao
	for nome: String in _tam["animacoes"]:
		for s in _camadas:
			var def: Dictionary = s.get_meta("def")
			var base := _base_com_arte(def, nome)
			for arq in [base + ".png", base + "_mascara.png"]:
				if ResourceLoader.exists(arq):
					_reservadas.append(load(arq))
	animacao = guardar

func _caminho_animacao(def: Dictionary, nome: String) -> String:
	var antes := animacao
	animacao = nome
	var c := _caminho(def)
	animacao = antes
	return c

func camada(nome: String) -> Sprite2D:
	for s in _camadas:
		if s.get_meta("def")["nome"] == nome:
			return s
	return null

func _process(delta: float) -> void:
	var a: Dictionary = _tam["animacoes"][animacao]
	var n := int(a["quadros"])
	if n <= 1:
		return
	_tempo += delta * float(a["fps"]) * velocidade
	var novo := int(_tempo) % n
	if novo != quadro:
		quadro = novo
		_mostrar_quadro()

func _mostrar_quadro() -> void:
	for s in _camadas:
		if s.texture:
			s.frame = mini(quadro, s.hframes - 1)
	_posicionar_pontos()
	quadro_mudou.emit(animacao, quadro)

## Brasões (escudo, sobreveste, caparação) no ponto de encaixe do quadro
## atual (coordenadas a partir da origem do quadro), convertidos para o pai.
func _posicionar_pontos() -> void:
	if _nos_pontos.is_empty():
		return
	var visual := raiz.get_node("Visual") as Node2D
	var da_anim: Dictionary = _pontos.get(tamanho, {}).get(animacao, {})
	for ponto: String in _nos_pontos:
		var pts: Variant = da_anim.get(ponto)
		if not pts is Array or pts.is_empty():
			continue
		var p: Array = pts[mini(quadro, pts.size() - 1)]
		var no: Node2D = _nos_pontos[ponto]
		# Brasão só aparece com a peça que o carrega (escudo, sobreveste, caparação).
		var dona: String = _dados.get("pontos_camada", {}).get(ponto, "")
		if dona != "":
			var c := camada(dona)
			no.visible = c != null and c.visible
		no.position = (no.get_parent() as Node2D).to_local(visual.to_global(Vector2(float(p[0]), float(p[1]))))

## A origem do quadro fica na origem do personagem (Visual), mesmo com a
## camada dentro de um encaixe deslocado.
func _alinhar(s: Sprite2D, encaixe: Node2D, def: Dictionary) -> void:
	var desloc := Vector2.ZERO
	var n: Node = encaixe
	var visual := raiz.get_node_or_null("Visual") if raiz else null
	while n != null and n != visual and n != self and n is Node2D:
		desloc += (n as Node2D).position
		n = n.get_parent()
	var origem: Array = def.get("origem", _tam["origem"])
	s.position = -desloc
	s.offset = -Vector2(float(origem[0]), float(origem[1]))

## Caminho (sem .png) da arte de uma camada na animação `nome`, com as reservas:
## sem o estágio de dano, usa a peça inteira; peça sem arte própria ainda usa a
## arte provisória do item (itens.json > visual_provisorio), no mesmo estágio.
func _base_com_arte(def: Dictionary, nome: String) -> String:
	var base := _caminho_animacao(def, nome)
	if ResourceLoader.exists(base + ".png"):
		return base
	if ResourceLoader.exists(_sem_dano(base) + ".png"):
		return _sem_dano(base)
	var antes := pecas
	pecas = pecas.duplicate()
	for chave: String in pecas:
		var v := str(pecas[chave])
		var r := RegEx.create_from_string(r"^(.*?)(_d[1-3])?$").search(v)
		var prov := visual_provisorio(r.get_string(1))
		if prov != "":
			pecas[chave] = prov + r.get_string(2)
	var alt := _caminho_animacao(def, nome)
	pecas = antes
	if ResourceLoader.exists(alt + ".png"):
		return alt
	return _sem_dano(alt)

static var _provisorios := {}

## Arte provisória de um visual sem arte própria ("" se não tem).
static func visual_provisorio(visual: String) -> String:
	if _provisorios.is_empty():
		var modelos: Dictionary = Balanceamento.ler("itens")["modelos"]
		for m: String in modelos:
			if modelos[m].has("visual_provisorio"):
				_provisorios[str(modelos[m]["visual"])] = str(modelos[m]["visual_provisorio"])
		_provisorios["__lido"] = ""
	return str(_provisorios.get(visual, ""))

## "peitoral_ferro_d2_galope" -> "peitoral_ferro_galope".
static func _sem_dano(base: String) -> String:
	var r := RegEx.create_from_string(r"_d[1-3](_[a-z]+)$")
	return r.sub(base, "$1")

func _caminho(def: Dictionary) -> String:
	var arquivo: String = def["arquivo"]
	for chave: String in pecas:
		arquivo = arquivo.replace("{%s}" % chave, str(pecas[chave]))
	return "%s/%s/%s_%s" % [_dados["pasta"], tamanho, arquivo, animacao]

func _aplicar_cores() -> void:
	var nomes: Array = _dados.get("materiais", [])
	for s in _camadas:
		var mat := s.material as ShaderMaterial
		mat.set_shader_parameter("cores", PackedColorArray(cores))
		mat.set_shader_parameter("material_padrao", maxi(nomes.find(s.get_meta("def")["material"]), 0))

## Leitura com cache (3.25: cada personagem relia camadas, pontos e paletas).
static func _ler_json(caminho: String) -> Dictionary:
	return Balanceamento.ler_json(caminho)
