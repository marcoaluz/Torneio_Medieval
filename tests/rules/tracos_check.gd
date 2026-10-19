extends SceneTree
## Traço de luta dos campeões (pve.json > tracos): todo campeão e o nêmesis
## têm traço, alcunha e frases de entrada e de derrota com tradução, a
## habilidade é de uma família aceita pelo traço, e o traço aparece de
## verdade: simulando justas pela regra pura contra um cavaleiro-espelho, a
## métrica da assinatura passa do mínimo (e, quando pedido, fica acima do
## mesmo campeão sem o perfil_ajuste). Relatório completo: tools/simular_campeoes.gd.

const Medidor := preload("res://tools/medir_campeoes.gd")
const JUSTAS := 12

var _falhas := 0

func _initialize() -> void:
	var pve: Dictionary = Balanceamento.carregar("pve")
	var tracos: Dictionary = pve["tracos"]
	var hab: Dictionary = Balanceamento.carregar("impacto")["habilidades"]
	var pecas: Dictionary = Balanceamento.carregar("itens")["pecas_trofeu"]
	TranslationServer.set_locale("pt_BR")
	var vistos := {}
	var usados := {}
	for item: Dictionary in Medidor.lista(pve):
		var id: String = item["id"]
		if vistos.has(id):
			continue  # o nêmesis volta em cada região; basta medir uma
		vistos[id] = true
		var r: Dictionary = item["rival"]
		var traco := str(r.get("traco", ""))
		_checa("%s tem traco do catalogo" % id, tracos.has(traco) and not traco.begins_with("_"))
		if not tracos.has(traco):
			continue
		usados[traco] = true
		var t: Dictionary = tracos[traco]
		for chave in [r.get("alcunha", ""), r.get("frase_entrada", ""), r.get("frase_derrota", ""),
				"TRACO_" + traco.to_upper(), "TRACO_%s_DESC" % traco.to_upper(), "TRACO_%s_FRAQUEZA" % traco.to_upper()]:
			_checa("%s: texto %s traduzido" % [id, chave], str(chave) != "" and tr(chave) != chave and _en(chave) != chave)
		var fams: Array = t["familias"]
		var fam := str(hab.get(r.get("habilidade", ""), {}).get("familia", ""))
		_checa("%s: habilidade %s cabe no traco" % [id, r.get("habilidade", "")], fams.is_empty() or fams.has(fam))
		if r.get("campeao", false):
			_checa("%s: peca de trofeu existe" % id, pecas.has(str(r.get("peca_trofeu", ""))) and str(pecas[r["peca_trofeu"]]["campeao"]) == id)
		var a: Dictionary = t["assinatura"]
		var metrica: String = a["metrica"]
		var neutra := str(hab.get(r.get("habilidade", ""), {}).get("familia", ""))
		var com := Medidor.medir(r, JUSTAS, 4242, neutra)
		var ok := int(com[metrica]) >= int(a["minimo"])
		var nota := "%s=%d (minimo %d)" % [metrica, int(com[metrica]), int(a["minimo"])]
		if a.has("acima_da_base"):
			var sem := Medidor.medir(r, JUSTAS, 4242, neutra, true)
			ok = ok and int(com[metrica]) - int(sem[metrica]) >= int(a["acima_da_base"])
			nota += ", sem o traco %d" % int(sem[metrica])
		_checa("%s: traco %s aparece (%s)" % [id, traco, nota], ok)
	for traco: String in tracos:
		if not traco.begins_with("_"):
			_checa("traco %s e usado por alguem" % traco, usados.has(traco))
	print("TRACOS %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _en(chave: String) -> String:
	TranslationServer.set_locale("en")
	var t := tr(chave)
	TranslationServer.set_locale("pt_BR")
	return t

func _checa(nome: String, ok: bool) -> void:
	print("TRACOS %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
