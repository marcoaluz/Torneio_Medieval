class_name AparenciaJogador
extends RefCounted
## Veste um personagem com a aparência do jogador (cores da casa, pele,
## cabelo, corpo, pelagem, peças com o guarda-roupa e brasão), lida do
## serviço Jogador. Usado na arena, na vila e nas telas.

## Para um Cavaleiro montado (justa, campo de treino).
static func vestir_cavaleiro(cav: Cavaleiro, jog: ServicoJogador) -> void:
	cav.definir_casa(casa(jog))
	var pecas := jog.visual_das_pecas()
	pecas["pelagem"] = jog.cavalo_ativo().get("pelagem", "alazao")
	pecas["corpo"] = jog.cavaleiro().get("corpo", "masculino")
	cav.camadas().vestir(pecas)
	cav.definir_brasao(brasao(jog))

## Para camadas soltas (vila a pé, retrato de Equipamentos).
static func vestir_camadas(c: CamadasPersonagem, jog: ServicoJogador) -> void:
	c.definir_casa(casa(jog))
	var pecas := jog.visual_das_pecas()
	var cav := jog.cavaleiro()
	pecas["corpo"] = cav.get("corpo", "masculino")
	pecas["rosto"] = cav.get("rosto", "1")
	pecas["cabelo"] = cav.get("cabelo", "1")
	c.vestir(pecas)

## Só o cavalo ativo (pelagem e peças do cavalo), sem cavaleiro: retrato do
## cavalo em Equipamentos e cena do estábulo. `troca` sobrepõe peças (prévia).
static func vestir_cavalo(c: CamadasPersonagem, jog: ServicoJogador, troca := {}) -> void:
	var cav := {"pelagem": jog.cavalo_ativo().get("pelagem", "alazao")}
	for k in ["corpo", "pernas", "peitoral", "sobreveste", "elmo", "cimeira", "escudo", "lanca"]:
		cav[k] = "nenhum"
	cav["caparacao"] = jog.visual_das_pecas().get("caparacao", "provisorio")
	cav.merge(troca, true)
	c.definir_casa(casa(jog))
	c.vestir(cav)

static func casa(jog: ServicoJogador) -> Dictionary:
	var cores: Dictionary = jog.casa()["cores"]
	var cav := jog.cavaleiro()
	return {"principal": cores["principal"], "secundaria": cores["secundaria"], "metal": cores.get("metal", "ferro"),
		"pele": cav.get("pele", "media"), "cabelo": cav.get("cor_cabelo", "castanho")}

## Brasão da casa; sem brasão definido, um padrão com as cores da casa.
static func brasao(jog: ServicoJogador) -> Dictionary:
	var b: Dictionary = jog.casa().get("brasao", {})
	if b.is_empty():
		var cores: Dictionary = jog.casa()["cores"]
		b = {"cor1": cores["principal"], "cor2": cores["secundaria"], "cor_simbolo": cores["secundaria"]}
	return b
