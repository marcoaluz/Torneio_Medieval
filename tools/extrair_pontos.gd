extends SceneTree
## Lê as folhas de pontos (game/art/sprites/personagem/<tamanho>/pontos_<anim>.png)
## e grava game/data/personagem/pontos.json: para cada tamanho e animação, a
## posição por quadro de cada ponto de encaixe, a partir da origem do quadro.
## Cor do pixel -> ponto: vermelho puro = brasao, verde puro = ponta_lanca.
## O artista pinta esses pixels numa camada a mais no PixelLab/Aseprite e
## exporta como folha igual às outras. Rode depois de importar arte nova:
##   bash .claude/skills/run-torneio-medieval/driver.sh script res://tools/extrair_pontos.gd

const CAMADAS := "res://game/data/personagem/camadas.json"
const SAIDA := "res://game/data/personagem/pontos.json"
const CORES := {"brasao": Color(1, 0, 0), "ponta_lanca": Color(0, 1, 0)}

func _initialize() -> void:
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CAMADAS))
	var saida := {"versao": 1, "_nota": "Gerado por tools/extrair_pontos.gd a partir das folhas pontos_<anim>.png. Nao edite a mao."}
	var total := 0
	for tamanho: String in dados["tamanhos"]:
		var tam: Dictionary = dados["tamanhos"][tamanho]
		var w := int(tam["quadro"][0])
		var origem := Vector2i(int(tam["origem"][0]), int(tam["origem"][1]))
		for anim: String in tam["animacoes"]:
			var caminho := "%s/%s/pontos_%s.png" % [dados["pasta"], tamanho, anim]
			if not FileAccess.file_exists(caminho):
				continue
			var img := Image.load_from_file(ProjectSettings.globalize_path(caminho))
			var n := int(tam["animacoes"][anim]["quadros"])
			var por_ponto := {}
			for nome: String in CORES:
				por_ponto[nome] = []
			for i in n:
				for nome: String in CORES:
					var p := _achar(img, Rect2i(i * w, 0, w, img.get_height()), CORES[nome])
					if p.x >= 0:
						por_ponto[nome].append([p.x - i * w - origem.x, p.y - origem.y])
			for nome: String in por_ponto.keys():
				if por_ponto[nome].size() == n:
					if not saida.has(tamanho):
						saida[tamanho] = {}
					if not saida[tamanho].has(anim):
						saida[tamanho][anim] = {}
					saida[tamanho][anim][nome] = por_ponto[nome]
					total += 1
				elif not por_ponto[nome].is_empty():
					push_error("PONTOS %s/%s: %s aparece em %d de %d quadros" % [tamanho, anim, nome, por_ponto[nome].size(), n])
	var f := FileAccess.open(SAIDA, FileAccess.WRITE)
	f.store_string(JSON.stringify(saida, "\t", false) + "\n")
	f.close()
	print("PONTOS %d conjuntos gravados em %s" % [total, SAIDA])
	quit(0)

func _achar(img: Image, area: Rect2i, cor: Color) -> Vector2i:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var c := img.get_pixel(x, y)
			if c.a > 0.99 and c.is_equal_approx(cor):
				return Vector2i(x, y)
	return Vector2i(-1, -1)
