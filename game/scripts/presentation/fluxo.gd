class_name FluxoTelas
extends Node
## Troca de telas do jogo (autoload "Fluxo"). Na abertura, decide pelo passo
## do tutorial salvo no Jogador (GDD Início do jogo):
##   0 título -> 1 criação -> 2 brasão -> 3 justa de exibição (automática,
##   vista da arquibancada, arauto explicando) -> 4 primeira justa (jogada,
##   com dicas) -> 5 primeiro baú (peça já equipada) -> 6 vila.
## As telas avisam quando terminam com concluiu(etapa). Pular o tutorial (quem
## reinstalou) vai da criação e do brasão direto para a vila, com a mesma
## recompensa. Também leva vila ⇄ arena com a disputa do PvE.

const TITULO := "res://game/scenes/ui/tela_titulo.tscn"
const CRIACAO := "res://game/scenes/ui/criacao_personagem.tscn"
const BRASAO := "res://game/scenes/ui/editor_brasao.tscn"
const BAU := "res://game/scenes/ui/tela_bau.tscn"
const VILA := "res://game/scenes/village/vila.tscn"
const ARENA := "res://game/scenes/arena/arena.tscn"

## Modo da justa que a arena vai abrir: "livre", "disputa", "exibicao", "tutorial".
var modo_justa := "livre"
## Disputa do PvE em andamento: {torneio, indice} ({} = nenhuma).
var disputa := {}
## Resultado da última disputa (para a vila mostrar ao voltar).
var ultimo_resultado := {}
## O jogador escolheu pular o tutorial.
var pulando_tutorial := false

func _jog() -> ServicoJogador:
	return get_node_or_null("/root/Jogador")

## Abertura do jogo: retoma do passo salvo.
func iniciar_jogo() -> void:
	var j := _jog()
	if j == null or j.tutorial_concluido():
		ir_para_vila()
		return
	ir_para_passo(j.tutorial_passo())

func ir_para_passo(passo: int) -> void:
	match passo:
		0: _trocar(TITULO)
		1: _trocar(CRIACAO)
		2: _trocar(BRASAO)
		3: _justa("exibicao")
		4: _justa("tutorial")
		5: _trocar(BAU)
		_: ir_para_vila()

## Uma tela terminou a etapa dela; o fluxo decide a próxima.
func concluiu(etapa: String) -> void:
	var j := _jog()
	if j == null or j.tutorial_concluido():
		if etapa in ["exibicao", "primeira_justa", "disputa", "livre"]:
			ir_para_vila()
		return
	var proximo := {"titulo": 1, "criacao": 2, "brasao": 3, "exibicao": 4, "primeira_justa": 5, "bau": 6}.get(etapa, -1) as int
	if proximo < 0:
		return
	if etapa == "brasao" and pulando_tutorial:
		j.recompensa_tutorial()
		proximo = ServicoJogador.TUTORIAL_CONCLUIDO
	j.definir_passo_tutorial(proximo)
	ir_para_passo(proximo)

## "Já joguei antes": pula a exibição, a primeira justa e o baú.
func pular_tutorial() -> void:
	pulando_tutorial = true
	concluiu("titulo")

func ir_para_vila() -> void:
	modo_justa = "livre"
	disputa = {}
	_trocar(VILA)

## Justa de uma disputa do PvE.
func justar(torneio: String, indice: int) -> void:
	disputa = {"torneio": torneio, "indice": indice}
	ultimo_resultado = {}
	_justa("disputa")

## Justa livre (treino, sem PvE).
func justa_livre() -> void:
	disputa = {}
	_justa("livre")

func em_disputa() -> bool:
	return modo_justa == "disputa" and not disputa.is_empty()

func _justa(modo: String) -> void:
	modo_justa = modo
	_trocar(ARENA)

func _trocar(cena: String) -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file.call_deferred(cena)
