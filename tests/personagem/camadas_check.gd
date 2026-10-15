extends SceneTree
## Personagem em camadas (headless): monta as camadas nos encaixes, todas no
## mesmo quadro, máscara e material certos, cores da casa no shader, brasão
## seguindo os pontos por quadro (e sem espelho no rival), troca de peça e
## peça inexistente escondida, e os três tamanhos.

var _falhas := 0

func _initialize() -> void:
	await process_frame
	var _jog_teste: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_arena/")
	_jog_teste.caminho_save = "user://teste_arena/jogador.json"
	_jog_teste.estado = _jog_teste.novo_estado()
	var cav: Cavaleiro = load("res://game/scenes/arena/cavaleiro.tscn").instantiate()
	cav.casa_principal = "vermelho_sangue"
	root.add_child(cav)
	await process_frame
	var c := cav.camadas()
	_checa("12 camadas na justa (com pele e cabelo)", c._camadas.size() == 12)
	_checa("peitoral no encaixe do peito", c.camada("peitoral").get_parent() == cav.get_node("Visual/Cavaleiro/Peito"))
	_checa("origem do quadro na origem do cavaleiro",
		c.camada("peitoral").get_global_transform() * c.camada("peitoral").offset == cav.get_node("Visual").global_transform * Vector2(-80, -160))
	_checa("escudo usa mascara", c.camada("escudo").material.get_shader_parameter("usa_mascara") == true)
	_checa("peitoral em cor original com mascara da casa",
		c.camada("peitoral").material.get_shader_parameter("usa_mascara") == true
		and c.camada("peitoral").material.get_shader_parameter("material_padrao") == 0)
	_checa("rosto pintado com a pele (5) e cabelo com a cor do cabelo (6)",
		c.camada("rosto").material.get_shader_parameter("material_padrao") == 5
		and c.camada("cabelo").material.get_shader_parameter("material_padrao") == 6)
	_checa("cavalo em material original (0)", c.camada("cavalo").material.get_shader_parameter("material_padrao") == 0)
	var cores: PackedColorArray = c.camada("escudo").material.get_shader_parameter("cores")
	_checa("cor principal da casa no shader", cores[1].is_equal_approx(Color("7a2326")))
	_checa("cor_casa para a interface", cav.cor_casa.is_equal_approx(Color("7a2326")))

	cav.animar("galope")
	var frames_iguais := true
	var brasao_segue := true
	var pts: Array = c._pontos["justa"]["galope"]["brasao"]
	for i in 8:
		c._process(0.1)
		for s in c._camadas:
			if s.visible and s.frame != c.quadro:
				frames_iguais = false
		var esperado: Vector2 = (cav.get_node("Visual") as Node2D).to_global(Vector2(pts[c.quadro][0], pts[c.quadro][1]))
		if not cav.brasao().global_position.is_equal_approx(esperado):
			brasao_segue = false
	_checa("todas as camadas no mesmo quadro", frames_iguais)
	_checa("brasao segue o ponto de encaixe a cada quadro", brasao_segue)

	c.vestir({"pelagem": "preto"})
	_checa("trocar pelagem troca a textura do cavalo", c.camada("cavalo").texture.resource_path.ends_with("cavalo_preto_galope.png"))
	c.vestir({"elmo": "inexistente"})
	_checa("peca sem arte fica escondida", not c.camada("elmo").visible)
	c.vestir({"elmo": "provisorio"})
	_checa("e volta quando existe", c.camada("elmo").visible)

	var rival: Cavaleiro = load("res://game/scenes/arena/cavaleiro.tscn").instantiate()
	rival.direcao = -1
	rival.escala = 0.85
	root.add_child(rival)
	await process_frame
	rival.animar("galope")
	rival.camadas()._process(0.25)
	_checa("brasao do rival continua sem espelho", rival.brasao().global_transform.determinant() > 0.0)

	for t: String in ["vila", "equipamentos"]:
		var p := CamadasPersonagem.new()
		p.tamanho = t
		root.add_child(p)
		await process_frame
		var visiveis := p._camadas.filter(func(s): return s.visible).size()
		_checa("%s monta %d camadas visiveis" % [t, visiveis], visiveis >= 6)
		var anim := "andar" if t == "vila" else "respirar"
		p.tocar(anim)
		_checa("%s anima (%s, %d quadros)" % [t, anim, p.camada("corpo").hframes], p.camada("corpo").hframes > 1)

	# Toda peça do catálogo tem arte no espaço dela, nos tamanhos que a usam
	# (elmo, peitoral e escudo nos três; lança e caparação só na justa), em todas
	# as animações. Peça ainda sem arte própria vale pela arte provisória.
	var dados: Dictionary = Balanceamento.ler_json("res://game/data/personagem/camadas.json")
	var faltando: Array[String] = []
	var pendentes := {}
	for m: Dictionary in Balanceamento.ler("itens")["modelos"].values():
		var esp: String = m["espaco"]
		var visual: String = m["visual"]
		if m.has("visual_provisorio") and not ResourceLoader.exists("res://game/art/sprites/personagem/justa/%s_%s_parado.png" % [esp, visual]):
			pendentes[visual] = true
			visual = m["visual_provisorio"]
		for t: String in (["justa", "vila", "equipamentos"] if esp in ["elmo", "peitoral", "escudo"] else ["justa"]):
			for anim: String in dados["tamanhos"][t]["animacoes"]:
				var arq := "res://game/art/sprites/personagem/%s/%s_%s_%s.png" % [t, esp, visual, anim]
				if not ResourceLoader.exists(arq):
					faltando.append(arq.get_file())
	_checa("arte de todas as pecas (%d faltando: %s)" % [faltando.size(), ", ".join(faltando.slice(0, 4))], faltando.is_empty())
	print("CAMADAS visuais ainda na arte provisoria: %d" % pendentes.size())
	# A arte provisória aparece de fato na camada (um visual fictício sem arte).
	CamadasPersonagem.visual_provisorio("")  # carrega o mapa
	CamadasPersonagem._provisorios["visual_de_teste"] = "escudeiro"
	var prov := CamadasPersonagem.new()
	prov.tamanho = "justa"
	root.add_child(prov)
	await process_frame
	prov.vestir({"elmo": "visual_de_teste", "escudo": "visual_de_teste_d2"})
	_checa("visual sem arte usa a provisoria (e o estagio de dano)", prov.camada("elmo").visible \
		and prov.camada("elmo").texture.resource_path.contains("elmo_escudeiro") \
		and prov.camada("escudo").texture.resource_path.contains("escudo_escudeiro_d2"))
	CamadasPersonagem._provisorios.erase("visual_de_teste")
	_checa("icone de toda peca nova existe (propio ou provisorio)", Balanceamento.ler("itens")["modelos"].keys().all(func(k): return ArteUi.icone_item(k) != null))

	print("CAMADAS %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("CAMADAS %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
