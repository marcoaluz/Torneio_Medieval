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
	_checa("10 camadas na justa", c._camadas.size() == 10)
	_checa("peitoral no encaixe do peito", c.camada("peitoral").get_parent() == cav.get_node("Visual/Cavaleiro/Peito"))
	_checa("origem do quadro na origem do cavaleiro",
		c.camada("peitoral").get_global_transform() * c.camada("peitoral").offset == cav.get_node("Visual").global_transform * Vector2(-80, -160))
	_checa("escudo usa mascara", c.camada("escudo").material.get_shader_parameter("usa_mascara") == true)
	_checa("peitoral sem mascara e material metal (3)",
		c.camada("peitoral").material.get_shader_parameter("usa_mascara") == false
		and c.camada("peitoral").material.get_shader_parameter("material_padrao") == 3)
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
			if s.frame != c.quadro:
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
		_checa("%s monta %d camadas visiveis" % [t, visiveis], visiveis == p._camadas.size() and visiveis >= 6)
		var anim := "andar" if t == "vila" else "respirar"
		p.tocar(anim)
		_checa("%s anima (%s, %d quadros)" % [t, anim, p.camada("corpo").hframes], p.camada("corpo").hframes > 1)

	print("CAMADAS %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("CAMADAS %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
