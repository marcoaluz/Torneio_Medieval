class_name RegistroErros
extends Node
## Registro de erros do jogo (autoload "Registro", Pacote 3.10): captura os
## erros do motor e dos scripts (push_error, erro de script) com um Logger do
## Godot e os manda como o evento "erro_jogo" nas métricas (tabela
## evento_metrica, visível no painel). Poucos por sessão e sem repetir o mesmo
## arquivo:linha, para um laço com erro não encher a fila nem a bateria.
## Não registra avisos. Em modo headless (testes) não captura sozinho.

const MAX_POR_SESSAO := 20
const TAMANHO_MENSAGEM := 200

var enviados := 0
## Já vistos nesta sessão (arquivo:linha).
var _vistos := {}
var _logger: _Capturador

class _Capturador extends Logger:
	var _mutex := Mutex.new()
	var _itens: Array[Dictionary] = []

	## Chamado pelo motor (pode ser de outra thread): só guarda.
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, backtraces: Array[ScriptBacktrace]) -> void:
		# 0 = erro, 2 = erro de script (1 = aviso, 3 = shader: não interessam).
		if error_type != 0 and error_type != 2:
			return
		# push_error aponta para o código do motor; o lugar útil é o primeiro quadro do script.
		var arquivo := file
		var linha := line
		var funcao := function
		for bt in backtraces:
			if bt != null and bt.get_frame_count() > 0:
				arquivo = bt.get_frame_file(0)
				linha = bt.get_frame_line(0)
				funcao = bt.get_frame_function(0)
				break
		_mutex.lock()
		if _itens.size() < 50:
			_itens.append({"arquivo": arquivo, "linha": linha, "funcao": funcao,
				"mensagem": rationale if rationale != "" else code})
		_mutex.unlock()

	func esvaziar() -> Array[Dictionary]:
		_mutex.lock()
		var r := _itens.duplicate()
		_itens.clear()
		_mutex.unlock()
		return r

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	ligar()

## Começa a capturar (os testes chamam).
func ligar() -> void:
	if _logger == null:
		_logger = _Capturador.new()
		OS.add_logger(_logger)

func _exit_tree() -> void:
	if _logger != null:
		OS.remove_logger(_logger)

func _process(_delta: float) -> void:
	if _logger != null:
		coletar()

## Passa os erros capturados às métricas. Devolve quantos registrou.
func coletar() -> int:
	if _logger == null:
		return 0
	var n := 0
	var m := get_node_or_null("/root/Metricas") as ServicoMetricas
	for e: Dictionary in _logger.esvaziar():
		var chave := "%s:%d" % [e["arquivo"], int(e["linha"])]
		if _vistos.has(chave) or enviados >= MAX_POR_SESSAO:
			continue
		_vistos[chave] = true
		enviados += 1
		n += 1
		if m:
			m.registrar("erro_jogo", {"arquivo": str(e["arquivo"]).get_file(), "linha": int(e["linha"]), "funcao": str(e["funcao"]),
				"mensagem": str(e["mensagem"]).left(TAMANHO_MENSAGEM)})
	return n
