extends SceneTree
## Vila viva (headless, save em user://teste_vila_viva/): cor por hora,
## tochas à noite, clima do dia (mesmo dia = mesmo clima; todos aparecem),
## treino só com o campo ocupado, estábulo (escovado/comendo/deitado),
## bandeira com o brasão e faíscas no armeiro ocupado.

var _falhas := 0

func _initialize() -> void:
	await process_frame
	var jog: ServicoJogador = root.get_node("Jogador")
	DirAccess.make_dir_recursive_absolute("user://teste_vila_viva/")
	jog.caminho_save = "user://teste_vila_viva/jogador.json"
	jog.estado = jog.novo_estado()
	jog.estado["criado_em"] = int(jog.estado["criado_em"]) - 200000  # fora do primeiro dia
	var vila: Vila = load("res://game/scenes/village/vila.tscn").instantiate()
	var amb: AmbienteVila = vila.get_node("Ambiente")
	amb.hora_forcada = 13.0
	amb.clima_forcado = "limpo"
	root.add_child(vila)
	await process_frame
	var vida: VidaVila = vila.vida

	_checa("meio-dia e claro", amb.cor_da_hora(13.0).is_equal_approx(Color("ffffff")) or amb.cor_da_hora(13.0).r > 0.95)
	_checa("meia-noite e escura e azulada", amb.cor_da_hora(0.0).r < 0.3 and amb.cor_da_hora(0.0).b > amb.cor_da_hora(0.0).r)
	_checa("entardecer puxa para o laranja", amb.cor_da_hora(19.0).r > amb.cor_da_hora(19.0).b)
	_checa("tochas apagadas de dia", not amb.tochas_acesas())
	amb.hora_forcada = 22.0
	amb._aplicar()
	var tochas := get_nodes_in_group("tocha")
	_checa("tochas acesas a noite (%d)" % tochas.size(), amb.tochas_acesas() and tochas.size() == (Balanceamento.ler("vila")["ordem"] as Array).size() and tochas.all(func(t): return t.acesa))

	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AmbienteVila.DADOS))
	_checa("mesmo dia, mesmo clima", AmbienteVila.sortear_clima(cfg, 20000) == AmbienteVila.sortear_clima(cfg, 20000))
	var vistos := {}
	for d in 200:
		vistos[AmbienteVila.sortear_clima(cfg, 20000 + d)] = true
	_checa("os quatro climas aparecem em 200 dias", vistos.size() == 4)

	_checa("campo ocioso: cavaleiro a pe e mestre de armas", not vida.cavaleiro_treino.visible and vida.cavaleiro_a_pe.visible and vida.mestre_armas.visible)
	var agora := ServicoTempo.agora()
	jog.estado["timers"].append({"id": "t_treino", "tipo": "teste", "alvo": "campo_treino", "inicio_em": agora, "termina_em": agora + 300})
	jog.estado["timers"].append({"id": "t_arm", "tipo": "teste", "alvo": "armeiro", "inicio_em": agora, "termina_em": agora + 300})
	vida.atualizar()
	_checa("campo ocupado: cavaleiro galopando", vida.cavaleiro_treino.visible and not vida.cavaleiro_a_pe.visible
		and vida.cavaleiro_treino.camadas().animacao == "galope")
	var x0 := vida.cavaleiro_treino.position.x
	vida._process(0.5)
	_checa("o cavaleiro se move no treino", vida.cavaleiro_treino.position.x != x0)
	var faiscas_antes := vida.get_children().filter(func(n): return n is CPUParticles2D).size()
	vida._proxima_martelada = 0.0
	vida._martelar(0.1)
	var faiscas := vida.get_children().filter(func(n): return n is CPUParticles2D).size()
	_checa("armeiro ocupado martela com faiscas", faiscas > faiscas_antes and vida.armeiro.animacao == "andar")
	_checa("ferreira ociosa parada", vida.ferreira.animacao == "parado")

	_checa("estabulo: escovado ou comendo", vida.estado_estabulo in ["escovado", "comendo"])
	vida._t = float(cfg["vida"]["estabulo_troca_s"]) + 0.1
	vida.atualizar()
	_checa("estabulo alterna para comendo (feno)", vida.estado_estabulo == "comendo" and vida.feno.visible and not vida.cavalarico.visible)
	jog.estado["cavalos"][0]["folego"] = 0
	jog.estado["cavalos"][0]["folego_em"] = ServicoTempo.agora()
	vida.atualizar()
	_checa("cavalo cansado deitado", vida.estado_estabulo == "deitado" and vida.cavalo.scale.y < vida.cavalo.scale.x)
	_checa("cavalo na pelagem do jogador", vida.cavalo.camada("cavalo").texture.resource_path.contains("cavalo_alazao"))
	_checa("bandeira com o brasao", vida.bandeira.texture != null)

	print("VILA_VIVA %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _checa(nome: String, ok: bool) -> void:
	print("VILA_VIVA %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
