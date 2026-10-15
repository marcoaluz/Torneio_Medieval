@tool
class_name Cavaleiro
extends Node2D
## Cavaleiro montado da justa (apresentação). A origem é o chão entre as patas
## do cavalo; a arte é desenhada olhando para a direita, num quadro de 160×160.
##
## Encaixes das camadas (montadas pelo nó Camadas, CamadasPersonagem, a
## partir de game/data/personagem/camadas.json):
##   Visual/Cavalo, Visual/Cavalo/Manta, Visual/Cavaleiro/Corpo,
##   Visual/Cavaleiro/Peito, Visual/Cavaleiro/Capacete,
##   Visual/Cavaleiro/Escudo, Visual/Lanca.
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
## Cores da casa (nomes de game/data/personagem/paletas.json), aplicadas
## pelo shader de paleta em todas as camadas.
@export var casa_principal := "azul_real"
@export var casa_secundaria := "ouro_velho"
@export var casa_metal := "ferro"
## Cor principal da casa (para a interface, como o retrato da plaquinha).
var cor_casa: Color:
	get:
		var pal: Variant = Balanceamento.ler_json(CamadasPersonagem.PALETAS)
		if pal is Dictionary and pal["cores_casa"].has(casa_principal):
			return Color(pal["cores_casa"][casa_principal])
		return Color.GRAY

var caido := false
var _posicao_lanca := Vector2.ZERO

## Gesto do golpe (só apresentação): -1 = recolhido (preparando), 0 = em
## guarda, 1 = estocada. O tronco (Visual/Cavaleiro) gira em torno da sela e a
## lança avança junto, para o golpe se ler mesmo parado no hit-stop.
const PIVO_SELA := Vector2(2, -80)
const GESTO_INCLINACAO_GRAUS := 11.0
const GESTO_ESTOCADA_PX := 3.0  ## mais que isso solta a guarda da mão desenhada
const GESTO_RECUO_PX := 3.0
var gesto := 0.0:
	set(v):
		gesto = v
		_aplicar_gesto()
var _tween_gesto: Tween
## Ângulo da lança apontada para o adversário (radianos, no quadro do Visual,
## olhando à direita), somado ao do gesto. Limitado a LANCA_MAX_GRAUS.
const LANCA_MAX_GRAUS := 28.0
var mira_lanca := 0.0:
	set(v):
		mira_lanca = clampf(v, -deg_to_rad(LANCA_MAX_GRAUS), deg_to_rad(LANCA_MAX_GRAUS))
		_aplicar_gesto()

## Ângulo (no quadro do Visual) para a lança, saindo da mão, apontar a `alvo`.
func angulo_para(alvo: Vector2) -> float:
	var v := visual()
	if v == null:
		return 0.0
	var d := v.to_local(alvo) - _posicao_lanca
	return atan2(d.y, d.x)

func _ready() -> void:
	_aplicar_orientacao()
	if not Engine.is_editor_hint():
		definir_casa({"principal": casa_principal, "secundaria": casa_secundaria, "metal": casa_metal})
		definir_brasao({"cor1": casa_principal, "cor2": casa_secundaria, "cor_simbolo": casa_secundaria})
	var lanca := get_node_or_null("Visual/Lanca") as Node2D
	if lanca:
		_posicao_lanca = lanca.position

func camadas() -> CamadasPersonagem:
	return get_node_or_null("Camadas") as CamadasPersonagem

## Cores da casa ({principal, secundaria, metal, ...}, nomes de paletas.json).
func definir_casa(casa: Dictionary) -> void:
	var c := camadas()
	if c:
		var atual := {"principal": casa_principal, "secundaria": casa_secundaria, "metal": casa_metal}
		atual.merge(casa, true)
		casa_principal = atual["principal"]
		casa_secundaria = atual["secundaria"]
		casa_metal = atual["metal"]
		c.definir_casa(atual)

## Animação das camadas ("parado", "galope") e o quanto ela corre.
func animar(nome: String, velocidade := 1.0) -> void:
	var c := camadas()
	if c:
		c.tocar(nome)
		c.velocidade = velocidade

func visual() -> Node2D:
	return get_node_or_null("Visual")

func brasao() -> Node2D:
	return get_node_or_null("Visual/Cavaleiro/Escudo/Brasao")

## Tamanho (px) do brasão em cada lugar onde aparece.
const LUGARES_BRASAO := {
	"Visual/Cavaleiro/Escudo/Brasao": Vector2i(12, 16),
	"Visual/Cavaleiro/Peito/BrasaoPeito": Vector2i(10, 12),
	"Visual/Cavalo/Manta/BrasaoManta": Vector2i(14, 16),
}

## Brasão da casa ({forma, divisao, cor1, cor2, simbolo, posicao, cor_simbolo})
## no escudo, na sobreveste e na caparação.
func definir_brasao(dados: Dictionary) -> void:
	for caminho: String in LUGARES_BRASAO:
		var img := get_node_or_null(caminho + "/Imagem") as Sprite2D
		if img:
			img.texture = GeradorBrasao.textura(dados, LUGARES_BRASAO[caminho])

## Textura do brasão do escudo (para a plaquinha da interface).
func brasao_textura() -> Texture2D:
	var img := get_node_or_null("Visual/Cavaleiro/Escudo/Brasao/Imagem") as Sprite2D
	return img.texture if img else null

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

## Recolhe o tronco e puxa a lança (o golpe vem a seguir).
func preparar_golpe(duracao := 0.18) -> void:
	if caido:
		return
	_novo_tween_gesto().tween_property(self, "gesto", -0.7, duracao).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Estocada: inclina para a frente e empurra a lança, segura um instante e
## volta à guarda.
func golpear(ida := 0.07, segura := 0.6, volta := 0.5) -> void:
	if caido:
		return
	var t := _novo_tween_gesto()
	t.tween_property(self, "gesto", 1.0, ida).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(segura)
	t.tween_property(self, "gesto", 0.0, volta).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _novo_tween_gesto() -> Tween:
	if _tween_gesto and _tween_gesto.is_valid():
		_tween_gesto.kill()
	_tween_gesto = create_tween()
	return _tween_gesto

func _aplicar_gesto() -> void:
	if caido:
		return
	var corpo := get_node_or_null("Visual/Cavaleiro") as Node2D
	var lanca := get_node_or_null("Visual/Lanca") as Node2D
	if corpo == null:
		return
	var a := deg_to_rad(GESTO_INCLINACAO_GRAUS) * gesto
	# Gira em torno da sela: posição = pivô + (origem - pivô) girada.
	corpo.rotation = a
	corpo.position = PIVO_SELA - PIVO_SELA.rotated(a)
	if lanca:
		var avanco := gesto * (GESTO_ESTOCADA_PX if gesto > 0.0 else GESTO_RECUO_PX)
		lanca.rotation = a * 0.35 + mira_lanca  # a ponta continua mirando o rival
		lanca.position = PIVO_SELA + (_posicao_lanca - PIVO_SELA).rotated(a) + Vector2(avanco, 0)

## Derrubada: o cavaleiro (Visual/Cavaleiro, com a lança) cai para trás,
## saindo do cavalo. `giro_graus` e `distancia` em px do quadro.
func cair(duracao: float, giro_graus: float, distancia: float) -> void:
	var corpo := get_node_or_null("Visual/Cavaleiro") as Node2D
	var lanca := get_node_or_null("Visual/Lanca") as Node2D
	if corpo == null:
		return
	if _tween_gesto and _tween_gesto.is_valid():
		_tween_gesto.kill()
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
	if _tween_gesto and _tween_gesto.is_valid():
		_tween_gesto.kill()
	caido = false
	mira_lanca = 0.0
	gesto = 0.0
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
	# Os brasões desfazem o espelho (nunca saem invertidos).
	for caminho: String in LUGARES_BRASAO:
		var b := get_node_or_null(caminho) as Node2D
		if b != null:
			b.scale.x = direcao

