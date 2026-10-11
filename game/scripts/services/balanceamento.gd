class_name Balanceamento
extends RefCounted
## Lê as tabelas de balanceamento de game/data/balance/<nome>.json.
## Hoje lê do pacote do jogo; na Parte 3 passa a vir do servidor (com versão).
## Falha alto: arquivo ausente, JSON inválido ou sem "versao" gera erro e
## devolve {} (quem chama não deve seguir com valores inventados).

const PASTA := "res://game/data/balance/"

static func carregar(nome: String) -> Dictionary:
	var caminho := PASTA + nome + ".json"
	var texto := FileAccess.get_file_as_string(caminho)
	if texto.is_empty():
		push_error("Balanceamento: não consegui ler %s (%s)" % [caminho, error_string(FileAccess.get_open_error())])
		return {}
	var dados: Variant = JSON.parse_string(texto)
	if not dados is Dictionary:
		push_error("Balanceamento: %s não é um objeto JSON válido" % caminho)
		return {}
	if not (dados as Dictionary).has("versao"):
		push_error("Balanceamento: %s sem campo \"versao\"" % caminho)
		return {}
	return dados
