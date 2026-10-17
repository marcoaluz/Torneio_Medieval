class_name ControladorJusta
extends Node
## Liga a regra da justa (Justa, pura) à cena da arena: passa o tempo, manda
## os toques, emite os sinais, troca o plano da câmera, move os cavaleiros,
## a bandeira do arauto e a barra de distância.
## Som, efeitos e interface só escutam os sinais; nada aqui decide resultado.
##
## Câmera por fase (GDD, tabela de fases). Câmera próxima em tudo: cavaleiro e
## cavalo grandes. Os dois só cabem juntos perto do encontro (largam a 780 px
## um do outro), então antes disso a câmera fica em um deles:
##   Apresentação: corta no rival e desliza até o jogador
##   Largada: no jogador, com o arauto e a bandeira à vista (o toque depende dela)
##   Corrida: segue o jogador (a velocidade vem do galope)
##   Mira: zoom no peito do rival, que fecha devagar ao longo da fase, com a
##     mira visível (MiraVisual) sobre a zona; cavaleiros em câmera lenta
##   Impacto: corte seco para um close inclinado com os dois cavaleiros
##     grandes e a cerca entre eles (do elmo do rival ao pé do jogador; é o
##     quadro que o hit-stop congela), abrindo um pouco depois.
## Como na referência de arte, o encontro é a uma lança de distância: as pistas
## são encurtadas só no desenho (`vao_encontro`), para os dois se verem inteiros
## no choque, e cada lança aponta para o adversário ao se aproximarem (a do
## jogador segue a mira). A barra de distância e a regra não mudam.
## Na Mira o jogador (pista da frente) fica translúcido se chegar a cobrir as
## zonas do rival.
## Gesto do golpe (Cavaleiro.preparar_golpe/golpear): o jogador recolhe ao
## soltar o dedo e o rival um pouco antes do choque; os dois estocam um
## instante antes do contato, para o congelamento do impacto pegar o golpe
## esticado. Tudo pelo relógio das fases da regra; nada disso muda resultado.
## Toque na tela inteira, com uma mão: pula a Apresentação, larga na
## Largada, galopa na Corrida. Na Corrida o dedo que tocou no compasso pode
## ficar na tela e arrastar para cima ou para baixo: sobe ou baixa a lança.
## O arrasto nunca vira toque (só encostar o dedo galopa), então não atrapalha
## o compasso. Na Mira: segura, arrasta a ponta da lança sobre o rival
## (arrasto relativo, o dedo não cobre o alvo) e solta para golpear; a Mira
## começa da altura escolhida na Corrida, e o dedo que já estava arrastando a
## lança quando a Mira chega passa a segurar sem precisar tocar de novo.
## A ponta segue o dedo com uma inércia leve (mola), na Corrida e na Mira.
## A zona sob a ponta brilha de leve no próprio rival. A altura da lança antes
## da Mira não muda o resultado: o golpe sai do ponto que a Mira manda à regra.

## Qualquer troca de fase. `anterior` é JustaFases.Fase.FIM no começo.
signal fase_mudou(fase: JustaFases.Fase, anterior: JustaFases.Fase, passada: int)
## Atalhos por fase, para quem só quer uma delas (som da trombeta, etc.).
signal apresentacao_comecou(passada: int)
signal largada_comecou(passada: int)
signal corrida_comecou(passada: int)
signal mira_comecou(passada: int)
signal impacto_comecou(passada: int)
signal bandeira_baixou(passada: int)
## qualidade: "perfeita", "boa" ou "ruim"; queimada = tocou antes da bandeira.
signal largada_avaliada(passada: int, qualidade: String, reacao_ms: int, queimada: bool)
## resultado: "no_tempo", "fora_do_tempo", "rapido_demais" ou "perdido".
signal toque_galope(resultado: String, desvio_ms: int, velocidade: int, folego: int)
signal corrida_terminou(passada: int, velocidade_jogador: int, ritmo_milesimos: int)
## O jogador soltou o dedo na Mira (o golpe sai no choque).
signal golpe_solto(passada: int)
## Golpe avaliado no choque: zona "capacete", "peito", "escudo", "cavalo" ou "erro".
signal golpe_avaliado(passada: int, zona: String, automatico: bool, sem_golpe: bool)
## Choque resolvido pela regra do impacto. `jogador`/`rival` = resultado do
## golpe daquele lado (ver Impacto): zona_final, pontos, falta, bloqueado,
## derrubou, dano... `derrubado`/`desclassificado` são JustaFases.Lado.
signal impacto_resolvido(passada: int, jogador: Dictionary, rival: Dictionary, derrubado: JustaFases.Lado, desclassificado: JustaFases.Lado)
## Habilidade ativa acionada ("jogador" ou "rival").
signal habilidade_ativada(passada: int, lado: String, nome: String)
signal passada_terminou(passada: int, pontos_jogador: int, pontos_rival: int, derrubado: JustaFases.Lado)
signal justa_terminou(vencedor: JustaFases.Lado, motivo: String, placar_jogador: int, placar_rival: int)

@export var arena: Arena
@export var barra: BarraDistancia
## Interface (para não tratar como jogo o toque que cai no botão).
@export var interface: InterfaceJusta
## Painel de ajuste (só em desenvolvimento; some no release).
@export var painel: PainelAjuste
## Segundos depois do fim até um toque começar outra justa.
@export var espera_para_recomecar := 1.0
@export var iniciar_sozinho := true
## Perfil da IA do rival (game/data/balance/ia_rival.json); vazio = rival sem IA.
@export var perfil_rival := "equilibrado"
## Velocidade dos cavaleiros depois do choque, em relação à Corrida (câmera
## lenta do Impacto; na exibição, também na Mira). Ajuste visual.
@export_range(0.05, 1.0, 0.05) var camera_lenta := 0.3
## Pista desenhada (só apresentação; a regra mede em milésimos e os tempos não
## mudam): px por unidade de pista na Corrida. 1,7 dá uns 160 px/s de galope,
## uma passada do desenho (~110 px) por ciclo da animação (8 quadros a 12 fps).
## Antes era 0,59 (75 px/s): as pernas corriam e o cavalo quase não saía do lugar.
@export var px_por_unidade_corrida := 1.7
## Na Mira o galope continua, só um pouco mais devagar que na Corrida (a regra
## cobre os últimos 150 de pista em 2 s): a câmera lenta fica para o acerto.
@export_range(0.2, 1.0, 0.05) var fator_mira := 0.55
## A exibição (vista da arquibancada, arena inteira) usa a pista curta, que cabe na tela.
@export var pista_exibicao_px := 780.0
## Close do Impacto: o quadro vai do elmo do rival (pista de trás) ao pé do
## jogador (pista da frente), com folga; zoom entre estes limites e inclinação.
@export var zoom_impacto := 1.7
@export var zoom_impacto_max := 2.5
@export var inclinacao_impacto := -5.0
## Vão (px) entre os dois no instante do choque (alcance da lança, em diagonal).
@export var vao_encontro := 190.0
## A partir de quantos px além do vão as lanças começam a apontar.
@export var apontar_desde_px := 320.0
## Na Mira, transparência do jogador quando chega ao rival (1 = opaco).
@export_range(0.2, 1.0, 0.05) var jogador_alfa_mira := 0.5
@export var folga_impacto := 1.12
@export var folga_topo_impacto := 0.12
## A barra de distância cobre o pé da tela: folga embaixo, em fração da altura.
@export var folga_baixo_impacto := 0.12
## Plano aberto (Apresentação, Largada, Fim): quanto o centro fica à frente de
## quem está sendo mostrado e acima do pé dele. Na exibição, a arena inteira.
@export var aberto_a_frente := 120.0
@export var aberto_acima := 70.0  ## centro acima do pé de quem é mostrado
@export var zoom_exibicao := 1.0
## Fração da Apresentação em que a câmera sai do rival para o jogador.
@export_range(0.0, 1.0, 0.05) var apresentacao_troca := 0.45
## Antecedência do gesto em relação ao choque (ms do relógio da regra).
@export var preparar_antes_ms := 420
@export var golpear_antes_ms := 110
## Quanto a ponta anda por px de arrasto aparente na tela (1 = acompanha o dedo).
@export var sensibilidade_mira := 1.0
## Na Corrida (rival longe, câmera aberta) o arrasto sobe ou baixa a lança:
## px da ponta (no quadro do rival) por px de arrasto na tela.
@export var sensibilidade_lanca_corrida := 0.6
## Inércia da ponta (mola): rigidez e amortecimento. Amortecimento perto de
## 2·√rigidez não passa do ponto; um pouco abaixo dá a sobra leve da mão.
@export var rigidez_lanca := 140.0
@export var amortecimento_lanca := 17.0
## Na Corrida, inclinação da lança (graus) por px de altura escolhida, até o
## rival chegar perto (aí ela aponta para o ponto de verdade).
@export var lanca_corrida_graus_por_px := 0.22

var justa: Justa
## Atributos de cada lado: {cavaleiro, cavalo, equipamento, habilidade}.
## O jogador vem dos dados do jogador (autoload Jogador); o rival, por enquanto,
## de game/data/balance/padrao.json (perfis de rival da região: 2.10).
var lado_jogador: Dictionary
var lado_rival: Dictionary
## Semente da justa (no servidor, Parte 3, quem sorteia é ele).
var semente := 0

## Todos os eventos da justa atual (estrelas do PvE, envio ao servidor).
var eventos_justa: Array[Dictionary] = []
## Entradas do jogador [t_ms, acao, x, y] (o que o servidor refaz para conferir
## a justa: disputa_conferida.ts). A mira entra no máximo a cada
## servidor.json > cliente > registro_mira_ms e sempre o último ponto antes de
## soltar ou do choque (só ele muda o golpe).
var entradas: Array = []
## Chave de tradução do nome do rival e do jogador (vazio = "Você").
var nome_rival := ""
var nome_jogador := ""
## "livre", "disputa" (PvE), "exibicao" (início do jogo: dois veteranos da IA,
## câmera da arquibancada, arauto explicando) ou "tutorial" (primeira justa,
## rival fraco, dicas por fase). Vem do Fluxo.
var modo := "livre"
## Disputa do PvE desta justa ({} = livre) e o resultado dela no Jogador.
var disputa := {}
var resultado_disputa := {}
## Disputa do PvE: provocação do campeão (chave de texto), desafios do
## torneio e se o cavalo do jogador cansa (cavalo emprestado não).
var provocacao := ""
var desafios: Array = []
## Anúncio do arauto com o título do jogador ("" sem título; 3.21).
var anuncio_titulo := ""
var _gasta_folego := true

var _resto_ms := 0.0
var _desistencia_registrada := false
var _mira_pendente: Array = []
var _t_ultima_mira := -100000
var _t_ultimo_toque := -100000
var _px_por_mil := 0.0  ## px desenhados por milésimo na Corrida
var _mira_px := 0.0  ## px que cada um desenha na Mira (o resto até o encontro)
var _total_desenho := 0.0  ## soma do que os dois desenham até o encontro
var _fim_corrida_j := 0.0  ## distâncias em px no fim da Corrida (para a Mira)
var _fim_corrida_r := 0.0
var _encontro_j := 0.0
var _encontro_r := 0.0
var _cfg: Dictionary
var _base_mira := Vector2.ZERO  ## ponta sem a oscilação, décimos de px do quadro do rival
var _alvo_mira := Vector2.ZERO  ## para onde o dedo levou a ponta (a ponta segue com inércia)
var _vel_mira := Vector2.ZERO
var _dedo_na_tela := false
var _arrastou_lanca := false  ## o dedo atual arrastou a lança na Corrida
var _tempo_mira := 0.0
var _tempo_desde_fim := 0.0
var _preparou := false  ## gesto do rival já recolhido nesta Mira
var _golpeou := false   ## estocada dos dois já disparada nesta Mira
var _apresentou := false  ## a Apresentação já passou do rival para o jogador

func _ready() -> void:
	if iniciar_sozinho:
		iniciar.call_deferred()

## Começa uma justa nova com os dados de game/data/balance/.
## `semente_fixa` < 0 sorteia uma.
func iniciar(semente_fixa := -1) -> void:
	_cfg = Justa.carregar_configuracao()
	var erro := Justa.validar(_cfg)
	var padrao := Balanceamento.carregar("padrao")
	if erro == "" and not (padrao.has("cavaleiro") and padrao.has("cavalo")):
		erro = "padrao.json sem cavaleiro/cavalo"
	if erro != "":
		push_error("ControladorJusta: " + erro)
		set_process(false)
		return
	if lado_jogador.is_empty():
		var jog := get_node_or_null("/root/Jogador") as ServicoJogador
		lado_jogador = jog.lado_para_justa() if jog else Justa.lado_padrao(padrao)
	if lado_rival.is_empty():
		lado_rival = Justa.lado_padrao(padrao)
	var perfil := {}
	var perfil_jogador := {}
	var fluxo := get_node_or_null("/root/Fluxo") as FluxoTelas
	var jog_d := get_node_or_null("/root/Jogador") as ServicoJogador
	modo = fluxo.modo_justa if fluxo else "livre"
	disputa = fluxo.disputa.duplicate() if fluxo and fluxo.em_disputa() else {}
	resultado_disputa = {}
	nome_rival = "RIVAL_" + perfil_rival.to_upper() if perfil_rival != "" else ""
	nome_jogador = ""
	var rv := {}
	anuncio_titulo = ""
	if jog_d and jog_d.titulo() != "" and modo in ["disputa", "livre", "pvp"]:
		anuncio_titulo = tr("ARAUTO_TITULO").format({"nome": jog_d.cavaleiro().get("nome", ""),
			"titulo": tr("TITULO_" + jog_d.titulo().to_upper())})
	# Frase do arauto comprada na loja (cosmético, 3.18).
	if jog_d and str(jog_d.estado.get("loja", {}).get("frase", "")) != "" and modo in ["disputa", "livre", "pvp"]:
		var frase := tr("ARAUTO_FRASE_" + str(jog_d.estado["loja"]["frase"]).to_upper()).format({"nome": jog_d.cavaleiro().get("nome", "")})
		anuncio_titulo = (anuncio_titulo + "  " if anuncio_titulo != "" else "") + frase
	provocacao = ""
	desafios = []
	_gasta_folego = true
	match modo:
		"disputa":
			if not disputa.is_empty() and jog_d:
				# Com o servidor: exatamente a configuração, os lados e a semente dele.
				var prep: Dictionary = disputa["servidor"] if disputa.has("servidor") \
					else jog_d.preparar_disputa(disputa["torneio"], int(disputa["indice"]))
				if disputa.has("servidor"):
					semente_fixa = int(prep["semente"])
				_cfg = prep["cfg"]
				lado_jogador = prep["lado_jogador"]
				rv = prep["rival"]
				provocacao = rv.get("provocacao", "")
				desafios = prep["desafios"]
				_gasta_folego = prep["gasta_folego"]
				arena.aplicar_ambiente(prep["visuais"])
		"pvp":
			if jog_d:
				var prep_p := jog_d.preparar_pvp()
				if not prep_p.is_empty():
					_cfg = prep_p["cfg"]
					lado_jogador = prep_p["lado_jogador"]
					rv = prep_p["rival"]
		"tutorial":
			if jog_d:
				rv = jog_d.rival_tutorial()
				rv["nome_chave"] = "RIVAL_TUTORIAL"
			# Primeira justa com semente fixa: a mesma experiência para todos.
			semente_fixa = int(Balanceamento.carregar("inicio")["tutorial"].get("semente_primeira_justa", semente_fixa))
		"exibicao":
			# Dois veteranos da IA; o jogador assiste da arquibancada.
			var ex: Dictionary = Balanceamento.carregar("inicio")["tutorial"]["exibicao"]
			var perfis_ex: Dictionary = Balanceamento.carregar("ia_rival")["perfis"]
			lado_jogador = Justa.lado_padrao(padrao)
			lado_rival = Justa.lado_padrao(padrao)
			perfil_rival = ex["perfil_vermelho"]
			perfil_jogador = perfis_ex[ex["perfil_azul"]]
			semente_fixa = int(ex["semente"])
			nome_jogador = "EXIBICAO_AZUL"
			nome_rival = "EXIBICAO_VERMELHO"
			arena.jogador.definir_casa({"principal": "azul_real", "secundaria": "prata"})
			arena.jogador.camadas().vestir({"pelagem": "branco", "corpo": "masculino", "elmo": "vigia", "peitoral": "vigia", "escudo": "vigia", "lanca": "vigia"})
			arena.jogador.definir_brasao({"cor1": "azul_real", "cor2": "prata", "simbolo": "cruz", "cor_simbolo": "prata"})
	if not rv.is_empty():
		lado_rival = rv["lado"]
		perfil_rival = rv["perfil_nome"]
		nome_rival = rv["nome_chave"]
		arena.rival.definir_casa(rv["casa"])
	if perfil_rival != "":
		var ia_cfg := Balanceamento.carregar("ia_rival")
		var e_ia := IaRival.validar(ia_cfg)
		if e_ia != "" or not ia_cfg["perfis"].has(perfil_rival):
			push_error("ControladorJusta: perfil de IA \"%s\" inválido: %s" % [perfil_rival, e_ia])
			set_process(false)
			return
		perfil = rv["perfil"] if rv.has("perfil") else ia_cfg["perfis"][perfil_rival]
	if rv.is_empty():
		arena.vestir_rival(perfil_rival)
	else:
		arena.rival.definir_brasao(rv["brasao"])
	eventos_justa.clear()
	entradas.clear()
	_mira_pendente = []
	_t_ultima_mira = -100000
	_t_ultimo_toque = -100000
	semente = semente_fixa if semente_fixa >= 0 else randi()
	justa = Justa.new(_cfg, lado_jogador, lado_rival, semente, perfil, perfil_jogador)
	_preparar_pista()
	_resto_ms = 0.0
	_tempo_desde_fim = 0.0
	set_process(true)
	_metrica("justa_iniciada", {"modo": modo, "rival": nome_rival, "disputa": disputa})
	_despachar(justa.iniciar())

## Move a ponta e guarda a entrada (no máximo uma a cada registro_mira_ms;
## a última fica pendente até soltar, outra entrada ou o fim da Mira).
func _mirar(ponto: Vector2i) -> void:
	if fase() != JustaFases.Fase.MIRA or justa.solto:
		return
	justa.mirar(ponto)
	var t := justa.fases.tempo_total_ms
	var p := justa.ponta
	if not _mira_pendente.is_empty() and int(_mira_pendente[2]) == p.x and int(_mira_pendente[3]) == p.y:
		return
	if not entradas.is_empty() and _mira_pendente.is_empty() and entradas[-1][1] == "mirar" \
			and int(entradas[-1][2]) == p.x and int(entradas[-1][3]) == p.y:
		return
	_mira_pendente = [t, "mirar", p.x, p.y]
	if t - _t_ultima_mira >= int(Balanceamento.ler("servidor")["cliente"]["registro_mira_ms"]):
		_gravar_mira_pendente()

func _gravar_mira_pendente() -> void:
	if _mira_pendente.is_empty():
		return
	entradas.append(_mira_pendente)
	_t_ultima_mira = int(_mira_pendente[0])
	_mira_pendente = []

func _entrada(acao: String) -> void:
	_gravar_mira_pendente()
	entradas.append([justa.fases.tempo_total_ms, acao, 0, 0])

## Toque do jogador (qualquer ponto da tela).
func tocar() -> void:
	if justa and not justa.terminou():
		# Dois toques mais próximos que isso não são de um dedo (o servidor recusa).
		var t := justa.fases.tempo_total_ms
		if t - _t_ultimo_toque < int(Balanceamento.ler("servidor")["anticheat"]["toque_min_intervalo_ms"]):
			return
		_t_ultimo_toque = t
		_entrada("tocar")
		_despachar(justa.tocar())

## Mira: começa a segurar (toque na tela).
func segurar_mira() -> void:
	if fase() == JustaFases.Fase.MIRA and not justa.solto:
		_mirar(_ponto_mira())

## Mira: arrasto do dedo, em px da tela. Converte para o quadro do rival
## (desfaz zoom, escala e espelho) e move o alvo da ponta (a ponta segue).
func arrastar_mira(delta_tela: Vector2) -> void:
	if fase() != JustaFases.Fase.MIRA or justa.solto or not justa.segurando:
		return
	var mundo := delta_tela / arena.camera.zoom * sensibilidade_mira
	# affine_inverse: basis_xform_inv só serve para base sem escala (usa a transposta).
	var quadro := arena.rival.visual().global_transform.affine_inverse().basis_xform(mundo)
	_alvo_mira = Vector2(Mira.limitar(_cfg["mira"], Vector2i((_alvo_mira + quadro * 10.0).round())))

## Corrida: arrasto vertical do dedo sobe ou baixa a lança (a Mira começa
## dali). Não é toque: o galope só conta o encostar do dedo.
func arrastar_lanca(delta_tela: Vector2) -> void:
	if fase() != JustaFases.Fase.CORRIDA or is_zero_approx(delta_tela.y):
		return
	_arrastou_lanca = true
	var dy := delta_tela.y * sensibilidade_lanca_corrida / arena.rival.escala
	_alvo_mira = Vector2(Mira.limitar(_cfg["mira"], Vector2i((_alvo_mira + Vector2(0.0, dy * 10.0)).round())))

## Ponta segue o alvo com uma mola (inércia leve), presa aos limites da mira.
func _seguir_alvo(delta: float) -> void:
	var f := fase()
	if not f in [JustaFases.Fase.CORRIDA, JustaFases.Fase.MIRA] or justa.solto:
		_vel_mira = Vector2.ZERO
		return
	# Passos curtos: a mola fica estável mesmo num quadro longo.
	var resta := minf(delta, 0.1)
	while resta > 0.0:
		var h := minf(resta, 1.0 / 120.0)
		resta -= h
		_vel_mira += ((_alvo_mira - _base_mira) * rigidez_lanca - _vel_mira * amortecimento_lanca) * h
		_base_mira += _vel_mira * h
	var limitada := Vector2(Mira.limitar(_cfg["mira"], Vector2i(_base_mira.round())))
	if not limitada.is_equal_approx(_base_mira.round()):
		_vel_mira = Vector2.ZERO
		_base_mira = limitada

## Mira: solta o dedo (golpeia).
func soltar_mira() -> void:
	if fase() == JustaFases.Fase.MIRA and justa.segurando and not justa.solto:
		_entrada("soltar")
		_despachar(justa.soltar())
		arena.jogador.preparar_golpe()

## Ponta da lança em coordenadas do mundo (para desenhar).
func ponta_no_mundo() -> Vector2:
	return arena.rival.visual().to_global(Vector2(justa.ponta) / 10.0)

## Ponta escolhida pelo dedo (com a inércia, sem a oscilação), no mundo.
func lanca_no_mundo() -> Vector2:
	return arena.rival.visual().to_global(_base_mira / 10.0)

## 0 com os dois longe, 1 no vão do encontro (as lanças apontam a partir dele).
func _peso_aproximacao() -> float:
	var dx := absf(arena.rival.global_position.x - arena.jogador.global_position.x)
	var peso := clampf(1.0 - (dx - vao_encontro) / apontar_desde_px, 0.0, 1.0)
	return peso * peso * (3.0 - 2.0 * peso)  # suave

## Painel de ajuste: troca o conteúdo da configuração `arquivo` no lugar, para
## a justa em andamento já ler os números novos (o que é calculado no começo
## da justa, como durações das fases, vale ao recomeçar).
func aplicar_ajuste(arquivo: String, dados: Dictionary) -> void:
	if not _cfg.has(arquivo):
		return
	var alvo: Dictionary = _cfg[arquivo]
	alvo.clear()
	alvo.merge(dados.duplicate(true))

## Botão de habilidade (Corrida): liga a habilidade ativa nesta passada.
func ativar_habilidade() -> void:
	if justa and not justa.terminou():
		var ev := justa.ativar_habilidade()
		if not ev.is_empty():
			_entrada("habilidade")
		_despachar(ev)

func fase() -> JustaFases.Fase:
	return justa.fases.fase if justa else JustaFases.Fase.FIM

## Desistência: sair da cena ou fechar o jogo com a justa em andamento.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_EXIT_TREE, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED]:
		if justa != null and not justa.terminou() and modo != "exibicao" and not _desistencia_registrada:
			_desistencia_registrada = true
			# Saiu no meio da disputa do servidor: avisa (conta como derrota na sequência).
			if disputa.has("servidor") and what != NOTIFICATION_APPLICATION_PAUSED:
				var nuvem := get_node_or_null("/root/Nuvem") as ServicoNuvem
				if nuvem:
					nuvem.enfileirar("abandonar_disputa", [])
			_metrica("desistencia", {"modo": modo, "fase": JustaFases.NOMES_FASE[justa.fases.fase],
				"passada": justa.fases.passada, "rival": nome_rival})

func _metrica(evento: String, dados := {}) -> void:
	var m := get_node_or_null("/root/Metricas") as ServicoMetricas
	if m:
		m.registrar(evento, dados)

func _process(delta: float) -> void:
	if justa == null:
		return
	if justa.terminou():
		_tempo_desde_fim += delta
		return
	_resto_ms += delta * 1000.0
	var ms := int(_resto_ms)
	_resto_ms -= ms
	_seguir_alvo(delta)
	if fase() == JustaFases.Fase.MIRA:
		_tempo_mira += delta
		if justa.segurando:
			_mirar(_ponto_mira())
	_despachar(justa.avancar(ms))
	if fase() != JustaFases.Fase.MIRA:
		_gravar_mira_pendente()  # o choque usou o último ponto: ele entra com o instante dele
	_atualizar_visual()

func _unhandled_input(event: InputEvent) -> void:
	if justa == null:
		return
	if event is InputEventScreenTouch and interface and interface.contem_ponto(event.position):
		return
	if event is InputEventScreenTouch and is_instance_valid(painel) and painel.contem_ponto(event.position):
		return
	if justa.terminou():
		if event is InputEventScreenTouch and event.pressed and _tempo_desde_fim >= espera_para_recomecar:
			get_viewport().set_input_as_handled()
			var fluxo := get_node_or_null("/root/Fluxo") as FluxoTelas
			match modo:
				"disputa", "pvp":
					if fluxo:
						fluxo.ir_para_vila()
				"exibicao":
					if fluxo:
						fluxo.concluiu("exibicao")
				"tutorial":
					if fluxo:
						fluxo.concluiu("primeira_justa")
				_:
					iniciar()
		return
	if modo == "exibicao":
		return  # na exibição o jogador só assiste
	if event is InputEventScreenTouch:
		_dedo_na_tela = event.pressed
		if event.pressed:
			_arrastou_lanca = false
	if fase() == JustaFases.Fase.MIRA:
		if event is InputEventScreenTouch:
			if event.pressed:
				segurar_mira()
			else:
				soltar_mira()
			get_viewport().set_input_as_handled()
		elif event is InputEventScreenDrag:
			arrastar_mira(event.relative)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		tocar()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and fase() == JustaFases.Fase.CORRIDA:
		arrastar_lanca(event.relative)
		get_viewport().set_input_as_handled()

## Ponta com a oscilação da mão (dados: mira.oscilacao), em décimos de px.
func _ponto_mira() -> Vector2i:
	var o: Dictionary = _cfg["mira"]["oscilacao"]
	var a := float(o["amplitude_px"]) * 10.0
	var fx := float(o["frequencia_x_milesimos"]) / 1000.0
	var fy := float(o["frequencia_y_milesimos"]) / 1000.0
	var osc := Vector2(sin(_tempo_mira * TAU * fx), sin(_tempo_mira * TAU * fy + 1.3)) * a
	return Mira.limitar(_cfg["mira"], Vector2i((_base_mira + osc).round()))

func _despachar(eventos: Array[Dictionary]) -> void:
	eventos_justa.append_array(eventos)
	for e in eventos:
		var p: int = e.get("passada", 0)
		match e["tipo"]:
			"fase":
				_ao_entrar_na_fase(e["fase"])
				fase_mudou.emit(e["fase"], e["anterior"], p)
				match e["fase"]:
					JustaFases.Fase.APRESENTACAO: apresentacao_comecou.emit(p)
					JustaFases.Fase.LARGADA: largada_comecou.emit(p)
					JustaFases.Fase.CORRIDA: corrida_comecou.emit(p)
					JustaFases.Fase.MIRA: mira_comecou.emit(p)
					JustaFases.Fase.IMPACTO: impacto_comecou.emit(p)
			"bandeira":
				arena.arauto.baixar()
				bandeira_baixou.emit(p)
			"largada":
				largada_avaliada.emit(p, e["qualidade"], e["reacao_ms"], e["queimada"])
			"toque":
				if barra:
					barra.lampejar(e["resultado"])
				toque_galope.emit(e["resultado"], e["desvio_ms"], e["velocidade"], e["folego"])
			"corrida_fim":
				_ao_fim_da_corrida(e)
				corrida_terminou.emit(p, e["velocidade_jogador"], e["ritmo_jogador_milesimos"])
			"soltou":
				golpe_solto.emit(p)
			"golpe":
				golpe_avaliado.emit(p, e["zona"], e["automatico"], e["sem_golpe"])
			"impacto":
				impacto_resolvido.emit(p, e["jogador"], e["rival"], e["derrubado"], e["desclassificado"])
			"habilidade":
				habilidade_ativada.emit(p, e["lado"], e["nome"])
			"passada":
				passada_terminou.emit(p, e["pontos_jogador"], e["pontos_rival"], e["derrubado"])
			"fim":
				_metrica("justa_terminada", {"modo": modo, "rival": nome_rival, "vencedor": JustaFases.NOMES_LADO[e["vencedor"]],
					"motivo": e["motivo"], "placar": [e["placar_jogador"], e["placar_rival"]], "passadas": justa.fases.passada,
					"ms": justa.fases.tempo_total_ms, "estrelas": resultado_disputa.get("estrelas", -1)})
				_registrar_no_jogador(e)
				justa_terminou.emit(e["vencedor"], e["motivo"], e["placar_jogador"], e["placar_rival"])

func _ao_entrar_na_fase(nova: JustaFases.Fase) -> void:
	var cam := arena.camera
	_animar_cavaleiros(nova)
	if nova == JustaFases.Fase.MIRA:
		_preparou = false
		_golpeou = false
		_mira_visual().reiniciar()
	if modo == "exibicao":
		# Vista da arquibancada: plano aberto o tempo todo.
		if nova == JustaFases.Fase.APRESENTACAO:
			arena.posicionar_nas_pontas()
			arena.arauto.levantar()
			cam.plano_aberto(true, Vector2.INF, zoom_exibicao)
		elif nova == JustaFases.Fase.LARGADA:
			arena.arauto.levantar()
		_atualizar_visual()
		return
	match nova:
		JustaFases.Fase.APRESENTACAO:
			arena.posicionar_nas_pontas()
			arena.arauto.levantar()
			_apresentou = false
			cam.plano_aberto(true, centro_aberto_em(arena.rival))
		JustaFases.Fase.LARGADA:
			arena.arauto.levantar()
			cam.plano_aberto(false, centro_aberto_em(arena.jogador))
			_base_mira = Vector2(Mira.ponta_inicial(_cfg["mira"]))
			_alvo_mira = _base_mira
			_vel_mira = Vector2.ZERO
		JustaFases.Fase.FIM:
			cam.plano_aberto(false, (arena.jogador.global_position + arena.rival.global_position) * 0.5 - Vector2(0, aberto_acima))
		JustaFases.Fase.CORRIDA:
			# Sem corte até o acerto: segue o jogador e, com o rival chegando,
			# vai enquadrando os dois (a Mira acontece nesse mesmo plano).
			cam.duelo(arena.jogador, arena.rival)
		JustaFases.Fase.MIRA:
			# Começa da altura escolhida na Corrida (a ponta inicial, se não mexeu).
			_tempo_mira = 0.0
			if _dedo_na_tela and _arrastou_lanca:
				segurar_mira()  # o dedo que arrastava a lança já segura
		JustaFases.Fase.IMPACTO:
			if not _golpeou:  # Mira curta demais para a antecedência
				_golpear()
			var q := quadro_do_impacto()
			var z := clampf(arena.get_viewport_rect().size.y / q.size.y, zoom_impacto, zoom_impacto_max)
			cam.impacto(q.get_center(), z, inclinacao_impacto)
			cam.deslizar(q.get_center(), z, 0.0)  # o tranco inclinado volta ao horizonte reto
	_atualizar_visual()

## Fim da justa: avisa o serviço Jogador (fôlego do cavalo; recompensas e
## desgaste nos prompts seguintes). Na Parte 3 vira o envio dos toques ao
## servidor, que recalcula e paga.
func _registrar_no_jogador(e: Dictionary) -> void:
	if modo == "exibicao":
		return  # a exibição não mexe nos dados do jogador
	var jog := get_node_or_null("/root/Jogador") as ServicoJogador
	if jog and modo == "pvp" and not jog.adversario().is_empty():
		resultado_disputa = jog.concluir_pvp(eventos_justa)
		var fluxo_p := get_node_or_null("/root/Fluxo") as FluxoTelas
		if fluxo_p:
			fluxo_p.ultimo_resultado = resultado_disputa
	if jog and not disputa.is_empty():
		resultado_disputa = jog.concluir_disputa(disputa["torneio"], int(disputa["indice"]), eventos_justa)
		# O resultado acima aparece já; o servidor refaz a justa com as entradas e paga
		# (mesma regra e semente: dá o mesmo). O estado dele vence quando a fila esvazia.
		if disputa.has("servidor"):
			_gravar_mira_pendente()
			var nuvem := get_node_or_null("/root/Nuvem") as ServicoNuvem
			if nuvem:
				nuvem.enfileirar("concluir_disputa_conferida", [entradas.duplicate(true)])
		var fluxo := get_node_or_null("/root/Fluxo") as FluxoTelas
		if fluxo:
			fluxo.ultimo_resultado = resultado_disputa
	if jog:
		jog.registrar_justa({"vencedor": JustaFases.NOMES_LADO[e["vencedor"]], "motivo": e["motivo"],
			"placar_jogador": e["placar_jogador"], "placar_rival": e["placar_rival"],
			"equipamento_final": justa.equipamento_final(true), "perfil_rival": perfil_rival, "semente": semente,
			"gasta_folego": _gasta_folego})

## Galope na Corrida (no ritmo da velocidade), um pouco mais lento na Mira
## (câmera lenta na exibição) e em câmera lenta no Impacto; parado nas pontas e no fim.
func _animar_cavaleiros(f: JustaFases.Fase) -> void:
	for lado: Array in [[arena.jogador, justa.jogador], [arena.rival, justa.rival]]:
		var cav: Cavaleiro = lado[0]
		var g: Galope = lado[1]
		var ritmo := float(g.velocidade) / maxf(float(g.velocidade_nominal), 1.0)
		match f:
			JustaFases.Fase.CORRIDA:
				cav.animar("galope", ritmo)
			JustaFases.Fase.MIRA:
				cav.animar("galope", ritmo * (camera_lenta if modo == "exibicao" else fator_mira))
			JustaFases.Fase.IMPACTO:
				cav.animar("galope", ritmo * camera_lenta)
			_:
				cav.animar("parado")

## Pista desenhada desta justa: px por milésimo na Corrida, quanto cada um
## anda na Mira e a distância entre as pontas (a arena estende o cenário).
## Os dois se encontram no meio, a uma lança de distância (vao_encontro).
func _preparar_pista() -> void:
	var total_mil := float(justa.distancia_total_mil())
	var corrida_mil := float(justa.distancia_corrida_mil())
	if modo == "exibicao":
		_px_por_mil = (pista_exibicao_px - vao_encontro) / total_mil
		_mira_px = (total_mil - corrida_mil) * _px_por_mil * 0.5
	else:
		_px_por_mil = px_por_unidade_corrida / 1000.0
		var nominal := (justa.jogador.velocidade_nominal + justa.rival.velocidade_nominal) * 0.5  # unidades/s
		var mira_s := justa.fases.duracao_ms(JustaFases.Fase.MIRA) / 1000.0
		_mira_px = nominal * px_por_unidade_corrida * fator_mira * mira_s
	_total_desenho = corrida_mil * _px_por_mil + 2.0 * _mira_px
	arena.ajustar_pista(_total_desenho + vao_encontro)
	arena.posicionar_nas_pontas()

## No fim da Corrida, divide o que falta até o encontro na proporção das
## velocidades: a Mira leva cada um até o ponto de encontro.
func _ao_fim_da_corrida(e: Dictionary) -> void:
	_fim_corrida_j = e["distancia_jogador_mil"] * _px_por_mil
	_fim_corrida_r = e["distancia_rival_mil"] * _px_por_mil
	var falta := _total_desenho - _fim_corrida_j - _fim_corrida_r
	var vj := float(e["velocidade_jogador"])
	var vr := float(e["velocidade_rival"])
	var parte_j := 0.5 if vj + vr <= 0.0 else vj / (vj + vr)
	_encontro_j = _fim_corrida_j + falta * parte_j
	_encontro_r = _fim_corrida_r + falta * (1.0 - parte_j)

## Distâncias percorridas (px) pelo jogador (x) e pelo rival (y) desde as pontas.
func distancias_px() -> Vector2:
	var f := justa.fases
	match f.fase:
		JustaFases.Fase.CORRIDA:
			return Vector2(justa.jogador.distancia_mil, justa.rival.distancia_mil) * _px_por_mil
		JustaFases.Fase.MIRA:
			var k := float(f.tempo_na_fase_ms) / f.duracao_ms(JustaFases.Fase.MIRA)
			return Vector2(lerpf(_fim_corrida_j, _encontro_j, k), lerpf(_fim_corrida_r, _encontro_r, k))
		JustaFases.Fase.IMPACTO:
			# Seguem devagar depois do choque, na velocidade da câmera lenta
			# (velocidade em milésimos por ms = tempo em ms).
			var t_ms := float(f.tempo_na_fase_ms)
			return Vector2(_encontro_j + justa.jogador.velocidade * _px_por_mil * camera_lenta * t_ms,
				_encontro_r + justa.rival.velocidade * _px_por_mil * camera_lenta * t_ms)
	return Vector2.ZERO

func _atualizar_visual() -> void:
	if justa == null or justa.terminou():
		return  # no fim, os cavaleiros ficam onde pararam
	var f := justa.fases
	if f.fase == JustaFases.Fase.APRESENTACAO and modo != "exibicao" and not _apresentou \
			and f.tempo_na_fase_ms >= f.duracao_ms(JustaFases.Fase.APRESENTACAO) * apresentacao_troca:
		_apresentou = true
		arena.camera.plano_aberto(false, centro_aberto_em(arena.jogador))
	var d := distancias_px()
	# As pontas ficam a _total_desenho + vão: no encontro da regra, sobra o vão entre os dois.
	arena.jogador.global_position = arena.inicio_jogador.global_position + Vector2(d.x, 0)
	arena.rival.global_position = arena.inicio_rival.global_position - Vector2(d.y, 0)
	_apontar_lancas()
	_atualizar_mira()
	if barra == null:
		return
	barra.posicao_jogador = d.x / _total_desenho
	barra.posicao_rival = 1.0 - d.y / _total_desenho
	barra.brilho = _brilho_do_compasso()

## Ponta da lança, mira visível e brilho leve na zona sob ela, só na Mira.
## Na Corrida, a marca aparece fraca quando o rival chega perto, na altura
## escolhida. Também dispara o gesto do golpe antes do choque.
func _atualizar_mira() -> void:
	var na_mira := justa.fases.fase == JustaFases.Fase.MIRA
	var na_corrida := justa.fases.fase == JustaFases.Fase.CORRIDA
	var perto_corrida := na_corrida and _peso_aproximacao() > 0.35 and modo != "exibicao"
	arena.ponta_lanca.visible = na_mira or perto_corrida
	if perto_corrida:
		arena.ponta_lanca.global_position = lanca_no_mundo()
		arena.ponta_lanca.modulate.a = 0.55
		var mc := _mira_visual()
		mc.zona = ""
		mc.segurando = false
		mc.travado = false
	if not na_mira:
		arena.rival.realcar("")
		arena.jogador.modulate.a = 1.0
		return
	arena.ponta_lanca.modulate.a = 1.0
	arena.ponta_lanca.global_position = ponta_no_mundo()
	var zona := Mira.zona_no_ponto(_cfg["mira"], justa.ponta, justa.precisao_jogador, justa.bonus_precisao_pct())
	arena.rival.realcar(zona)
	var m := _mira_visual()
	m.zona = zona
	# O jogador passa na frente do rival: fica translúcido conforme chega perto.
	var perto := clampf(1.0 - absf(arena.jogador.global_position.x - arena.rival.global_position.x) / 160.0, 0.0, 1.0)
	arena.jogador.modulate.a = lerpf(1.0, jogador_alfa_mira, perto)
	m.segurando = justa.segurando and not justa.solto
	m.travado = justa.solto
	var f := justa.fases
	var dur := f.duracao_ms(JustaFases.Fase.MIRA)
	var falta := dur - f.tempo_na_fase_ms
	if not _preparou and falta <= preparar_antes_ms:
		_preparou = true
		arena.rival.preparar_golpe()
		if not justa.solto:
			arena.jogador.preparar_golpe()  # sem soltar, o golpe sai no choque do mesmo jeito
	if not _golpeou and falta <= golpear_antes_ms:
		_golpear()

## Centro do plano aberto num cavaleiro: um pouco à frente dele (para onde vai).
func centro_aberto_em(c: Cavaleiro) -> Vector2:
	return Vector2(c.global_position.x + aberto_a_frente * float(c.direcao), c.global_position.y - aberto_acima)

## Retângulo do mundo que o close do Impacto mostra: do elmo do rival (pista
## de trás) até o pé do jogador (pista da frente), acima da barra de distância.
func quadro_do_impacto() -> Rect2:
	var j := arena.jogador
	var r := arena.rival
	var topo := r.global_position.y - 150.0 * r.escala
	var baixo := j.global_position.y
	var x := (j.global_position.x + r.global_position.x) * 0.5
	var alto := (baixo - topo) * folga_impacto
	# O placar e o letreiro ocupam o alto da tela: a folga extra fica em cima.
	var em_cima := alto * folga_topo_impacto
	var embaixo := alto * folga_baixo_impacto
	var total := alto + em_cima + embaixo
	var largo := total * arena.get_viewport_rect().size.x / arena.get_viewport_rect().size.y
	return Rect2(x - largo * 0.5, (topo + baixo) * 0.5 - alto * 0.5 - em_cima, largo, total)

## Lanças apontam para o adversário conforme se aproximam (a do jogador para a
## mira na Mira; antes, para o peito do rival). Depois do choque, ficam como estão.
func _apontar_lancas() -> void:
	var f := justa.fases.fase
	if not f in [JustaFases.Fase.CORRIDA, JustaFases.Fase.MIRA]:
		return
	var j := arena.jogador
	var r := arena.rival
	var peso := _peso_aproximacao()
	if f == JustaFases.Fase.MIRA:
		j.mira_lanca = j.angulo_para(ponta_no_mundo()) * peso
	else:
		# Corrida: longe, a lança só inclina pela altura escolhida; perto, aponta para ela.
		var dy := (_base_mira.y - float(Mira.ponta_inicial(_cfg["mira"]).y)) / 10.0
		var inclinada := deg_to_rad(dy * lanca_corrida_graus_por_px)
		j.mira_lanca = lerpf(inclinada, j.angulo_para(lanca_no_mundo()), peso)
	r.mira_lanca = r.angulo_para(j.ponto_alvo("Peito")) * peso

func _golpear() -> void:
	_golpeou = true
	arena.jogador.golpear()
	arena.rival.golpear()

func _mira_visual() -> MiraVisual:
	return arena.ponta_lanca.get_node("Mira") as MiraVisual

## 1 dentro da janela da batida mais próxima, caindo até 0 a uma janela
## de distância dela; 0 fora da Corrida. A janela visível já inclui o
## Temperamento do cavalo.
func _brilho_do_compasso() -> float:
	if justa.fases.fase != JustaFases.Fase.CORRIDA:
		return 0.0
	var g := justa.jogador
	var p := g.compasso_ms()
	var k := (g.t_ms + p / 2) / p
	if k < 1:
		return 0.0
	var desvio := absi(g.t_ms - k * p)
	if desvio <= g.janela_ms:
		return 1.0
	return clampf(1.0 - float(desvio - g.janela_ms) / g.janela_ms, 0.0, 1.0)
