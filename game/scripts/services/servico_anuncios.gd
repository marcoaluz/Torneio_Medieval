class_name ServicoAnuncios
extends Node
## Anúncios premiados (autoload "Anuncios", Pacote 3.19; GDD: sempre
## opcionais, nunca forçados). Três usos: cortar 30 min de um timer, dobrar
## o ouro de uma vitória, baú de madeira extra — com limite diário em
## economia.json > anuncios. VIP recebe o benefício sem assistir.
## Fluxo: assistir(tipo, alvo) mostra o anúncio pelo provedor e, só se o
## jogador assistiu até o fim, pede a recompensa ao serviço Jogador (que, na
## Parte 3, vira a Edge Function que confere o token do provedor no servidor).
## Provedor: o plugin de anúncios (AdMob) quando instalado (singleton
## "AdMob"/"GodotAdMob", ver docs/ANDROID.md); sem ele, um provedor de TESTE
## que só funciona em build de depuração (devolve "assistido" na hora).

signal terminou(resultado: Dictionary)

## Callable(tipo) -> {assistiu: bool, token: String}; pode ser corrotina. Injetável nos testes.
var provedor: Callable
var _plugin: Object

func _ready() -> void:
	for nome in ["AdMob", "GodotAdMob"]:
		if Engine.has_singleton(nome):
			_plugin = Engine.get_singleton(nome)
	if not provedor.is_valid():
		provedor = _provedor_padrao

func disponivel() -> bool:
	return _plugin != null or OS.is_debug_build()

## Mostra (ou pula, para o VIP) e entrega. {ok, erro, tipo, recompensa, sem_anuncio}.
func assistir(tipo: String, alvo := "") -> Dictionary:
	var jog := get_node("/root/Jogador") as ServicoJogador
	var pode := jog.pode_recompensa_anuncio(tipo, alvo)
	if not pode["ok"]:
		terminou.emit(pode)
		return pode
	var sem_anuncio := jog.anuncio_sem_assistir()
	var token := "vip"
	if not sem_anuncio:
		if not disponivel():
			return _fim(ServicoJogador._erro("anuncio_indisponivel"))
		var visto: Dictionary = await provedor.call(tipo)
		if not visto.get("assistiu", false):
			return _fim(ServicoJogador._erro("anuncio_nao_assistido"))
		token = str(visto.get("token", ""))
	var r := jog.recompensa_anuncio(tipo, alvo, token)
	r["sem_anuncio"] = sem_anuncio
	return _fim(r)

func _fim(r: Dictionary) -> Dictionary:
	terminou.emit(r)
	return r

func _provedor_padrao(tipo: String) -> Dictionary:
	if _plugin != null and _plugin.has_method("show_rewarded"):
		# Plugin real: o resultado chega por sinal; o nome depende do plugin.
		_plugin.call("show_rewarded", tipo)
		if _plugin.has_signal("rewarded"):
			var a: Array = await Signal(_plugin, "rewarded")
			return {"assistiu": true, "token": str(a[0]) if a.size() > 0 else ""}
		return {"assistiu": false, "token": ""}
	# Provedor de teste (só em depuração): "assistido" na hora.
	await get_tree().process_frame
	return {"assistiu": OS.is_debug_build(), "token": "teste_%s_%d" % [tipo, ServicoTempo.agora()]}
