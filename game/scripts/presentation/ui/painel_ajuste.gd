class_name PainelAjuste
extends CanvasLayer
## Painel de ajuste da justa (Pacote 1.10), só em build de depuração.
## Muda em tempo real os números dos JSON de game/data/balance/ e salva no
## arquivo. O valor muda o mesmo dicionário que a justa em andamento lê,
## então janelas, zonas, pontos e chances valem na hora; durações das fases,
## atributos e o perfil do rival valem ao recomeçar a justa (botão).
## Enquanto aberto, o jogo fica pausado. Os rótulos dos campos são os
## caminhos nos JSON (ferramenta de desenvolvimento).

## Campos: [arquivo, caminho com pontos (índices de lista também), mínimo, máximo, passo].
const CAMPOS := [
	["galope", "largada.perfeita_ms", 0, 1000, 10],
	["galope", "largada.boa_ms", 0, 1000, 10],
	["galope", "largada.bandeira_variacao_ms", 0, 700, 10],
	["galope", "galope.compasso_ms", 200, 1200, 10],
	["galope", "galope.janela_base_ms", 0, 240, 5],
	["galope", "galope.janela_por_temperamento_milesimos", 0, 3000, 50],
	["galope", "galope.janela_max_ms", 0, 300, 5],
	["galope", "galope.ganho_pct", 0, 20, 1],
	["galope", "galope.perda_perdido_pct", 0, 20, 1],
	["galope", "folego.custo_erro", 0, 30, 1],
	["mira", "precisao.crescimento_por_ponto_milesimos", 0, 2000, 50],
	["mira", "precisao.crescimento_max_pct", 0, 150, 5],
	["mira", "oscilacao.amplitude_px", 0, 20, 1],
	["mira", "zonas.0.retangulos.0.2", 4, 60, 1],
	["mira", "zonas.0.retangulos.0.3", 4, 60, 1],
	["mira", "zonas.1.retangulos.0.2", 4, 60, 1],
	["mira", "zonas.1.retangulos.0.3", 4, 60, 1],
	["mira", "zonas.2.retangulos.0.2", 4, 60, 1],
	["mira", "zonas.2.retangulos.0.3", 4, 80, 1],
	["impacto", "pontos.capacete", 0, 10, 1],
	["impacto", "pontos.peito", 0, 10, 1],
	["impacto", "pontos.escudo", 0, 10, 1],
	["impacto", "falta.penalidade_pontos", 0, 10, 1],
	["impacto", "bloqueio.base_milesimos", 0, 400, 5],
	["impacto", "derrubada.base_por_zona_milesimos.capacete", 0, 500, 5],
	["impacto", "derrubada.base_por_zona_milesimos.peito", 0, 500, 5],
	["impacto", "derrubada.forca_menos_equilibrio_milesimos", 0, 20, 1],
	["impacto", "derrubada.teto_milesimos", 0, 1000, 10],
	["justa", "fases_ms.corrida", 2000, 10000, 100],
	["justa", "fases_ms.mira", 500, 5000, 100],
	["padrao", "cavaleiro.forca", 0, 100, 1],
	["padrao", "cavaleiro.precisao", 0, 100, 1],
	["padrao", "cavaleiro.equilibrio", 0, 100, 1],
	["padrao", "cavalo.velocidade", 0, 100, 1],
	["padrao", "cavalo.folego", 0, 100, 1],
	["padrao", "cavalo.temperamento", 0, 100, 1],
]
const ARQUIVOS := ["galope", "mira", "impacto", "justa", "padrao"]

@export var controlador: ControladorJusta
## Pasta onde salvar (os testes trocam por user://).
@export var pasta_saida := Balanceamento.PASTA

var dados := {}  ## arquivo -> dicionário em edição
var _campos := {}  ## "arquivo:caminho" -> SpinBox

@onready var _abrir: Button = $Abrir
@onready var _painel: PanelContainer = $Painel
@onready var _lista: VBoxContainer = $Painel/Coluna/Rolagem/Lista
@onready var _perfil: OptionButton = $Painel/Coluna/Perfil
@onready var _status: Label = $Painel/Coluna/Status

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_painel.visible = false
	_abrir.text = tr("PAINEL_ABRIR")
	_abrir.pressed.connect(abrir)
	$Painel/Coluna/Botoes/Salvar.text = tr("PAINEL_SALVAR")
	$Painel/Coluna/Botoes/Salvar.pressed.connect(salvar)
	$Painel/Coluna/Botoes/Recomecar.text = tr("PAINEL_RECOMECAR")
	$Painel/Coluna/Botoes/Recomecar.pressed.connect(recomecar)
	$Painel/Coluna/Botoes/Fechar.text = tr("PAINEL_FECHAR")
	$Painel/Coluna/Botoes/Fechar.pressed.connect(fechar)
	_perfil.item_selected.connect(func(i): if controlador: controlador.perfil_rival = _perfil.get_item_text(i))
	_montar()

## O painel ocupa este ponto da tela (para o jogo não tratar o toque)?
func contem_ponto(ponto: Vector2) -> bool:
	if _painel.visible:
		return true
	return _abrir.visible and _abrir.get_global_rect().has_point(ponto)

func abrir() -> void:
	_painel.visible = true
	_abrir.visible = false
	get_tree().paused = true

func fechar() -> void:
	_painel.visible = false
	_abrir.visible = true
	get_tree().paused = false

## Muda um valor (como o SpinBox faz) e aplica na justa em andamento.
func definir_valor(arquivo: String, caminho: String, valor: float) -> void:
	_escrever(dados[arquivo], caminho.split("."), int(valor) if valor == floorf(valor) else valor)
	Balanceamento.definir(arquivo, dados[arquivo])
	if controlador:
		controlador.aplicar_ajuste(arquivo, dados[arquivo])
	if _campos.has(arquivo + ":" + caminho):
		(_campos[arquivo + ":" + caminho] as SpinBox).set_value_no_signal(valor)

func ler_valor(arquivo: String, caminho: String) -> Variant:
	return _ler(dados[arquivo], caminho.split("."))

## Salva todos os arquivos em edição. Devolve true se todos gravaram.
func salvar() -> bool:
	var ok := true
	for arquivo: String in dados:
		var erro := Balanceamento.salvar(arquivo, dados[arquivo], pasta_saida)
		if erro != OK:
			ok = false
			_status.text = tr("PAINEL_ERRO_SALVAR").format({"arquivo": arquivo, "erro": error_string(erro)})
	if ok:
		_status.text = tr("PAINEL_SALVO")
	return ok

## Recomeça a justa com os valores atuais (atributos e perfil incluídos).
func recomecar() -> void:
	fechar()
	if controlador:
		controlador.lado_jogador = {}
		controlador.lado_rival = {}
		controlador.iniciar()

func _montar() -> void:
	for arquivo: String in ARQUIVOS:
		dados[arquivo] = Balanceamento.carregar(arquivo)
	var ultimo := ""
	for c: Array in CAMPOS:
		if c[0] != ultimo:
			ultimo = c[0]
			var titulo := Label.new()
			titulo.text = "%s.json" % ultimo
			titulo.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
			_lista.add_child(titulo)
		var linha := HBoxContainer.new()
		var rotulo := Label.new()
		rotulo.text = c[1]
		rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rotulo.add_theme_font_size_override("font_size", 11)
		var caixa := SpinBox.new()
		caixa.min_value = c[2]
		caixa.max_value = c[3]
		caixa.step = c[4]
		caixa.allow_greater = true
		caixa.custom_minimum_size.x = 90
		var atual: Variant = _ler(dados[c[0]], String(c[1]).split("."))
		caixa.value = float(atual) if atual != null else 0.0
		caixa.value_changed.connect(func(v): definir_valor(c[0], c[1], v))
		linha.add_child(rotulo)
		linha.add_child(caixa)
		_lista.add_child(linha)
		_campos[c[0] + ":" + c[1]] = caixa
	var perfis: Dictionary = Balanceamento.carregar("ia_rival").get("perfis", {})
	for nome: String in perfis:
		_perfil.add_item(nome)
		if controlador and nome == controlador.perfil_rival:
			_perfil.select(_perfil.item_count - 1)

static func _ler(d: Variant, partes: PackedStringArray) -> Variant:
	var atual: Variant = d
	for p in partes:
		if atual is Dictionary and atual.has(p):
			atual = atual[p]
		elif atual is Array and p.is_valid_int() and int(p) < atual.size():
			atual = atual[int(p)]
		else:
			return null
	return atual

static func _escrever(d: Variant, partes: PackedStringArray, valor: Variant) -> void:
	var atual: Variant = d
	for i in partes.size() - 1:
		var p := partes[i]
		atual = atual[int(p)] if atual is Array else atual[p]
	var ultima := partes[partes.size() - 1]
	if atual is Array:
		atual[int(ultima)] = valor
	else:
		atual[ultima] = valor
