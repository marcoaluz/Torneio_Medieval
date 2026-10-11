class_name OpcoesAcessibilidade
extends Node
## Acessibilidade (autoload "Acessibilidade"; Pacote 3.24): aplica as opções
## salvas em estado.config (serviço Jogador):
##   - idioma ("" = o do aparelho) no TranslationServer;
##   - tamanho do texto: todo Label/Button/CheckButton/RichTextLabel que entra
##     na árvore tem o tamanho de fonte multiplicado pela escala (o tamanho
##     base de cada um fica guardado em metadado, para trocar de escala);
##   - canhoto: as telas chamam `espelhar(controle)` para trocar de lado;
##   - economia de bateria (3.25): limita os quadros por segundo; quem cria
##     partículas multiplica a quantidade por `fator_particulas()`.
## Escalas e padrões em game/data/ui/acessibilidade.json.

const DADOS := "res://game/data/ui/acessibilidade.json"
const META_BASE := "tm_fonte_base"

var cfg: Dictionary
var escala := 1.0
var _jog: ServicoJogador
var _idioma_aparelho := ""

func _ready() -> void:
	cfg = JSON.parse_string(FileAccess.get_file_as_string(DADOS))
	_idioma_aparelho = TranslationServer.get_locale()
	_jog = get_node_or_null("/root/Jogador")
	if _jog:
		_jog.mudou.connect(func(secao): if secao in ["config", "tudo"]: aplicar())
	get_tree().node_added.connect(_ao_entrar)
	aplicar()

func opcao(chave: String) -> Variant:
	if _jog:
		return _jog.config_valor(chave)
	return cfg["padrao"][chave]

## Reaplica idioma e tamanho do texto em tudo que já está na tela.
func aplicar() -> void:
	var idioma: String = opcao("idioma")
	TranslationServer.set_locale(idioma if idioma != "" else _idioma_aparelho)
	escala = float(cfg["tamanhos_texto"].get(str(opcao("texto")), 1.0))
	var b: Dictionary = cfg["bateria"]
	Engine.max_fps = int(b["fps_economia"] if economia_bateria() else b["fps_normal"])
	if is_inside_tree():
		_percorrer(get_tree().root)

func canhoto() -> bool:
	return bool(opcao("canhoto"))

func vibracao() -> bool:
	return bool(opcao("vibracao"))

func economia_bateria() -> bool:
	return bool(opcao("economia_bateria"))

## Quantas partículas criar (1.0 normal; menos na economia de bateria).
func fator_particulas() -> float:
	return float(cfg["bateria"]["particulas_pct"]) / 100.0 if economia_bateria() else 1.0

## Atalho para quem não tem o autoload à mão (testes, ferramentas).
static func fator(no: Node) -> float:
	var ac := no.get_node_or_null("/root/Acessibilidade") as OpcoesAcessibilidade
	return ac.fator_particulas() if ac else 1.0

## Espelha um controle na horizontal (âncoras e margens): o que estava à
## direita vai para a esquerda e vice-versa.
static func espelhar(c: Control) -> void:
	var al := c.anchor_left
	var ar := c.anchor_right
	var ol := c.offset_left
	var orr := c.offset_right
	c.anchor_left = 1.0 - ar
	c.anchor_right = 1.0 - al
	c.offset_left = -orr
	c.offset_right = -ol
	if c.grow_horizontal == Control.GROW_DIRECTION_BEGIN:
		c.grow_horizontal = Control.GROW_DIRECTION_END
	elif c.grow_horizontal == Control.GROW_DIRECTION_END:
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN

func _ao_entrar(no: Node) -> void:
	if no is Control:
		_ajustar.call_deferred(no)

func _percorrer(no: Node) -> void:
	if no is Control:
		_ajustar(no)
	for f in no.get_children():
		_percorrer(f)

func _ajustar(no: Node) -> void:
	if not is_instance_valid(no) or not (no is Label or no is Button or no is RichTextLabel or no is LineEdit):
		return
	var c := no as Control
	var chave := "normal_font_size" if c is RichTextLabel else "font_size"
	if not c.has_meta(META_BASE):
		c.set_meta(META_BASE, c.get_theme_font_size(chave))
	var base := int(c.get_meta(META_BASE))
	if base <= 0:
		return
	if is_equal_approx(escala, 1.0) and not c.has_theme_font_size_override(chave):
		return
	c.add_theme_font_size_override(chave, maxi(6, roundi(base * escala)))
