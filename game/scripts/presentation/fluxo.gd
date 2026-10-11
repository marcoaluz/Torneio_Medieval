class_name FluxoTelas
extends Node
## Troca de telas do jogo (autoload "Fluxo"): vila, justa (livre ou disputa
## do PvE) e o que vier no início do jogo (2.11). Guarda a disputa em
## andamento para a arena saber quem é o rival e para onde voltar.

const VILA := "res://game/scenes/village/vila.tscn"
const ARENA := "res://game/scenes/arena/arena.tscn"

## Disputa do PvE em andamento: {torneio, indice} ({} = justa livre).
var disputa := {}
## Resultado da última disputa (para a vila mostrar ao voltar).
var ultimo_resultado := {}

func ir_para_vila() -> void:
	get_tree().change_scene_to_file(VILA)

## Justa de uma disputa do PvE.
func justar(torneio: String, indice: int) -> void:
	disputa = {"torneio": torneio, "indice": indice}
	ultimo_resultado = {}
	get_tree().change_scene_to_file(ARENA)

## Justa livre (sem PvE): rival padrão.
func justa_livre() -> void:
	disputa = {}
	get_tree().change_scene_to_file(ARENA)

func em_disputa() -> bool:
	return not disputa.is_empty()
