extends SceneTree
## Grava os cenários de paridade do servidor (3.2): roda cada comando do
## ServicoJogador (GDScript, a referência) passo a passo e guarda o resultado
## e o que mudou no estado, para a versão TypeScript (supabase/functions/
## _shared/servidor/) reproduzir. Entrada: tests/shared/cenarios_servico_entrada.json
## (cenários escritos à mão); saída: tests/shared/cenarios_servico.json.
##   bash .claude/skills/run-torneio-medieval/driver.sh script res://tools/gravar_cenarios.gd
## Passo: {"t": segundos desde criado_em, "cmd": nome, "args": [...]} ou
## {"t", "set": {"caminho.com.pontos": valor}} (ajuste direto do estado, para montar
## situações: ouro, nível, projetos...; índice de lista como número no caminho).
## Argumentos "@timer:N", "@bau:N", "@item:N", "@cavalo:N", "@missao:diarias:N" viram
## o id do N-ésimo (para não depender dos ids gerados). O relógio é fixo por passo
## (ServicoTempo.deslocamento), então tudo é determinístico.

const ENTRADA := "res://tests/shared/cenarios_servico_entrada.json"
const SAIDA := "res://tests/shared/cenarios_servico.json"
const CRIADO_EM := 1790000000

func _initialize() -> void:
	await process_frame
	var entrada: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ENTRADA))
	var saida := {"versao": 1,
		"descricao": "Cenários do ServicoJogador gravados pelo GDScript (tools/gravar_cenarios.gd). Passo: {t, cmd|set, args, resultado, dif}. dif = [{c: caminho, v: valor novo | r: true se removido}] entre o estado antes e depois, chaves em ordem alfabética, arrays do mesmo tamanho comparados por posição. A versão TypeScript parte do estado_inicial e tem que reproduzir resultado e dif de cada passo.",
		"cenarios": []}
	DirAccess.make_dir_recursive_absolute("user://cenarios/")
	for c: Dictionary in entrada["cenarios"]:
		saida["cenarios"].append(_rodar(c))
	var f := FileAccess.open(SAIDA, FileAccess.WRITE)
	f.store_string(JSON.stringify(saida) + "\n")
	f.close()
	print("CENARIOS gravados: %d em %s" % [saida["cenarios"].size(), SAIDA])
	quit(0)

func _rodar(c: Dictionary) -> Dictionary:
	ServicoTempo.fixo = CRIADO_EM
	var jog := ServicoJogador.new()
	jog.caminho_save = "user://cenarios/jogador.json"
	jog.estado = jog.novo_estado()
	var estado_inicial: Variant = _normal(jog.estado)
	var passos: Array = []
	var anterior: Variant = _normal(jog.estado)
	for p: Dictionary in c["passos"]:
		ServicoTempo.fixo = CRIADO_EM + int(p["t"])
		var res: Variant = {}
		if p.has("set"):
			for caminho: String in p["set"]:
				_definir(jog.estado, caminho.split("."), ServicoJogador._inteiros(p["set"][caminho]))
		else:
			var args: Array = _resolver(ServicoJogador._inteiros(p.get("args", [])), jog.estado)
			res = _normal(jog.callv(p["cmd"], args))
		var depois: Variant = _normal(jog.estado)
		var dif: Array = []
		_dif(anterior, depois, [], dif)
		anterior = depois
		var passo := p.duplicate(true)
		passo["resultado"] = res
		passo["dif"] = dif
		passos.append(passo)
	ServicoTempo.fixo = -1
	return {"nome": c["nome"], "criado_em": CRIADO_EM, "estado_inicial": estado_inicial, "passos": passos}

## Normaliza (JSON ida e volta, inteiros como int) para comparar e gravar.
func _normal(v: Variant) -> Variant:
	return ServicoJogador._inteiros(JSON.parse_string(JSON.stringify(v)))

func _definir(d: Variant, caminho: PackedStringArray, valor: Variant) -> void:
	for i in caminho.size() - 1:
		var k: Variant = int(caminho[i]) if d is Array else caminho[i]
		if d is Dictionary and not d.has(k):
			d[k] = {}
		d = d[k]
	var ultimo: Variant = int(caminho[caminho.size() - 1]) if d is Array else caminho[caminho.size() - 1]
	d[ultimo] = valor

## Troca "@tipo:N" pelo id do N-ésimo (recursivo nos argumentos).
func _resolver(v: Variant, estado: Dictionary) -> Variant:
	if v is String and (v as String).begins_with("@"):
		var p := (v as String).substr(1).split(":")
		match p[0]:
			"timer": return estado["timers"][int(p[1])]["id"]
			"bau": return estado["baus"]["espacos"][int(p[1])]["id"]
			"item": return estado["inventario"]["itens"][int(p[1])]["id"]
			"cavalo": return estado["cavalos"][int(p[1])]["id"]
			"missao": return estado["metas"][p[1]][int(p[2])]["id"]
		return v
	if v is Array:
		return (v as Array).map(func(x): return _resolver(x, estado))
	if v is Dictionary:
		var r := {}
		for k in v:
			r[k] = _resolver(v[k], estado)
		return r
	return v

## Diferenças entre dois valores normalizados (mesmo algoritmo do TypeScript).
func _dif(a: Variant, b: Variant, caminho: Array, saida: Array) -> void:
	if a is Dictionary and b is Dictionary:
		var chaves: Array = (a as Dictionary).keys()
		for k in (b as Dictionary).keys():
			if not chaves.has(k):
				chaves.append(k)
		chaves.sort()
		for k in chaves:
			var c := caminho + [k]
			if not (b as Dictionary).has(k):
				saida.append({"c": c, "r": true})
			elif not (a as Dictionary).has(k):
				saida.append({"c": c, "v": b[k]})
			else:
				_dif(a[k], b[k], c, saida)
	elif a is Array and b is Array and (a as Array).size() == (b as Array).size():
		for i in (a as Array).size():
			_dif(a[i], b[i], caminho + [i], saida)
	elif JSON.stringify(a) != JSON.stringify(b):
		saida.append({"c": caminho, "v": b})
