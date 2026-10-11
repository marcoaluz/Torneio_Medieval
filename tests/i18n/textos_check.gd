extends SceneTree
## Textos do jogo (game/i18n/textos.csv): toda linha com 3 colunas (chave,
## pt_BR, en), chaves únicas, os dois idiomas preenchidos e toda chave
## literal usada em tr("...") nos scripts existindo no arquivo.

const CSV := "res://game/i18n/textos.csv"

var _falhas := 0

func _initialize() -> void:
	var f := FileAccess.open(CSV, FileAccess.READ)
	var chaves := {}
	var ruins: Array[String] = []
	var cabecalho := f.get_csv_line()
	_checa("cabecalho keys,pt_BR,en", cabecalho == PackedStringArray(["keys", "pt_BR", "en"]))
	while not f.eof_reached():
		var l := f.get_csv_line()
		if l.size() == 1 and l[0] == "":
			continue
		if l.size() != 3:
			ruins.append("%s (%d colunas)" % [l[0], l.size()])
			continue
		if chaves.has(l[0]):
			ruins.append("%s repetida" % l[0])
		if l[1].strip_edges() == "" or l[2].strip_edges() == "":
			ruins.append("%s sem texto" % l[0])
		chaves[l[0]] = true
	_checa("linhas bem formadas %s" % [ruins], ruins.is_empty())

	var faltando: Array[String] = []
	var r := RegEx.create_from_string(r"tr\(\"([A-Z0-9_]+)\"\)")
	for arq in _scripts("res://game/scripts"):
		var texto := FileAccess.get_file_as_string(arq)
		for m in r.search_all(texto):
			var chave := m.get_string(1)
			if not chaves.has(chave) and not faltando.has(chave):
				faltando.append(chave)
	_checa("chaves usadas no codigo existem %s" % [faltando], faltando.is_empty())
	print("TEXTOS %s" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(0 if _falhas == 0 else 1)

func _scripts(pasta: String) -> Array[String]:
	var saida: Array[String] = []
	var d := DirAccess.open(pasta)
	for nome in d.get_files():
		if nome.ends_with(".gd"):
			saida.append(pasta.path_join(nome))
	for sub in d.get_directories():
		saida.append_array(_scripts(pasta.path_join(sub)))
	return saida

func _checa(nome: String, ok: bool) -> void:
	print("TEXTOS %s %s" % [nome, "OK" if ok else "FALHOU"])
	if not ok:
		_falhas += 1
