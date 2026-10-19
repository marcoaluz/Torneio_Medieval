extends SceneTree
## Campeões do PvE no serviço Jogador (save em user://teste_campeoes/): dados
## da ficha (traço, alcunha, retrato, poder), troféu e peça na primeira
## vitória, peça de troféu só na aparência, revanche heroica (uma por dia,
## mais forte a cada vitória, recompensa melhor) e a migração do save v11.

var _falhas := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_campeoes/")
	jog.caminho_save = "user://teste_campeoes/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
	jog.estado["cavaleiro"]["nivel"] = 20
	var pve := jog.pve()

	# Ficha: tudo o que a tela mostra vem do serviço.
	var rv := jog.rival_para_justa("martim_martelo")
	_checa("ficha: traco, alcunha e frases", rv["traco"] == "cacador_de_elmos" and rv["alcunha"] == "ALCUNHA_MARTIM_MARTELO"
		and rv["frase_entrada"] != "" and rv["frase_derrota"] != "")
	_checa("ficha: retrato = id do rival", rv["retrato"] == "martim_martelo")
	_checa("ficha: rei Sancho usa o retrato do rei da historia", jog.rival_para_justa("rei_sancho_justador")["retrato"] == "rei")
	_checa("ficha: poder do rival > 0 (%d)" % int(rv["poder"]), int(rv["poder"]) > 0)
	var forte := jog.rival_para_justa("rei_sancho_justador")
	_checa("ficha: o rei e mais forte que Martim", int(forte["poder"]) > int(rv["poder"]))
	_checa("ficha: rei e vermelho para um cavaleiro novo",
		RegraPve.faixa_poder(jog.poder_jogador(), int(forte["poder"]), pve["ficha"]) == "vermelho")
	_checa("ficha: o nemesis traz encontros e bonus", jog.rival_para_justa("nemesis_corvo").has("encontros"))
	_checa("ficha: 17 campeoes no circuito, em ordem", jog.campeoes().size() == 17 and jog.campeoes()[0] == "campeao_valdemar"
		and jog.campeoes()[-1] == "rei_sancho_justador")

	# Troféu: só na primeira vitória sobre o campeão.
	for t in ["feira_moinho", "feira_ponte", "feira_mercado", "feira_colheita"]:
		jog.estado["pve"]["torneios"][t] = {"proxima": 9, "concluido": true, "estrelas": {}}
	jog.estado["pve"]["torneios"]["feira_grande"] = {"proxima": 4, "concluido": false, "estrelas": {}}
	_checa("revanche antes do trofeu: sem_trofeu", jog.pode_revanche("campeao_valdemar")["erro"] == "sem_trofeu")
	_checa("revanche de quem nao e campeao", jog.pode_revanche("cavaleiro_negro")["erro"] == "nao_e_campeao")
	var perdeu := jog.concluir_disputa("feira_grande", 4, _ev(false))
	_checa("derrota nao da trofeu", perdeu["trofeu"] == "" and jog.trofeus().is_empty())
	var venceu := jog.concluir_disputa("feira_grande", 4, _ev(true))
	_checa("primeira vitoria: trofeu e peca", venceu["trofeu"] == "campeao_valdemar" and venceu["peca_trofeu"] == "trofeu_campeao_valdemar")
	_checa("trofeu na estante", jog.trofeus().size() == 1 and jog.trofeus()[0]["torneio"] == "feira_grande")
	_checa("peca conquistada", jog.pecas_trofeu() == ["trofeu_campeao_valdemar"])
	var de_novo := jog.concluir_disputa("feira_grande", 4, _ev(true))
	_checa("vencer de novo nao da outro trofeu", de_novo["trofeu"] == "" and jog.trofeus().size() == 1)

	# Peça de troféu: só aparência, por cima do espaço.
	var lado_antes := JSON.stringify(jog.lado_para_justa())
	var poder_antes := jog.poder_jogador()
	_checa("usar a peca no espaco errado", jog.usar_peca_trofeu("cimeira", "trofeu_campeao_valdemar")["erro"] == "espaco_errado")
	_checa("usar peca nao conquistada", jog.usar_peca_trofeu("cimeira", "trofeu_martim_martelo")["erro"] == "peca_bloqueada")
	_checa("usar a peca", jog.usar_peca_trofeu("estandarte", "trofeu_campeao_valdemar")["ok"])
	_checa("a peca vai para a aparencia", jog.visual_das_pecas().get("estandarte", "") == "trofeu_campeao_valdemar")
	_checa("a peca nao muda a justa nem o poder", JSON.stringify(jog.lado_para_justa()) == lado_antes and jog.poder_jogador() == poder_antes)
	jog.usar_peca_trofeu("estandarte", "")
	_checa("tirar a peca", not jog.visual_das_pecas().has("estandarte"))
	# Manta de troféu sobre a caparação usa a provisória até ter arte.
	jog.estado["pve"]["trofeus"]["sir_egas_muro"] = {"em": 1, "torneio": "torneio_conde", "revanches": 0}
	jog.usar_peca_trofeu("caparacao", "trofeu_sir_egas_muro")
	_checa("manta de trofeu por cima da caparacao", jog.visual_das_pecas()["caparacao"] == "trofeu_sir_egas_muro")
	_checa("manta de trofeu tem arte provisoria", CamadasPersonagem.visual_provisorio("trofeu_sir_egas_muro") == "xadrez_real")
	jog.usar_peca_trofeu("caparacao", "")
	jog.estado["pve"]["trofeus"].erase("sir_egas_muro")

	# Revanche heroica: mais forte, uma por dia, recompensa melhor.
	var cfg: Dictionary = pve["revanche"]
	var base := jog.rival_para_justa("campeao_valdemar")
	var prep := jog.preparar_revanche("campeao_valdemar")
	var b0 := int(cfg["bonus_atributos"])
	_checa("revanche: +%d em cada atributo" % b0, int(prep["rival"]["lado"]["cavaleiro"]["forca"]) == int(base["lado"]["cavaleiro"]["forca"]) + b0
		and int(prep["rival"]["lado"]["cavalo"]["velocidade"]) == int(base["lado"]["cavalo"]["velocidade"]) + b0)
	_checa("revanche: largada perfeita do perfil sobe", int(prep["rival"]["perfil"]["largada_perfeita_milesimos"])
		== int(base["perfil"]["largada_perfeita_milesimos"]) + int(cfg["perfil_ajuste"]["largada_perfeita_milesimos"]))
	_checa("revanche: sem desafios e marcada", prep["desafios"].is_empty() and prep["rival"]["revanche"] and prep["revanche"] == "campeao_valdemar")
	_checa("revanche: poder maior que o do campeao", int(prep["rival"]["poder"]) > int(base["poder"]))
	var ouro_antes := jog.ouro()
	var r1 := jog.concluir_revanche("campeao_valdemar", _ev(true))
	var rd: Dictionary = pve["recompensa_disputa"]
	var esperado := (int(rd["ouro_base"]) + 3 * int(rd["ouro_por_estrela"])) * 100 / 100 * int(cfg["recompensa_pct"]) / 100
	_checa("revanche vencida: ouro de 3 estrelas x %d%% (%d)" % [int(cfg["recompensa_pct"]), int(r1["ouro"])], r1["venceu"] and int(r1["ouro"]) == esperado
		and jog.ouro() == ouro_antes + esperado)
	_checa("revanche vencida: bau e materiais", r1["baus"].size() == 1 and r1["baus"][0]["tipo"] == cfg["bau"] and not r1["materiais"].is_empty())
	_checa("revanche paga mais que repetir a disputa", int(r1["ouro"]) > int(de_novo["ouro"]))
	_checa("uma revanche por dia", jog.pode_revanche("campeao_valdemar")["erro"] == "revanche_feita_hoje"
		and jog.concluir_revanche("campeao_valdemar", _ev(true))["erro"] == "revanche_feita_hoje")
	_checa("estante mostra a revanche do dia feita", jog.trofeus()[0]["hoje"] and int(jog.trofeus()[0]["revanches"]) == 1)
	ServicoTempo.deslocamento += 86400
	_checa("no dia seguinte, pode de novo", jog.pode_revanche("campeao_valdemar")["ok"])
	_checa("e volta mais forte (+%d)" % jog.bonus_revanche("campeao_valdemar"),
		jog.bonus_revanche("campeao_valdemar") == b0 + int(cfg["bonus_por_vitoria"]))
	var r2 := jog.concluir_revanche("campeao_valdemar", _ev(false))
	_checa("perder a revanche: nada pago, mas gasta a do dia", not r2["venceu"] and int(r2["ouro"]) == 0
		and jog.pode_revanche("campeao_valdemar")["erro"] == "revanche_feita_hoje")
	ServicoTempo.deslocamento += 86400 * 20
	jog.estado["pve"]["trofeus"]["campeao_valdemar"]["revanches"] = 50
	_checa("o bonus para no teto", jog.bonus_revanche("campeao_valdemar") == int(cfg["bonus_max"]))
	ServicoTempo.deslocamento = 0

	# Migração: save v11 ganha troféus e peças em uso.
	var antigo := jog.novo_estado()
	antigo["versao"] = 11
	antigo["pve"].erase("trofeus")
	antigo.erase("visual_trofeu")
	var m := ServicoJogador.migrar(antigo)
	_checa("migracao v11 -> v12", int(m["versao"]) == ServicoJogador.VERSAO and m["pve"]["trofeus"] == {} and m["visual_trofeu"] == {})
	_checa("versao do save e 12", ServicoJogador.VERSAO == 12)

	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_campeoes/" + arq)
	print("CAMPEOES %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _ev(venceu: bool) -> Array:
	return [{"tipo": "impacto", "jogador": {"zona": "peito", "falta": false}},
		{"tipo": "fim", "vencedor": JustaFases.Lado.JOGADOR if venceu else JustaFases.Lado.RIVAL,
			"motivo": "derrubada" if venceu else "pontos", "placar_jogador": 2, "placar_rival": 0 if venceu else 3}]

func _checa(nome: String, ok: bool) -> void:
	print("CAMPEOES %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
