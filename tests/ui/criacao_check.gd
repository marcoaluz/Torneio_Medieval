extends SceneTree
## Tela de criação de personagem (headless). O save do Jogador vai para
## user://teste_criacao/ (não toca no perfil real).

var _falhas := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame  # o _ready do autoload Jogador roda antes de mexermos nele
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_criacao/")
	jog.caminho_save = "user://teste_criacao/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000  # fora do primeiro dia
	var tela: CriacaoPersonagem = load("res://game/scenes/ui/criacao_personagem.tscn").instantiate()
	root.add_child(tela)
	await process_frame

	_checa("titulo traduzido", tela.get_node("Titulo").text == "Seu cavaleiro")
	tela.confirmar()
	_checa("sem nome mostra erro traduzido", tela._erro.text == "Dê um nome ao seu cavaleiro." and not jog.tem_personagem())
	tela._nome.text = "Sir Merda"
	tela._casa.text = "Casa Boa"
	tela.confirmar()
	_checa("nome ofensivo recusado", tela._erro.text == "Escolha outro nome." and not jog.tem_personagem())

	tela._seletores["corpo"].escolher("feminino")
	tela._amostras["cor_principal"].escolher("verde_floresta")
	tela._seletores["pelagem"].escolher("branco")
	_checa("previa muda a cor da casa", tela._cavaleiro.casa_principal == "verde_floresta")
	_checa("previa muda a pelagem", tela._cavaleiro.camadas().camada("cavalo").texture.resource_path.contains("cavalo_branco"))
	_checa("previa muda o corpo", tela._retrato.camada("corpo").texture.resource_path.contains("corpo_feminino"))

	tela.sortear()
	_checa("sortear preenche nome e casa", tela._nome.text != "" and tela._casa.text != "")
	_checa("sortear nao repete as duas cores", tela.escolha["cor_principal"] != tela.escolha["cor_secundaria"])
	_checa("nomes sorteados passam no filtro", ServicoNomes.validar(tela._nome.text) == "" and ServicoNomes.validar(tela._casa.text) == "")
	var criado := [false]
	tela.personagem_criado.connect(func(): criado[0] = true)
	tela.confirmar()
	_checa("confirmar cria o personagem", criado[0] and jog.tem_personagem() and jog.cavaleiro()["nome"] == tela._nome.text)
	_checa("cores e pelagem gravadas", jog.casa()["cores"]["principal"] == tela.escolha["cor_principal"]
		and jog.cavalo_ativo()["pelagem"] == tela.escolha["pelagem"])

	for f in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_criacao/" + f)
	print("CRIACAO %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("CRIACAO %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
