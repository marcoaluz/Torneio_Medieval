class_name EditorBrasao
extends Control
## Editor de brasão (Pacote 2.3): formato do escudo, divisão do campo,
## símbolo e posição, cores. As opções vêm de game/data/crests/brasao.json
## (acrescente formas, símbolos e cores lá). A prévia mostra o brasão grande,
## no escudo, na sobreveste e na caparação do cavaleiro montado e numa
## bandeira. Confirmar grava com Jogador.definir_brasao.

signal brasao_definido(brasao: Dictionary)

## Escolhas atuais: {forma, divisao, cor1, cor2, simbolo, posicao, cor_simbolo}.
var brasao := {}
## Edita o brasão da ORDEM do jogador (3.20) em vez do da casa: parte do
## brasão da ordem e confirmar só avisa (`brasao_definido`); quem abriu grava.
## Definir antes de entrar na árvore.
var alvo_ordem := false

var _seletores := {}
var _amostras := {}
var _rng := RandomNumberGenerator.new()

@onready var _campos: VBoxContainer = $Formulario/Coluna/Rolagem/Campos
@onready var _grande: TextureRect = $Previa/Grande
@onready var _bandeira: TextureRect = $Previa/Bandeira
@onready var _cavaleiro: Cavaleiro = $Previa/Cavaleiro

func _ready() -> void:
	var cfg := GeradorBrasao.opcoes()
	$Titulo.text = tr("ORDEM_BRASAO_TITULO" if alvo_ordem else "BRASAO_TITULO")
	$Formulario/Coluna/Botoes/Sortear.text = tr("CRIACAO_SORTEAR")
	$Formulario/Coluna/Botoes/Confirmar.text = tr("CRIACAO_CONFIRMAR")
	$Formulario/Coluna/Botoes/Sortear.pressed.connect(sortear)
	$Formulario/Coluna/Botoes/Confirmar.pressed.connect(confirmar)
	var jog := get_node_or_null("/root/Jogador") as ServicoJogador
	var atual: Dictionary = jog.casa().get("brasao", {}) if jog else {}
	if alvo_ordem and jog:
		atual = jog.ordem().get("brasao", atual)
	if atual.is_empty() and jog:
		var cores: Dictionary = jog.casa()["cores"]
		atual = {"cor1": cores["principal"], "cor2": cores["secundaria"], "cor_simbolo": cores["secundaria"]}
	brasao = GeradorBrasao.completar(atual)
	_seletor("forma", "BRASAO_FORMA", cfg["formas"].keys())
	_seletor("divisao", "BRASAO_DIVISAO", cfg["divisoes"])
	_cor("cor1", "BRASAO_COR1")
	_cor("cor2", "BRASAO_COR2")
	_seletor("simbolo", "BRASAO_SIMBOLO", cfg["simbolos"].keys())
	_seletor("posicao", "BRASAO_POSICAO", cfg["posicoes"].keys())
	_cor("cor_simbolo", "BRASAO_COR_SIMBOLO")
	if jog:
		var cores: Dictionary = jog.casa()["cores"]
		_cavaleiro.definir_casa({"principal": cores["principal"], "secundaria": cores["secundaria"]})
	_cavaleiro.animar("galope", 0.5)
	atualizar_previa()

func atualizar_previa() -> void:
	_grande.texture = GeradorBrasao.textura(brasao, Vector2i(48, 60))
	_bandeira.texture = GeradorBrasao.textura(brasao, Vector2i(28, 40), false)
	_cavaleiro.definir_brasao(brasao)

func sortear() -> void:
	for chave: String in _seletores:
		var s: Seletor = _seletores[chave]
		s.escolher(s.opcoes[_rng.randi() % s.opcoes.size()]["valor"])
	# Regra das tinturas: campo e partição de tinturas diferentes, símbolo oposto ao campo.
	var cores := GeradorBrasao.sortear_cores(_rng, GeradorBrasao.opcoes()["cores"], 3)
	for i in 3:
		(_amostras[["cor1", "cor2", "cor_simbolo"][i]] as AmostrasCor).escolher(cores[i])

func confirmar() -> void:
	var jog := get_node_or_null("/root/Jogador") as ServicoJogador
	if jog and not alvo_ordem:
		jog.definir_brasao(brasao)
	brasao_definido.emit(brasao.duplicate())
	if alvo_ordem:
		return
	var f := get_node_or_null("/root/Fluxo") as FluxoTelas
	if f and jog and not jog.tutorial_concluido():
		f.concluiu("brasao")

func _rotulo(chave_texto: String) -> void:
	var l := Label.new()
	l.text = tr(chave_texto)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.85, 0.72, 0.45))
	_campos.add_child(l)

func _seletor(chave: String, chave_texto: String, valores: Array) -> void:
	_rotulo(chave_texto)
	var s := Seletor.new()
	var lista: Array = []
	var grupo := chave.to_upper()
	for v: String in valores:
		lista.append({"valor": v, "texto": tr("BRASAO_%s_%s" % [grupo, v.to_upper()])})
	s.definir_opcoes(lista, brasao[chave])
	s.mudou.connect(func(v): brasao[chave] = v; atualizar_previa())
	_campos.add_child(s)
	_seletores[chave] = s

func _cor(chave: String, chave_texto: String) -> void:
	_rotulo(chave_texto)
	var pal: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CamadasPersonagem.PALETAS))["cores_casa"]
	var cores := {}
	for nome: String in GeradorBrasao.opcoes()["cores"]:
		cores[nome] = Color(pal[nome])
	var a := AmostrasCor.new()
	a.columns = 8
	_campos.add_child(a)
	a.definir(cores, brasao[chave], "COR_")
	a.escolhida.connect(func(n): brasao[chave] = n; atualizar_previa())
	_amostras[chave] = a
