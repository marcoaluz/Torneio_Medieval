# Oráculo independente da regra do impacto (game/scripts/rules/impacto.gd e
# supabase/functions/_shared/regra/impacto.ts), escrito a partir da
# especificação no topo de impacto.gd, para gerar o "esperado" dos casos
# compartilhados em tests/shared/impacto.json sem copiar a saída das próprias
# implementações. `python -I tools/oraculo_impacto.py conferir` refaz todos os
# casos do arquivo e aponta divergências; `gerar` embute a config atual de
# game/data/balance/impacto.json, dá a cada lado dos casos antigos a largada de
# LARGADA_DOS_CASOS (padrão "boa"), acrescenta CASOS_NOVOS e refaz o esperado
# de todos.
import copy
import json
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARQ = os.path.join(RAIZ, "tests", "shared", "impacto.json")
ERRO = "erro"
M32 = 0xFFFFFFFF


def div(a, b):
    """Divisão inteira truncada para zero (como GDScript e Math.trunc)."""
    q = abs(a) // abs(b)
    return q if (a >= 0) == (b > 0) else -q


class Rng:
    def __init__(self, semente):
        self.e = semente & M32 or 0x9E3779B9

    def proximo(self):
        x = self.e
        x = (x ^ (x << 13)) & M32
        x = x ^ (x >> 17)
        x = (x ^ (x << 5)) & M32
        self.e = x
        return x

    def chance(self, c):
        return self.proximo() % 1000 < c


def suave(v, teto, joelho_pct):
    if v <= 0 or teto <= 0:
        return 0
    joelho = div(teto * joelho_pct, 100)
    if v <= joelho:
        return v
    exc, resto = v - joelho, teto - joelho
    if resto <= 0:
        return teto
    return joelho + div(exc * resto, exc + resto)


def da_largada(cfg, largada):
    pl = cfg["derrubada"]["por_largada"]
    return pl[largada] if isinstance(largada, str) and largada in pl else pl["ruim"]


def stat(eq, peca, k):
    if not isinstance(eq, dict) or peca not in eq:
        return 0
    p = eq[peca]
    if int(p.get("durabilidade", 0)) <= 0:
        return 0
    return int(p.get(k, 0))


def familia(cfg, n):
    return str(cfg["habilidades"][n].get("familia", n))


def ativas(cfg, lado):
    lista = lado["habilidades"] if isinstance(lado.get("habilidades"), list) else ([lado["habilidade"]] if isinstance(lado.get("habilidade"), dict) else [])
    return [str(h["nome"]) for h in lista if isinstance(h, dict) and h.get("ativa", False) and str(h.get("nome", "")) in cfg["habilidades"]]


def em_efeito(cfg, lado, outro):
    dele = ativas(cfg, outro)
    return [h for h in ativas(cfg, lado) if not any(cfg["habilidades"][o]["vence"] == familia(cfg, h) for o in dele)]


def soma(cfg, hs, k):
    return sum(int(cfg["habilidades"][h].get(k, 0)) for h in hs)


def vel_pct(a):
    nom = int(a.get("velocidade_nominal", 0))
    if nom <= 0:
        return 100
    return div(max(int(a.get("velocidade", nom)), 0) * 100, nom)


def dano(cfg, r, a, d, zona, ha):
    dn = cfg["dano"]
    if zona not in dn["base_por_zona"]:
        return
    peca = dn["peca_por_zona"][zona]
    extra = max(vel_pct(a) - 100, 0)
    v = div(int(dn["base_por_zona"][zona]) * (1000 + extra * int(dn["velocidade_por_pct_milesimos"])), 1000)
    if ha:
        v = div(v * (100 + soma(cfg, ha, "dano_bonus_pct")), 100)
    red = div(stat(d.get("equipamento"), peca, "defesa") * int(dn["defesa_reduz_por_ponto_milesimos"]), 1000)
    r["dano"] = {peca: max(v - red, int(dn["minimo"]))}
    r["dano_lanca"] = int(dn["lanca_por_contato"])


def golpe(cfg, a, d, ha, hd, rng):
    zona = a.get("zona", ERRO)
    r = {"zona": zona, "zona_final": zona, "bloqueado": False, "bloqueio_por": "", "falta": False, "pontos": 0,
         "chance_derrubar_milesimos": 0, "derrubou": False, "habilidade": ha[0] if ha else "", "habilidades": list(ha),
         "habilidade_bloqueio": "", "dano": {}, "dano_lanca": 0}
    if zona == ERRO or zona not in cfg["pontos"]:
        r["zona"] = r["zona_final"] = ERRO
        return r
    joelho = int(cfg["teto_suave_joelho_pct"])
    if zona == cfg["falta"]["zona"]:
        r["falta"] = True
        r["pontos"] = -int(cfg["falta"]["penalidade_pontos"])
        dano(cfg, r, a, d, zona, [])
        return r
    b = cfg["bloqueio"]
    if zona in b["zonas"]:
        hb = ""
        for h in hd:
            bh = int(cfg["habilidades"][h]["bloqueio_milesimos"])
            if bh > 0 and (hb == "" or bh > int(cfg["habilidades"][hb]["bloqueio_milesimos"])):
                hb = h
        if hb and rng.chance(int(cfg["habilidades"][hb]["bloqueio_milesimos"])):
            r.update(bloqueado=True, bloqueio_por="habilidade", habilidade_bloqueio=hb)
        if not r["bloqueado"]:
            c = suave(int(b["base_milesimos"]) + stat(d.get("equipamento"), "escudo", "bloqueio_milesimos"), int(b["teto_milesimos"]), joelho)
            if rng.chance(c):
                r.update(bloqueado=True, bloqueio_por="escudo")
        if r["bloqueado"]:
            r["zona_final"] = b["vira_zona"]
    zf = r["zona_final"]
    r["pontos"] = int(cfg["pontos"][zf])
    dr = cfg["derrubada"]
    dl = da_largada(cfg, a.get("largada", "ruim"))
    if zf in dl["base_por_zona_milesimos"]:
        peca = cfg["dano"]["peca_por_zona"].get(zf, "")
        c = int(dl["base_por_zona_milesimos"][zf])
        c += (int(a["cavaleiro"]["forca"]) - int(d["cavaleiro"]["equilibrio"])) * int(dr["forca_menos_equilibrio_milesimos"])
        c += (vel_pct(a) - 100) * int(dr["velocidade_por_pct_milesimos"])
        c += div(int(dr["ritmo_max_milesimos"]) * min(max(int(a.get("ritmo_milesimos", 0)), 0), 1000), 1000)
        c += stat(a.get("equipamento"), "lanca", "poder") * int(dr["poder_lanca_milesimos"])
        c -= stat(d.get("equipamento"), peca, "defesa") * int(dr["defesa_peca_milesimos"])
        c += soma(cfg, ha, "derrubada_bonus_milesimos")
        c += soma(cfg, hd, "exposicao_milesimos")
        c -= soma(cfg, hd, "derrubada_reducao_milesimos")
        c = suave(c, int(dl["teto_milesimos"]), joelho)
        r["chance_derrubar_milesimos"] = c
        r["derrubou"] = rng.chance(c)
    dano(cfg, r, a, d, zf, ha)
    return r


def resolver(cfg, entrada, semente):
    rng = Rng(semente)
    j, r = entrada["jogador"], entrada["rival"]
    hj, hr = em_efeito(cfg, j, r), em_efeito(cfg, r, j)
    return {"jogador": golpe(cfg, j, r, hj, hr, rng), "rival": golpe(cfg, r, j, hr, hj, rng)}


# --------------------------------------------------------------- casos novos

def cav(f=50, p=50, e=50):
    return {"forca": f, "precisao": p, "equilibrio": e}


def lado(zona, habs=(), f=50, e=50, vel=95, largada="boa"):
    d = {"cavaleiro": cav(f, 50, e), "zona": zona, "velocidade": vel, "velocidade_nominal": 95, "ritmo_milesimos": 500}
    if largada is not None:
        d["largada"] = largada
    if habs:
        d["habilidades"] = [{"nome": n, "ativa": a} for n, a in habs]
    return d


# Largada de cada lado nos casos que já existiam antes dela (o resto: "boa").
LARGADA_DOS_CASOS = {
    "teto suave segura a chance de derrubar": ("perfeita", "perfeita"),
    "forca alta contra equilibrio baixo derruba mais": ("perfeita", "ruim"),
    "equilibrio alto quase nao cai": ("ruim", "perfeita"),
    "lanca do sol: derrubada e dano": ("perfeita", "boa"),
    "sorteio da derrubada semente 21": ("perfeita", "perfeita"),
    "sorteio da derrubada semente 22": ("perfeita", "boa"),
    "sorteio da derrubada semente 23": ("boa", "perfeita"),
    "sorteio da derrubada semente 24": ("boa", "ruim"),
    "sorteio da derrubada semente 25": ("ruim", "perfeita"),
    "sorteio da derrubada semente 26": ("perfeita", "ruim"),
}

CASOS_NOVOS = [
    ("largada perfeita: base e teto maiores", 31, lado("capacete", largada="perfeita"), lado("peito", largada="perfeita")),
    ("largada boa: base e teto medios", 31, lado("capacete", largada="boa"), lado("peito", largada="boa")),
    ("largada ruim: quase nao derruba", 31, lado("capacete", largada="ruim"), lado("peito", largada="ruim")),
    ("sem largada vale ruim", 31, lado("capacete", largada=None), lado("escudo", largada=None)),
    ("largada desconhecida vale ruim", 31, lado("capacete", largada="relampago"), lado("peito", largada="")),
    ("largadas diferentes nos dois lados", 33, lado("peito", largada="perfeita"), lado("peito", largada="ruim")),
    ("escudo com largada perfeita", 35, lado("escudo", largada="perfeita"), lado("escudo", largada="boa")),
    ("teto da largada perfeita com tudo a favor", 37, lado("capacete", [("lanca_do_sol", True)], f=100, e=50, vel=114, largada="perfeita"),
     lado("capacete", e=0, largada="perfeita")),
    ("teto da largada ruim com tudo a favor", 37, lado("capacete", [("lanca_do_sol", True)], f=100, e=50, vel=114, largada="ruim"),
     lado("capacete", e=0, largada="ruim")),
    ("bloqueio vira escudo e usa a base do escudo da largada", 1, lado("capacete", largada="perfeita"), lado("peito", [("baluarte_real", True)], largada="boa")),
    ("largada perfeita: sorteio semente 61", 61, lado("capacete", largada="perfeita"), lado("capacete", largada="perfeita")),
    ("largada perfeita: sorteio semente 62", 62, lado("capacete", largada="perfeita"), lado("capacete", largada="perfeita")),
    ("largada perfeita: sorteio semente 63", 63, lado("peito", largada="perfeita"), lado("peito", largada="perfeita")),
    ("largada perfeita: sorteio semente 64", 64, lado("peito", largada="perfeita"), lado("capacete", largada="boa")),

    ("golpe do campeao: derrubada e dano maiores", 7, lado("peito", [("golpe_do_campeao", True)]), lado("erro")),
    ("golpe do campeao: quem usa fica exposto", 7, lado("erro", [("golpe_do_campeao", True)]), lado("peito")),
    ("golpe do campeao ainda nao acionado: sem bonus nem exposicao", 7, lado("peito", [("golpe_do_campeao", False)]), lado("peito")),
    ("golpe do campeao (golpe pesado) anula a carga andante", 9, lado("peito", [("golpe_do_campeao", True)]), lado("peito", [("carga_andante", True)])),
    ("baluarte anula o golpe do campeao e a exposicao", 9, lado("peito", [("golpe_do_campeao", True)]), lado("peito", [("baluarte_real", True)])),
    ("fantasma do corcel: menos chance de cair", 11, lado("peito", [("fantasma_do_corcel", True)]), lado("peito")),
    ("fantasma do corcel anulado pela investida", 11, lado("peito", [("fantasma_do_corcel", True)]), lado("peito", [("investida", True)])),
    ("fantasma do corcel nao anula o golpe pesado do outro", 11, lado("peito", [("fantasma_do_corcel", True)]), lado("peito", [("martelo_negro", True)])),
    ("fantasma do corcel: chance nunca negativa", 11, lado("escudo", [("fantasma_do_corcel", True)], e=90), lado("escudo", f=10)),
    ("manto do corvo: sorteio do bloqueio semente 51", 51, lado("peito"), lado("peito", [("manto_do_corvo", True)])),
    ("manto do corvo: sorteio do bloqueio semente 52", 52, lado("capacete"), lado("peito", [("manto_do_corvo", True)])),
    ("manto do corvo: falha semente 54", 54, lado("peito"), lado("peito", [("manto_do_corvo", True)])),
    ("manto do corvo falha e o escudo segura semente 68", 68, lado("peito"), lado("peito", [("manto_do_corvo", True)])),
    ("manto do corvo anula o golpe do campeao", 13, lado("peito", [("golpe_do_campeao", True)]), lado("peito", [("manto_do_corvo", True)])),
    ("mira do falcao nao muda o impacto nem anula ninguem", 15, lado("peito", [("mira_do_falcao", True)]), lado("peito", [("martelo_negro", True)])),
]


def main():
    dados = json.load(open(ARQ, encoding="utf-8"))
    jogo = json.load(open(os.path.join(RAIZ, "game", "data", "balance", "impacto.json"), encoding="utf-8"))
    if sys.argv[1:] == ["gerar"]:
        cfg = copy.deepcopy(jogo)
        dados["config"] = cfg
        nomes = {c["nome"] for c in dados["casos"]}
        for c in dados["casos"]:
            lj, lr = LARGADA_DOS_CASOS.get(c["nome"], ("boa", "boa"))
            c["entrada"]["jogador"].setdefault("largada", lj)
            c["entrada"]["rival"].setdefault("largada", lr)
        for nome, sem, j, r in CASOS_NOVOS:
            if nome in nomes:
                continue
            dados["casos"].append({"nome": nome, "semente": sem, "entrada": {"jogador": j, "rival": r}})
        for c in dados["casos"]:
            c["esperado"] = resolver(cfg, c["entrada"], int(c["semente"]))
        json.dump(dados, open(ARQ, "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent="\t")  # mesmo formato, sem quebra no fim
    falhas = 0
    for c in dados["casos"]:
        obtido = resolver(dados["config"], c["entrada"], int(c["semente"]))
        if json.dumps(obtido, sort_keys=True) != json.dumps(c["esperado"], sort_keys=True):
            falhas += 1
            print("DIVERGE", c["nome"])
    print("casos %d, divergencias %d" % (len(dados["casos"]), falhas))
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
