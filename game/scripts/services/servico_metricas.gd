class_name ServicoMetricas
extends Node
## Métricas de jogo (autoload "Metricas", Pacote 2.13): registra eventos
## (tutorial, justas, prédios, desistências) numa fila guardada em
## user://metricas.json e envia em lotes para a tabela evento_metrica do
## Supabase quando a nuvem está ligada. Sem nuvem, a fila só cresce até o
## limite (os mais antigos saem) e espera.

const FILA := "user://metricas.json"
## Limite da fila guardada e tamanho de cada lote enviado.
const LIMITE := 500
const LOTE := 50
## A cada quantos segundos tenta enviar.
const INTERVALO_S := 30.0

var caminho_fila := FILA
## Em modo headless (só os testes usam) não registra nada, para os testes não
## encherem a fila real; o teste das métricas liga.
var ativo := DisplayServer.get_name() != "headless"
var fila: Array = []
var sessao_id := ""
var _acumulado := 0.0
var _enviando := false

func _ready() -> void:
	sessao_id = "%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 100000]
	if FileAccess.file_exists(caminho_fila):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho_fila))
		if v is Array:
			fila = v

## Esquece tudo (exclusão de conta, 3.9).
func limpar() -> void:
	fila.clear()
	if FileAccess.file_exists(caminho_fila):
		DirAccess.remove_absolute(caminho_fila)

## Registra um evento (nome curto em minúsculas, dados pequenos).
func registrar(evento: String, dados := {}) -> void:
	if not ativo:
		return
	fila.append({"evento": evento, "dados": dados, "sessao": sessao_id,
		"criado_em_cliente": Time.get_datetime_string_from_unix_time(ServicoTempo.agora(), true) + "Z"})
	while fila.size() > LIMITE:
		fila.pop_front()
	_guardar()

func _process(delta: float) -> void:
	_acumulado += delta
	if _acumulado >= INTERVALO_S:
		_acumulado = 0.0
		enviar()

## Envia um lote pela Nuvem (se conectada). Devolve quantos foram enviados.
func enviar() -> int:
	var nuvem := get_node_or_null("/root/Nuvem") as ServicoNuvem
	if _enviando or fila.is_empty() or nuvem == null or not nuvem.configurado() or not nuvem.conectado():
		return 0
	_enviando = true
	var lote := fila.slice(0, LOTE)
	var corpo := lote.map(func(e): return {"evento": e["evento"], "dados": e["dados"], "sessao": e["sessao"],
		"criado_em_cliente": e["criado_em_cliente"]})
	var resp: Dictionary = await nuvem._autenticado(HTTPClient.METHOD_POST, nuvem._url("/rest/v1/evento_metrica"),
		JSON.stringify(corpo), ["Prefer: return=minimal"])
	_enviando = false
	if int(resp["codigo"]) >= 300:
		return 0
	fila = fila.slice(lote.size())
	_guardar()
	return lote.size()

func _guardar() -> void:
	var f := FileAccess.open(caminho_fila, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(fila))
