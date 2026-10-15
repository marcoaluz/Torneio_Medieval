extends SceneTree
## Junta os estágios de cada prédio gerados pelo PixelLab
## (game/art/fontes/vila/<nome>_<n>.png, pasta com .gdignore) numa folha
## horizontal game/art/sprites/vila/<nome>.png, um quadro por estágio, como o
## PredioVila espera (hframes = estagios). Quadros de tamanhos diferentes são
## centralizados na base (o chão fica na mesma linha). Prédio com estágio
## faltando é pulado (a vila segue com o desenho provisório).
##   bash .claude/skills/run-torneio-medieval/driver.sh script res://tools/montar_folhas_vila.gd

func _initialize() -> void:
	var vila: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/balance/vila.json"))
	var fontes := ProjectSettings.globalize_path("res://game/art/fontes/vila/")
	DirAccess.make_dir_recursive_absolute("res://game/art/sprites/vila/")
	var feitas := 0
	for nome: String in vila["predios"]:
		var n := int(vila["predios"][nome]["estagios"])
		var quadros: Array[Image] = []
		for e in n:
			var arq := fontes + "%s_%d.png" % [nome, e + 1]
			if not FileAccess.file_exists(arq):
				break
			var img := Image.load_from_file(arq)
			if img == null:
				break
			img.convert(Image.FORMAT_RGBA8)
			quadros.append(img)
		if quadros.size() != n:
			print("FOLHA %s pulada (%d de %d estágios)" % [nome, quadros.size(), n])
			continue
		var w := 0
		var h := 0
		for q in quadros:
			w = maxi(w, q.get_width())
			h = maxi(h, q.get_height())
		var folha := Image.create_empty(w * n, h, false, Image.FORMAT_RGBA8)
		for i in n:
			var q := quadros[i]
			folha.blit_rect(q, Rect2i(Vector2i.ZERO, q.get_size()), Vector2i(i * w + (w - q.get_width()) / 2, h - q.get_height()))
		folha.save_png("res://game/art/sprites/vila/%s.png" % nome)
		feitas += 1
		print("FOLHA %s ok (%d estágios de %dx%d)" % [nome, n, w, h])
	print("FOLHAS %d montadas" % feitas)
	quit(0)
