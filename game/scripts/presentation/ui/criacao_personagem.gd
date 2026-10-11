class_name CriacaoPersonagem
extends Control
## Tela de criação de personagem (Pacote 2.2, GDD Início do jogo): corpo,
## rosto, cabelo e cor, tom de pele, nome e nome da casa, cores da casa e
## pelagem do cavalo inicial, com pré-visualização ao vivo do cavaleiro
## montado e do retrato. Opções em game/data/personagem/opcoes_criacao.json,
## nomes para sortear em game/data/texto/nomes_sorteio.json. Confirmar pede
## ao serviço Jogador (que valida o nome com o filtro de ofensivos).

signal personagem_criado

const OPCOES := "res://game/data/personagem/opcoes_criacao.json"
const SORTEIO := "res://game/data/texto/nomes_sorteio.json"

## Escolhas atuais (mesmas chaves de Jogador.criar_personagem).
var escolha := {}

var _op: Dictionary
var _pal: Dictionary
var _seletores := {}
var _amostras := {}
var _rng := RandomNumberGenerator.new()

@onready var _campos: VBoxContainer = $Formulario/Coluna/Rolagem/Campos
@onready var _nome: LineEdit
@onready var _casa: LineEdit
@onready var _erro: Label = $Formulario/Coluna/Erro
@onready var _cavaleiro: Cavaleiro = $Previa/Cavaleiro
@onready var _retrato: CamadasPersonagem = $Previa/Retrato

func _ready() -> void:
	_op = _ler(OPCOES)
	_pal = _ler(CamadasPersonagem.PALETAS)
	$Titulo.text = tr("CRIACAO_TITULO")
	$Formulario/Coluna/Botoes/Sortear.text = tr("CRIACAO_SORTEAR")
	$Formulario/Coluna/Botoes/Confirmar.text = tr("CRIACAO_CONFIRMAR")
	$Formulario/Coluna/Botoes/Sortear.pressed.connect(sortear)
	$Formulario/Coluna/Botoes/Confirmar.pressed.connect(confirmar)
	_erro.text = ""
	escolha = {"nome": "", "nome_casa": "", "corpo": _op["corpos"][0], "rosto": _op["rostos"][0],
		"cabelo": _op["cabelos"][0], "cor_cabelo": "castanho", "pele": "media",
		"cor_principal": "azul_real", "cor_secundaria": "ouro_velho", "pelagem": _op["pelagens"][0]}
	_montar()
	_cavaleiro.animar("galope", 0.6)
	_retrato.tocar("respirar")
	atualizar_previa()

## Preenche os campos com escolhas aleatórias (nome conforme o corpo).
func sortear() -> void:
	var nomes := _ler(SORTEIO)
	for chave: String in ["corpo", "rosto", "cabelo", "pelagem"]:
		var lista: Array = _op[_plural(chave)]
		(_seletores[chave] as Seletor).escolher(lista[_rng.randi() % lista.size()])
	for chave: String in ["cor_cabelo", "pele", "cor_principal", "cor_secundaria"]:
		var lista: Array = _op[_lista_cor(chave)]
		var v: String = lista[_rng.randi() % lista.size()]
		if chave == "cor_secundaria":
			while v == escolha["cor_principal"] and lista.size() > 1:
				v = lista[_rng.randi() % lista.size()]
		(_amostras[chave] as AmostrasCor).escolher(v)
	var lista_nomes: Array = nomes["femininos"] if escolha["corpo"] == "feminino" else nomes["masculinos"]
	_nome.text = lista_nomes[_rng.randi() % lista_nomes.size()]
	_casa.text = nomes["casas"][_rng.randi() % nomes["casas"].size()]
	_erro.text = ""

func confirmar() -> void:
	escolha["nome"] = _nome.text
	escolha["nome_casa"] = _casa.text
	var jog := get_node_or_null("/root/Jogador") as ServicoJogador
	if jog == null:
		return
	var r := jog.criar_personagem(escolha)
	if not r["ok"]:
		_erro.text = tr("ERRO_" + str(r["erro"]).to_upper())
		return
	_erro.text = ""
	personagem_criado.emit()
	var f := get_node_or_null("/root/Fluxo") as FluxoTelas
	if f and not jog.tutorial_concluido():
		f.concluiu("criacao")

func atualizar_previa() -> void:
	var casa := {"principal": escolha["cor_principal"], "secundaria": escolha["cor_secundaria"],
		"pele": escolha["pele"], "cabelo": escolha["cor_cabelo"]}
	_cavaleiro.definir_casa(casa)
	_cavaleiro.camadas().vestir({"corpo": escolha["corpo"], "pelagem": escolha["pelagem"]})
	_retrato.definir_casa(casa)
	_retrato.vestir({"corpo": escolha["corpo"], "rosto": escolha["rosto"], "cabelo": escolha["cabelo"]})

func _montar() -> void:
	_nome = _campo_texto("CRIACAO_NOME")
	_casa = _campo_texto("CRIACAO_CASA")
	_campo_seletor("corpo", "CRIACAO_CORPO", "CORPO_")
	_campo_seletor("rosto", "CRIACAO_ROSTO", "")
	_campo_seletor("cabelo", "CRIACAO_CABELO", "")
	_campo_cor("cor_cabelo", "CRIACAO_COR_CABELO", "cabelos", "CABELO_")
	_campo_cor("pele", "CRIACAO_PELE", "peles", "PELE_")
	_campo_cor("cor_principal", "CRIACAO_COR_PRINCIPAL", "cores_casa", "COR_")
	_campo_cor("cor_secundaria", "CRIACAO_COR_SECUNDARIA", "cores_casa", "COR_")
	_campo_seletor("pelagem", "CRIACAO_PELAGEM", "PELAGEM_")

func _rotulo(chave_texto: String) -> void:
	var l := Label.new()
	l.text = tr(chave_texto)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.85, 0.72, 0.45))
	_campos.add_child(l)

func _campo_texto(chave_texto: String) -> LineEdit:
	_rotulo(chave_texto)
	var e := LineEdit.new()
	e.max_length = 20
	e.placeholder_text = tr(chave_texto)
	_campos.add_child(e)
	return e

func _campo_seletor(chave: String, chave_texto: String, prefixo: String) -> void:
	_rotulo(chave_texto)
	var s := Seletor.new()
	var lista: Array = []
	for v: String in _op[_plural(chave)]:
		var texto := tr(prefixo + v.to_upper()) if prefixo != "" else tr("CRIACAO_OPCAO").format({"n": v})
		lista.append({"valor": v, "texto": texto})
	s.definir_opcoes(lista, escolha[chave])
	s.mudou.connect(func(v): escolha[chave] = v; atualizar_previa())
	_campos.add_child(s)
	_seletores[chave] = s

func _campo_cor(chave: String, chave_texto: String, grupo_paleta: String, prefixo: String) -> void:
	_rotulo(chave_texto)
	var a := AmostrasCor.new()
	a.columns = 8
	var cores := {}
	for nome: String in _op[_lista_cor(chave)]:
		cores[nome] = Color(_pal[grupo_paleta][nome])
	_campos.add_child(a)
	a.definir(cores, escolha[chave], prefixo)
	a.escolhida.connect(func(n): escolha[chave] = n; atualizar_previa())
	_amostras[chave] = a

static func _plural(chave: String) -> String:
	return {"corpo": "corpos", "rosto": "rostos", "cabelo": "cabelos", "pelagem": "pelagens"}[chave]

static func _lista_cor(chave: String) -> String:
	return {"cor_cabelo": "cores_cabelo", "pele": "peles", "cor_principal": "cores_casa", "cor_secundaria": "cores_casa"}[chave]

static func _ler(caminho: String) -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	return v if v is Dictionary else {}
