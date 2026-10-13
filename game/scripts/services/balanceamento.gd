class_name Balanceamento
extends RefCounted
## Lê as tabelas de balanceamento de game/data/balance/<nome>.json.
## Hoje lê do pacote do jogo; na Parte 3 passa a vir do servidor (com versão).
## Falha alto: arquivo ausente, JSON inválido ou sem "versao" gera erro e
## devolve {} (quem chama não deve seguir com valores inventados).
##
## Balanceamento remoto (3.3): o servidor guarda as tabelas ativas (tabela
## `balanceamento`, mudada pelo painel do Supabase). A Nuvem baixa e guarda
## em cache (user://balanceamento_remoto.json); na abertura seguinte
## aplicar_cache_remoto() troca em memória as tabelas que o jogo conhece e que
## não são de versão mais antiga que a do pacote. Sem cache ou sem rede, vale o
## que veio no pacote (funciona com sinal fraco).
##
## Painel de ajuste (só em desenvolvimento): definir() troca a tabela em
## memória para as próximas leituras, e salvar() grava o JSON de volta.
##
## Desempenho (3.25): cada arquivo é lido e interpretado uma vez só e fica em
## cache, travado contra escrita em todos os níveis (make_read_only).
##   ler(nome) / ler_json(caminho): o dado compartilhado, SEM cópia — para
##     caminhos quentes que só leem (mudar dá erro na hora).
##   carregar(nome): uma cópia que pode ser mudada à vontade.

const PASTA := "res://game/data/balance/"
const CACHE_REMOTO := "user://balanceamento_remoto.json"

static var _sobrescritas := {}
static var _cache := {}

static func carregar(nome: String) -> Dictionary:
	return ler(nome).duplicate(true)

## Tabela de balanceamento compartilhada (somente leitura).
static func ler(nome: String) -> Dictionary:
	if _sobrescritas.has(nome):
		return _sobrescritas[nome]
	var d := ler_json(PASTA + nome + ".json")
	if not d.is_empty() and not d.has("versao"):
		push_error("Balanceamento: %s sem campo \"versao\"" % nome)
		return {}
	return d

## Qualquer arquivo JSON de dados, com cache (somente leitura).
static func ler_json(caminho: String) -> Dictionary:
	if _cache.has(caminho):
		return _cache[caminho]
	var texto := FileAccess.get_file_as_string(caminho)
	if texto.is_empty():
		push_error("Balanceamento: não consegui ler %s (%s)" % [caminho, error_string(FileAccess.get_open_error())])
		return {}
	var dados: Variant = JSON.parse_string(texto)
	if not dados is Dictionary:
		push_error("Balanceamento: %s não é um objeto JSON válido" % caminho)
		return {}
	_travar(dados)
	_cache[caminho] = dados
	return dados

## Aplica por cima dos arquivos do jogo as tabelas baixadas do servidor (cache).
## Em modo headless (testes) não faz nada, a menos que `forcar`. Devolve quantas
## tabelas trocou. Só troca tabelas que o jogo conhece, com "versao" (esquema)
## igual ou maior que a do pacote.
static func aplicar_cache_remoto(forcar := false, caminho := CACHE_REMOTO) -> int:
	if not forcar and DisplayServer.get_name() == "headless":
		return 0
	if not FileAccess.file_exists(caminho):
		return 0
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if not v is Dictionary or not v.get("tabelas") is Dictionary:
		return 0
	var n := 0
	for nome: String in v["tabelas"]:
		var t: Variant = v["tabelas"][nome]
		var arquivo := PASTA + nome + ".json"
		if not t is Dictionary or not FileAccess.file_exists(arquivo):
			continue
		var local := ler_json(arquivo)
		if int((t as Dictionary).get("versao", 0)) < int(local.get("versao", 0)):
			continue
		definir(nome, _inteiros(t))
		n += 1
	return n

## Guarda no cache as tabelas baixadas: {nome: dados}, com a revisão de cada uma.
static func salvar_cache_remoto(tabelas: Dictionary, revisoes: Dictionary, caminho := CACHE_REMOTO) -> Error:
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"revisoes": revisoes, "tabelas": tabelas}))
	f.close()
	return OK

## Esquece o cache (testes que trocam arquivos; o painel usa definir()).
static func limpar_cache() -> void:
	_cache.clear()

static func _travar(v: Variant) -> void:
	if v is Dictionary:
		for k in v:
			_travar(v[k])
		(v as Dictionary).make_read_only()
	elif v is Array:
		for x in v:
			_travar(x)
		(v as Array).make_read_only()

## Troca a tabela em memória (as próximas leituras de `nome` devolvem esta).
static func definir(nome: String, dados: Dictionary) -> void:
	var copia := dados.duplicate(true)
	_travar(copia)
	_sobrescritas[nome] = copia

## Volta a ler do arquivo.
static func esquecer(nome: String) -> void:
	_sobrescritas.erase(nome)

## Grava a tabela em `pasta`/<nome>.json (tabulação, números inteiros sem
## ".0"). Em build exportado res:// é só leitura: só funciona rodando o
## projeto. Devolve o código de erro do Godot (OK = 0).
static func salvar(nome: String, dados: Dictionary, pasta := PASTA) -> Error:
	if not dados.has("versao"):
		return ERR_INVALID_DATA
	var f := FileAccess.open(pasta.path_join(nome + ".json"), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(_inteiros(dados), "\t", false) + "\n")
	f.close()
	return OK

## Número sem parte fracionária vira int (o JSON do Godot lê tudo como float).
static func _inteiros(v: Variant) -> Variant:
	if v is float and v == floorf(v) and absf(v) < 1e15:
		return int(v)
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _inteiros(v[k])
		return d
	if v is Array:
		return (v as Array).map(_inteiros)
	return v
