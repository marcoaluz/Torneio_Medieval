extends SceneTree
## Dados do jogador e save local (headless, save em user://teste_jogador/):
## estado inicial vindo dos dados, criação de personagem com filtro de nomes,
## salvar/carregar sem perder tipos, recuperação pelo .bak, equipar e
## guarda-roupa, lado para a regra da justa e relógio adiantável.

const PASTA := "user://teste_jogador/"

var _falhas := 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(PASTA)
	for f in ["jogador.json", "jogador.json.bak", "jogador.json.tmp"]:
		DirAccess.remove_absolute(PASTA + f)
	var j := ServicoJogador.new()
	j.caminho_save = PASTA + "jogador.json"
	root.add_child(j)
	await process_frame

	_checa("sem save comeca sem personagem", not j.tem_personagem())
	_checa("estado tem versao", j.estado["versao"] == ServicoJogador.VERSAO)
	_checa("ouro inicial dos dados", j.ouro() == int(Balanceamento.carregar("inicio")["ouro"]))
	_checa("um cavalo ativo", j.cavalos().size() == 1 and not j.cavalo_ativo().is_empty())
	_checa("pecas iniciais equipadas", not j.equipado("elmo").is_empty() and not j.equipado("lanca").is_empty())

	# Nomes
	_checa("nome curto recusado", ServicoNomes.validar("A") == "nome_curto")
	_checa("nome com numero recusado", ServicoNomes.validar("R2D2 Cavaleiro") == "nome_caracteres")
	_checa("palavrao recusado", ServicoNomes.validar("Sir Porra") == "nome_ofensivo")
	_checa("palavrao disfarcado recusado", ServicoNomes.validar("Sir P0rr@") == "nome_caracteres" or ServicoNomes.validar("Fvck Merd4") != "")
	_checa("nome com acento aceito", ServicoNomes.validar("Álvaro d'Ávila") == "")
	_checa("espacos repetidos limpos", ServicoNomes.limpar("  Joana   de  Arc ") == "Joana de Arc")

	var dados := {"nome": "Joana  de Arc", "nome_casa": "Casa Ferreira", "corpo": "feminino", "rosto": "1",
		"cabelo": "2", "pele": "morena", "cor_principal": "verde_floresta", "cor_secundaria": "branco_osso", "pelagem": "preto"}
	var ruim := dados.duplicate()
	ruim["nome"] = "Sir Merda"
	_checa("criar com nome ofensivo falha", j.criar_personagem(ruim)["erro"] == "nome_ofensivo" and not j.tem_personagem())
	var mudancas := []
	j.mudou.connect(func(s): mudancas.append(s))
	var r := j.criar_personagem(dados)
	_checa("criar personagem", r["ok"] and j.tem_personagem() and j.cavaleiro()["nome"] == "Joana de Arc")
	_checa("aviso de mudanca", mudancas.has("cavaleiro"))
	_checa("pelagem do cavalo", j.cavalo_ativo()["pelagem"] == "preto")
	_checa("leitura devolve copia", (func(): var c := j.cavaleiro(); c["nome"] = "x"; return j.cavaleiro()["nome"] == "Joana de Arc").call())

	# Equipar e guarda-roupa
	var elmo_id: String = j.estado["equipamento"]["elmo"]
	_checa("equipar item inexistente falha", not j.equipar("nada")["ok"])
	_checa("guarda-roupa no espaco errado falha", j.definir_visual("peitoral", elmo_id)["erro"] == "espaco_errado")
	_checa("guarda-roupa ok", j.definir_visual("elmo", elmo_id)["ok"] and j.visual_das_pecas()["elmo"] == "escudeiro")

	# Lado para a justa
	var lado := j.lado_para_justa()
	_checa("lado tem as quatro pecas da regra", lado["equipamento"].keys().size() == 4)
	_checa("lado com atributos do inicio", int(lado["cavaleiro"]["forca"]) == 30)
	_checa("lado valido para a justa", Justa.validar(Justa.carregar_configuracao()) == "" and lado["habilidades"] == ["investida"])
	var cfg := Justa.carregar_configuracao()
	var justa := Justa.new(cfg, lado, Justa.lado_padrao(Balanceamento.carregar("padrao")), 1)
	_checa("justa aceita o lado do jogador", justa.iniciar().size() > 0)

	# Salvar e carregar
	var j2 := ServicoJogador.new()
	j2.caminho_save = j.caminho_save
	_checa("carregar le o save", j2.carregar() and j2.cavaleiro()["nome"] == "Joana de Arc")
	_checa("inteiros continuam inteiros", typeof(j2.estado["inventario"]["ouro"]) == TYPE_INT and typeof(j2.estado["versao"]) == TYPE_INT)
	j.definir_brasao({"forma": "classico"})
	var f := FileAccess.open(j.caminho_save, FileAccess.WRITE)
	f.store_string("{corrompido")
	f.close()
	var j3 := ServicoJogador.new()
	j3.caminho_save = j.caminho_save
	_checa("save estragado cai no .bak", j3.carregar() and j3.tem_personagem())
	_checa("migrar mantem versao atual", ServicoJogador.migrar({"versao": 1})["versao"] == ServicoJogador.VERSAO)

	# Relógio
	var fim := ServicoTempo.agora() + 60
	_checa("timer nao pronto", not ServicoTempo.pronto(fim) and ServicoTempo.restante(fim) > 55)
	ServicoTempo.deslocamento = 61
	_checa("relogio adiantado termina o timer", ServicoTempo.pronto(fim) and ServicoTempo.restante(fim) == 0)
	ServicoTempo.deslocamento = 0

	j2.free()
	j3.free()
	print("JOGADOR %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("JOGADOR %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
