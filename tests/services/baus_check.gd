extends SceneTree
## Baús (3.14, headless): espaços (4; cheio dá só ouro), um abrindo por vez
## com horário de término, chave, peças novas no inventário e repetidas em
## fragmentos, primeiro dia em segundos, baús das vitórias do PvE (ferro só
## na primeira vez com 3 estrelas, ouro no campeão), migração do save e a
## tela com a animação e as chances.

var _falhas := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_baus/")
	jog.caminho_save = "user://teste_baus/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000  # fora do primeiro dia
	var cfg := jog.cfg_baus()

	_checa("comeca sem baus, com 1 chave", jog.baus().is_empty() and jog.chaves() == int(Balanceamento.carregar("inicio")["chaves"]) and jog.fragmentos() == 0)
	for t in ["madeira", "ferro", "ouro", "real"]:
		jog.ganhar_bau(t)
	_checa("4 espacos cheios", jog.baus().size() == 4)
	var ouro0 := jog.ouro()
	var cheio := jog.ganhar_bau("ferro")
	_checa("cheio: so ouro (%d)" % cheio["ouro"], cheio["cheio"] and jog.baus().size() == 4 and jog.ouro() == ouro0 + int(cfg["tipos"]["ferro"]["ouro"][0]))

	var b_mad: String = jog.baus()[0]["id"]
	var b_fer: String = jog.baus()[1]["id"]
	_checa("abrir antes: fechado", jog.abrir_bau(b_mad)["erro"] == "bau_fechado")
	_checa("comeca a abrir", jog.comecar_abrir(b_mad)["ok"] and int(jog.bau_abrindo()["abre_em"]) == ServicoTempo.agora() + int(cfg["tipos"]["madeira"]["segundos"]))
	_checa("um por vez", jog.comecar_abrir(b_fer)["erro"] == "outro_bau_abrindo")
	_checa("ainda nao pronto", not jog.bau_pronto(b_mad) and jog.abrir_bau(b_mad)["erro"] == "bau_fechado")
	ServicoTempo.deslocamento += int(cfg["tipos"]["madeira"]["segundos"])
	_checa("pronto no horario de termino", jog.bau_pronto(b_mad))
	var n_itens := jog.itens().size()
	var ouro1 := jog.ouro()
	var r := jog.abrir_bau(b_mad)
	var novos: int = r["itens"].filter(func(i): return not i["repetida"]).size()
	_checa("abriu: ouro, pecas e espaco livre", r["ok"] and jog.ouro() == ouro1 + int(r["ouro"]) and jog.itens().size() == n_itens + novos and jog.baus().size() == 3)
	var nova_ok := true
	for it: Dictionary in r["itens"]:
		if not it["repetida"]:
			var maxd := int(Balanceamento.carregar("itens")["modelos"][it["modelo"]]["durabilidade_max"])
			nova_ok = nova_ok and jog.item(it["id"])["durabilidade"] == maxd
	_checa("peca nova com id e durabilidade cheia", nova_ok)
	_checa("fragmentos guardados", jog.fragmentos() == int(r["fragmentos"]))

	# Chave
	var chaves0 := jog.chaves()
	var rc := jog.abrir_bau(b_fer, true)
	_checa("chave abre na hora", rc["ok"] and jog.chaves() == chaves0 - 1 and jog.baus().size() == 2)
	_checa("sem chave", jog.abrir_bau(jog.baus()[0]["id"], true)["erro"] == "sem_chave")
	_checa("garantia contou o ferro", int(jog.estado["baus"]["garantia"]) <= int(cfg["garantia_raro_a_cada"]))

	# Repetida vira fragmentos
	jog.estado["baus"]["chaves"] = 20
	var antes_frag := jog.fragmentos()
	var repetidas := 0
	var frag_baus := 0
	for i in 12:
		var g := jog.ganhar_bau("madeira")
		var rr := jog.abrir_bau(g["id"], true)
		frag_baus += int(rr["fragmentos"])
		repetidas += rr["itens"].filter(func(x): return x["repetida"]).size()
	_checa("repetidas viram fragmentos (%d repetidas)" % repetidas, repetidas > 0 and jog.fragmentos() == antes_frag + frag_baus)
	var modelos_inv := {}
	var duplicado := false
	for it: Dictionary in jog.itens():
		duplicado = duplicado or modelos_inv.has(it["modelo"])
		modelos_inv[it["modelo"]] = true
	_checa("nenhum modelo duplicado no inventario", not duplicado)

	# Primeiro dia: abre em segundos
	jog.estado["criado_em"] = ServicoTempo.agora()
	var g1 := jog.ganhar_bau("real")
	jog.estado["baus"]["espacos"] = [jog.estado["baus"]["espacos"].back()]
	jog.comecar_abrir(g1["id"])
	_checa("primeiro dia: real abre em segundos", ServicoTempo.restante(int(jog.bau_abrindo()["abre_em"])) <= int(Balanceamento.carregar("inicio")["primeiro_dia"]["timer_max_s"]))
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
	jog.estado["baus"]["espacos"] = []

	# PvE: baús das vitórias
	jog.estado["cavaleiro"]["nivel"] = 20
	var tres := [{"tipo": "impacto", "jogador": {"zona": "capacete", "falta": false}},
		{"tipo": "fim", "vencedor": JustaFases.Lado.JOGADOR, "motivo": "derrubada"}]
	var d1 := jog.concluir_disputa("feira_moinho", 0, tres)
	_checa("3 estrelas pela primeira vez: ferro", d1["baus"].size() >= 1 and d1["baus"][0]["tipo"] == "ferro")
	var d2 := jog.concluir_disputa("feira_moinho", 0, tres)
	_checa("repetir 3 estrelas nao da ferro", d2["baus"].all(func(b): return b["tipo"] != "ferro"))
	jog.estado["baus"]["espacos"] = []
	for t: String in ["feira_moinho", "feira_ponte", "feira_mercado", "feira_colheita"]:
		jog.estado["pve"]["torneios"][t] = {"proxima": 99, "concluido": true, "estrelas": {}}
	jog.estado["pve"]["torneios"]["feira_grande"] = {"proxima": 4, "concluido": false, "estrelas": {}}
	var dc := jog.concluir_disputa("feira_grande", 4, tres)
	_checa("vencer o campeao da baú de ouro", dc["baus"].any(func(b): return b["tipo"] == "ouro"))

	# Migração v2 -> v3
	var velho := {"versao": 2, "criado_em": 10, "inventario": {"ouro": 1, "itens": [], "materiais": {"sucata": 2}, "projetos": []}}
	ServicoJogador.migrar(velho)
	_checa("migracao cria baus e fragmentos", velho.has("baus") and int(velho["inventario"]["materiais"]["fragmentos"]) == 0 and int(velho["versao"]) == ServicoJogador.VERSAO)

	# Tela
	jog.estado["baus"]["espacos"] = []
	jog.ganhar_bau("ferro")
	jog.ganhar_bau("madeira")
	var tela: TelaBaus = load("res://game/scenes/ui/tela_baus.tscn").instantiate()
	root.add_child(tela)
	await process_frame
	tela.abrir()
	await process_frame
	_checa("tela: 4 espacos", tela.get_node("Coluna/Espacos").get_child_count() == 4)
	_checa("chances: todas as raridades do bau real", tela.texto_probabilidades().contains("Lendária") and tela.texto_probabilidades().contains("Baú real"))
	tela.abrir_bau(jog.baus()[0]["id"], true)
	await create_timer(1.6).timeout
	_checa("animacao mostra as pecas", tela.get_node("Abertura").visible and tela.get_node("Abertura/Itens").get_child_count() == int(cfg["tipos"]["ferro"]["itens"]) and tela.get_node("Abertura/Continuar").visible)
	tela.queue_free()

	ServicoTempo.deslocamento = 0
	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_baus/" + arq)
	print("BAUS %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("BAUS %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
