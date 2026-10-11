extends SceneTree
## Anúncios premiados (3.19, headless): provedor falso injetado; baú extra,
## cortar timer (uma vez por timer), dobrar a vitória (prazo), limite
## diário, anúncio não terminado não paga, VIP não assiste, comprovante
## obrigatório, migração e o botão na tela de baús.

var _falhas := 0
var _chamadas := 0
var _assiste := true

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_anuncios/")
	jog.caminho_save = "user://teste_anuncios/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
	var an: ServicoAnuncios = root.get_node("Anuncios")
	an.provedor = _provedor
	var cfg := jog.cfg_anuncios()

	# Baú extra
	var r := await an.assistir("bau_madeira_extra")
	_checa("bau de madeira extra", r["ok"] and jog.baus().size() == 1 and _chamadas == 1)

	# Anúncio que não terminou não paga
	_assiste = false
	var r2 := await an.assistir("bau_madeira_extra")
	_checa("anuncio nao assistido nao paga", r2["erro"] == "anuncio_nao_assistido" and jog.baus().size() == 1 and jog.anuncios_restantes() == int(cfg["limite_dia"]) - 1)
	_assiste = true

	# Cortar timer
	jog.treinar_cavaleiro("forca")
	jog.estado["cavaleiro"]["nivel"] = 12
	var t: Dictionary = jog.timers()[0]
	t["termina_em"] = ServicoTempo.agora() + 3 * 3600
	for x: Dictionary in jog.estado["timers"]:
		x["termina_em"] = ServicoTempo.agora() + 3 * 3600
	var antes := int(jog.timers()[0]["termina_em"])
	var r3 := await an.assistir("cortar_timer", t["id"])
	_checa("corta 30 min", r3["ok"] and int(jog.timers()[0]["termina_em"]) == antes - int(cfg["cortar_minutos"]) * 60)
	_checa("uma vez por timer", (await an.assistir("cortar_timer", t["id"]))["erro"] == "timer_ja_cortado")

	# Dobrar a vitória
	jog.estado["cavaleiro"]["nivel"] = 20
	var vit := [{"tipo": "impacto", "jogador": {"zona": "peito", "falta": false}}, {"tipo": "fim", "vencedor": JustaFases.Lado.JOGADOR, "motivo": "pontos", "placar_jogador": 4, "placar_rival": 1}]
	var d := jog.concluir_disputa("feira_moinho", 0, vit)
	var ouro0 := jog.ouro()
	var r4 := await an.assistir("dobrar_vitoria")
	_checa("dobra o ouro da vitoria (+%d)" % r4.get("recompensa", {}).get("ouro", 0), r4["ok"] and jog.ouro() == ouro0 + int(d["ouro"]) * (int(cfg["dobrar_vitoria"]) - 1))
	_checa("nao dobra duas vezes", (await an.assistir("dobrar_vitoria"))["erro"] == "sem_vitoria_para_dobrar")
	jog.concluir_disputa("feira_moinho", 0, vit)
	ServicoTempo.deslocamento += 700
	_checa("prazo para dobrar", (await an.assistir("dobrar_vitoria"))["erro"] == "sem_vitoria_para_dobrar")
	ServicoTempo.deslocamento = 0

	# Limite diário
	var guarda := 0
	while jog.anuncios_restantes() > 0 and guarda < 10:
		jog.estado["baus"]["espacos"] = []
		await an.assistir("bau_madeira_extra")
		guarda += 1
	jog.estado["baus"]["espacos"] = []
	_checa("limite diario", (await an.assistir("bau_madeira_extra"))["erro"] == "limite_anuncios")
	ServicoTempo.deslocamento += 86400
	_checa("dia novo renova", jog.anuncios_restantes() == int(cfg["limite_dia"]))

	# VIP: sem assistir
	jog.comprar("vip_mensal")
	var chamadas0 := _chamadas
	var r5 := await an.assistir("bau_madeira_extra")
	_checa("VIP recebe sem assistir", r5["ok"] and r5["sem_anuncio"] and _chamadas == chamadas0)
	ServicoTempo.deslocamento = 0

	_checa("sem comprovante nao paga", jog.recompensa_anuncio("bau_madeira_extra", "", "")["erro"] in ["anuncio_sem_comprovante", "espacos_cheios"])

	# Migração
	var velho := {"versao": 9}
	ServicoJogador.migrar(velho)
	_checa("migracao cria anuncios", velho.has("anuncios") and int(velho["anuncios"]["usados"]) == 0)

	# Tela de baús
	jog.estado["baus"]["espacos"] = []
	jog.estado["loja"]["vip_ate"] = 0
	ServicoTempo.deslocamento += 3 * 86400
	var tela: TelaBaus = load("res://game/scenes/ui/tela_baus.tscn").instantiate()
	root.add_child(tela)
	await process_frame
	tela.abrir()
	await process_frame
	var botao := tela.get_node_or_null("Coluna/AnuncioBau") as Button
	_checa("botao do bau gratis por anuncio", botao != null and botao.visible and botao.text.begins_with("▶"))
	tela.queue_free()
	ServicoTempo.deslocamento = 0

	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_anuncios/" + arq)
	print("ANUNCIOS %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _provedor(tipo: String) -> Dictionary:
	_chamadas += 1
	await process_frame
	return {"assistiu": _assiste, "token": "falso_%s" % tipo}

func _checa(nome: String, ok: bool) -> void:
	print("ANUNCIOS %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
