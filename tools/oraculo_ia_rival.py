# Oráculo independente da IA do rival (game/scripts/ai/ia_rival.gd e
# supabase/functions/_shared/regra/ia_rival.ts), escrito a partir da
# especificação no topo de ia_rival.gd, para gerar o "esperado" dos casos
# compartilhados em tests/shared/ia_rival.json sem copiar a saída das próprias
# implementações. `python -I tools/oraculo_ia_rival.py conferir` refaz os casos
# do arquivo e aponta divergências; `gerar` embute os dados atuais
# (game/data/balance/ia_rival.json, a largada de galope.json e a mira) e refaz
# o esperado de todos os casos.
import json
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARQ = os.path.join(RAIZ, "tests", "shared", "ia_rival.json")
BAL = os.path.join(RAIZ, "game", "data", "balance")
M32 = 0xFFFFFFFF
MASCARA_SEMENTE = 0x5DEECE66


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

    def inteiro(self, a, b):
        if b <= a:
            return a
        return a + self.proximo() % (b - a + 1)

    def chance(self, c):
        return self.proximo() % 1000 < c


class Ia:
    def __init__(self, perfil, semente):
        self.p = perfil
        self.rng = Rng(semente)

    def variacao(self, v):
        if v <= 0:
            return 0
        soma = self.rng.inteiro(0, 2 * v) + self.rng.inteiro(0, 2 * v)
        return soma // 2 - v

    def reacao(self, larg):
        pm, bm = int(larg["perfeita_ms"]), int(larg["boa_ms"])
        q = self.rng.inteiro(0, 999)
        pf = int(self.p["largada_perfeita_milesimos"])
        if q < pf:
            return self.rng.inteiro(0, pm)
        if q < pf + int(self.p["largada_boa_milesimos"]):
            return self.rng.inteiro(pm + 1, bm)
        return self.rng.inteiro(bm + 1, bm + max(int(self.p["largada_ruim_atraso_ms"]), 1))

    def galope(self, compasso, dur):
        plano = []
        cedo = self.p["acelera"] == "cedo"
        metade = int(self.p["metade_batidas"])
        for k in range(1, dur // compasso + 1):
            acel = k <= metade if cedo else k > metade
            if not acel and k % 2 == 1:
                continue
            if self.rng.chance(int(self.p["perder_batida_milesimos"])):
                continue
            t = k * compasso + int(self.p["desvio_medio_ms"]) + self.variacao(int(self.p["desvio_variacao_ms"]))
            if t >= 1 and (not plano or t > plano[-1]):
                plano.append(t)
        return plano

    def mira(self, cfg_mira):
        cx, cy = centro(cfg_mira, self.p["zona_preferida"])
        d = self.p["deslocamento_mira_px"]
        cx, cy = cx + int(d[0]) * 10, cy + int(d[1]) * 10
        erro = int(self.p["erro_mira_px"]) * 10
        dx = self.variacao(erro)
        dy = self.variacao(erro)
        return [cx + dx, cy + dy]


def centro(cfg_mira, zona):
    for z in cfg_mira["zonas"]:
        if z["nome"] == zona:
            r = z["retangulos"][0]
            return [int(r[0]) * 10 + int(r[2]) * 5, int(r[1]) * 10 + int(r[3]) * 5]
    return [0, 0]


def passadas(dados, caso):
    ia = Ia(dados["config_ia"]["perfis"][caso["perfil"]], (int(caso["semente_justa"]) ^ MASCARA_SEMENTE) & M32)
    res = []
    for _ in caso["passadas"]:
        r = ia.reacao(dados["config_largada"])
        g = ia.galope(500, 6000)
        m = ia.mira(dados["config_mira"])
        res.append({"reacao_ms": r, "galope": g, "mira": m})
    return res


def main():
    dados = json.load(open(ARQ, encoding="utf-8"))
    if sys.argv[1:] == ["gerar"]:
        dados["config_ia"] = json.load(open(os.path.join(BAL, "ia_rival.json"), encoding="utf-8"))
        dados["config_largada"] = json.load(open(os.path.join(BAL, "galope.json"), encoding="utf-8"))["largada"]
        dados["descricao"] = ("IA do rival (game/scripts/ai/ia_rival.gd). Para cada caso: IaRival(perfil, semente_ia); por passada"
                              " chame reacao_largada_ms(config_largada), plano_galope(500, 6000), ponto_mira(mira) nessa ordem."
                              " semente_ia = (semente_justa ^ 0x5DEECE66) & 0xFFFFFFFF. Esperado gerado por tools/oraculo_ia_rival.py.")
        for z in dados["centros"]:
            dados["centros"][z] = centro(dados["config_mira"], z)
        for c in dados["casos"]:
            c["semente_ia"] = (int(c["semente_justa"]) ^ MASCARA_SEMENTE) & M32
            c["passadas"] = passadas(dados, c)
        json.dump(dados, open(ARQ, "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent="\t")
    falhas = 0
    for c in dados["casos"]:
        if json.dumps(passadas(dados, c), sort_keys=True) != json.dumps(c["passadas"], sort_keys=True):
            falhas += 1
            print("DIVERGE", c["perfil"], c["semente_justa"])
    print("casos %d, divergencias %d" % (len(dados["casos"]), falhas))
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
