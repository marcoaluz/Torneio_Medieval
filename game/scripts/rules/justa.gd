class_name Justa
extends RefCounted
## A justa inteira como regra pura: junta as fases (JustaFases), a largada e
## o galope dos dois lados (Galope), a mira (Mira), o impacto (Impacto) e os
## sorteios (Aleatorio: bandeira e impacto, nessa ordem de uso). O jogador só manda entradas no instante atual: tocar(),
## mirar(ponto) e soltar(). O servidor refaz a justa com a mesma semente e
## as mesmas entradas nos mesmos instantes.
##
## Entradas por fase:
##   Apresentação: tocar() pula
##   Largada: tocar() larga (só o primeiro toque conta)
##   Corrida: tocar() galopa; ativar_habilidade() liga a habilidade ativa
##            (Investida, Golpe Pesado) nesta passada, uma vez por justa,
##            depois de `impacto.habilidade_carga_ms` de Corrida (carrega)
##   Mira: mirar(ponto) segura e move a ponta da lança; soltar() trava o golpe.
##         Se ainda estiver segurando quando a Mira acaba, o golpe sai onde a
##         ponta estiver (automatico); se nunca segurou, o golpe é "erro".
## A Corrida termina quando a soma das distâncias chega ao ponto da Mira
## (pista.distancia_total - pista.distancia_mira) ou no teto fases_ms.corrida.
## O golpe é avaliado no choque (fim da Mira), não no instante em que solta.
## No choque, a regra do impacto resolve os dois golpes; falta conta para a
## desclassificação (impacto.falta.faltas_para_desclassificar) e o dano gasta
## a durabilidade das peças, que vale para as passadas seguintes.
## Rival: com `perfil_ia` (ia_rival.json), a IA (IaRival, semente derivada)
## larga, galopa, mira e aciona a habilidade sozinha, nos instantes que ela
## planeja. Sem perfil, o rival corre na velocidade nominal e só golpeia se
## alguém chamar rival_mirar().
## Modo automático (PvE, 2.10): com `perfil_ia_jogador`, outra IA (semente
## própria) faz as entradas do jogador pelos mesmos caminhos (tocar, mirar,
## soltar, ativar_habilidade). Ordem num mesmo ms: bandeira, rival, jogador.
##
## Configuração: {justa, galope, mira, impacto} (os JSON de game/data/balance/).
## Cada lado: {cavaleiro: {forca, precisao, equilibrio}, cavalo: {velocidade,
## folego, temperamento}, equipamento?: {peca: {...}}, habilidades?: [nome]
## (no máximo uma ativa e uma passiva; habilidade?: nome também vale)}.
## Habilidade passiva (Bloqueio) vale em todas as passadas; ativa só quando
## acionada.
##
## Eventos (além dos de JustaFases), todos com "t":
##   {tipo:"bandeira", passada}
##   {tipo:"largada", passada, qualidade, tocou, reacao_ms, queimada}
##   {tipo:"toque", passada, resultado, batida, desvio_ms, velocidade, folego}
##   {tipo:"corrida_fim", passada, velocidade_jogador, velocidade_rival,
##        ritmo_jogador_milesimos, distancia_jogador_mil, distancia_rival_mil}
##   {tipo:"soltou", passada, x, y, t_mira_ms}
##   {tipo:"golpe", passada, zona, x, y, t_mira_ms, automatico, sem_golpe}
##        (x, y em décimos de px do quadro do rival; vem logo antes da fase Impacto)
##   {tipo:"habilidade", passada, lado, nome}  (ativa acionada)
##   {tipo:"largada_rival", passada, qualidade, reacao_ms}
##   {tipo:"toque_rival", passada, resultado, batida, desvio_ms, velocidade, folego}
##   {tipo:"impacto", passada, jogador, rival, faltas_jogador, faltas_rival,
##        derrubado, desclassificado}  (jogador/rival = resultado de Impacto.resolver)

var fases: JustaFases
var jogador: Galope
var rival: Galope
var bandeira_ms := 0  ## instante da bandeira dentro da Largada desta passada
var bandeira_baixou := false
var qualidade_largada := ""
var tocou_largada := false
var reacao_largada_ms := 0  ## negativo = tocou antes da bandeira (queimada)
## Mira da passada atual (décimos de px do quadro do rival).
var ponta := Vector2i.ZERO
var segurando := false
var solto := false
var t_soltou_ms := 0
var precisao_jogador := 0
var precisao_rival := 0
## Golpe do rival nesta passada (da IA): ponto no quadro do jogador.
var ponta_rival := Vector2i.ZERO
var rival_mirou := false
## Lados com o equipamento sendo gasto ao longo da justa (cópias).
var lado_jogador: Dictionary
var lado_rival: Dictionary
var faltas_jogador := 0
var faltas_rival := 0
var habilidade_usada_jogador := false
var habilidade_usada_rival := false
var habilidade_na_passada_jogador := false
var habilidade_na_passada_rival := false
## Último resultado do impacto (para a apresentação).
var ultimo_impacto: Dictionary
## Largada do rival nesta passada.
var qualidade_largada_rival := ""
var ia: IaRival
var ia_jogador: IaRival

var _rival_largada_ms := -1  ## instante (na Largada) do toque do rival; -1 = não toca
var _rival_largou := false
var _plano_rival: Array[int] = []
var _plano_ix := 0
var _jog_largada_ms := -1
var _plano_jogador: Array[int] = []
var _plano_jog_ix := 0

var _cfg: Dictionary
var _rng: Aleatorio

static func validar(cfg: Dictionary) -> String:
	for nome in ["justa", "galope", "mira", "impacto"]:
		if not cfg.get(nome) is Dictionary:
			return "falta a configuração \"%s\"" % nome
	var erro := JustaFases.validar(cfg["justa"])
	if erro != "":
		return "justa.json: " + erro
	erro = Galope.validar(cfg["galope"])
	if erro != "":
		return "galope.json: " + erro
	erro = Mira.validar(cfg["mira"])
	if erro != "":
		return "mira.json: " + erro
	erro = Impacto.validar(cfg["impacto"])
	if erro != "":
		return "impacto.json: " + erro
	var l: Dictionary = cfg["galope"]["largada"]
	if int(l["bandeira_ms"]) + int(l["bandeira_variacao_ms"]) >= int(cfg["justa"]["fases_ms"]["largada"]):
		return "a bandeira precisa baixar antes do fim da Largada"
	return ""

## Lado a partir de padrao.json: {cavaleiro, cavalo, equipamento, habilidade}.
static func lado_padrao(padrao: Dictionary) -> Dictionary:
	var lado := {"cavaleiro": padrao["cavaleiro"], "cavalo": padrao["cavalo"]}
	if padrao.has("equipamento"):
		lado["equipamento"] = padrao["equipamento"]
	if padrao.has("habilidade"):
		lado["habilidade"] = padrao["habilidade"]
	return lado.duplicate(true)

## Lê as configurações de game/data/balance/ (para o jogo; os testes montam
## a sua). Devolve {} e avisa se faltar arquivo.
static func carregar_configuracao() -> Dictionary:
	var cfg := {}
	for nome in ["justa", "galope", "mira", "impacto"]:
		cfg[nome] = Balanceamento.carregar(nome)
	return cfg

func _init(cfg: Dictionary, lado_j: Dictionary, lado_r: Dictionary, semente: int, perfil_ia := {}, perfil_ia_jogador := {}) -> void:
	_cfg = cfg
	lado_jogador = lado_j.duplicate(true)
	lado_rival = lado_r.duplicate(true)
	fases = JustaFases.new(cfg["justa"])
	jogador = Galope.new(cfg["galope"], lado_jogador["cavalo"])
	rival = Galope.new(cfg["galope"], lado_rival["cavalo"])
	rival.automatico = perfil_ia.is_empty()
	if not perfil_ia.is_empty():
		ia = IaRival.new(perfil_ia, IaRival.semente_da_justa(semente))
	if not perfil_ia_jogador.is_empty():
		ia_jogador = IaRival.new(perfil_ia_jogador, IaRival.semente_da_justa(semente ^ 0x2545F491))
	_rng = Aleatorio.new(semente)
	precisao_jogador = Impacto.precisao_efetiva(lado_jogador)
	precisao_rival = Impacto.precisao_efetiva(lado_rival)

func iniciar() -> Array[Dictionary]:
	return _observar(fases.iniciar())

func terminou() -> bool:
	return fases.terminou()

## Distância (milésimos) em que a Corrida acaba.
func distancia_corrida_mil() -> int:
	var p: Dictionary = _cfg["galope"]["pista"]
	return (int(p["distancia_total"]) - int(p["distancia_mira"])) * 1000

func distancia_total_mil() -> int:
	return int(_cfg["galope"]["pista"]["distancia_total"]) * 1000

## Bônus de precisão (%) desta passada, pela largada.
func bonus_precisao_pct() -> int:
	if qualidade_largada == "":
		return 0
	return int(_cfg["galope"]["largada"]["bonus_precisao_pct"][qualidade_largada])

## Zonas efetivas do rival para o jogador nesta passada (para o realce na tela).
func zonas_efetivas() -> Array[Dictionary]:
	return Mira.zonas_efetivas(_cfg["mira"], precisao_jogador, bonus_precisao_pct())

## Liga a habilidade ativa do jogador nesta passada (só na Corrida, uma vez
## por justa, e só se a habilidade equipada for do tipo "ativa").
func ativar_habilidade() -> Array[Dictionary]:
	if fases.fase != JustaFases.Fase.CORRIDA or habilidade_usada_jogador or not habilidade_carregada(true):
		return []
	var nome := _ativa_de(lado_jogador)
	if nome == "":
		return []
	habilidade_usada_jogador = true
	habilidade_na_passada_jogador = true
	return [{"tipo": "habilidade", "passada": fases.passada, "lado": "jogador", "nome": nome, "t": fases.tempo_total_ms}]

## Fração da carga da habilidade nesta Corrida (0 a 1; 0 fora da Corrida).
func carga_habilidade(do_jogador: bool) -> float:
	if fases.fase != JustaFases.Fase.CORRIDA:
		return 0.0
	var carga := int(_cfg["impacto"]["habilidade_carga_ms"])
	var t := (jogador if do_jogador else rival).t_ms
	return 1.0 if carga <= 0 else minf(float(t) / carga, 1.0)

func habilidade_carregada(do_jogador: bool) -> bool:
	return (jogador if do_jogador else rival).t_ms >= int(_cfg["impacto"]["habilidade_carga_ms"])

## Habilidade ativa equipada por um lado ("" se não tem ou é passiva).
func habilidade_ativa_de(do_jogador: bool) -> String:
	var nome := _ativa_de(lado_jogador if do_jogador else lado_rival)
	if nome == "":
		return ""
	return nome

## O mesmo para o rival (chamado pela IA).
func rival_ativar_habilidade() -> Array[Dictionary]:
	if fases.fase != JustaFases.Fase.CORRIDA or habilidade_usada_rival or not habilidade_carregada(false):
		return []
	var nome := _ativa_de(lado_rival)
	if nome == "":
		return []
	habilidade_usada_rival = true
	habilidade_na_passada_rival = true
	return [{"tipo": "habilidade", "passada": fases.passada, "lado": "rival", "nome": nome, "t": fases.tempo_total_ms}]

## Golpe do rival (IA): ponto no quadro do jogador, em décimos de px. Só na
## Mira; o último antes do choque vale.
func rival_mirar(ponto: Vector2i) -> void:
	if fases.fase != JustaFases.Fase.MIRA:
		return
	ponta_rival = Mira.limitar(_cfg["mira"], ponto)
	rival_mirou = true

## Equipamento de um lado depois do desgaste desta justa (para salvar, 2.9).
func equipamento_final(do_jogador: bool) -> Dictionary:
	return (lado_jogador if do_jogador else lado_rival).get("equipamento", {}).duplicate(true)

## Habilidades do lado (lista "habilidades", ou a antiga "habilidade").
static func _habilidades_de(lado: Dictionary) -> Array[String]:
	var res: Array[String] = []
	if lado.get("habilidades") is Array:
		for h: Variant in lado["habilidades"]:
			if h is String and h != "":
				res.append(h)
	elif lado.get("habilidade", "") is String and lado.get("habilidade", "") != "":
		res.append(lado["habilidade"])
	return res

## A habilidade ativa (botão) do lado; "" se não tem.
func _ativa_de(lado: Dictionary) -> String:
	for h in _habilidades_de(lado):
		if _cfg["impacto"]["habilidades"].has(h) and _cfg["impacto"]["habilidades"][h]["tipo"] == "ativa":
			return h
	return ""

func avancar(ms: int) -> Array[Dictionary]:
	var eventos: Array[Dictionary] = []
	while ms > 0 and not fases.terminou():
		match fases.fase:
			JustaFases.Fase.CORRIDA:
				ms -= 1
				eventos.append_array(_corrida_1ms())
			JustaFases.Fase.LARGADA:
				var ate_fase := fases.duracao_ms(fases.fase) - fases.tempo_na_fase_ms
				var passo := mini(ms, ate_fase)
				if not bandeira_baixou:
					passo = mini(passo, bandeira_ms - fases.tempo_na_fase_ms)
				if not _rival_largou and _rival_largada_ms >= 0:
					passo = mini(passo, _rival_largada_ms - fases.tempo_na_fase_ms)
				if ia_jogador and not tocou_largada and _jog_largada_ms >= 0:
					passo = mini(passo, _jog_largada_ms - fases.tempo_na_fase_ms)
				if passo > 0:
					ms -= passo
					eventos.append_array(_observar(fases.avancar(passo)))
				if fases.fase == JustaFases.Fase.LARGADA:
					if not bandeira_baixou and fases.tempo_na_fase_ms >= bandeira_ms:
						bandeira_baixou = true
						eventos.append({"tipo": "bandeira", "passada": fases.passada, "t": fases.tempo_total_ms})
					if not _rival_largou and _rival_largada_ms >= 0 and fases.tempo_na_fase_ms >= _rival_largada_ms:
						eventos.append(_rival_larga())
					if ia_jogador and not tocou_largada and _jog_largada_ms >= 0 and fases.tempo_na_fase_ms >= _jog_largada_ms:
						eventos.append_array(tocar())
			_:
				var ate_fase := fases.duracao_ms(fases.fase) - fases.tempo_na_fase_ms
				var passo := mini(ms, ate_fase)
				ms -= passo
				eventos.append_array(_observar(fases.avancar(passo)))
	return eventos

## Toque do jogador no instante atual.
func tocar() -> Array[Dictionary]:
	var eventos: Array[Dictionary] = []
	match fases.fase:
		JustaFases.Fase.APRESENTACAO:
			eventos.append_array(_observar(fases.pular()))
		JustaFases.Fase.LARGADA:
			if not tocou_largada:
				tocou_largada = true
				reacao_largada_ms = fases.tempo_na_fase_ms - bandeira_ms
				qualidade_largada = Galope.avaliar_largada(_cfg["galope"], true, reacao_largada_ms)
				eventos.append(_evento_largada())
		JustaFases.Fase.CORRIDA:
			var r := jogador.tocar()
			eventos.append(_evento_toque(r, jogador))
	return eventos

## Segura e move a ponta da lança (décimos de px do quadro do rival). Só na
## Mira e antes de soltar; o ponto é preso aos limites da mira.
func mirar(ponto: Vector2i) -> void:
	if fases.fase != JustaFases.Fase.MIRA or solto:
		return
	ponta = Mira.limitar(_cfg["mira"], ponto)
	segurando = true

## Solta o dedo: trava o golpe no ponto atual. Só na Mira, segurando.
func soltar() -> Array[Dictionary]:
	if fases.fase != JustaFases.Fase.MIRA or solto or not segurando:
		return []
	solto = true
	segurando = false
	t_soltou_ms = fases.tempo_na_fase_ms
	return [{"tipo": "soltou", "passada": fases.passada, "x": ponta.x, "y": ponta.y,
		"t_mira_ms": t_soltou_ms, "t": fases.tempo_total_ms}]

func _corrida_1ms() -> Array[Dictionary]:
	var eventos: Array[Dictionary] = []
	if ia:
		# Toques da IA no instante planejado (mesma regra do toque do jogador).
		while _plano_ix < _plano_rival.size() and _plano_rival[_plano_ix] <= rival.t_ms:
			if _plano_rival[_plano_ix] == rival.t_ms:
				var r := rival.tocar()
				var ev := _evento_toque(r, rival)
				ev["tipo"] = "toque_rival"
				eventos.append(ev)
			_plano_ix += 1
		var hb := ia.batida_habilidade()
		if hb > 0 and rival.t_ms == hb * rival.compasso_ms():
			eventos.append_array(rival_ativar_habilidade())
	if ia_jogador:
		while _plano_jog_ix < _plano_jogador.size() and _plano_jogador[_plano_jog_ix] <= jogador.t_ms:
			if _plano_jogador[_plano_jog_ix] == jogador.t_ms:
				eventos.append_array(tocar())
			_plano_jog_ix += 1
		var hbj := ia_jogador.batida_habilidade()
		if hbj > 0 and jogador.t_ms == hbj * jogador.compasso_ms():
			eventos.append_array(ativar_habilidade())
	var perdido := jogador.avancar_1ms()
	var perdido_rival := rival.avancar_1ms()
	if not perdido.is_empty():
		eventos.append(_evento_toque(perdido, jogador))
	if not perdido_rival.is_empty():
		var ev := _evento_toque(perdido_rival, rival)
		ev["tipo"] = "toque_rival"
		eventos.append(ev)
	# Primeiro o relógio (pode bater o teto); depois a chegada.
	eventos.append_array(_observar(fases.avancar(1)))
	if fases.fase == JustaFases.Fase.CORRIDA and jogador.distancia_mil + rival.distancia_mil >= distancia_corrida_mil():
		eventos.append_array(_observar(fases.encerrar_corrida()))
	return eventos

## Reage às trocas de fase da regra: prepara a Largada (sorteia a bandeira),
## fecha a largada e começa o galope, anota o fim da Corrida, prepara a Mira
## e avalia o golpe no choque.
func _observar(eventos: Array[Dictionary]) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for e in eventos:
		if e["tipo"] == "fase" and e["anterior"] == JustaFases.Fase.CORRIDA:
			saida.append({"tipo": "corrida_fim", "passada": fases.passada,
				"velocidade_jogador": jogador.velocidade, "velocidade_rival": rival.velocidade,
				"ritmo_jogador_milesimos": jogador.ritmo_milesimos(),
				"distancia_jogador_mil": jogador.distancia_mil, "distancia_rival_mil": rival.distancia_mil,
				"t": e["t"]})
		if e["tipo"] == "fase" and e["anterior"] == JustaFases.Fase.MIRA:
			var golpe := _avaliar_golpe(e["t"])
			saida.append(golpe)
			saida.append(_resolver_impacto(golpe, e["t"]))
		saida.append(e)
		if e["tipo"] != "fase":
			continue
		match e["fase"]:
			JustaFases.Fase.APRESENTACAO:
				habilidade_na_passada_jogador = false
				habilidade_na_passada_rival = false
			JustaFases.Fase.LARGADA:
				var l: Dictionary = _cfg["galope"]["largada"]
				bandeira_ms = int(l["bandeira_ms"]) + _rng.inteiro(0, int(l["bandeira_variacao_ms"]))
				bandeira_baixou = false
				tocou_largada = false
				qualidade_largada = ""
				reacao_largada_ms = 0
				_rival_largou = false
				qualidade_largada_rival = ""
				_rival_largada_ms = -1
				if ia:
					# Reação antes da bandeira = toque antes dela (queimada); nunca antes do 0.
					var tr := maxi(bandeira_ms + ia.reacao_largada_ms(), 0)
					if tr < fases.duracao_ms(JustaFases.Fase.LARGADA):
						_rival_largada_ms = tr
				_jog_largada_ms = -1
				if ia_jogador:
					var tj := maxi(bandeira_ms + ia_jogador.reacao_largada_ms(), 0)
					if tj < fases.duracao_ms(JustaFases.Fase.LARGADA):
						_jog_largada_ms = tj
			JustaFases.Fase.CORRIDA:
				if not tocou_largada:
					qualidade_largada = Galope.avaliar_largada(_cfg["galope"], false, 0)
					saida.append(_evento_largada())
				jogador.nova_passada(qualidade_largada)
				if ia:
					if not _rival_largou:
						qualidade_largada_rival = Galope.avaliar_largada(_cfg["galope"], false, 0)
						saida.append({"tipo": "largada_rival", "passada": fases.passada,
							"qualidade": qualidade_largada_rival, "reacao_ms": 0, "t": fases.tempo_total_ms})
						_rival_largou = true
					rival.nova_passada(qualidade_largada_rival)
					_plano_rival = ia.plano_galope(rival.compasso_ms(), fases.duracao_ms(JustaFases.Fase.CORRIDA))
					_plano_ix = 0
				else:
					rival.nova_passada("boa")
				if ia_jogador:
					_plano_jogador = ia_jogador.plano_galope(jogador.compasso_ms(), fases.duracao_ms(JustaFases.Fase.CORRIDA))
					_plano_jog_ix = 0
			JustaFases.Fase.MIRA:
				ponta = Mira.ponta_inicial(_cfg["mira"])
				segurando = false
				solto = false
				t_soltou_ms = 0
				rival_mirou = false
				precisao_jogador = Impacto.precisao_efetiva(lado_jogador)
				precisao_rival = Impacto.precisao_efetiva(lado_rival)
				if ia:
					rival_mirar(ia.ponto_mira(_cfg["mira"]))
				if ia_jogador:
					mirar(ia_jogador.ponto_mira(_cfg["mira"]))
					saida.append_array(soltar())
	return saida

func _avaliar_golpe(t: int) -> Dictionary:
	var sem_golpe := not solto and not segurando
	var automatico := not solto and segurando
	var zona := Mira.ERRO if sem_golpe else Mira.zona_no_ponto(_cfg["mira"], ponta, precisao_jogador, bonus_precisao_pct())
	var t_mira := t_soltou_ms if solto else fases.duracao_ms(JustaFases.Fase.MIRA)
	solto = true
	segurando = false
	return {"tipo": "golpe", "passada": fases.passada, "zona": zona, "x": ponta.x, "y": ponta.y,
		"t_mira_ms": t_mira, "automatico": automatico, "sem_golpe": sem_golpe, "t": t}

## Resolve o choque com a regra do impacto, conta faltas, gasta o
## equipamento e registra o resultado da passada.
func _resolver_impacto(golpe: Dictionary, t: int) -> Dictionary:
	var zona_rival := Mira.ERRO
	if rival_mirou:
		var bonus_rival := 0
		if qualidade_largada_rival != "":
			bonus_rival = int(_cfg["galope"]["largada"]["bonus_precisao_pct"][qualidade_largada_rival])
		zona_rival = Mira.zona_no_ponto(_cfg["mira"], ponta_rival, precisao_rival, bonus_rival)
	var entrada := {
		"jogador": _golpeador(lado_jogador, golpe["zona"], jogador, habilidade_na_passada_jogador),
		"rival": _golpeador(lado_rival, zona_rival, rival, habilidade_na_passada_rival),
	}
	var res := Impacto.resolver(_cfg["impacto"], entrada, _rng)
	ultimo_impacto = res
	var rj: Dictionary = res["jogador"]
	var rr: Dictionary = res["rival"]
	if rj["falta"]:
		faltas_jogador += 1
	if rr["falta"]:
		faltas_rival += 1
	# O golpe do jogador gasta as peças do rival, e vice-versa; cada lança gasta no contato.
	_gastar(lado_rival, rj["dano"])
	_gastar(lado_jogador, rr["dano"])
	_gastar(lado_jogador, {"lanca": rj["dano_lanca"]})
	_gastar(lado_rival, {"lanca": rr["dano_lanca"]})
	var limite := int(_cfg["impacto"]["falta"]["faltas_para_desclassificar"])
	var dq := _lado_de(faltas_jogador >= limite, faltas_rival >= limite)
	var derrubado := _lado_de(rr["derrubou"], rj["derrubou"])
	fases.registrar_resultado(int(rj["pontos"]), int(rr["pontos"]), derrubado, dq)
	return {"tipo": "impacto", "passada": fases.passada, "jogador": rj, "rival": rr,
		"faltas_jogador": faltas_jogador, "faltas_rival": faltas_rival,
		"derrubado": derrubado, "desclassificado": dq, "t": t}

## Lado afetado: o jogador, o rival, os dois ou nenhum.
static func _lado_de(jogador_afetado: bool, rival_afetado: bool) -> JustaFases.Lado:
	if jogador_afetado and rival_afetado:
		return JustaFases.Lado.AMBOS
	if jogador_afetado:
		return JustaFases.Lado.JOGADOR
	if rival_afetado:
		return JustaFases.Lado.RIVAL
	return JustaFases.Lado.NENHUM

## Passivas valem em toda passada; a ativa, só na passada em que foi acionada.
func _golpeador(lado: Dictionary, zona: String, g: Galope, ativa_na_passada: bool) -> Dictionary:
	var habs: Array = []
	for nome in _habilidades_de(lado):
		var em_efeito := false
		if _cfg["impacto"]["habilidades"].has(nome):
			em_efeito = _cfg["impacto"]["habilidades"][nome]["tipo"] == "passiva" or ativa_na_passada
		habs.append({"nome": nome, "ativa": em_efeito})
	return {"cavaleiro": lado["cavaleiro"], "equipamento": lado.get("equipamento", {}),
		"habilidades": habs, "zona": zona,
		"velocidade": g.velocidade, "velocidade_nominal": g.velocidade_nominal,
		"ritmo_milesimos": g.ritmo_milesimos()}

## Tira o dano da durabilidade das peças (nunca abaixo de 0).
static func _gastar(lado: Dictionary, dano: Dictionary) -> void:
	var equip: Variant = lado.get("equipamento")
	if not equip is Dictionary:
		return
	var nomes: Array = dano.keys()
	nomes.sort()
	for peca: String in nomes:
		if equip.has(peca):
			var p: Dictionary = equip[peca]
			p["durabilidade"] = maxi(int(p.get("durabilidade", 0)) - int(dano[peca]), 0)

func _rival_larga() -> Dictionary:
	_rival_largou = true
	var reacao := _rival_largada_ms - bandeira_ms
	qualidade_largada_rival = Galope.avaliar_largada(_cfg["galope"], true, reacao)
	return {"tipo": "largada_rival", "passada": fases.passada, "qualidade": qualidade_largada_rival,
		"reacao_ms": reacao, "t": fases.tempo_total_ms}

func _evento_largada() -> Dictionary:
	return {"tipo": "largada", "passada": fases.passada, "qualidade": qualidade_largada,
		"tocou": tocou_largada, "reacao_ms": reacao_largada_ms,
		"queimada": tocou_largada and reacao_largada_ms < 0, "t": fases.tempo_total_ms}

func _evento_toque(r: Dictionary, g: Galope) -> Dictionary:
	return {"tipo": "toque", "passada": fases.passada, "resultado": r["resultado"], "batida": r["batida"],
		"desvio_ms": r["desvio_ms"], "velocidade": g.velocidade, "folego": g.folego, "t": fases.tempo_total_ms}
