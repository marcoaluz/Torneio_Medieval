class_name SomJusta
extends Node
## Som da justa (nó Arena/Som). Só escuta os sinais do ControladorJusta e
## pede ao autoload Audio: a regra continua sem saber de som (skill som).
##   Apresentação: música da justa, torcida ao fundo, arauto abre a justa
##   Largada: trompete; bandeira baixando
##   Corrida: galope em loop; cada toque soa no tempo ou fora
##   Impacto: som pela zona atingida, lança estilhaçando, queda, torcida e arauto
##   Habilidade: som da família; fim: vitória ou derrota

const ZONAS := {"escudo": "impacto_escudo", "capacete": "impacto_capacete", "peito": "impacto_peito", "cavalo": "impacto_cavalo"}
const ARAUTO := {"escudo": "no_escudo", "capacete": "acerto_elmo", "peito": "acerto_peito", "cavalo": "falta_cavalo"}

@export var controlador: ControladorJusta

## A arena é a cena principal: o que a cena anterior tocava para.
func _enter_tree() -> void:
	var a := _audio()
	if a:
		a.trocar_cena("arena")

func _ready() -> void:
	if controlador == null:
		return
	controlador.apresentacao_comecou.connect(_ao_apresentar)
	controlador.largada_comecou.connect(func(_p): _tocar("largada_trompete"))
	controlador.bandeira_baixou.connect(func(_p): _tocar("bandeira"))
	controlador.corrida_comecou.connect(func(_p): _laco("galope", true))
	controlador.impacto_comecou.connect(func(_p): _laco("galope", false))
	controlador.toque_galope.connect(_ao_tocar)
	controlador.impacto_resolvido.connect(_ao_impacto)
	controlador.habilidade_ativada.connect(_ao_ativar)
	controlador.passada_terminou.connect(func(_p, _a, _b, d): if d == JustaFases.Lado.NENHUM: _tocar("cavalo_bufando"))
	controlador.justa_terminou.connect(_ao_terminar)
	tree_exiting.connect(func():
		_laco("galope", false)
		_laco("torcida_fundo", false))

func _audio() -> ServicoAudio:
	return get_node_or_null("/root/Audio") as ServicoAudio

func _tocar(id: String, volume_db := 0.0) -> void:
	var a := _audio()
	if a:
		a.tocar(id, volume_db)

func _laco(id: String, ligado: bool) -> void:
	var a := _audio()
	if a:
		a.laco(id, ligado)

func _voz(id: String) -> void:
	var a := _audio()
	if a:
		a.voz(id)

func _ao_apresentar(passada: int) -> void:
	var a := _audio()
	if a == null:
		return
	a.laco("torcida_fundo", true)
	if passada == 1:
		a.musica("tema_justa")
		a.voz("senhoras_e_senhores")
	elif passada > int(controlador.justa.fases._passadas):
		a.voz("passada_decisiva")

func _ao_tocar(resultado: String, _desvio: int, _vel: int, _folego: int) -> void:
	if resultado == "no_tempo":
		_tocar("toque_no_tempo")
	elif resultado in ["fora_do_tempo", "rapido_demais"]:
		_tocar("toque_fora")

## jog = golpe do jogador no rival; riv = golpe do rival no jogador.
func _ao_impacto(_p: int, jog: Dictionary, riv: Dictionary, _d: JustaFases.Lado, _q: JustaFases.Lado) -> void:
	var houve := false
	for res: Dictionary in [jog, riv]:
		var zona := str(res.get("zona_final", Mira.ERRO))
		if ZONAS.has(zona):
			_tocar(ZONAS[zona])
			houve = true
		if res.get("derrubou", false):
			_tocar("derrubada")
	if houve:
		_tocar("lanca_estilhaca", -4.0)
	# Torcida e arauto acompanham o golpe do jogador; a falta de qualquer um é anunciada.
	if jog.get("derrubou", false):
		_tocar("torcida_explode")
		_voz("derrubado")
	elif int(jog.get("pontos", 0)) > 0:
		_tocar("torcida_explode", -3.0)
		_voz(ARAUTO.get(str(jog["zona_final"]), ""))
	elif riv.get("derrubou", false) or int(riv.get("pontos", 0)) > 0:
		_tocar("torcida_decepcionada")
		if riv.get("derrubou", false):
			_voz("derrubado")
	if str(jog.get("zona_final", "")) == "cavalo" or str(riv.get("zona_final", "")) == "cavalo":
		_voz("falta_cavalo")

func _ao_ativar(_p: int, _lado: String, nome: String) -> void:
	var h: Dictionary = Balanceamento.ler("impacto")["habilidades"].get(nome, {})
	if h.has("familia"):
		_tocar("habilidade_" + str(h["familia"]))

func _ao_terminar(vencedor: JustaFases.Lado, _m: String, _a: int, _b: int) -> void:
	_laco("galope", false)
	var a := _audio()
	if a == null:
		return
	a.musica("", 0.4)
	if vencedor == JustaFases.Lado.JOGADOR:
		a.tocar("vitoria")
		a.voz("vitoria")
	elif vencedor == JustaFases.Lado.RIVAL:
		a.tocar("derrota")
