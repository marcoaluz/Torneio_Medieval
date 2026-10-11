class_name InterfaceJusta
extends Control
## Interface da justa (Pacote 1.7): plaquinhas no topo (jogador à esquerda,
## rival à direita), placar e "Passada 1/3" no centro, letreiro curto para
## largada/golpe/habilidade, barra de distância embaixo, botão redondo de
## habilidade no canto inferior direito e o resultado no fim.
## Só mostra: lê o estado da Justa e escuta os sinais do ControladorJusta.
## Textos sempre por tr() (game/i18n/textos.csv). Só o botão recebe toque.

@export var controlador: ControladorJusta
## Tempo do letreiro na tela (s).
@export var duracao_letreiro := 1.2

@onready var plaquinha_jogador: Plaquinha = $Topo/PlaquinhaJogador
@onready var plaquinha_rival: Plaquinha = $Topo/PlaquinhaRival
@onready var placar: Label = $Topo/Centro/Placar
@onready var passada: Label = $Topo/Centro/Passada
@onready var letreiro: Label = $Letreiro
@onready var resultado: PanelContainer = $Resultado
@onready var resultado_titulo: Label = $Resultado/Coluna/Titulo
@onready var resultado_motivo: Label = $Resultado/Coluna/Motivo
@onready var resultado_dica: Label = $Resultado/Coluna/Dica
@onready var barra: BarraDistancia = $BarraDistancia
@onready var botao: BotaoHabilidade = $BotaoHabilidade

var _armadura_inicial_jogador := 0
var _armadura_inicial_rival := 0
var _tempo_letreiro := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in find_children("*", "Control", true, false):
		if c != botao:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	letreiro.visible = false
	resultado.visible = false
	botao.visible = false
	botao.pressed.connect(_ao_apertar_botao)
	if controlador:
		controlador.apresentacao_comecou.connect(_ao_comecar_passada)
		controlador.largada_avaliada.connect(_ao_avaliar_largada)
		controlador.habilidade_ativada.connect(_ao_ativar_habilidade)
		controlador.impacto_resolvido.connect(_ao_resolver_impacto)
		controlador.justa_terminou.connect(_ao_terminar)
		controlador.fase_mudou.connect(_ao_mudar_fase)

## A interface ocupa este ponto da tela (para o jogo não tratar o toque)?
func contem_ponto(ponto_tela: Vector2) -> bool:
	return botao.visible and botao.get_global_rect().has_point(ponto_tela)

func _process(delta: float) -> void:
	if _tempo_letreiro > 0.0:
		_tempo_letreiro -= delta
		if _tempo_letreiro <= 0.0:
			letreiro.visible = false
	var j := controlador.justa if controlador else null
	if j == null:
		return
	plaquinha_jogador.atualizar(_fracao_armadura(j.lado_jogador, _armadura_inicial_jogador),
		float(j.jogador.folego) / maxi(j.jogador.folego_max, 1))
	plaquinha_rival.atualizar(_fracao_armadura(j.lado_rival, _armadura_inicial_rival),
		float(j.rival.folego) / maxi(j.rival.folego_max, 1))
	placar.text = "%d  ×  %d" % [j.fases.placar_jogador, j.fases.placar_rival]
	var total := j.fases.total_passadas()
	if j.fases.passada > total:
		passada.text = tr("JUSTA_PASSADA_EXTRA")
	else:
		passada.text = tr("JUSTA_PASSADA").format({"atual": j.fases.passada, "total": total})
	_atualizar_botao(j)

func _atualizar_botao(j: Justa) -> void:
	var nome := j.habilidade_ativa_de(true)
	botao.visible = nome != "" and not j.terminou() and controlador.modo != "exibicao"
	if not botao.visible:
		return
	botao.text = tr("HABILIDADE_" + nome.to_upper())
	if j.habilidade_usada_jogador:
		botao.carga = 0.0
		botao.disabled = true
	else:
		botao.carga = j.carga_habilidade(true)
		botao.disabled = not (j.fases.fase == JustaFases.Fase.CORRIDA and j.habilidade_carregada(true))

func _ao_apertar_botao() -> void:
	if controlador:
		controlador.ativar_habilidade()

func _ao_comecar_passada(numero: int) -> void:
	if numero != 1:
		return
	var j := controlador.justa
	resultado.visible = false
	_armadura_inicial_jogador = _soma_armadura(j.lado_jogador)
	_armadura_inicial_rival = _soma_armadura(j.lado_rival)
	plaquinha_jogador.definir(tr(controlador.nome_jogador if controlador.nome_jogador != "" else "JUSTA_NOME_JOGADOR"), controlador.arena.jogador.cor_casa)
	plaquinha_rival.definir(tr(controlador.nome_rival) if controlador.nome_rival != "" else "", controlador.arena.rival.cor_casa)

## Exibição: o arauto explica cada fase. Tutorial: a dica da fase fica na tela.
func _ao_mudar_fase(f: JustaFases.Fase, _anterior: JustaFases.Fase, _p: int) -> void:
	var dica: Label = $Dica
	var nome := JustaFases.NOMES_FASE[f].to_upper()
	match controlador.modo:
		"exibicao":
			dica.text = tr("ARAUTO_EXIBICAO_" + nome) if f != JustaFases.Fase.FIM else ""
		"tutorial":
			dica.text = tr("DICA_" + nome) if f != JustaFases.Fase.FIM else ""
		"disputa":
			# Na apresentação o arauto lê a provocação do campeão e os desafios.
			var linhas: Array[String] = []
			if f == JustaFases.Fase.APRESENTACAO and controlador.justa.fases.passada <= 1:
				if controlador.provocacao != "":
					linhas.append(tr("ARAUTO_PROVOCACAO").format({"texto": tr(controlador.provocacao)}))
				for d: String in controlador.desafios:
					linhas.append(tr("DESAFIO_" + d.to_upper()))
			dica.text = "\n".join(linhas)
		_:
			dica.text = ""

func _ao_avaliar_largada(_p: int, qualidade: String, _reacao: int, queimada: bool) -> void:
	mostrar_letreiro(tr("LARGADA_QUEIMADA") if queimada else tr("LARGADA_" + qualidade.to_upper()))

func _ao_ativar_habilidade(_p: int, lado: String, nome: String) -> void:
	if lado == "jogador":
		mostrar_letreiro(tr("HABILIDADE_" + nome.to_upper()))

func _ao_resolver_impacto(_p: int, jog: Dictionary, riv: Dictionary, _d: JustaFases.Lado, _q: JustaFases.Lado) -> void:
	var partes: Array[String] = []
	if jog["falta"]:
		partes.append(tr("GOLPE_FALTA"))
	elif jog["zona"] == Mira.ERRO:
		partes.append(tr("GOLPE_ERRO"))
	else:
		if jog["bloqueado"]:
			partes.append(tr("GOLPE_BLOQUEADO"))
		partes.append("%s +%d" % [tr("GOLPE_" + str(jog["zona_final"]).to_upper()), jog["pontos"]])
	if jog["derrubou"]:
		partes.append(tr("GOLPE_DERRUBOU"))
	if riv["derrubou"]:
		partes.append(tr("GOLPE_CAIU"))
	mostrar_letreiro("  ".join(partes))

func _ao_terminar(vencedor: JustaFases.Lado, motivo: String, _pj: int, _pr: int) -> void:
	match vencedor:
		JustaFases.Lado.JOGADOR: resultado_titulo.text = tr("RESULTADO_VITORIA")
		JustaFases.Lado.RIVAL: resultado_titulo.text = tr("RESULTADO_DERROTA")
		_: resultado_titulo.text = tr("RESULTADO_EMPATE")
	resultado_motivo.text = tr("MOTIVO_" + motivo.to_upper())
	resultado_dica.text = tr("JUSTA_TOQUE_DE_NOVO")
	if controlador.modo in ["exibicao", "tutorial"]:
		resultado_dica.text = tr("INICIO_TOQUE_PARA_SEGUIR")
	if controlador.modo == "exibicao":
		resultado_titulo.text = tr("EXIBICAO_FIM")
	var r: Dictionary = controlador.resultado_disputa
	if not r.is_empty():
		var linhas: Array[String] = [tr("MOTIVO_" + motivo.to_upper())]
		if r.get("venceu", false):
			linhas.append("★".repeat(int(r["estrelas"])) + "☆".repeat(3 - int(r["estrelas"])))
			linhas.append(tr("PVE_RECOMPENSA").format({"ouro": r["ouro"], "xp": r["xp"]}))
		for n: int in r.get("niveis", []):
			linhas.append(tr("PVE_SUBIU_NIVEL").format({"nivel": n}))
		if r.get("torneio_concluido", false):
			linhas.append(tr("PVE_TORNEIO_VENCIDO"))
		var mats: Dictionary = r.get("materiais", {})
		if not mats.is_empty():
			var partes: Array[String] = []
			for m: String in mats:
				partes.append("+%d %s" % [int(mats[m]), tr("MATERIAL_" + m.to_upper())])
			linhas.append(tr("PVE_MATERIAIS").format({"lista": ", ".join(partes)}))
		for b: Dictionary in r.get("baus", []):
			if b["cheio"]:
				linhas.append(tr("PVE_BAU_CHEIO").format({"bau": tr("BAU_" + str(b["tipo"]).to_upper()), "ouro": b["ouro"]}))
			else:
				linhas.append(tr("PVE_BAU_GANHO").format({"bau": tr("BAU_" + str(b["tipo"]).to_upper())}))
		if str(r.get("projeto", "")) != "":
			linhas.append(tr("PVE_PROJETO_GANHO").format({"conjunto": tr("CONJUNTO_" + str(r["projeto"]).to_upper())}))
		if str(r.get("regiao_nova", "")) != "":
			linhas.append(tr("PVE_REGIAO_LIBERADA").format({"regiao": tr("REGIAO_" + str(r["regiao_nova"]).to_upper())}))
		resultado_motivo.text = "\n".join(linhas)
		resultado_dica.text = tr("PVE_TOQUE_PARA_VOLTAR")
	resultado.visible = true

func mostrar_letreiro(texto: String) -> void:
	letreiro.text = texto
	letreiro.visible = true
	_tempo_letreiro = duracao_letreiro

## Peças de armadura = todo o equipamento menos a lança.
static func _soma_armadura(lado: Dictionary) -> int:
	var soma := 0
	var equip: Dictionary = lado.get("equipamento", {})
	for peca: String in equip:
		if peca != "lanca":
			soma += int(equip[peca].get("durabilidade", 0))
	return soma

static func _fracao_armadura(lado: Dictionary, inicial: int) -> float:
	return 1.0 if inicial <= 0 else float(_soma_armadura(lado)) / inicial
