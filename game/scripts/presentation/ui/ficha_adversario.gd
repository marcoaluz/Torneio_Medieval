class_name FichaAdversario
extends PanelContainer
## Ficha do adversário, antes de toda justa do PvE e do PvP: os dois lados
## lado a lado (retrato, nome, alcunha, brasão, habilidade, poder) e, do
## rival, o traço de luta com o ponto fraco. O poder do rival vem colorido
## pela faixa (RegraPve.faixa_poder: verde favorável, amarelo parelha,
## vermelho difícil; números em pve.json > ficha). Botões: Voltar,
## Equipamentos (troca antes de lutar; a ficha se refaz ao voltar) e Lutar.
## Só lê do serviço Jogador; quem abre decide o que Lutar faz.

signal lutar
signal voltar
signal abrir_equipamentos

const COR_DESTAQUE := Color(1, 0.88, 0.55)
const COR_FRACA := Color(0.75, 0.7, 0.62)
const COR_TEXTO := Color(0.95, 0.9, 0.8)

## Rival mostrado (como rival_para_justa / preparar_pvp / preparar_revanche).
var rival: Dictionary = {}
## Função que refaz o rival depois de trocar o equipamento ({} = mantém).
var _refazer: Callable
var _jog: ServicoJogador
var _corpo: HBoxContainer
var _titulo: Label
var _lutar: Button
var _voltar: Button
var _equip: Button

func _ready() -> void:
	_jog = get_node("/root/Jogador")
	visible = false
	theme = load("res://game/scenes/ui/tema_jogo.tres")
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	_titulo = Label.new()
	_titulo.theme_type_variation = &"Titulo"
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_titulo)
	_corpo = HBoxContainer.new()
	_corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_corpo.add_theme_constant_override("separation", 14)
	col.add_child(_corpo)
	var botoes := HBoxContainer.new()
	botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	botoes.add_theme_constant_override("separation", 12)
	col.add_child(botoes)
	_voltar = _botao(botoes, "Voltar")
	_equip = _botao(botoes, "Equipamentos")
	_lutar = _botao(botoes, "Lutar")
	_voltar.pressed.connect(func(): fechar(); voltar.emit())
	_equip.pressed.connect(func(): abrir_equipamentos.emit())
	_lutar.pressed.connect(func(): fechar(); lutar.emit())
	_jog.mudou.connect(func(_s): if visible: atualizar())

func _botao(pai: Control, nome: String) -> Button:
	var b := Button.new()
	b.name = nome
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(200, 64)
	pai.add_child(b)
	return b

## Abre a ficha do `rv`. `refazer` (opcional) devolve o rival de novo depois
## de trocar o equipamento (o poder do rival não muda; o do jogador, sim).
func abrir(rv: Dictionary, refazer := Callable()) -> void:
	rival = rv
	_refazer = refazer
	visible = true
	atualizar()

func fechar() -> void:
	visible = false

## Refaz tudo (depois de voltar dos Equipamentos, de mudar o idioma...).
func atualizar() -> void:
	if _refazer.is_valid():
		var novo: Dictionary = _refazer.call()
		if not novo.is_empty():
			rival = novo
	_titulo.text = tr("FICHA_TITULO")
	_voltar.text = tr("FICHA_VOLTAR")
	_equip.text = tr("FICHA_EQUIPAMENTOS")
	_lutar.text = tr("FICHA_LUTAR")
	for c in _corpo.get_children():
		_corpo.remove_child(c)
		c.queue_free()
	var pj := _jog.poder_jogador()
	var pr := int(rival.get("poder", 0))
	var cfg: Dictionary = _jog.pve()["ficha"]
	var faixa := RegraPve.faixa_poder(pj, pr, cfg)
	var cor := Color(str(cfg["cores"][faixa]))
	_corpo.add_child(_lado_jogador(pj))
	_corpo.add_child(_meio(faixa, cor))
	_corpo.add_child(_lado_rival(pr, cor))

## Faixa da ficha para estes poderes (verde, amarelo, vermelho).
func faixa() -> String:
	return RegraPve.faixa_poder(_jog.poder_jogador(), int(rival.get("poder", 0)), _jog.pve()["ficha"])

func _lado_jogador(poder: int) -> VBoxContainer:
	var v := _coluna()
	v.name = "Jogador"
	var ret := RetratoCabeca.new()
	ret.custom_minimum_size = Vector2(128, 128)
	var moldura := CenterContainer.new()
	moldura.add_child(ret)
	v.add_child(moldura)
	ret.vestir.call_deferred(_jog)  # as camadas só se montam dentro da árvore
	var cav := _jog.cavaleiro()
	v.add_child(_rotulo(str(cav.get("nome", "")) if str(cav.get("nome", "")) != "" else tr("FICHA_VOCE"), COR_DESTAQUE, true))
	v.add_child(_rotulo(str(_jog.casa().get("nome", "")), COR_FRACA))
	var brasao := TextureRect.new()
	brasao.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	brasao.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brasao.custom_minimum_size = Vector2(36, 46)
	brasao.texture = GeradorBrasao.textura(AparenciaJogador.brasao(_jog), Vector2i(36, 46))
	v.add_child(brasao)
	var p := _rotulo(tr("FICHA_PODER").format({"n": poder}), COR_DESTAQUE, true)
	p.name = "Poder"
	v.add_child(p)
	var nomes: Array[String] = []
	for h: String in _jog.habilidades_em_uso():
		nomes.append(tr("HABILIDADE_" + h.to_upper()))
	v.add_child(_rotulo(tr("FICHA_SUAS_HABILIDADES").format({"lista": ", ".join(nomes) if not nomes.is_empty() else "—"}), COR_TEXTO))
	return v

func _meio(faixa_id: String, cor: Color) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.custom_minimum_size = Vector2(130, 0)
	var contra := _rotulo(tr("DUELO_CONTRA"), COR_FRACA)
	contra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(contra)
	var f := _rotulo(tr("FICHA_FAIXA_" + faixa_id.to_upper()), cor, true)
	f.name = "Faixa"
	f.autowrap_mode = TextServer.AUTOWRAP_OFF  # uma palavra: sem quebrar no meio
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(f)
	return v

func _lado_rival(poder: int, cor: Color) -> VBoxContainer:
	var v := _coluna()
	v.name = "Rival"
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 10)
	v.add_child(topo)
	var ret := RetratoRival.new()
	ret.name = "Retrato"
	ret.custom_minimum_size = Vector2(112, 112)
	var nome := tr(str(rival.get("nome_chave", "")))
	ret.mostrar(str(rival.get("retrato", rival.get("id", ""))), "neutro", rival.get("casa", {}), rival.get("brasao", {}), nome)
	topo.add_child(ret)
	var id := VBoxContainer.new()
	id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(id)
	id.add_child(_rotulo(nome, COR_DESTAQUE, true))
	if str(rival.get("alcunha", "")) != "":
		id.add_child(_rotulo(tr(rival["alcunha"]), COR_FRACA))
	var p := _rotulo(tr("FICHA_PODER").format({"n": poder}), cor, true)
	p.name = "Poder"
	id.add_child(p)
	v.add_child(_rotulo(_texto_habilidade(), COR_TEXTO))
	var traco := str(rival.get("traco", ""))
	if traco != "":
		var t := _rotulo(tr("FICHA_TRACO").format({"nome": tr("TRACO_" + traco.to_upper())}) + " — " + tr("TRACO_%s_DESC" % traco.to_upper()), COR_DESTAQUE)
		t.name = "Traco"
		v.add_child(t)
		v.add_child(_rotulo(tr("FICHA_FRAQUEZA").format({"texto": tr("TRACO_%s_FRAQUEZA" % traco.to_upper())}), Color(0.6, 0.85, 0.6)))
	elif not rival.get("pvp", false):
		v.add_child(_rotulo(tr("FICHA_SEM_TRACO"), COR_FRACA))
	if rival.get("nemesis", false):
		v.add_child(_rotulo(tr("FICHA_ENCONTROS").format({"n": int(rival.get("encontros", 0)), "bonus": int(rival.get("bonus_encontro", 0))}), COR_FRACA))
	if rival.get("revanche", false):
		v.add_child(_rotulo(tr("FICHA_REVANCHE").format({"bonus": int(rival.get("bonus_revanche", 0)),
			"pct": int(_jog.pve()["revanche"]["recompensa_pct"])}), COR_DESTAQUE))
	return v

## "Habilidade: X (anulada por Y)" pela família da habilidade do rival.
func _texto_habilidade() -> String:
	var lado: Dictionary = rival.get("lado", {})
	var lista: Array = lado.get("habilidades", []) if lado.get("habilidades") is Array else []
	if lista.is_empty() and str(lado.get("habilidade", "")) != "":
		lista = [lado["habilidade"]]
	if lista.is_empty():
		return tr("FICHA_SEM_HABILIDADE")
	var defs: Dictionary = Balanceamento.ler("impacto")["habilidades"]
	var partes: Array[String] = []
	for h: String in lista:
		var txt := tr("HABILIDADE_" + h.to_upper())
		var contra := que_anula(h, defs)
		if contra != "":
			txt += " " + tr("FICHA_ANULADA_POR").format({"nome": tr("HABILIDADE_" + contra.to_upper())})
		partes.append(txt)
	return tr("FICHA_HABILIDADE").format({"nome": ", ".join(partes)})

## Habilidade de base que anula a família de `h` ("" se nenhuma).
static func que_anula(h: String, defs: Dictionary) -> String:
	var fam := str(defs.get(h, {}).get("familia", ""))
	for b in ["investida", "golpe_pesado", "bloqueio"]:
		if fam != "" and str(defs.get(b, {}).get("vence", "")) == fam:
			return b
	return ""

func _coluna() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.custom_minimum_size = Vector2(180, 0)
	return v

func _rotulo(texto: String, cor: Color, titulo := false) -> Label:
	var l := Label.new()
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", cor)
	if titulo:
		l.theme_type_variation = &"Titulo"
	return l

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and visible and _titulo != null:
		atualizar()
