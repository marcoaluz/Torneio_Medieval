extends SceneTree
## Desafios especiais do PvE e estilo dos campeões (regra pura), pelos casos
## compartilhados de tests/shared/desafios_pve.json (o servidor roda os mesmos).

var _falhas := 0

func _initialize() -> void:
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/shared/desafios_pve.json"))
	var b: Dictionary = dados["base"]
	var copia := JSON.stringify(b)
	for caso: Dictionary in dados["casos"]:
		var r := RegraPve.aplicar_desafios(b["cfg"], b["lado_jogador"], b["lado_rival"], b["perfil_rival"], caso["desafios"], dados["defs"])
		var ok := true
		for chave: String in caso["esperado"]:
			var v: Variant = _ler(r, chave)
			var e: Variant = caso["esperado"][chave]
			if (e == null and v != null) or (e != null and (v == null or int(v) != int(e))):
				ok = false
				print("  %s: esperado %s, veio %s" % [chave, e, v])
		if caso["desafios"].is_empty():
			ok = ok and JSON.stringify({"cfg": r["cfg"], "lado_jogador": r["lado_jogador"], "lado_rival": r["lado_rival"], "perfil_rival": r["perfil_rival"]}) \
				== JSON.stringify({"cfg": b["cfg"], "lado_jogador": b["lado_jogador"], "lado_rival": b["lado_rival"], "perfil_rival": b["perfil_rival"]})
		_checa(caso["nome"], ok)
	_checa("nao muda a entrada", JSON.stringify(b) == copia)
	for caso: Dictionary in dados["perfil"]:
		var p := RegraPve.ajustar_perfil(caso["perfil"], caso["ajuste"])
		var ok := true
		for k: String in caso["esperado"]:
			if str(p.get(k)) != str(caso["esperado"][k]) and not (typeof(caso["esperado"][k]) == TYPE_FLOAT and int(p.get(k, -1)) == int(caso["esperado"][k])):
				ok = false
		_checa("perfil: " + caso["nome"], ok)
	for caso: Dictionary in dados["perfil_rival"]:
		var p := RegraPve.perfil_do_rival(dados["ia_perfil_rival"], caso["rival"])
		var ok := true
		for k: String in caso["esperado"]:
			var e: Variant = caso["esperado"][k]
			if e == null:
				ok = ok and not p.has(k)
			elif str(p.get(k)) != str(e) and not (typeof(e) == TYPE_FLOAT and int(p.get(k, -1)) == int(e)):
				ok = false
		_checa("perfil do rival: " + caso["nome"], ok)
	# Os desafios do jogo de verdade batem com os casos (mesmos ids e efeitos).
	var defs_jogo: Dictionary = Balanceamento.carregar("pve")["desafios"]
	_checa("pve.json tem os 5 desafios do GDD", defs_jogo.keys().size() == 5 and dados["defs"].keys().all(func(k): return defs_jogo.has(k)))
	print("DESAFIOS %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

## Lê "a.b.c" de dicionários aninhados (null se não existe).
func _ler(d: Dictionary, caminho: String) -> Variant:
	var v: Variant = d
	for parte in caminho.split("."):
		if not (v is Dictionary) or not (v as Dictionary).has(parte):
			return null
		v = v[parte]
	return v

func _checa(nome: String, ok: bool) -> void:
	print("DESAFIOS %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
