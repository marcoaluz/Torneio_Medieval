class_name CenaHistoria
extends Control
## Cena curta de história (Pacote 3.22): retrato, nome e fala, uma por vez;
## o texto aparece aos poucos (toque mostra inteiro; outro toque segue).
## "Pular" encerra a cena. Ao terminar, marca como vista no serviço e emite
## `terminou`. Falas e personagens em game/data/historia/historia.json (o
## retrato é provisório: quadro com a cor e a inicial; troca por sprite em
## game/art/sprites/retratos/{id}_{expressao}.png quando existir).

signal terminou(id: String)

const VELOCIDADE_LETRAS := 45.0

var cena := ""
var _falas: Array = []
var _i := 0
var _tween: Tween
var _jog: ServicoJogador

@onready var _retrato: ColorRect = $Caixa/Linha/Retrato
@onready var _inicial: Label = $Caixa/Linha/Retrato/Inicial
@onready var _sprite: TextureRect = $Caixa/Linha/Retrato/Sprite
@onready var _nome: Label = $Caixa/Linha/Coluna/Nome
@onready var _texto: Label = $Caixa/Linha/Coluna/Texto
@onready var _dica: Label = $Caixa/Linha/Coluna/Dica
@onready var _pular: Button = $Pular

func _ready() -> void:
	_jog = get_node_or_null("/root/Jogador")
	visible = false
	_pular.text = tr("HIST_PULAR")
	_dica.text = tr("HIST_TOQUE")
	_pular.pressed.connect(_fim)

## Toca a cena `id`.
func tocar(id: String) -> void:
	var h := _jog.cfg_historia()
	cena = id
	_falas = h["cenas"][id]["falas"]
	_i = 0
	visible = true
	_mostrar()

func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		avancar()
		accept_event()

## Primeiro toque completa o texto; o seguinte passa para a próxima fala.
func avancar() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
		_texto.visible_ratio = 1.0
		return
	_i += 1
	if _i >= _falas.size():
		_fim()
	else:
		_mostrar()

func _mostrar() -> void:
	var h := _jog.cfg_historia()
	var f: Dictionary = _falas[_i]
	var quem: String = f["quem"]
	if quem == "jogador":
		_nome.text = _jog.cavaleiro().get("nome", "")
		# Retrato do jogador na cor principal da casa (paletas.json).
		var pal: Dictionary = Balanceamento.ler_json(CamadasPersonagem.PALETAS)
		_retrato.color = Color(pal["cores_casa"].get(_jog.casa()["cores"]["principal"], "2c3a5a"))
		_inicial.text = str(_nome.text).left(1)
	else:
		var p: Dictionary = h["personagens"][quem]
		_nome.text = tr(p["nome"])
		_retrato.color = Color(p["cor"])
		_inicial.text = p["inicial"]
	var arte := "res://game/art/sprites/retratos/%s_%s.png" % [quem, f.get("expressao", "neutro")]
	_sprite.texture = load(arte) if ResourceLoader.exists(arte) else null
	_inicial.visible = _sprite.texture == null
	_texto.text = tr(f["texto"])
	_texto.visible_ratio = 0.0
	_tween = create_tween()
	_tween.tween_property(_texto, "visible_ratio", 1.0, maxf(0.2, _texto.text.length() / VELOCIDADE_LETRAS))

func _fim() -> void:
	if _tween:
		_tween.kill()
	visible = false
	var id := cena
	cena = ""
	if _jog and id != "":
		_jog.marcar_cena_vista(id)
	terminou.emit(id)
