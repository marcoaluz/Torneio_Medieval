extends SceneTree
## Verificacao headless das configuracoes do projeto. Sai com codigo 1 se algo divergir.

func _init() -> void:
	var ok := true
	ok = _expect("viewport_width", ProjectSettings.get_setting("display/window/size/viewport_width"), 960) and ok
	ok = _expect("viewport_height", ProjectSettings.get_setting("display/window/size/viewport_height"), 540) and ok
	ok = _expect("stretch_mode", ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items") and ok
	ok = _expect("renderer", ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility") and ok
	ok = _expect("texture_filter", ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0) and ok
	TranslationServer.set_locale("pt_BR")
	ok = _expect("tr_pt_BR", TranslationServer.translate("JOGO_TITULO"), "Torneio Medieval") and ok
	TranslationServer.set_locale("en")
	ok = _expect("tr_en", TranslationServer.translate("JOGO_TITULO"), "Medieval Tournament") and ok
	print("HEADLESS_CHECK ", "OK" if ok else "FALHOU")
	quit(0 if ok else 1)

func _expect(nome: String, atual, esperado) -> bool:
	if atual != esperado:
		printerr("DIVERGE %s: atual=%s esperado=%s" % [nome, atual, esperado])
		return false
	return true
