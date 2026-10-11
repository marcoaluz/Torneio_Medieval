class_name Balanceamento
extends RefCounted
## Lê as tabelas de balanceamento de game/data/balance/<nome>.json.
## Hoje lê do pacote do jogo; na Parte 3 passa a vir do servidor (com versão).
## Falha alto: arquivo ausente, JSON inválido ou sem "versao" gera erro e
## devolve {} (quem chama não deve seguir com valores inventados).
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
