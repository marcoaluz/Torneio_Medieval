# Gera arte no PixelLab (skill estilo-arte) para o que pode sair pronto de uma
# geracao: os predios da vila (um quadro por estagio) e os retratos dos
# personagens da historia. Cavaleiro, cavalo e pecas em camadas (A*/B*) NAO
# saem daqui: precisam do mesmo esqueleto, tons de cinza e retoque quadro a
# quadro (docs/PERSONAGEM.md).
#
#   python -I tools/gerar_arte.py --simular            lista o que falta, sem gastar credito
#   python -I tools/gerar_arte.py                       gera tudo o que falta
#   python -I tools/gerar_arte.py --so arena,ferreira   so estes predios/personagens
#   python -I tools/gerar_arte.py --grupo vila|retratos|campeoes   (campeoes: docs/ARTE_PENDENTE.md)
#   depois: driver.sh script res://tools/montar_folhas_vila.gd  (junta os estagios na folha)
#
# Chave: variavel de ambiente PIXELLAB_API_KEY ou .chaves.env na raiz (fora do git).
# Cores: toda geracao recebe a paleta do jogo como color_image (paletas.json:
# cores da casa, metais, neutros, peles, cabelos e mundo), entao tudo sai com as
# mesmas cores e combina. Predios: mesma semente em todos os estagios e o
# estagio 1 como init_image fraca dos demais (mesma cara, mas cresce). O
# modelo bitforge foi testado e desenhou figuras fora do pedido: so pixflux.
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
    "guilda": "a knights' order hall, a stately timber and stone lodge with a wide double door, a plain bare wooden signboard above the door and an empty flagpole, no heraldry, no emblems",
    "salao_liga": "a guild hall of champions with heraldic banners and a stone entrance",
}
ESTAGIOS = [
    "tiny humble one-room version, rough timber walls and a sagging thatched roof, patched and poor",
    "small modest version, timber frame with plaster walls and a wooden shingle roof",
    "medium sturdy version, stone ground floor with timber upper floor and a slate roof",
    "large prosperous version, dressed stone walls, two floors, slate roof, small heraldic banners",
    "grand imposing version, fine stonework, three floors with a tower, tall slate roof, large heraldic banners and iron details",
]
SO_PREDIO = ("single building only, sitting flat on the ground, no terrain base, no floating island, "
             "no ground platform, no trees, no people")
NEGATIVO_PREDIO = NEGATIVO + ", floating island, diorama base, terrain block, dirt platform, cliff, trees, bushes"
FORCA_ESTAGIO1 = 120  # init_image_strength (1-999): baixo = so a cara, deixa o predio crescer
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
    "derrotado": "defeated and humbled expression, bruised face, looking down, dented helmet",
}
# Campeões do PvE (grupo "campeoes"): retrato de cada um em 3 expressões
# (neutro na ficha, debochado no duelo, derrotado ao cair). O rei e o nêmesis
# usam a descrição de RETRATO (são os mesmos da história). Lista e prompts
# completos em docs/ARTE_PENDENTE.md. Cores: as da casa (pve.json > rivais > casa).
RETRATO_CAMPEAO = {
    "campeao_valdemar": "a cocky village fair champion knight in his forties, blond moustache, open bascinet with the visor raised, old gold and royal blue surcoat",
    "martim_martelo": "a burly brute of a knight with a broken nose and a shaved head, great helm under his arm, royal blue and bone-white tabard",
    "dama_isolda_gaviao": "a lean sharp-eyed lady knight with a hawk feather on her helm, hair tied back, forest green and old gold surcoat",
    "sir_egas_muro": "a massive broad-shouldered knight with a thick black beard and a huge kite shield behind him, purple and old gold tabard",
    "conde_rodrigo_alvar": "a haughty count with a trimmed grey goatee and a fur-trimmed cloak over polished armor, silver and royal blue heraldry",
    "sir_henrique_lamina": "a slim young knight with slicked dark hair and a thin scar on the cheek, elegant fluted armor, royal blue and bone-white",
    "dama_mafalda_tormenta": "a fierce northern lady knight with wild red hair and a storm-grey cloak, visor half lowered, forest green and old gold",
    "sir_bermudo_touro": "a huge bull-necked knight with a horned helm and a thick red beard, purple and old gold tabard",
    "duque_afonso_montargil": "a proud duke in gilded armor with a ducal coronet on his helm, clean-shaven, silver and royal blue heraldry",
    "sir_gil_implacavel": "a silent knight in plain blued-steel armor, closed visor with only cold eyes visible through the slit, royal blue and bone-white",
    "dama_brites_escarpa": "a stern weathered lady knight with short grey hair and a heavy tower shield, forest green and old gold",
    "sir_tristao_ferro_velho": "an old veteran knight with a white beard, many scars and patched old-fashioned armor, purple and old gold",
    "principe_fernando_aurora": "a young arrogant prince with golden curls and an ornate sunburst helm, silver and royal blue heraldry",
    "sir_aurelio_invicto": "a legendary knight in his prime, a lance decorated with a hundred colored ribbons behind him, royal blue and bone-white",
    "dama_elvira_sangue_real": "a cold aristocratic lady knight with pale skin, braided dark hair and a thin circlet, forest green and old gold",
    "sir_baltasar_escudo_ouro": "a wealthy knight with a gleaming golden shield and rings over his gauntlets, purple and old gold",
}
EXPRESSOES_CAMPEAO = ["neutro", "debochado", "derrotado"]


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
    if "campeoes" in grupos:
        pve = ler("game/data/balance/pve.json")["rivais"]
        cores = ler("game/data/personagem/paletas.json")["cores_casa"]
        for rid, r in pve.items():
            if not (r.get("campeao") or r.get("nemesis")):
                continue
            quem = r.get("retrato", rid)
            if so and quem not in so:
                continue
            for expr in EXPRESSOES_CAMPEAO:
                destino = os.path.join(RETRATOS, "%s_%s.png" % (quem, expr))
                if not os.path.exists(destino):
                    falta.append(("campeoes", quem, expr, destino, (128, 128), {"cores": [cores[c] for c in r["casa"]]}))
    return falta


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--simular", action="store_true")
    ap.add_argument("--so", default="")
    ap.add_argument("--grupo", default="vila,retratos")
    a = ap.parse_args()
    so = set(x for x in a.so.split(",") if x)
    falta = plano(set(a.grupo.split(",")), so)
    print("faltam %d imagens (%d da vila, %d retratos, %d de campeoes)" % (
        len(falta), sum(1 for f in falta if f[0] == "vila"), sum(1 for f in falta if f[0] == "retratos"),
        sum(1 for f in falta if f[0] == "campeoes")))
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
        caminho = "/generate-image-pixflux"
        if grupo == "vila":
            n_est = int(dados["estagios"])
            # Estágio no espectro de 5 (prédio de 4 estágios pula o mais humilde).
            nivel = extra + (5 - n_est)
            estagio = ESTAGIOS[nivel]
            if quem == "guilda":  # o brasão da ordem entra pelo jogo, nunca desenhado
                estagio = estagio.replace(", small heraldic banners", "").replace("large heraldic banners and iron details", "iron details")
            descricao = "%s, top-down three-quarter view, %s, %s, %s, transparent background" % (
                ESTILO, PREDIOS.get(quem, quem), estagio, SO_PREDIO)
            corpo = {"description": descricao, "negative_description": NEGATIVO_PREDIO, "image_size": {"width": w, "height": hh},
                     "view": "high top-down", "no_background": True, "detail": "highly detailed", "shading": "detailed shading",
                     "outline": "selective outline", "seed": 1000 + (sorted(PREDIOS).index(quem) if quem in PREDIOS else 99),
                     "color_image": {"type": "base64", "base64": paleta_png([dados["cor_telhado"]])}}
            primeiro = anterior.get(quem)
            arq1 = os.path.join(FONTES_VILA, "%s_1.png" % quem)
            if primeiro is None and extra > 0 and os.path.exists(arq1):
                primeiro = base64.b64encode(open(arq1, "rb").read()).decode("ascii")
            if primeiro and extra > 0:
                corpo["init_image"] = {"type": "base64", "base64": primeiro}
                corpo["init_image_strength"] = FORCA_ESTAGIO1
        else:
            # Retratos da história e dos campeões: mesma moldura de prompt.
            desc = RETRATO[quem] if quem in RETRATO else RETRATO_CAMPEAO[quem]
            descricao = "%s, portrait bust, head and shoulders, facing right, %s, %s, plain dark background" % (
                ESTILO, desc, EXPRESSOES.get(extra, extra))
            semente = 2000 + sorted(RETRATO).index(quem) if quem in RETRATO else 3000 + sorted(RETRATO_CAMPEAO).index(quem)
            cores_p = dados.get("cores") or ([dados["cor"]] if dados.get("cor") else [])
            corpo = {"description": descricao, "negative_description": NEGATIVO, "image_size": {"width": w, "height": hh},
                     "view": "side", "detail": "highly detailed", "shading": "detailed shading", "outline": "selective outline",
                     "seed": semente,
                     "color_image": {"type": "base64", "base64": paleta_png(cores_p)}}
        try:
            r = pedir(caminho, corpo, k)
        except RuntimeError as erro:
            print("FALHOU %s: %s" % (os.path.relpath(destino, RAIZ), erro))
            if "401" in str(erro) or "402" in str(erro):
                return 1
            continue
        dados_png = b64_da_resposta(r)
        open(destino, "wb").write(base64.b64decode(dados_png))
        if grupo == "vila" and extra == 0:
            anterior[quem] = dados_png
        feitos += 1
        print("ok %s (%s)" % (os.path.relpath(destino, RAIZ), r.get("usage", {})))
    print("geradas %d de %d" % (feitos, len(falta)))
    if any(f[0] == "vila" for f in falta):
        print("agora: bash .claude/skills/run-torneio-medieval/driver.sh script res://tools/montar_folhas_vila.gd")
    return 0


if __name__ == "__main__":
    sys.exit(main())
