extends SceneTree
## Ficha do adversário, duelo do campeão e estante de troféus, headless com a
## vila de verdade (save em user://teste_ficha/): Justar no torneio abre a
## ficha (não a arena); a ficha mostra traço, ponto fraco, habilidade com a
## que anula, e o poder colorido pela faixa; Equipamentos troca e volta para
## a ficha; Lutar contra campeão passa pelo duelo, contra rival comum vai
## direto; o PvP também passa pela ficha; a casa senhorial tem a estante com
## um lugar por campeão e a revanche heroica abre a ficha da revanche.

var _falhas := 0
var _lutou := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_ficha/")
	jog.caminho_save = "user://teste_ficha/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000
	jog.estado["cavaleiro"]["nivel"] = 20
	jog.estado["cavaleiro"]["nome"] = "Isolda"
	for t in ["feira_moinho", "feira_ponte", "feira_mercado", "feira_colheita"]:
		jog.estado["pve"]["torneios"][t] = {"proxima": 9, "concluido": true, "estrelas": {}}
	jog.estado["pve"]["torneios"]["feira_grande"] = {"proxima": 4, "concluido": false, "estrelas": {}}
	var vila: Vila = load("res://game/scenes/village/vila.tscn").instantiate()
	root.add_child(vila)
	await _quadros(3)
	vila.cena_historia.visible = false

	# Justar contra o campeão: a ficha, não a arena.
	vila.tela_torneios.abrir()
	vila.tela_torneios.torneio = "feira_grande"
	vila.tela_torneios.montar()
	await _quadros(2)
	vila.tela_torneios._justar(4)
	await _quadros(2)
	var ficha := vila.ficha()
	_checa("justar abre a ficha", ficha.visible and ficha.rival.get("id", "") == "campeao_valdemar")
	var textos := _textos(ficha)
	_checa("ficha: nome e alcunha do campeao", textos.has(tr("RIVAL_CAMPEAO_VALDEMAR")) and textos.has(tr("ALCUNHA_CAMPEAO_VALDEMAR")))
	_checa("ficha: traco e ponto fraco", textos.any(func(t): return t.contains(tr("TRACO_LARGADA_PERFEITA")) and t.contains(tr("TRACO_LARGADA_PERFEITA_DESC")))
		and
		textos.any(func(t): return t.contains(tr("TRACO_LARGADA_PERFEITA_FRAQUEZA"))))
	_checa("ficha: habilidade e a que anula", textos.any(func(t): return t.contains(tr("HABILIDADE_GOLPE_PESADO")) and t.contains(tr("HABILIDADE_BLOQUEIO"))))
	var poder_r := ficha.find_child("Rival", true, false).find_child("Poder", true, false) as Label
	var cor: Color = Color(str(jog.pve()["ficha"]["cores"][ficha.faixa()]))
	_checa("ficha: poder do rival na cor da faixa %s" % ficha.faixa(), poder_r != null and poder_r.get_theme_color("font_color") == cor)
	_checa("ficha: poder dos dois lados", textos.filter(func(t): return t.begins_with(tr("FICHA_PODER").split("{")[0])).size() == 2)
	_checa("ficha: retrato provisorio com a cor da casa", (ficha.find_child("Retrato", true, false) as RetratoRival) != null)

	# Equipamentos e de volta.
	(ficha.find_child("Equipamentos", true, false) as Button).pressed.emit()
	await _quadros(2)
	_checa("Equipamentos troca a ficha pela tela de equipamentos", vila.tela_equipamentos.visible and not ficha.visible)
	vila.tela_equipamentos.fechar()
	await _quadros(2)
	_checa("fechar os equipamentos volta para a ficha", ficha.visible)

	# Lutar contra campeão: duelo, depois a arena (aqui, o espião).
	vila._ao_lutar = func(): _lutou += 1
	(ficha.find_child("Lutar", true, false) as Button).pressed.emit()
	await _quadros(2)
	var duelo := vila.duelo()
	_checa("lutar contra campeao abre o duelo", duelo.visible and not ficha.visible and _lutou == 0)
	var dt := _textos(duelo)
	_checa("duelo: o arauto anuncia os dois", dt.any(func(t): return t.contains("Isolda") and t.contains(tr("RIVAL_CAMPEAO_VALDEMAR"))))
	_checa("duelo: frase de entrada do campeao", dt.has(tr("ENTRADA_CAMPEAO_VALDEMAR")))
	duelo.seguir()
	duelo.seguir()
	await _quadros(1)
	_checa("o toque no duelo segue para a liça", _lutou == 1 and not duelo.visible)

	# Rival comum: Lutar vai direto.
	vila.tela_torneios.torneio = "feira_moinho"
	vila.tela_torneios._justar(0)
	await _quadros(2)
	vila._ao_lutar = func(): _lutou += 1
	_checa("rival comum: ficha sem alcunha", ficha.visible and str(ficha.rival.get("alcunha", "")) == "")
	(ficha.find_child("Lutar", true, false) as Button).pressed.emit()
	await _quadros(2)
	_checa("rival comum: sem duelo", _lutou == 2 and not duelo.visible)
	vila.tela_torneios.visible = false

	# PvP: a ficha também.
	jog.procurar_adversario()
	vila.tela_liga.abrir()
	await _quadros(2)
	vila.tela_liga._justar()
	await _quadros(2)
	_checa("PvP abre a ficha do adversario", ficha.visible and ficha.rival.get("pvp", false) and int(ficha.rival["poder"]) > 0)
	ficha.fechar()
	vila.tela_liga.visible = false

	# Estante de troféus e revanche heroica.
	jog.concluir_disputa("feira_grande", 4, [{"tipo": "fim", "vencedor": JustaFases.Lado.JOGADOR, "motivo": "derrubada"}])
	vila.tela_perfil.abrir()
	vila.tela_perfil.aba = "trofeus"
	vila.tela_perfil.atualizar()
	await _quadros(2)
	var estante := vila.tela_perfil.find_child("Estante", true, false)
	var lugares := estante.find_children("*", "Button", true, false) if estante else []
	_checa("estante: um lugar por campeao (%d)" % lugares.size(), lugares.size() == 17)
	var lugar := estante.find_child("campeao_valdemar", true, false) as Button
	_checa("estante: o vencido tem o brasao, os outros ficam escuros", lugar != null and not lugar.disabled and lugar.icon != null
		and (estante.find_child("rei_sancho_justador", true, false) as Button).disabled)
	lugar.pressed.emit()
	await _quadros(2)
	var caixa := vila.tela_perfil.find_child("Trofeu", true, false)
	_checa("estante: o trofeu mostra a peca e a revanche", caixa != null and caixa.find_child("UsarPeca", true, false) != null)
	(caixa.find_child("UsarPeca", true, false) as Button).pressed.emit()
	await _quadros(2)
	_checa("estante: usar a peca", jog.peca_trofeu_em_uso("estandarte") == "trofeu_campeao_valdemar")
	(vila.tela_perfil.find_child("Revanche", true, false) as Button).pressed.emit()
	await _quadros(2)
	_checa("revanche abre a ficha da revanche", ficha.visible and ficha.rival.get("revanche", false) and not vila.tela_perfil.visible)
	_checa("ficha da revanche mostra o bonus", _textos(ficha).any(func(t): return t.contains(str(jog.bonus_revanche("campeao_valdemar")))))
	vila._ao_lutar = func(): _lutou += 1
	(ficha.find_child("Lutar", true, false) as Button).pressed.emit()
	await _quadros(2)
	_checa("revanche passa pelo duelo com o anuncio da revanche", duelo.visible and _textos(duelo).any(func(t): return t.contains(tr("DUELO_ARAUTO_REVANCHE").split("{")[0].strip_edges())))

	for arq in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_ficha/" + arq)
	print("FICHA %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _textos(raiz: Node) -> Array:
	var t: Array = []
	for n in raiz.find_children("*", "Label", true, false):
		if (n as Label).is_visible_in_tree():
			t.append((n as Label).text)
	return t

func _quadros(n: int) -> void:
	for i in n:
		await process_frame

func _checa(nome: String, ok: bool) -> void:
	print("FICHA %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
