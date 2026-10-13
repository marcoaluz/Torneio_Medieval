class_name RegraOrdem
extends RefCounted
## Ordens (guildas), ajuda, doações, torneio semanal, loja da ordem e código
## de amigo (GDD, Funções sociais), regra pura: o servidor (Edge Function,
## 3.8) faz a mesma conta e roda os mesmos casos de tests/shared/ordem.json.
## Sem nós, sem tempo real e sem sorteio global (o que sorteia recebe a
## semente e usa o xorshift de `Aleatorio`). Números em ordem.json.

const ALFABETO_CODIGO := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

# ------------------------------------------------------------- cargos

## O cargo pode fazer a ação? (permissões em ordem.json > permissoes.)
static func pode(cargo: String, acao: String, cfg: Dictionary) -> bool:
	return (cfg["permissoes"].get(cargo, []) as Array).has(acao)

## Ação sobre outro membro: o líder promove, rebaixa e expulsa; o oficial só
## expulsa membro comum; ninguém age sobre o líder (só ele passa a liderança).
static func pode_sobre(cargo_ator: String, cargo_alvo: String, acao: String, cfg: Dictionary) -> bool:
	if cargo_alvo == "lider":
		return false
	match acao:
		"promover":
			return cargo_alvo == "membro" and pode(cargo_ator, "promover", cfg)
		"rebaixar":
			return cargo_alvo == "oficial" and pode(cargo_ator, "rebaixar", cfg)
		"expulsar":
			return pode(cargo_ator, "expulsar_oficial" if cargo_alvo == "oficial" else "expulsar_membro", cfg)
	return false

## Cargo depois da ação (promover membro → oficial, rebaixar oficial → membro).
static func cargo_depois(cargo: String, acao: String) -> String:
	if acao == "promover" and cargo == "membro":
		return "oficial"
	if acao == "rebaixar" and cargo == "oficial":
		return "membro"
	return cargo

## Dá para entrar ou convidar mais gente? (limite de membros.)
static func tem_vaga(membros: int, cfg: Dictionary) -> bool:
	return membros < int(cfg["membros_max"])

# ------------------------------------------------------ ajuda e doação

## Quantos segundos uma ajuda tira de um timer que ainda tem `restante_s`
## (nunca passa do que falta).
static func segundos_da_ajuda(restante_s: int, cfg: Dictionary) -> int:
	return clampi(restante_s, 0, int(cfg["ajuda"]["segundos_por_ajuda"]))

## Ainda cabe ajuda neste pedido?
static func pedido_aceita_ajuda(ajudas_recebidas: int, cfg: Dictionary) -> bool:
	return ajudas_recebidas < int(cfg["ajuda"]["ajudas_max_por_pedido"])

## Moeda da ordem de uma ajuda, respeitando o teto do dia.
static func moeda_da_ajuda(moeda_hoje: int, cfg: Dictionary) -> int:
	return clampi(int(cfg["ajuda"]["moeda_max_dia"]) - moeda_hoje, 0, int(cfg["ajuda"]["moeda_por_ajuda"]))

## Unidades que ainda podem ser doadas hoje.
static func doacao_restante(unidades_hoje: int, cfg: Dictionary) -> int:
	return maxi(0, int(cfg["doacao"]["limite_dia_unidades"]) - unidades_hoje)

# ------------------------------------------------------ torneio semanal

## Posição da ordem (1 = primeira): 1 + quantas outras têm MAIS vitórias
## (empate fica à frente: a ordem do jogador vence o desempate).
static func posicao_no_torneio(minhas: int, outras: Array) -> int:
	var p := 1
	for o in outras:
		if int(o) > minhas:
			p += 1
	return p

## Prêmio da posição: o primeiro da lista com posicao <= ate_posicao.
static func premio_do_torneio(posicao: int, cfg: Dictionary) -> Dictionary:
	for p: Dictionary in cfg["torneio"]["premios"]:
		if posicao <= int(p["ate_posicao"]):
			return {"moeda": int(p.get("moeda", 0)), "bau": str(p.get("bau", ""))}
	return {"moeda": 0, "bau": ""}

## Vitórias de PvP que um membro simulado acumula até agora na semana: o
## total da semana (sorteado pela semente) vezes a fração já passada,
## arredondado para cima (quem já entrou na semana tem pelo menos 1).
## fracao_milesimos: 0..1000 do tempo da semana.
static func vitorias_simuladas(semente: int, semana: int, indice: int, fracao_milesimos: int, cfg: Dictionary) -> int:
	var f: Array = cfg["torneio"]["vitorias_por_membro_semana"]
	var rng := Aleatorio.new(semente + 4099 * (semana + 1) + 131 * (indice + 1))
	var total := rng.inteiro(int(f[0]), int(f[1]))
	return (total * clampi(fracao_milesimos, 0, 1000) + 999) / 1000

# ------------------------------------------------------------- loja

## "" se dá para comprar; senão o código do erro.
static func erro_da_compra(moeda: int, comprados_na_semana: int, item: Dictionary) -> String:
	if comprados_na_semana >= int(item["limite_semana"]):
		return "limite_semana"
	if moeda < int(item["moeda"]):
		return "moeda_insuficiente"
	return ""

# --------------------------------------------------- código de amigo

## Código público de um jogador ("TM-" + 6 caracteres sem 0/O/1/I) pela
## semente dele. Determinístico: o mesmo save sempre tem o mesmo código.
static func codigo_amigo(semente: int) -> String:
	var rng := Aleatorio.new(semente ^ 0x2545F491)
	rng.proximo()
	var s := "TM-"
	for i in 6:
		s += ALFABETO_CODIGO[rng.proximo() % ALFABETO_CODIGO.length()]
	return s

## Maiúsculas, sem espaços; aceita sem o "TM-" e sem hífen.
static func normalizar_codigo(texto: String) -> String:
	var t := texto.strip_edges().to_upper().replace(" ", "")
	if t.begins_with("TM-"):
		t = t.substr(3)
	elif t.begins_with("TM"):
		t = t.substr(2)
	return "TM-" + t

static func codigo_valido(texto: String) -> bool:
	var c := normalizar_codigo(texto)
	if c.length() != 9:
		return false
	for i in range(3, 9):
		if ALFABETO_CODIGO.find(c[i]) < 0:
			return false
	return true

# -------------------------------------------------- ordens simuladas

## `quantas` ordens para o jogador escolher (até o servidor). nomes: lista de
## nomes; cores/simbolos/divisoes: opções do gerador de brasão. Cada uma:
## {id ("s0".."sN"), nome, membros, poder, brasao}. Os nomes não repetem.
static func ordens_simuladas(semente: int, cfg: Dictionary, nomes: Array, cores: Array, simbolos: Array, divisoes: Array) -> Array:
	var rng := Aleatorio.new(semente + 99991)
	var s: Dictionary = cfg["simuladas"]
	var disponiveis := nomes.duplicate()
	var r: Array = []
	for i in mini(int(s["quantas"]), disponiveis.size()):
		var nome: String = disponiveis.pop_at(rng.inteiro(0, disponiveis.size() - 1))
		var c1: String = cores[rng.inteiro(0, cores.size() - 1)]
		var c2: String = cores[rng.inteiro(0, cores.size() - 1)]
		var membros := rng.inteiro(int(s["membros"][0]), int(s["membros"][1]))
		r.append({"id": "s%d" % i, "nome": nome, "membros": membros, "poder": rng.inteiro(int(s["poder"][0]), int(s["poder"][1])),
			"brasao": {"cor1": c1, "cor2": c2, "cor_simbolo": c2, "simbolo": simbolos[rng.inteiro(0, simbolos.size() - 1)],
				"divisao": divisoes[rng.inteiro(0, divisoes.size() - 1)]}})
	return r
