class_name RegraPve
extends RefCounted
## Regras puras do PvE (GDD Disputas PvE): estrelas de uma disputa e a
## simulação do modo automático. Puras e determinísticas (o servidor repete).

## Estrelas de uma disputa a partir dos eventos da Justa:
## 0 se não venceu; 1 pela vitória; +1 sem errar (nenhum golpe do jogador
## em "erro" nem falta); +1 se venceu por derrubada.
static func estrelas(eventos: Array) -> int:
	var venceu := false
	var derrubada := false
	var errou := false
	for e: Dictionary in eventos:
		match e["tipo"]:
			"impacto":
				var g: Dictionary = e["jogador"]
				if g["zona"] == Mira.ERRO or g["falta"]:
					errou = true
			"fim":
				venceu = e["vencedor"] == JustaFases.Lado.JOGADOR
				derrubada = e["motivo"] == "derrubada"
	if not venceu:
		return 0
	return 1 + (0 if errou else 1) + (1 if derrubada else 0)

## Joga a justa inteira sem ninguém tocar: o jogador também é uma IA
## (perfil do automático). Devolve {eventos, equipamento_final}.
static func simular(cfg: Dictionary, lado_j: Dictionary, lado_r: Dictionary, semente: int,
		perfil_rival: Dictionary, perfil_jogador: Dictionary) -> Dictionary:
	var j := Justa.new(cfg, lado_j, lado_r, semente, perfil_rival, perfil_jogador)
	var eventos: Array[Dictionary] = j.iniciar()
	var guarda := 0
	while not j.terminou() and guarda < 1000:
		eventos.append_array(j.avancar(1000))
		guarda += 1
	return {"eventos": eventos, "equipamento_final": j.equipamento_final(true)}
