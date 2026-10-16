extends SceneTree
## Apagar progresso e novo jogo (headless, save em user://teste_novo_jogo/):
## com personagem e tutorial concluído o jogo abre na vila; Configurações >
## Apagar progresso pede um segundo toque, apaga o save (guardando as
## configurações) e volta para a criação, e dali o Início do jogo segue
## (criação -> brasão -> exibição); o botão "Novo jogo" do painel de
## depuração faz o mesmo; sem save, o jogo abre no título; e a Nuvem real
## nunca fala com o servidor quando o save é de teste.

var _falhas := 0
var _jog: ServicoJogador
var _fluxo: FluxoTelas
const PASTA := "user://teste_novo_jogo/"

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	await process_frame
	_jog = root.get_node("Jogador")
	_fluxo = root.get_node("Fluxo")
	var nuvem: ServicoNuvem = root.get_node("Nuvem")
	DirAccess.make_dir_recursive_absolute(PASTA)
	_jog.caminho_save = PASTA + "jogador.json"
	nuvem.caminho_sessao = PASTA + "sessao.json"
	nuvem.caminho_fila = PASTA + "fila.json"
	nuvem.caminho_cache_balanceamento = PASTA + "balanceamento_remoto.json"
	_checa("nuvem real isolada com save de teste", nuvem.isolado())
	nuvem.sessao = {}

	# Sem save: título (Início do jogo do GDD).
	_jog.estado = _jog.novo_estado()
	_fluxo.iniciar_jogo()
	_checa("sem save abre no titulo", await _cena() is TelaTitulo)

	# Com personagem e tutorial concluído: vila.
	_com_personagem()
	_fluxo.iniciar_jogo()
	var cena := await _cena()
	_checa("com save abre na vila", cena is Vila)
	var vila := cena as Vila
	if vila.cena_historia.visible:
		vila.cena_historia.visible = false

	# Configurações > Apagar progresso, em dois toques.
	vila.tela_configuracoes.abrir()
	var b := _botao(vila.tela_configuracoes, tr("CONFIG_APAGAR_PROGRESSO"))
	_checa("configuracoes tem apagar progresso", b != null)
	b.pressed.emit()
	await process_frame
	var conf := _botao(vila.tela_configuracoes, tr("CONFIG_APAGAR_CONFIRMA"))
	_checa("primeiro toque so pede confirmacao", conf != null and _jog.tem_personagem())
	var cancelar := _botao(vila.tela_configuracoes, tr("CONFIG_EXCLUIR_CANCELAR"))
	cancelar.pressed.emit()
	await process_frame
	_checa("cancelar volta ao botao normal", _botao(vila.tela_configuracoes, tr("CONFIG_APAGAR_PROGRESSO")) != null and _jog.tem_personagem())
	_botao(vila.tela_configuracoes, tr("CONFIG_APAGAR_PROGRESSO")).pressed.emit()
	await process_frame
	_botao(vila.tela_configuracoes, tr("CONFIG_APAGAR_CONFIRMA")).pressed.emit()
	cena = await _cena()
	_checa("segundo toque volta para a criacao", cena is CriacaoPersonagem)
	_checa("sem personagem e tutorial no comeco", not _jog.tem_personagem() and _jog.tutorial_passo() == 1 and not _jog.tutorial_concluido())
	_checa("progresso zerado (nivel 1, sem pecas extras)", int(_jog.cavaleiro()["nivel"]) == 1 and _jog.itens().size() == (Balanceamento.ler("inicio")["itens"] as Array).size())
	_checa("configuracoes guardadas (volume e politica)", int(_jog.config_valor("volume_musica")) == 40 and _jog.privacidade_aceita())
	var disco: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_jog.caminho_save))
	_checa("save no disco sem o personagem", str(disco["cavaleiro"]["nome"]) == "")

	# Daqui o Início do jogo segue normalmente.
	(cena as CriacaoPersonagem).sortear()
	(cena as CriacaoPersonagem).confirmar()
	cena = await _cena()
	_checa("criacao -> brasao", cena is EditorBrasao and _jog.tem_personagem())
	(cena as EditorBrasao).confirmar()
	cena = await _cena()
	_checa("brasao -> justa de exibicao", cena is Arena and _fluxo.modo_justa == "exibicao")

	# Painel de depuração: "Novo jogo" em dois toques.
	var dep := root.get_node_or_null("Depuracao") as ContadorFps
	_checa("painel de depuracao tem novo jogo (build de desenvolvimento)", dep != null and dep.novo_jogo != null)
	_com_personagem()
	dep.novo_jogo.pressed.emit()
	await process_frame
	_checa("depuracao: primeiro toque pede confirmacao", dep.novo_jogo.text == tr("DEPURACAO_NOVO_JOGO_CONFIRMA") and _jog.tem_personagem())
	dep.novo_jogo.pressed.emit()
	cena = await _cena()
	_checa("depuracao: segundo toque vai para a criacao sem personagem", cena is CriacaoPersonagem and not _jog.tem_personagem())
	_checa("depuracao: botao volta ao normal", dep.novo_jogo.text == tr("DEPURACAO_NOVO_JOGO"))

	for arq in ["jogador.json", "jogador.json.bak", "sessao.json", "fila.json"]:
		DirAccess.remove_absolute(PASTA + arq)
	print("NOVOJOGO %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

## Personagem criado, tutorial concluído, nível 4, volume da música 40 e política aceita.
func _com_personagem() -> void:
	_jog.estado = _jog.novo_estado()
	_jog.aceitar_privacidade(false)
	_jog.definir_config("volume_musica", 40)
	_jog.criar_personagem({"nome": "Isolda", "nome_casa": "Casa Pardal", "corpo": "feminino", "rosto": "1", "cabelo": "1",
		"pele": "clara", "cor_principal": "azul_real", "cor_secundaria": "ouro_velho", "pelagem": "preto"})
	_jog.definir_passo_tutorial(ServicoJogador.TUTORIAL_CONCLUIDO)
	_jog.estado["cavaleiro"]["nivel"] = 4
	_jog.salvar()

func _botao(raiz: Node, texto: String) -> Button:
	for n in raiz.find_children("*", "Button", true, false):
		if (n as Button).text == texto and not n.is_queued_for_deletion():
			return n
	return null

## Espera a troca de cena (deferida) e devolve a cena atual.
func _cena() -> Node:
	for i in 4:
		await process_frame
	return current_scene

func _checa(nome: String, ok: bool) -> void:
	print("NOVOJOGO %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
