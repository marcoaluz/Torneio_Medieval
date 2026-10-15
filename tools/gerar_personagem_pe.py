# Cavaleiro a pé em camadas (vila 96x96 e retrato de Equipamentos 256x256),
# gerado no PixelLab com as mesmas técnicas da justa (tools/gerar_personagem.py):
# pintura localizada com o corpo em magenta (o que o PixelLab desenha por cima
# sai separado), armadura de cada conjunto pintada numa referência e, na vila,
# levada aos quadros da caminhada numa grade (a referência num canto como
# exemplo). Rodar com `python -E -P tools/gerar_personagem_pe.py <etapa> <tamanho> [conjunto]`.
#
#   base vila|equip            corpo masculino (base escolhida), feminino (só a cabeça
#                              repintada) e a caminhada (vila)
#   conjunto vila|equip <c>    armadura do conjunto <c>
#   exportar vila|equip        folhas no formato do jogo (todas as peças prontas)
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gerar_personagem as g  # noqa: E402
import pixellab_cliente as p  # noqa: E402
from PIL import Image  # noqa: E402

RAIZ = p.RAIZ
FONTE = os.path.join(RAIZ, "game", "art", "fontes", "personagem", "pe")
CFG = {
    "vila": {"lado": 96, "base": "base_vila_71.png", "pasta": "vila", "anims": {"parado": [0], "andar": list(range(1, 9))},
             "escudo": (12, 15), "caminhada": 8},
    "equip": {"lado": 256, "base": "base_equip.png", "pasta": "equipamentos", "anims": {"parado": [0], "respirar": [0, 1]},
              "escudo": (40, 52), "caminhada": 0},
}


def carregar(nome):
    return Image.open(os.path.join(FONTE, nome)).convert("RGBA")


def salvar(img, nome):
    os.makedirs(FONTE, exist_ok=True)
    img.save(os.path.join(FONTE, nome))


def existe(nome):
    return os.path.exists(os.path.join(FONTE, nome))


def no_chao(img, lado):
    """Pés no fundo do quadro e o corpo centrado (a origem do jogo é o chão, no meio)."""
    b = img.getbbox()
    out = Image.new("RGBA", (lado, lado))
    out.alpha_composite(img.crop(b), (lado // 2 - (b[2] - b[0]) // 2, lado - (b[3] - b[1])))
    return out


def silhueta(img):
    pi = img.load()
    return {(x, y) for y in range(img.height) for x in range(img.width) if pi[x, y][3] >= 128}


def faixas(img):
    """Linhas do corpo a partir da silhueta: topo, pescoço, cintura e pés."""
    pts = silhueta(img)
    ys = [y for _, y in pts]
    topo, pes = min(ys), max(ys)
    altura = pes - topo
    return {"topo": topo, "pescoco": topo + int(altura * 0.16), "cintura": topo + int(altura * 0.47), "pes": pes}


def mascara_de(pontos, lado, folga=2, acima=0):
    sil = set(pontos)
    for _ in range(folga):
        sil |= {(x + a, y + b) for (x, y) in sil for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))}
    for _ in range(acima):
        sil |= {(x, y - 1) for (x, y) in sil}
    m = Image.new("RGB", (lado, lado), (0, 0, 0))
    pm = m.load()
    for (x, y) in sil:
        if 0 <= x < lado and 0 <= y < lado:
            pm[x, y] = (255, 255, 255)
    return m


def pintar(imagem, mascara, descricao, seed, rotulo):
    r = p.pedir("/inpaint-v3", {"description": descricao, "inpainting_image": p.quadro(imagem),
                                 "mask_image": p.quadro(mascara.convert("RGBA")), "seed": seed,
                                 "no_background": True, "crop_to_mask": True}, rotulo=rotulo)
    novo = p.imagens(r)[0]
    if novo.size != imagem.size:
        novo = novo.resize(imagem.size, Image.NEAREST)
    res = imagem.copy()
    pm, pn, pr = mascara.load(), novo.load(), res.load()
    for y in range(imagem.height):
        for x in range(imagem.width):
            if pm[x, y][0] > 127:
                pr[x, y] = pn[x, y]
    print("  pintado %s %s" % (rotulo, r.get("_usage")))
    return res


def nao_chave(img, mascara):
    pi, pm = img.load(), mascara.load()
    return {(x, y) for y in range(img.height) for x in range(img.width)
            if pm[x, y][0] > 127 and not g.e_chave(pi[x, y])}


# ------------------------------------------------------------------ base

def etapa_base(t):
    c = CFG[t]
    lado = c["lado"]
    if not existe("corpo_%s_masculino_0.png" % t):
        base = no_chao(carregar(c["base"]), lado)
        salvar(base, "corpo_%s_masculino_0.png" % t)
    base = carregar("corpo_%s_masculino_0.png" % t)
    quadros = [base]
    if c["caminhada"]:
        if not all(existe("corpo_%s_masculino_%d.png" % (t, k)) for k in range(1, 1 + c["caminhada"])):
            r = p.pedir("/animate-pixminimax", {"first_frame": p.img_b64(base), "last_frame": p.img_b64(base),
                        "description": "walks in place with a calm natural walking cycle: arms swing gently, legs step, one full loop that returns to the starting pose",
                        "frame_count": c["caminhada"], "seed": 17, "no_background": True,
                        "subject_description": "a young medieval squire in a grey gambeson", "initial_pose": "standing upright"},
                        rotulo="caminhada %s" % t)
            ims = p.imagens(r)[1:1 + c["caminhada"]]
            for k, im in enumerate(ims, 1):
                salvar(im, "corpo_%s_masculino_%d.png" % (t, k))
            print("  caminhada %s %s" % (t, r.get("_usage")))
        quadros += [carregar("corpo_%s_masculino_%d.png" % (t, k)) for k in range(1, 1 + c["caminhada"])]
    # Feminino: a cabeça repintada uma vez (no parado) e levada a cada quadro da
    # caminhada na posição da cabeça daquele quadro (rosto igual em todos).
    if not existe("corpo_%s_feminino_0.png" % t):
        f0 = faixas(base)
        cab0 = {(x, y) for (x, y) in silhueta(base) if y <= f0["pescoco"] + 1}
        desc = ("pixel art, the head of a young woman, long dark hair tied back in a braid, determined expression, "
                "same angle as the original head, same neck and collar")
        fem0 = pintar(base, mascara_de(cab0, lado, folga=3, acima=2), desc, 43, "feminino %s" % t)
        salvar(fem0, "corpo_%s_feminino_0.png" % t)
        regiao = mascara_de(cab0, lado, folga=3, acima=2).load()
        cabeca_f = {(x, y): fem0.getpixel((x, y)) for y in range(lado) for x in range(lado)
                    if regiao[x, y][0] > 127 and fem0.getpixel((x, y))[3] >= 128}
        molde = {(x, y): base.getpixel((x, y)) for (x, y) in cab0}
        for k in range(1, len(quadros)):
            q = quadros[k]
            dx, dy = casar(molde, q, lado)
            out = q.copy()
            po = out.load()
            for y in range(lado):
                for x in range(lado):
                    if 0 <= x - dx < lado and 0 <= y - dy < lado and regiao[x - dx, y - dy][0] > 127:
                        po[x, y] = (0, 0, 0, 0)
            for (x, y), c in cabeca_f.items():
                if 0 <= x + dx < lado and 0 <= y + dy < lado:
                    po[x + dx, y + dy] = c
            salvar(out, "corpo_%s_feminino_%d.png" % (t, k))


def casar(molde, img, lado, raio=6):
    """(dx, dy) em que o molde (pixels da cabeça) melhor se encaixa em img."""
    pi = img.load()
    melhor = (10 ** 12, 0, 0)
    for dy in range(-raio, raio + 1):
        for dx in range(-raio, raio + 1):
            sad = 0
            for (x, y), c in molde.items():
                xx, yy = x + dx, y + dy
                if 0 <= xx < lado and 0 <= yy < lado and pi[xx, yy][3] >= 128:
                    d = pi[xx, yy]
                    sad += abs(d[0] - c[0]) + abs(d[1] - c[1]) + abs(d[2] - c[2])
                else:
                    sad += 300
            if sad < melhor[0]:
                melhor = (sad, dx, dy)
    return melhor[1], melhor[2]


# --------------------------------------------------------------- conjunto

def chaveado(q):
    """Corpo em magenta (forma e luz) para pintar armadura por cima."""
    return g.chave(q, "magenta")


def etapa_conjunto(t, nome):
    c = CFG[t]
    lado = c["lado"]
    pecas = g.CONJUNTOS[nome]
    base = carregar("corpo_%s_masculino_0.png" % t)
    f = faixas(base)
    sil = silhueta(base)
    regioes = {
        "pernas": {(x, y) for (x, y) in sil if y >= f["cintura"]},
        "peitoral": {(x, y) for (x, y) in sil if f["pescoco"] - 2 <= y <= f["cintura"] + 4},
        "elmo": {(x, y) for (x, y) in sil if y <= f["pescoco"] + 2},
    }
    folgas = {"pernas": (2, 0), "peitoral": (3, 0), "elmo": (2, max(3, lado // 24))}
    atual = chaveado(base)
    salvar(atual, "ref_%s_%s_base.png" % (t, nome))
    for i, peca in enumerate(["pernas", "peitoral", "elmo"]):
        arq = "ref_%s_%s_%s.png" % (t, nome, peca)
        m = mascara_de(regioes[peca], lado, *folgas[peca])
        salvar(m.convert("RGBA"), "mascara_%s_%s.png" % (t, peca))
        desc = "pixel art, the standing knight wearing %s; %s" % (pecas[peca].replace("the rider", "the knight"), g.CORES)
        atual = pintar(atual, m, desc, 500 + i, "%s %s %s" % (t, nome, peca))
        salvar(atual, arq)
    # Caminhada (vila): grade com a referência pronta no canto e os quadros a pintar.
    if c["caminhada"]:
        quadros = [carregar("corpo_%s_masculino_%d.png" % (t, k)) for k in range(1, 1 + c["caminhada"])]
        col = 3
        lin = (len(quadros) + 1 + col - 1) // col
        img = Image.new("RGBA", (lado * col, lado * lin))
        msk = Image.new("RGB", (lado * col, lado * lin), (0, 0, 0))
        img.alpha_composite(atual, (0, 0))
        cantos = [((i % col) * lado, (i // col) * lado) for i in range(1, len(quadros) + 1)]
        for q, (cx, cy) in zip(quadros, cantos):
            img.alpha_composite(chaveado(q), (cx, cy))
            msk.paste(mascara_de(silhueta(q), lado, 2, max(3, lado // 24)), (cx, cy))
        desc = ("pixel art sprite sheet of the same knight walking; paint on every figure exactly the same armor as the top-left knight: "
                "%s, %s, %s; %s" % (pecas["elmo"], pecas["peitoral"], pecas["pernas"], g.CORES))
        r = p.pedir("/inpaint-v3", {"description": desc, "inpainting_image": p.quadro(img), "mask_image": p.quadro(msk.convert("RGBA")),
                                     "seed": 510, "no_background": True, "crop_to_mask": True}, rotulo="%s %s caminhada" % (t, nome))
        novo = p.imagens(r)[0]
        if novo.size != img.size:
            novo = novo.resize(img.size, Image.NEAREST)
        print("  caminhada %s %s %s" % (t, nome, r.get("_usage")))
        for k, (cx, cy) in enumerate(cantos, 1):
            salvar(novo.crop((cx, cy, cx + lado, cy + lado)), "arm_%s_%s_%d.png" % (t, nome, k))
    salvar(atual, "arm_%s_%s_0.png" % (t, nome))
    escudo(t, nome)
    print("conjunto %s %s: ok" % (t, nome))


def escudo(t, nome):
    arq = "escudo_%s_%s.png" % (t, nome)
    if existe(arq):
        return
    fonte = os.path.join(g.FONTE, "obj_escudo_%s.png" % nome)
    # Reaproveita o escudo da justa (mesmo desenho); no retrato grande gera de novo em 64 px.
    r = p.pedir("/generate-image-pixflux", {
        "description": "%s, a single medieval jousting shield seen straight from the front, %s; the face is solid plain red with nothing painted on it, steel parts plain grey, trims solid blue" % (
            g.ESTILO_OBJ, g.CONJUNTOS[nome]["escudo"].replace(" held on the left arm", "").replace(", its face painted plain", "")),
        "negative_description": "emblem, symbol, cross, lion, text, person, hand, arm",
        "image_size": {"width": 64, "height": 64}, "no_background": True, "seed": 300,
        "detail": "highly detailed", "shading": "detailed shading", "outline": "single color black outline"},
        versao=1, assincrono=False, rotulo="escudo " + nome)
    img = p.imagens(r)[0]
    img = img.crop(img.getbbox())
    img.thumbnail(CFG[t]["escudo"], Image.NEAREST)
    salvar(img, arq)


# --------------------------------------------------------------- exportar

def quadros_corpo(t, corpo):
    c = CFG[t]
    if c["caminhada"]:
        return [carregar("corpo_%s_%s_%d.png" % (t, corpo, k)) for k in range(1 + c["caminhada"])]
    q = carregar("corpo_%s_%s_0.png" % (t, corpo))
    return [q, respirar(q, faixas(carregar("corpo_%s_masculino_0.png" % t))["cintura"])]


def respirar(img, cintura):
    """Respiração: tudo acima da cintura desce 1 px (o mesmo em todas as camadas)."""
    out = img.copy()
    po, pi = out.load(), img.load()
    for y in range(img.height - 1, 0, -1):
        if y <= cintura:
            for x in range(img.width):
                po[x, y] = pi[x, y - 1]
    for x in range(img.width):
        po[x, 0] = (0, 0, 0, 0)
    return out


def separar_pele_cabelo(img, f):
    """Pele (rosto e mãos) e cabelo em cinza normalizado; o resto como está."""
    pi = img.load()
    pts = silhueta(img)
    pele, escuros = {}, set()
    for (x, y) in pts:
        c = pi[x, y]
        h, sa, v = g._hsv(c)
        if v >= 0.35 and sa >= 0.14 and (h <= 45 or h >= 350):
            pele[(x, y)] = c
        elif y <= f["pescoco"] + 6 and v < 0.36:
            escuros.add((x, y))
    viz = ((1, 0), (-1, 0), (0, 1), (0, -1))
    miolo = {q for q in escuros if sum((q[0] + a, q[1] + b) in escuros for a, b in viz) >= 3}
    cabelo = miolo | {q for q in escuros if any((q[0] + a, q[1] + b) in miolo for a, b in viz)}
    cabelo = g.limpar({(x, y) for (x, y) in cabelo if y <= f["pescoco"] + 2 or True}, 6)
    resto = {xy: pi[xy] for xy in pts if xy not in pele and xy not in cabelo}
    return (g.normalizar(pele, 0.62, 0.22), g.normalizar({xy: pi[xy] for xy in cabelo}, 0.5, 0.3), resto)


def imagem_de(pixels, lado):
    img = Image.new("RGBA", (lado, lado))
    pi = img.load()
    for xy, c in pixels.items():
        pi[xy] = c
    return img


def escrever(quadros, arquivo, t, com_mascara=True):
    lado = CFG[t]["lado"]
    folha = Image.new("RGBA", (lado * len(quadros), lado))
    for i, q in enumerate(quadros):
        folha.alpha_composite(q, (lado * i, 0))
    pasta = os.path.join(RAIZ, "game", "art", "sprites", "personagem", CFG[t]["pasta"])
    os.makedirs(pasta, exist_ok=True)
    folha.save(os.path.join(pasta, arquivo + ".png"))
    masc = os.path.join(pasta, arquivo + "_mascara.png")
    m = g.mascara_de(folha) if com_mascara else None
    if m:
        m.save(masc)
    elif os.path.exists(masc):
        os.remove(masc)


def exportar(t):
    c = CFG[t]
    lado = c["lado"]
    fb = faixas(carregar("corpo_%s_masculino_0.png" % t))
    cabelos = {"masculino": "1", "feminino": "2"}
    for corpo in ("masculino", "feminino"):
        qs = quadros_corpo(t, corpo)
        partes = [separar_pele_cabelo(q, faixas(q)) for q in qs]
        for nome_arq, idx_parte in (("corpo_%s" % corpo, 2), ("rosto_%s_1" % corpo, 0), ("cabelo_%s" % cabelos[corpo], 1)):
            imgs = [imagem_de(pt[idx_parte], lado) for pt in partes]
            for anim, idx in c["anims"].items():
                escrever([imgs[i] for i in idx], "%s_%s" % (nome_arq, anim), t, com_mascara=False)
    pontos = {}
    for nome in g.CONJUNTOS:
        if not existe("arm_%s_%s_0.png" % (t, nome)):
            continue
        corpo_m = quadros_corpo(t, "masculino")
        if c["caminhada"]:
            arm = [carregar("arm_%s_%s_%d.png" % (t, nome, k)) for k in range(1 + c["caminhada"])]
        else:
            a0 = carregar("arm_%s_%s_0.png" % (t, nome))
            arm = [a0, respirar(a0, fb["cintura"])]
        esc = carregar("escudo_%s_%s.png" % (t, nome))
        elmos, peitos, escudos, centros = [], [], [], []
        for k, (a, cm) in enumerate(zip(arm, corpo_m)):
            f = faixas(cm)
            pa = a.load()
            el = Image.new("RGBA", (lado, lado)); pe = Image.new("RGBA", (lado, lado))
            pel, ppe = el.load(), pe.load()
            for y in range(lado):
                for x in range(lado):
                    cc = pa[x, y]
                    if cc[3] < 128 or g.e_chave(cc):
                        continue
                    (pel if y <= f["pescoco"] else ppe)[x, y] = cc
            elmos.append(el); peitos.append(pe)
            # Escudo no braço da frente, à altura do peito, seguindo o tronco.
            tronco = [(x, y) for (x, y) in silhueta(cm) if f["pescoco"] <= y <= f["cintura"]]
            cx = min(x for x, _ in tronco) + int(lado * 0.02)
            cy = (f["pescoco"] + f["cintura"]) // 2 + int(lado * 0.04)
            e = Image.new("RGBA", (lado, lado))
            e.alpha_composite(esc, (cx - esc.width // 2, cy - esc.height // 2))
            escudos.append(e)
            centros.append([cx - lado // 2, cy - lado])
        for anim, idx in c["anims"].items():
            for peca, imgs in (("elmo", elmos), ("peitoral", peitos), ("escudo", escudos)):
                escrever([imgs[i] for i in idx], "%s_%s_%s" % (peca, nome, anim), t)
                for e_ in (1, 2, 3):
                    dan = [g.danificar(imgs[i], e_, 1000 * e_ + len(peca) + sum(map(ord, nome)), (0, 0)) for i in idx]
                    escrever(dan, "%s_%s_d%d_%s" % (peca, nome, e_, anim), t)
            pontos[anim] = {"brasao": [centros[i] for i in idx]}
    json.dump(pontos, open(os.path.join(FONTE, "pontos_%s.json" % t), "w", encoding="utf-8"), indent=1)
    print("exportado %s" % t)


if __name__ == "__main__":
    etapa, t = sys.argv[1], sys.argv[2]
    if etapa == "base":
        etapa_base(t)
    elif etapa == "conjunto":
        etapa_conjunto(t, sys.argv[3])
    elif etapa == "exportar":
        exportar(t)
