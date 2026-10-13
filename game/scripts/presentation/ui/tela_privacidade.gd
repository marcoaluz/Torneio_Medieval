class_name TelaPrivacidade
extends Control
## Política de privacidade, termos de uso e consentimento de anúncios (Pacote
## 3.9). Aparece antes de começar o jogo (título) e pode ser revista nas
## Configurações. Os textos são do arquivo de traduções (PRIVACIDADE_*,
## TERMOS_*) e PRECISAM de revisão jurídica antes do lançamento.
##   aceita(personalizados): o jogador aceitou a versão atual (e escolheu os anúncios);
##   fechada: saiu sem mudar nada (só quando aberta para rever).
## A escolha fica no save (config.privacidade_aceita = versão aceita;
## config.anuncios_personalizados) e vale também para o servidor (consentimento).

signal aceita(personalizados: bool)
signal fechada

const DADOS := "res://game/data/ui/privacidade.json"
const PARTES_POLITICA := 6
const PARTES_TERMOS := 4

## true = aberta pelas Configurações: só rever (sem "Aceitar").
var revisao := false

@onready var _titulo: Label = $Painel/Coluna/Titulo
@onready var _texto: Label = $Painel/Coluna/Rolagem/Texto
@onready var _personalizados: CheckButton = $Painel/Coluna/Personalizados
@onready var _aceitar: Button = $Painel/Coluna/Botoes/Aceitar
@onready var _fechar: Button = $Painel/Coluna/Botoes/Fechar

func _ready() -> void:
	var jog := get_node_or_null("/root/Jogador") as ServicoJogador
	_titulo.text = tr("PRIVACIDADE_TITULO")
	var partes: Array[String] = []
	for i in range(1, PARTES_POLITICA + 1):
		partes.append(tr("PRIVACIDADE_P%d" % i))
	partes.append(tr("TERMOS_TITULO"))
	for i in range(1, PARTES_TERMOS + 1):
		partes.append(tr("TERMOS_P%d" % i))
	_texto.text = "\n\n".join(partes)
	_personalizados.text = tr("PRIVACIDADE_ANUNCIOS_PERSONALIZADOS")
	_personalizados.button_pressed = jog != null and bool(jog.config_valor("anuncios_personalizados"))
	_aceitar.text = tr("PRIVACIDADE_SALVAR" if revisao else "PRIVACIDADE_ACEITAR")
	_fechar.text = tr("PAINEL_FECHAR" if revisao else "PRIVACIDADE_SAIR")
	_aceitar.pressed.connect(_ao_aceitar)
	_fechar.pressed.connect(_ao_fechar)

func _ao_aceitar() -> void:
	var jog := get_node_or_null("/root/Jogador") as ServicoJogador
	if jog:
		jog.aceitar_privacidade(_personalizados.button_pressed)
	aceita.emit(_personalizados.button_pressed)
	queue_free()

func _ao_fechar() -> void:
	if revisao:
		fechada.emit()
		queue_free()
	else:
		# Sem aceitar não dá para jogar: sair do jogo (no celular, volta para o sistema).
		get_tree().quit()
