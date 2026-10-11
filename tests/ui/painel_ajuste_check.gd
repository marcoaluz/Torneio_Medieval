extends SceneTree
## Painel de ajuste (headless, build de depuração): abre e pausa, muda valores
## que a justa em andamento já usa, atributos e perfil valendo ao recomeçar,
## e salvar grava JSON válido (versão mantida, inteiros sem ".0") numa pasta
## de teste em user:// (os dados do jogo não são tocados).

const PASTA_TESTE := "user://ajuste_teste/"

var _falhas := 0

func _initialize() -> void:
	var arena: Arena = load("res://game/scenes/arena/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var c: ControladorJusta = arena.get_node("Justa")
	var p: PainelAjuste = arena.get_node("PainelAjuste")
	c.set_process(false)
	c.iniciar(9)

	_checa("painel existe em depuracao", is_instance_valid(p) and OS.is_debug_build())
	_checa("botao do painel nao vira toque do jogo", p.contem_ponto(p.get_node("Abrir").get_global_rect().get_center()))
	p.abrir()
	_checa("abrir pausa o jogo", paused)
	_checa("painel aberto segura todos os toques", p.contem_ponto(Vector2(480, 270)))

	p.definir_valor("galope", "galope.compasso_ms", 600)
	_checa("compasso muda na justa em andamento (%d)" % c.justa.jogador.compasso_ms(), c.justa.jogador.compasso_ms() == 600)
	var antes := Mira.zona_no_ponto(c._cfg["mira"], Vector2i(150, -1390), 0, 0)
	p.definir_valor("mira", "zonas.1.retangulos.0.2", 30)
	var depois := Mira.zona_no_ponto(c._cfg["mira"], Vector2i(150, -1390), 0, 0)
	_checa("zona do capacete alarga na hora (%s -> %s)" % [antes, depois], antes == "erro" and depois == "capacete")
	_checa("valor lido de volta", p.ler_valor("mira", "zonas.1.retangulos.0.2") == 30)

	p.definir_valor("padrao", "cavaleiro.forca", 77)
	var perfil_ix := -1
	var op: OptionButton = p.get_node("Painel/Coluna/Perfil")
	for i in op.item_count:
		if op.get_item_text(i) == "agressivo":
			perfil_ix = i
	op.select(perfil_ix)
	op.item_selected.emit(perfil_ix)
	p.recomecar()
	_checa("fechar volta a rodar", not paused)
	_checa("forca nova vale ao recomecar (%s)" % c.justa.lado_jogador["cavaleiro"]["forca"], int(c.justa.lado_jogador["cavaleiro"]["forca"]) == 77)
	_checa("perfil do rival muda ao recomecar", c.perfil_rival == "agressivo")

	DirAccess.make_dir_recursive_absolute(PASTA_TESTE)
	p.pasta_saida = PASTA_TESTE
	_checa("salvar grava os arquivos", p.salvar())
	var texto := FileAccess.get_file_as_string(PASTA_TESTE + "galope.json")
	var lido: Variant = JSON.parse_string(texto)
	_checa("JSON salvo e valido e com versao", lido is Dictionary and lido.has("versao") and Galope.validar(lido) == "")
	_checa("inteiro sem .0 no arquivo", texto.contains("\"compasso_ms\": 600") and not texto.contains("600.0"))
	_checa("dados do jogo nao foram tocados", int(JSON.parse_string(FileAccess.get_file_as_string("res://game/data/balance/galope.json"))["galope"]["compasso_ms"]) == 500)

	for nome in PainelAjuste.ARQUIVOS:
		Balanceamento.esquecer(nome)
		DirAccess.remove_absolute(PASTA_TESTE + nome + ".json")
	print("PAINEL %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("PAINEL %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
