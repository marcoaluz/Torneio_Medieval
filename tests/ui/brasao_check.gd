extends SceneTree
## Brasão (headless): gerador (divisões, símbolo, furo, contorno, forma,
## mesma entrada = mesma imagem), editor (prévia e gravar no Jogador, save
## em user://teste_brasao/) e brasões no cavaleiro (três lugares, sem espelho
## no rival).

var _falhas := 0

func _initialize() -> void:
	TranslationServer.set_locale("pt_BR")
	var cfg := GeradorBrasao.opcoes()
	var pal: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CamadasPersonagem.PALETAS))["cores_casa"]
	var azul := Color(pal["azul_real"])
	var ouro := Color(pal["ouro_velho"])
	var contorno := Color(cfg["cor_contorno"])
	var tam := Vector2i(40, 48)

	var liso := GeradorBrasao.imagem({"divisao": "liso", "simbolo": "nenhum", "cor1": "azul_real"}, tam)
	_checa("liso pinta tudo com a cor 1", _igual(liso.get_pixel(10, 10), azul) and _igual(liso.get_pixel(30, 30), azul))
	_checa("contorno escuro na borda", _igual(liso.get_pixel(0, 10), contorno))
	_checa("fora do escudo e transparente (ponta)", liso.get_pixel(0, 47).a == 0.0)
	var partido := GeradorBrasao.imagem({"divisao": "partido", "simbolo": "nenhum", "cor1": "azul_real", "cor2": "ouro_velho"}, tam)
	_checa("partido: esquerda cor 1, direita cor 2", _igual(partido.get_pixel(8, 12), azul) and _igual(partido.get_pixel(32, 12), ouro))
	var esq := GeradorBrasao.imagem({"divisao": "esquartelado", "simbolo": "nenhum", "cor1": "azul_real", "cor2": "ouro_velho"}, tam)
	_checa("esquartelado alterna", _igual(esq.get_pixel(8, 8), azul) and _igual(esq.get_pixel(32, 8), ouro) and _igual(esq.get_pixel(32, 32), azul))
	var cruz := GeradorBrasao.imagem({"divisao": "liso", "simbolo": "cruz", "posicao": "centro", "cor1": "azul_real", "cor_simbolo": "ouro_velho"}, tam)
	_checa("simbolo no centro", _igual(cruz.get_pixel(20, 21), ouro))
	var lua := GeradorBrasao.imagem({"divisao": "liso", "simbolo": "lua", "posicao": "centro", "cor1": "azul_real", "cor_simbolo": "ouro_velho"}, tam)
	var furo := lua.get_pixel(23, 20)
	_checa("furo recorta o simbolo (crescente)", _igual(furo, azul) and _igual(lua.get_pixel(12, 22), ouro))
	var redondo := GeradorBrasao.imagem({"forma": "redondo", "simbolo": "nenhum"}, tam)
	_checa("forma muda o recorte", redondo.get_pixel(1, 1).a == 0.0 and liso.get_pixel(2, 2).a > 0.0)
	var a := GeradorBrasao.imagem({"simbolo": "torre", "divisao": "bandado"}, tam)
	var b := GeradorBrasao.imagem({"simbolo": "torre", "divisao": "bandado"}, tam)
	_checa("mesma entrada, mesma imagem", a.get_data() == b.get_data())
	_checa("textura em cache", GeradorBrasao.textura({"simbolo": "torre"}, tam) == GeradorBrasao.textura({"simbolo": "torre"}, tam))

	# Editor
	await process_frame  # o _ready do autoload Jogador roda antes de mexermos nele
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_brasao/")
	jog.caminho_save = "user://teste_brasao/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000  # fora do primeiro dia
	var ed: EditorBrasao = load("res://game/scenes/ui/editor_brasao.tscn").instantiate()
	root.add_child(ed)
	await process_frame
	_checa("editor comeca com as cores da casa", ed.brasao["cor1"] == jog.casa()["cores"]["principal"])
	var antes := ed._grande.texture
	ed._seletores["simbolo"].escolher("coroa")
	_checa("mudar o simbolo atualiza a previa", ed._grande.texture != antes and ed.brasao["simbolo"] == "coroa")
	_checa("opcao traduzida", ed._seletores["divisao"]._rotulo.text == "Liso")
	ed.sortear()
	_checa("sortear usa cores diferentes", ed.brasao["cor1"] != ed.brasao["cor2"] and ed.brasao["cor2"] != ed.brasao["cor_simbolo"])
	ed.confirmar()
	_checa("confirmar grava no jogador", jog.casa()["brasao"]["simbolo"] == ed.brasao["simbolo"])
	_checa("brasao no escudo, sobreveste e caparacao", ed._cavaleiro.get_node("Visual/Cavaleiro/Escudo/Brasao/Imagem").texture != null
		and ed._cavaleiro.get_node("Visual/Cavaleiro/Peito/BrasaoPeito/Imagem").texture != null
		and ed._cavaleiro.get_node("Visual/Cavalo/Manta/BrasaoManta/Imagem").texture != null)

	# Rival espelhado
	var rival: Cavaleiro = load("res://game/scenes/arena/cavaleiro.tscn").instantiate()
	rival.direcao = -1
	root.add_child(rival)
	await process_frame
	var nenhum_espelhado := true
	for caminho: String in Cavaleiro.LUGARES_BRASAO:
		if (rival.get_node(caminho) as Node2D).global_transform.determinant() <= 0.0:
			nenhum_espelhado = false
	_checa("brasoes do rival sem espelho nos tres lugares", nenhum_espelhado)

	for f in ["jogador.json", "jogador.json.bak"]:
		DirAccess.remove_absolute("user://teste_brasao/" + f)
	# Regra das tinturas nos sorteios: nunca metal com metal nem cor com cor.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var todas: Array = GeradorBrasao.opcoes()["cores"]
	var quebrou := 0
	var campos := {}
	for k in 200:
		var c := GeradorBrasao.sortear_cores(rng, todas, 3)
		campos[c[0]] = true
		var t := c.map(func(x): return GeradorBrasao.tintura(x))
		if t[0] == t[1] or t[2] == t[0] or c[2] == c[1] or "" in t:
			quebrou += 1
	_checa("sorteio respeita a regra das tinturas (%d quebras)" % quebrou, quebrou == 0)
	_checa("sorteio varia o campo (%d cores)" % campos.size(), campos.size() >= 6)
	var cores_casa: Array = Balanceamento.ler_json(GeradorBrasao.PALETAS)["cores_casa"].keys()
	_checa("toda cor da casa tem tintura", cores_casa.all(func(x): return GeradorBrasao.tintura(x) != ""))
	print("BRASAO %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _igual(a: Color, b: Color) -> bool:
	return a.is_equal_approx(b) or (absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01 and a.a > 0.99)

func _checa(nome: String, ok: bool) -> void:
	print("BRASAO %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
