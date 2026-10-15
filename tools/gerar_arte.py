# Gera arte no PixelLab (skill estilo-arte) para o que pode sair pronto de uma
# geracao: os predios da vila (um quadro por estagio) e os retratos dos
# personagens da historia. Cavaleiro, cavalo e pecas em camadas (A*/B*) NAO
# saem daqui: precisam do mesmo esqueleto, tons de cinza e retoque quadro a
# quadro (docs/PERSONAGEM.md).
#
#   python -I tools/gerar_arte.py --simular            lista o que falta, sem gastar credito
#   python -I tools/gerar_arte.py                       gera tudo o que falta
#   python -I tools/gerar_arte.py --so arena,ferreira   so estes predios/personagens
#   python -I tools/gerar_arte.py --grupo vila|retratos
#   depois: driver.sh script res://tools/montar_folhas_vila.gd  (junta os estagios na folha)
#
# Chave: variavel de ambiente PIXELLAB_API_KEY ou .chaves.env na raiz (fora do git).
# Cores: toda geracao recebe a paleta do jogo como color_image (paletas.json:
# cores da casa, metais, neutros, peles, cabelos e mundo), entao tudo sai com as
# mesmas cores e combina. Estagio N do predio parte do estagio N-1 (init_image),
# com a mesma semente, para o predio crescer sem mudar de cara.
# Nao sobrescreve: gerar de novo = apagar o arquivo antes.
import argparse
import base64
import json
import os
import struct
import sys
import time
import urllib.error
import urllib.request
import zlib

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = "https://api.pixellab.ai/v1"
FONTES_VILA = os.path.join(RAIZ, "game", "art", "fontes", "vila")
RETRATOS = os.path.join(RAIZ, "game", "art", "sprites", "retratos")

# Prefixo do estilo (skill estilo-arte), sem a vista: cada grupo diz a sua.
ESTILO = ("High-detail pixel art, dark medieval tone, gritty and mature, muted earthy palette "
          "(iron grey, worn leather brown, mud, overcast sky), heraldic colors as the only saturated accents, "
          "rim light from an overcast sky, visible wear, scratches and dirt, crisp pixel clusters, "
          "no anti-aliasing blur, no outlines thicker than 1 pixel")
NEGATIVO = ("cartoon, chibi, cute, bright saturated colors everywhere, 3D render, blurry, smooth gradients, "
            "text, watermark, modern elements, fantasy glowing armor, anime")

PREDIOS = {
    "casa_senhorial": "a lord's manor house with a small tower and a banner pole",
    "estabulo": "a horse stable with stalls, hay bales and a fenced paddock",
    "campo_treino": "a jousting practice yard with a wooden quintain, a fence and a weapon rack",
    "ferreiro": "a blacksmith workshop with a stone forge chimney, anvil and bellows under a roof",
    "arena": "a small jousting arena with a tilt barrier, wooden stands and pennants",
    "armeiro": "an armorer's workshop with armor stands, shields hanging on the walls and a workbench",
    "loja": "a merchant stall shop with a striped awning, crates and barrels",
    "salao_liga": "a guild hall of champions with heraldic banners and a stone entrance",
}
ESTAGIOS = [
    "humble and small, rough timber and thatch, patched and simple",
    "modest, timber frame with plaster walls, wooden shingles",
    "solid, stone foundation, timber upper floor, slate roof",
    "large and well kept, dressed stone walls, slate roof, small heraldic banners",
    "grand and imposing, fine stonework, tall slate roof, large heraldic banners and ironwork",
]
RETRATO = {
    "arauto": "a jovial middle-aged royal herald with a feathered cap and a tabard, holding a brass trumpet",
    "ferreira": "a strong blacksmith woman with soot on her face, leather apron, rolled sleeves, braided hair",
    "escudeiro": "a young squire boy with messy hair and a simple padded gambeson",
    "nemesis": "a menacing knight called the Raven, black armor with crow feathers on the helm, visor up, cruel smile",
    "rei": "an old king who loves jousting, grey beard, golden crown, fur mantle over armor",
}
EXPRESSOES = {
    "neutro": "calm neutral expression", "alegre": "warm smiling expression", "serio": "serious stern expression",
    "timido": "shy nervous expression, looking slightly down", "bravo": "angry snarling expression",
    "debochado": "mocking smirk, one eyebrow raised",
}


def chave():
    k = os.environ.get("PIXELLAB_API_KEY", "")
    arq = os.path.join(RAIZ, ".chaves.env")
    if not k and os.path.exists(arq):
        for linha in open(arq, encoding="utf-8"):
            if linha.strip().startswith("PIXELLAB_API_KEY="):
                k = linha.split("=", 1)[1].strip().strip('"')
    return k


def ler(caminho):
    return json.load(open(os.path.join(RAIZ, caminho), encoding="utf-8"))


def png(largura, altura, pixels_rgba):
    """PNG RGBA mínimo (sem bibliotecas)."""
    linhas = b"".join(b"\x00" + bytes(pixels_rgba[y * largura * 4:(y + 1) * largura * 4]) for y in range(altura))
    def bloco(tipo, dados):
        return struct.pack(">I", len(dados)) + tipo + dados + struct.pack(">I", zlib.crc32(tipo + dados) & 0xFFFFFFFF)
    return (b"\x89PNG\r\n\x1a\n" + bloco(b"IHDR", struct.pack(">IIBBBBB", largura, altura, 8, 6, 0, 0, 0))
            + bloco(b"IDAT", zlib.compress(linhas, 9)) + bloco(b"IEND", b""))


def paleta_png(cores_extra=()):
    """Imagem com uma faixa por cor da paleta do jogo (color_image do PixelLab)."""
    p = ler("game/data/personagem/paletas.json")
    cores = []
    for grupo in ("cores_casa", "metais", "neutros", "peles", "cabelos", "mundo"):
        cores += [v for k, v in p.get(grupo, {}).items() if not k.startswith("_")]
    cores += list(cores_extra)
    vistas = []
    for c in cores:
        c = c.lstrip("#").lower()[:6]
        if c not in vistas:
            vistas.append(c)
    lado = 4
    largura, altura = lado * len(vistas), lado
    px = bytearray()
    for _y in range(altura):
        for c in vistas:
            for _x in range(lado):
                px += bytes(int(c[i:i + 2], 16) for i in (0, 2, 4)) + b"\xff"
    return base64.b64encode(png(largura, altura, px)).decode("ascii")


def pedir(caminho, corpo, k):
    req = urllib.request.Request(API + caminho, data=json.dumps(corpo).encode("utf-8"), method="POST",
                                 headers={"Authorization": "Bearer " + k, "Content-Type": "application/json"})
    for tentativa in range(3):
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            msg = e.read().decode("utf-8", "replace")[:300]
            if e.code in (429, 500, 502, 503) and tentativa < 2:
                time.sleep(5 * (tentativa + 1))
                continue
            raise RuntimeError("HTTP %d em %s: %s" % (e.code, caminho, msg))
    raise RuntimeError("sem resposta: " + caminho)


def b64_da_resposta(r):
    s = r["image"]["base64"]
    return s.split(",", 1)[1] if s.startswith("data:") else s


def tamanho_predio(t):
    # Um pouco maior que a pegada no chão (telhado, sombra, bandeiras); múltiplo de 8.
    def m8(v):
        return int((v + 7) // 8 * 8)
    return m8(t[0] * 1.3), m8(t[1] * 1.7)


def plano(grupos, so):
    falta = []
    vila = ler("game/data/balance/vila.json")["predios"]
    if "vila" in grupos:
        for nome, d in vila.items():
            if so and nome not in so:
                continue
            for e in range(int(d["estagios"])):
                destino = os.path.join(FONTES_VILA, "%s_%d.png" % (nome, e + 1))
                if not os.path.exists(destino):
                    falta.append(("vila", nome, e, destino, tamanho_predio(d["tamanho"]), d))
    if "retratos" in grupos:
        h = ler("game/data/historia/historia.json")
        usadas = set()
        for cena in h["cenas"].values() if isinstance(h["cenas"], dict) else h["cenas"]:
            for f in cena.get("falas", []):
                if f["quem"] in RETRATO:
                    usadas.add((f["quem"], f.get("expressao", "neutro")))
        for quem in RETRATO:
            usadas.add((quem, "neutro"))
        for quem, expr in sorted(usadas):
            if so and quem not in so:
                continue
            destino = os.path.join(RETRATOS, "%s_%s.png" % (quem, expr))
            if not os.path.exists(destino):
                falta.append(("retratos", quem, expr, destino, (128, 128), h["personagens"].get(quem, {})))
    return falta


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--simular", action="store_true")
    ap.add_argument("--so", default="")
    ap.add_argument("--grupo", default="vila,retratos")
    a = ap.parse_args()
    so = set(x for x in a.so.split(",") if x)
    falta = plano(set(a.grupo.split(",")), so)
    print("faltam %d imagens (%d da vila, %d retratos)" % (
        len(falta), sum(1 for f in falta if f[0] == "vila"), sum(1 for f in falta if f[0] == "retratos")))
    if a.simular:
        for f in falta:
            print("  %-8s %s  %dx%d" % (f[0], os.path.relpath(f[3], RAIZ), f[4][0], f[4][1]))
        return 0
    k = chave()
    if not k:
        print("sem PIXELLAB_API_KEY (variavel de ambiente ou .chaves.env na raiz)")
        return 2
    feitos = 0
    anterior = {}
    for grupo, quem, extra, destino, (w, hh), dados in falta:
        os.makedirs(os.path.dirname(destino), exist_ok=True)
        if grupo == "vila":
            descricao = "%s, top-down three-quarter view, %s, %s, transparent background" % (ESTILO, PREDIOS.get(quem, quem), ESTAGIOS[min(extra, 4)])
            corpo = {"description": descricao, "negative_description": NEGATIVO, "image_size": {"width": w, "height": hh},
                     "view": "high top-down", "no_background": True, "detail": "highly detailed", "shading": "detailed shading",
                     "outline": "selective outline", "seed": 1000 + sorted(PREDIOS).index(quem) if quem in PREDIOS else 999,
                     "color_image": {"type": "base64", "base64": paleta_png([dados["cor_telhado"]])}}
            prev = anterior.get(quem)
            if prev is None and extra > 0:
                arq = os.path.join(FONTES_VILA, "%s_%d.png" % (quem, extra))
                if os.path.exists(arq):
                    prev = base64.b64encode(open(arq, "rb").read()).decode("ascii")
            if prev:
                corpo["init_image"] = {"type": "base64", "base64": prev}
                corpo["init_image_strength"] = 350
        else:
            descricao = "%s, portrait bust, head and shoulders, facing right, %s, %s, plain dark background" % (
                ESTILO, RETRATO[quem], EXPRESSOES.get(extra, extra))
            corpo = {"description": descricao, "negative_description": NEGATIVO, "image_size": {"width": w, "height": hh},
                     "view": "side", "detail": "highly detailed", "shading": "detailed shading", "outline": "selective outline",
                     "seed": 2000 + sorted(RETRATO).index(quem),
                     "color_image": {"type": "base64", "base64": paleta_png([dados.get("cor", "")] if dados.get("cor") else [])}}
        try:
            r = pedir("/generate-image-pixflux", corpo, k)
        except RuntimeError as erro:
            print("FALHOU %s: %s" % (os.path.relpath(destino, RAIZ), erro))
            if "401" in str(erro) or "402" in str(erro):
                return 1
            continue
        dados_png = b64_da_resposta(r)
        open(destino, "wb").write(base64.b64decode(dados_png))
        if grupo == "vila":
            anterior[quem] = dados_png
        feitos += 1
        print("ok %s (%s)" % (os.path.relpath(destino, RAIZ), r.get("usage", {})))
    print("geradas %d de %d" % (feitos, len(falta)))
    if any(f[0] == "vila" for f in falta):
        print("agora: bash .claude/skills/run-torneio-medieval/driver.sh script res://tools/montar_folhas_vila.gd")
    return 0


if __name__ == "__main__":
    sys.exit(main())
