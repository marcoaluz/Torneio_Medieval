class_name ServicoNomes
extends RefCounted
## Validação de nomes do jogador (cavaleiro e casa): tamanho, caracteres
## permitidos e filtro de palavras ofensivas, com a lista em
## game/data/texto/nomes_proibidos.json. Na Parte 3 o servidor repete a mesma
## validação (o celular não é confiável). Códigos de erro viram textos de
## tradução ERRO_<CODIGO>.

const LISTA := "res://game/data/texto/nomes_proibidos.json"
const TROCAS := {"0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s"}

static var _dados: Dictionary

## "" se o nome serve; senão o código: nome_curto, nome_longo,
## nome_caracteres ou nome_ofensivo.
static func validar(nome: String) -> String:
	var d := _carregar()
	var limpo := limpar(nome)
	if limpo.length() < int(d.get("tamanho_min", 2)):
		return "nome_curto"
	if limpo.length() > int(d.get("tamanho_max", 20)):
		return "nome_longo"
	var permitido := RegEx.create_from_string(r"^[\p{L}' -]+$")
	if permitido.search(limpo) == null:
		return "nome_caracteres"
	var norm := normalizar(nome)
	for raiz: String in d.get("raizes", []):
		if norm.contains(raiz):
			return "nome_ofensivo"
	return ""

## Texto livre (chat): tem alguma raiz ofensiva da lista? Mesmo filtro dos nomes.
static func texto_ofensivo(texto: String) -> bool:
	var norm := normalizar(texto)
	for raiz: String in _carregar().get("raizes", []):
		if norm.contains(raiz):
			return true
	return false

## Tira espaços das pontas e espaços repetidos.
static func limpar(nome: String) -> String:
	var r := RegEx.create_from_string(r"\s+")
	return r.sub(nome.strip_edges(), " ", true)

## Minúsculas, sem acento, com números/símbolos trocados por letras e só letras.
static func normalizar(nome: String) -> String:
	var s := nome.to_lower()
	var acentos := {"á": "a", "à": "a", "â": "a", "ã": "a", "ä": "a", "é": "e", "ê": "e", "è": "e", "ë": "e",
		"í": "i", "î": "i", "ì": "i", "ï": "i", "ó": "o", "ô": "o", "õ": "o", "ò": "o", "ö": "o",
		"ú": "u", "û": "u", "ù": "u", "ü": "u", "ç": "c", "ñ": "n"}
	var saida := ""
	for ch in s:
		if acentos.has(ch):
			ch = acentos[ch]
		elif TROCAS.has(ch):
			ch = TROCAS[ch]
		if ch >= "a" and ch <= "z":
			saida += ch
	return saida

static func _carregar() -> Dictionary:
	if _dados.is_empty():
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(LISTA))
		_dados = v if v is Dictionary else {}
	return _dados
