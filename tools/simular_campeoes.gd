extends SceneTree
## Relatório dos traços de luta dos campeões (pve.json > tracos): para cada
## campeão e o nêmesis em cada região, o comportamento medido com o traço e
## sem ele (só o perfil + ajuste_campeao), e quanto o campeão vence o
## cavaleiro-espelho com e sem a habilidade que anula a dele. Serve para
## revisar se cada traço é legível (aparece nos números) e justo (tem saída).
##   bash .claude/skills/run-torneio-medieval/driver.sh script res://tools/simular_campeoes.gd
## Variáveis: TM_N (justas por linha, padrão 200).

const Medidor := preload("res://tools/medir_campeoes.gd")

func _initialize() -> void:
	var n := int(OS.get_environment("TM_N")) if OS.get_environment("TM_N") != "" else 200
	var pve: Dictionary = Balanceamento.carregar("pve")
	var hab: Dictionary = Balanceamento.carregar("impacto")["habilidades"]
	var tracos: Dictionary = pve.get("tracos", {})
	print("campeao | regiao | traco | assinatura: com / sem traco | vence espelho: neutro / com a que anula | derruba | largada perf | capacete/peito/escudo/erro")
	for item: Dictionary in Medidor.lista(pve):
		var r: Dictionary = item["rival"]
		var traco: String = r.get("traco", "")
		var a: Dictionary = tracos.get(traco, {}).get("assinatura", {})
		var metrica: String = a.get("metrica", "vitorias_rival_pct")
		var neutra := _neutra(str(r.get("habilidade", "")), hab)
		var contra := _que_anula(str(r.get("habilidade", "")), hab)
		var com := Medidor.medir(r, n, 1000, neutra)
		print("   %s" % JSON.stringify(com))
		var sem := Medidor.medir(r, n, 1000, neutra, true)
		var vs_contra := Medidor.medir(r, n, 1000, contra)
		print("%s | %s | %s | %s: %d / %d | %d%% / %d%% (%s) | %d%% | %d%% | %d/%d/%d/%d" % [item["id"], item["regiao"], traco, metrica,
			int(com[metrica]), int(sem[metrica]), int(com["vitorias_rival_pct"]), int(vs_contra["vitorias_rival_pct"]), contra,
			int(com["derrubadas_rival_pct"]), int(com["largada_perfeita_pct"]), int(com["zona_capacete_pct"]), int(com["zona_peito_pct"]),
			int(com["zona_escudo_pct"]), int(com["zona_erro_pct"])])
	quit(0)

## Habilidade de base que não mexe com a do rival: a da mesma família (no
## ciclo de três, cada uma das outras ou anula ou é anulada).
static func _neutra(h: String, hab: Dictionary) -> String:
	return str(hab.get(h, {}).get("familia", ""))

## Habilidade de base que anula a família da do rival.
static func _que_anula(h: String, hab: Dictionary) -> String:
	var fam := str(hab.get(h, {}).get("familia", ""))
	for b in ["investida", "golpe_pesado", "bloqueio"]:
		if str(hab[b]["vence"]) == fam:
			return b
	return ""
