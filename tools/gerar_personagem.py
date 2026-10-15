# Arte do cavaleiro e do cavalo em camadas (justa) gerada no PixelLab.
# Rodar com `python -E -P tools/gerar_personagem.py <etapa> [args]` (Pillow na pasta do usuário).
#
# Como funciona (docs/PERSONAGEM.md > "Geração automática"):
#  1. Base: o cavalo galopando (ciclo de 8 quadros, PixMiniMax) e parado; quadro de
#     trabalho 256x160 com a origem do jogo (pés) em (80, 160) e espaço à frente
#     para a lança. A sela é localizada em cada quadro (casar_sela).
#  2. Cavaleiro: pintura localizada (inpaint-v3) sobre o galope 0, só na região do
#     cavaleiro (o cavalo fica idêntico, então a diferença é exatamente o
#     cavaleiro). O feminino repinta só a cabeça do masculino (o corpo é o mesmo,
#     a armadura serve nos dois).
#  3. Armadura do cavaleiro: pinturas localizadas na referência, uma peça por vez
#     (pernas, peitoral, elmo), cada uma só na sua região; escudo e lança são
#     objetos gerados à parte. Tudo isso é rígido: em cada quadro vai para a
#     posição da sela (o cavaleiro sobe e desce com o galope).
#  4. Caparação (deforma com o cavalo): pintada no galope 0 e depois em grades
#     2x2 de 512x320 (o quadro pronto como exemplo + 3 quadros a pintar), para o
#     pano sair igual em todos; só tecido e metal entram na camada.
#  5. Saída no formato do jogo: folhas por camada (cor original) com máscara de
#     cor da casa (R principal = tecido/pintura vermelha, G secundária = debrum
#     azul, B metal = aço), estágios de dano _d1.._d3, pontos do brasão.
#
# Tudo que vem do PixelLab fica em cache (tools/pixellab_cliente.py): rodar de novo
# não gasta geração. Saídas brutas em game/art/fontes/personagem/justa/.
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_cliente as p  # noqa: E402
from PIL import Image  # noqa: E402

RAIZ = p.RAIZ
FONTE = os.path.join(RAIZ, "game", "art", "fontes", "personagem", "justa")
PILOTO = os.path.join(RAIZ, "game", "art", "fontes", "personagem", "piloto")
SAIDA = os.path.join(RAIZ, "game", "art", "sprites", "personagem", "justa")
W, H = 256, 160
OX, OY = 80, 160          # origem do jogo dentro do quadro de trabalho
QUADRO = 160              # quadro das camadas no jogo (lança: 320)
N_GALOPE = 8
# Ordem dos quadros de trabalho: 0 = parado, 1..8 = galope.
ANIMS = {"parado": [0], "galope": list(range(1, 1 + N_GALOPE))}

SO_EDITAR = "; keep everything else exactly the same (same pose, same horse, same pixels elsewhere)"
ESTILO_OBJ = ("High-detail pixel art, dark medieval tone, gritty, visible wear, crisp pixel clusters, "
              "no anti-aliasing blur, 1 pixel dark outline, transparent background")
CORES = ("all cloth and painted surfaces are solid plain red, decorative trims are solid blue, "
         "steel parts are plain grey steel, leather is brown")

# Conjuntos: a descrição de cada peça (a cadeia de edição segue esta ordem).
ORDEM_PECAS = ["caparacao", "pernas", "peitoral", "elmo", "escudo", "lanca"]
PINTADAS = ["caparacao", "pernas", "peitoral", "elmo"]   # inpaint na referência
OBJETOS = ["escudo", "lanca"]                             # objetos rígidos
# Regiões (quadro de trabalho, referência = galope 0 do cavaleiro masculino):
# retângulos [x0, y0, x1, y1] onde cada peça pode ser pintada. O cavaleiro:
# cabeça x 86-100 y 31-46; tronco x 78-100 y 46-78; mão na rédea (102, 69);
# perna até a bota em y 120.
REGIOES = {
    "elmo": [[80, 16, 106, 50]],
    "peitoral": [[72, 42, 112, 86]],
    "pernas": [[78, 76, 110, 126]],
}
# Onde o cavaleiro é pintado sobre o cavalo (galope 0) e a cabeça (corpo feminino).
REGIAO_CAVALEIRO = [[56, 16, 110, 90], [64, 84, 102, 128]]
REGIAO_CABECA = [[68, 20, 98, 50]]
# Sela no galope 0 (o molde que localiza o cavaleiro em cada quadro).
SELA_MOLDE = [58, 74, 102, 102]
# Caparação: a silhueta do cavalo (dilatada) acima dos joelhos, menos o tronco do
# cavaleiro e o assento da sela (o pano passa por baixo da perna, que é pintada depois).
JOELHO_Y = 122
SELA = [64, 78, 96, 92]
TRONCO_Y = 86
# Âncoras dos objetos rígidos na referência: centro do escudo e a mão da lança.
ANCORA_ESCUDO = (85, 58)
ANCORA_LANCA = (100, 69)
TAM_ESCUDO = (17, 22)
CONJUNTOS = {
    "escudeiro": {
        "caparacao": "a simple plain cloth saddle blanket under the saddle",
        "pernas": "simple leather riding boots with small iron knee caps",
        "peitoral": "a padded leather jerkin with iron studs and simple leather shoulder guards over the gambeson",
        "elmo": "a simple open-faced iron kettle hat helmet",
        "escudo": "a small round wooden shield with an iron rim and boss held on the left arm, its face painted plain",
        "lanca": "a plain wooden jousting lance with a small iron tip, couched under the right arm and pointing forward",
    },
    "vigia": {
        "caparacao": "a cloth caparison draped over the horse's body down to the knees, and a steel chanfron plate on the horse's face",
        "pernas": "steel greaves and knee poleyns over mail leggings",
        "peitoral": "a riveted brigandine over mail with rounded steel pauldrons and steel arm guards",
        "elmo": "a rounded steel bascinet helmet with a closed snout-shaped visor and a mail aventail",
        "escudo": "a heater shield with a steel rim held on the left arm, its face painted plain",
        "lanca": "a long jousting lance with spiral painted stripes, a round steel vamplate hand guard and a blunt crown tip, couched under the right arm and pointing forward",
    },
    "cavaleiro_andante": {
        "caparacao": "a long flowing cloth caparison with a dagged hem covering the horse's body",
        "pernas": "mail chausses with steel knee cops",
        "peitoral": "a long mail hauberk under a cloth surcoat with a belt, steel shoulder discs",
        "elmo": "a flat-topped steel great helm with eye slits and breathing holes",
        "escudo": "a large heater shield with a steel rim held on the left arm, its face painted plain",
        "lanca": "a long plain wooden jousting lance with a steel vamplate, couched under the right arm and pointing forward",
    },
    "ferro_negro": {
        "caparacao": "dark blackened iron horse armor plates over the horse's neck and chest with a black iron chanfron, and a short cloth skirt",
        "pernas": "blackened dark iron plate leg armor",
        "peitoral": "blackened dark iron full plate cuirass with large angular pauldrons and plate arms",
        "elmo": "a blackened dark iron sallet helmet with a bevor covering the face and a narrow eye slit",
        "escudo": "a heavy dark iron heater shield with a thick black iron rim held on the left arm, its face painted plain",
        "lanca": "a dark wooden jousting lance with a black iron vamplate and a sharp black iron tip, couched under the right arm and pointing forward",
    },
    "guarda_real": {
        "caparacao": "a rich cloth caparison with decorative trims covering the horse, and a polished steel chanfron with a small plume",
        "pernas": "polished steel plate leg armor with fluted ridges",
        "peitoral": "a polished fluted steel plate cuirass with layered pauldrons, a cloth tabard over it with trims",
        "elmo": "a polished steel armet helmet with a pointed visor and a tall plume",
        "escudo": "a heater shield with a polished steel rim and decorative trim held on the left arm, its face painted plain",
        "lanca": "a long jousting lance painted with spiral stripes and trims, a polished steel vamplate, couched under the right arm and pointing forward",
    },
    "dragao": {
        "caparacao": "a cloth caparison with scalloped edges like dragon scales, and a steel chanfron shaped like a dragon head with small horns",
        "pernas": "steel leg armor made of overlapping scale plates",
        "peitoral": "steel armor made of overlapping dragon-scale plates with spiked pauldrons",
        "elmo": "a steel helmet shaped like a dragon head with horns and a fanged visor",
        "escudo": "a heater shield with a spiked steel rim shaped like dragon wings held on the left arm, its face painted plain",
        "lanca": "a jousting lance with a steel vamplate shaped like dragon scales and a fang-shaped tip, couched under the right arm and pointing forward",
    },
    "rei_sol": {
        "caparacao": "a regal cloth caparison with a gilded gold sun embroidered border, and a gilded gold chanfron with sun rays",
        "pernas": "ornate steel plate leg armor with gilded gold trim",
        "peitoral": "ornate steel plate cuirass with gilded gold sun motifs and gold-trimmed pauldrons",
        "elmo": "an ornate steel helmet with a gilded gold sun crown of rays",
        "escudo": "a heater shield with a gilded gold rim with sun rays held on the left arm, its face painted plain",
        "lanca": "a jousting lance with gilded gold spiral bands and a gold sun-shaped vamplate, couched under the right arm and pointing forward",
    },
}


# ------------------------------------------------------------------ util

def carregar(nome):
    return Image.open(os.path.join(FONTE, nome)).convert("RGBA")


def salvar(img, nome):
    os.makedirs(FONTE, exist_ok=True)
    img.save(os.path.join(FONTE, nome))


def tela(img):
    """Quadro 160x160 do cavalo -> quadro de trabalho 256x160 (origem igual)."""
    q = Image.new("RGBA", (W, H))
    q.alpha_composite(img, (0, 0))
    return q


def opaco(px):
    return px[3] >= 128


def dist(a, b):
    return abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])


def folha_de(nome):
    """Lista dos 9 quadros de trabalho salvos em <nome>_<i>.png."""
    return [carregar("%s_%d.png" % (nome, i)) for i in range(1 + N_GALOPE)]


def tem_folha(nome):
    return all(os.path.exists(os.path.join(FONTE, "%s_%d.png" % (nome, i))) for i in range(1 + N_GALOPE))


# --------------------------------------------------------------- etapas

def etapa_base():
    """Cavalo: galope (ciclo de 8 do piloto) e parado (fim do 'parar')."""
    ciclo = Image.open(os.path.join(PILOTO, "cavalo_ciclo_6_8.png")).convert("RGBA")
    parado = Image.open(os.path.join(PILOTO, "parar_8.png")).convert("RGBA")
    quadros = [tela(parado)] + [tela(ciclo.crop((160 * i, 0, 160 * i + 160, 160))) for i in range(N_GALOPE)]
    for i, q in enumerate(quadros):
        salvar(q, "cavalo_%d.png" % i)
    print("base: %d quadros" % len(quadros))


def transferir(ref, quadros, rotulo, instrucoes, seed=3):
    """transfer-outfit-v2 em lotes de 3 quadros; devolve a lista na mesma ordem."""
    saida = []
    lotes = [quadros[i:i + 3] for i in range(0, len(quadros), 3)]
    for n, lote in enumerate(lotes):
        if len(lote) == 1:  # o pedido exige 2 quadros: repete e descarta
            lote = lote + lote
            extra = True
        else:
            extra = False
        r = p.pedir("/transfer-outfit-v2", {"reference_image": p.referencia(ref), "frames": [p.quadro(c) for c in lote],
                                            "image_size": {"width": W, "height": H}, "seed": seed, "no_background": True,
                                            "additional_instructions": instrucoes}, rotulo="%s lote %d" % (rotulo, n))
        ims = p.imagens(r)
        saida += ims[:1] if extra else ims
        print("  %s lote %d/%d %s" % (rotulo, n + 1, len(lotes), r.get("_usage")))
    return saida


def mascara_retangulos(rets):
    m = Image.new("RGB", (W, H), (0, 0, 0))
    pm = m.load()
    for x0, y0, x1, y1 in rets:
        for y in range(max(0, y0), min(H, y1 + 1)):
            for x in range(max(0, x0), min(W, x1 + 1)):
                pm[x, y] = (255, 255, 255)
    return m


def pintar(imagem, mascara, descricao, seed, rotulo):
    """inpaint-v3 que só muda o que está dentro da máscara (o resto é recolado)."""
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


def etapa_cavaleiro(corpo):
    """Cavaleiro sem armadura pintado sobre o galope 0 (masculino; o feminino
    repinta só a cabeça do masculino)."""
    if corpo == "masculino":
        base = chave(carregar("cavalo_1.png"), "verde")
        desc = ("pixel art, a medieval rider seated upright in the saddle with the hips on the saddle seat, side view facing right, wearing a plain grey "
                "quilted gambeson, dark grey trousers and tall black leather riding boots, bare head with short dark hair, left hand holding "
                "the reins, right fist forward at the hip as if holding a lance, in proportion to the horse")
        ref = pintar(base, mascara_retangulos(REGIAO_CAVALEIRO), desc, 41, "cavaleiro masculino")
    else:
        base = carregar("ref_cavaleiro_masculino.png")
        desc = ("pixel art, the head of a young woman rider, side view facing right, long dark hair tied back in a braid, "
                "determined expression, same neck and collar of the grey gambeson")
        ref = pintar(base, mascara_retangulos(REGIAO_CABECA), desc, 43, "cavaleiro feminino")
    salvar(ref, "ref_cavaleiro_%s.png" % corpo)
    print("cavaleiro %s: ok" % corpo)


def recortar_pintura(novo, antes, rets, limiar=36):
    """Pixels da figura pintada dentro de `rets`: diferem de todo vizinho 3x3 do
    original (o pelo só redesenhado não conta), sem ruído, com buracos fechados."""
    pn, pa = novo.load(), antes.load()
    dentro = set()
    for x0, y0, x1, y1 in rets:
        for y in range(max(0, y0), min(H, y1 + 1)):
            for x in range(max(0, x0), min(W, x1 + 1)):
                dentro.add((x, y))
    cand = set()
    for (x, y) in dentro:
        c = pn[x, y]
        if c[3] < 128:
            continue
        menor = 999
        for a in (-1, 0, 1):
            for b in (-1, 0, 1):
                xx, yy = x + a, y + b
                if 0 <= xx < W and 0 <= yy < H:
                    d = pa[xx, yy]
                    menor = min(menor, dist(c, d) if d[3] >= 128 else 999)
        if menor > limiar:
            cand.add((x, y))
    cand = limpar(cand, 30)
    # Fecha buracos: o que não se alcança de fora da caixa, dentro da caixa, é da figura.
    if cand:
        xs = [x for x, _ in cand]; ys = [y for _, y in cand]
        bx0, by0, bx1, by1 = min(xs) - 1, min(ys) - 1, max(xs) + 1, max(ys) + 1
        fora, pilha = set(), [(bx0, by0)]
        while pilha:
            v = pilha.pop()
            if v in fora or v in cand or not (bx0 <= v[0] <= bx1 and by0 <= v[1] <= by1):
                continue
            fora.add(v)
            pilha += [(v[0] + 1, v[1]), (v[0] - 1, v[1]), (v[0], v[1] + 1), (v[0], v[1] - 1)]
        for y in range(by0, by1 + 1):
            for x in range(bx0, bx1 + 1):
                if (x, y) not in fora and (x, y) not in cand and (x, y) in dentro and pn[x, y][3] >= 128:
                    cand.add((x, y))
    return cand


def chave(img, cor):
    """Pinta a figura numa cor de recorte ('verde' ou 'magenta') mantendo a luz:
    o PixelLab vê a forma e o volume, e o que ele desenhar por cima sai em
    outras cores (separação exata, como fundo verde de cinema)."""
    out = img.copy()
    po = out.load()
    for y in range(img.height):
        for x in range(img.width):
            c = po[x, y]
            if c[3] < 128:
                continue
            l = (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255.0
            v = int(50 + l * 205)
            po[x, y] = (int(v * 0.12), v, int(v * 0.12), 255) if cor == "verde" else (v, int(v * 0.12), v, 255)
    return out


def e_chave(c):
    """O pixel é da cor de recorte (verde ou magenta)?"""
    if c[3] < 128:
        return True
    r, g, b = c[0], c[1], c[2]
    mx, mn = max(r, g, b), min(r, g, b)
    if mx < 40 or (mx - mn) / max(mx, 1) < 0.45:
        return False
    if g == mx and g > 1.6 * max(r, b):
        return True  # verde
    if r > 1.5 * g and b > 1.5 * g and abs(r - b) < 0.35 * mx:
        return True  # magenta
    return False


def recorte_chave(img, rets):
    """Pixels dentro de `rets` que não são da cor de recorte (a figura pintada)."""
    pi = img.load()
    out = set()
    for x0, y0, x1, y1 in rets:
        for y in range(max(0, y0), min(H, y1 + 1)):
            for x in range(max(0, x0), min(W, x1 + 1)):
                if not e_chave(pi[x, y]):
                    out.add((x, y))
    return limpar(out, 8)


PELAGENS = {
    "preto": "make the horse's coat jet black with subtle dark blue-grey highlights, and its mane and tail black",
    "branco": "make the horse's coat white with soft light grey shading, and its mane and tail white",
}


def etapa_pelagens():
    """Pelagens por tabela de cores: o PixelLab repinta o galope 0 e cada uma das
    cores do cavalo ganha a cor nova mais votada (sela e arreios ficam iguais).
    A tabela vale para todos os quadros (idêntico em todos, sem tremer)."""
    from collections import Counter, defaultdict
    base = carregar("cavalo_1.png")
    for nome, desc in PELAGENS.items():
        r = p.pedir("/edit-image-pixen", {"image": p.img_b64(base), "seed": 61,
                                          "description": desc + "; keep the saddle, saddle pad, bridle, reins, stirrups and hooves exactly the same" + SO_EDITAR,
                                          "no_background": True}, rotulo="pelagem " + nome)
        novo = p.imagens(r)[0]
        votos = defaultdict(Counter)
        pa, pn = base.load(), novo.load()
        for y in range(H):
            for x in range(W):
                if opaco(pa[x, y]) and opaco(pn[x, y]):
                    votos[pa[x, y][:3]][pn[x, y][:3]] += 1
        # O PixelLab diz o que é pelo (a cor mudou muito) e o que é sela/arreio (ficou);
        # o tom novo do pelo vem de uma rampa pela luz original, sempre na mesma ordem
        # de claro e escuro (sem manchas de reflexo nos outros quadros).
        tabela = {}
        for c, v in votos.items():
            alvo = v.most_common(1)[0][0]
            h, sa, va = _hsv(c)
            sombra_de_pelo = (h <= 15 or h >= 340) and 0.3 <= sa <= 0.62 and va > 0.06
            if dist(c, alvo) < 60 and not sombra_de_pelo:
                continue  # sela, arreio, ferragem: fica como está
            l = (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255.0
            if nome == "preto":
                t = 0.06 + 0.32 * l
                tabela[c] = (int(255 * t * 0.86), int(255 * t * 0.92), int(255 * min(1.0, t * 1.12)))
            else:
                t = 0.50 + 0.50 * l
                tabela[c] = (int(255 * t), int(255 * t), int(255 * min(1.0, t * 1.03)))
        for k in range(1 + N_GALOPE):
            img = carregar("cavalo_%d.png" % k)
            pi = img.load()
            for y in range(H):
                for x in range(W):
                    c = pi[x, y]
                    if opaco(c) and c[:3] in tabela:
                        pi[x, y] = tabela[c[:3]] + (c[3],)
            salvar(img, "cavalo_%s_%d.png" % (nome, k))
        print("pelagem %s: %d cores (%s)" % (nome, len(tabela), r.get("_usage")))


def casar_sela(img):
    """(dx, dy) da sela do galope 0 dentro de `img` (menor diferença de cor)."""
    ref = carregar("cavalo_1.png").load()
    x0, y0, x1, y1 = SELA_MOLDE
    molde = [(x, y, ref[x, y]) for y in range(y0, y1) for x in range(x0, x1) if ref[x, y][3] >= 128]
    pi = img.load()
    melhor = (10 ** 12, 0, 0)
    for dy in range(-18, 19):
        for dx in range(-18, 19):
            sad = 0
            for x, y, c in molde:
                xx, yy = x + dx, y + dy
                if 0 <= xx < W and 0 <= yy < H and pi[xx, yy][3] >= 128:
                    d = pi[xx, yy]
                    sad += abs(d[0] - c[0]) + abs(d[1] - c[1]) + abs(d[2] - c[2])
                else:
                    sad += 300
                if sad >= melhor[0]:
                    break
            if sad < melhor[0]:
                melhor = (sad, dx, dy)
    return melhor[1], melhor[2]


_SELA = {}


def sela(k):
    if k not in _SELA:
        _SELA[k] = casar_sela(carregar("cavalo_%d.png" % k))
    return _SELA[k]


def mascara_regiao(nome_peca, cav, cvl):
    """Imagem P/B (branco = pode pintar) da peça no quadro de referência."""
    m = Image.new("RGB", (W, H), (0, 0, 0))
    pm = m.load()
    if nome_peca == "caparacao":
        cavaleiro = limpar(mudou(cvl, cav), 12)
        pc = cav.load()
        horse = {(x, y) for y in range(H) for x in range(W) if opaco(pc[x, y])}
        dil = set(horse)
        for _ in range(3):
            dil |= {(x + a, y + b) for (x, y) in dil for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))}
        sx0, sy0, sx1, sy1 = SELA
        for (x, y) in dil:
            if not (0 <= x < W and 0 <= y < H) or y > JOELHO_Y:
                continue
            if (x, y) in cavaleiro and y < TRONCO_Y:
                continue
            if sx0 <= x <= sx1 and sy0 <= y <= sy1:
                continue
            pm[x, y] = (255, 255, 255)
        return m
    for x0, y0, x1, y1 in REGIOES[nome_peca]:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                pm[x, y] = (255, 255, 255)
    return m


def base_armadura():
    """Referência para pintar armadura: cavalo em verde, corpo em magenta."""
    ref = carregar("ref_cavaleiro_masculino.png")
    corpo = recorte_chave(ref, REGIAO_CAVALEIRO)
    pr = ref.load()
    so_corpo = Image.new("RGBA", (W, H))
    pc = so_corpo.load()
    for xy in corpo:
        pc[xy] = pr[xy]
    out = chave(carregar("cavalo_1.png"), "verde")
    out.alpha_composite(chave(so_corpo, "magenta"))
    return out


# Quanto a máscara de cada peça cresce além da silhueta do corpo (e para cima, no elmo).
FOLGA = {"pernas": 2, "peitoral": 3, "elmo": 3}
FOLGA_ACIMA = {"elmo": 10}


def mascara_silhueta(peca):
    """Silhueta do corpo dentro da região da peça, alargada: a pintura só pode
    vestir o corpo (não inventa pano sobre o cavalo)."""
    ref = carregar("ref_cavaleiro_masculino.png")
    corpo = recorte_chave(ref, REGIOES[peca])
    sil = set(corpo)
    for _ in range(FOLGA[peca]):
        sil |= {(x + a, y + b) for (x, y) in sil for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))}
    for _ in range(FOLGA_ACIMA.get(peca, 0)):
        sil |= {(x, y - 1) for (x, y) in sil}
    m = Image.new("RGB", (W, H), (0, 0, 0))
    pm = m.load()
    x0, y0, x1, y1 = REGIOES[peca][0]
    for (x, y) in sil:
        if 0 <= x < W and 0 <= y < H and x0 - 4 <= x <= x1 + 4 and y0 - 12 <= y <= y1 + 2:
            pm[x, y] = (255, 255, 255)
    return m


def etapa_conjunto(nome, so_refs=False):
    """Armadura do cavaleiro (pintura localizada sobre o corpo em magenta) e objetos."""
    pecas = CONJUNTOS[nome]
    atual = base_armadura()
    salvar(atual, "ref_%s_base.png" % nome)
    for i, peca in enumerate(["pernas", "peitoral", "elmo"]):
        desc = "pixel art, side view facing right, the rider wearing %s; %s" % (pecas[peca], CORES)
        mask = mascara_silhueta(peca)
        salvar(mask.convert("RGBA"), "mascara_%s.png" % peca)
        atual = pintar(atual, mask, desc, 200 + i, "%s %s" % (nome, peca))
        salvar(atual, "ref_%s_%s.png" % (nome, peca))
    objetos(nome)
    caparacao(nome)
    print("conjunto %s: ok" % nome)


def mascara_cavalo(k):
    """Silhueta do cavalo do quadro k (dilatada) até a altura dos joelhos."""
    cav = carregar("cavalo_%d.png" % k)
    pc = cav.load()
    dy = sela(k)[1]
    corpo = {(x, y) for y in range(H) for x in range(W) if opaco(pc[x, y])}
    dil = set(corpo)
    for _ in range(3):
        dil |= {(x + a, y + b) for (x, y) in dil for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))}
    m = Image.new("RGB", (W, H), (0, 0, 0))
    pm = m.load()
    for (x, y) in dil:
        if 0 <= x < W and 0 <= y < H and y <= JOELHO_Y + dy:
            pm[x, y] = (255, 255, 255)
    return m


def caparacao(nome):
    """Pintada no galope 0 (cavalo em verde) e nos demais quadros em grades 2x2:
    o quadro pronto fica num canto como exemplo e os outros três são pintados."""
    if all(os.path.exists(os.path.join(FONTE, "capa_%s_%d.png" % (nome, k))) for k in range(1 + N_GALOPE)):
        return
    desc = "pixel art, side view facing right, the horse wearing %s; %s" % (CONJUNTOS[nome]["caparacao"], CORES)
    ref = pintar(chave(carregar("cavalo_1.png"), "verde"), mascara_cavalo(1), desc, 210, "%s caparacao" % nome)
    salvar(ref, "capa_%s_1.png" % nome)
    resto = [k for k in range(1 + N_GALOPE) if k != 1]
    for n in range(0, len(resto), 3):
        lote = resto[n:n + 3]
        img = Image.new("RGBA", (2 * W, 2 * H))
        msk = Image.new("RGB", (2 * W, 2 * H), (0, 0, 0))
        img.alpha_composite(ref, (0, 0))
        cantos = [(W, 0), (0, H), (W, H)]
        for k, (cx, cy) in zip(lote, cantos):
            img.alpha_composite(chave(carregar("cavalo_%d.png" % k), "verde"), (cx, cy))
            msk.paste(mascara_cavalo(k), (cx, cy))
        desc_g = ("pixel art sprite sheet of the same horse in four gallop poses; paint the same caparison as the top-left horse "
                  "on every horse, identical design and colors: %s; %s" % (CONJUNTOS[nome]["caparacao"], CORES))
        r = p.pedir("/inpaint-v3", {"description": desc_g, "inpainting_image": p.quadro(img), "mask_image": p.quadro(msk.convert("RGBA")),
                                     "seed": 211 + n, "no_background": True, "crop_to_mask": True}, rotulo="%s caparacao grade %d" % (nome, n))
        novo = p.imagens(r)[0]
        if novo.size != img.size:
            novo = novo.resize(img.size, Image.NEAREST)
        print("  caparacao grade %d %s" % (n, r.get("_usage")))
        for k, (cx, cy) in zip(lote, cantos):
            base = chave(carregar("cavalo_%d.png" % k), "verde")
            parte = novo.crop((cx, cy, cx + W, cy + H))
            mk = mascara_cavalo(k).load()
            pb, pp = base.load(), parte.load()
            for y in range(H):
                for x in range(W):
                    if mk[x, y][0] > 127:
                        pb[x, y] = pp[x, y]
            salvar(base, "capa_%s_%d.png" % (nome, k))


# Lanças que vieram grossas demais foram refeitas num quadro mais baixo (haste fina).
ALTURA_LANCA = {"cavaleiro_andante": 24, "ferro_negro": 24}
SEMENTE_LANCA = {"cavaleiro_andante": 303, "ferro_negro": 303}


def objetos(nome):
    """Escudo (de frente, para o brasão) e lança (horizontal), gerados à parte."""
    pecas = CONJUNTOS[nome]
    if not os.path.exists(os.path.join(FONTE, "obj_escudo_%s.png" % nome)):
        forma = pecas["escudo"].replace(" held on the left arm", "").replace(", its face painted plain", "")
        r = p.pedir("/generate-image-pixflux", {
            "description": "%s, a single medieval jousting shield seen straight from the front, %s; the face is solid plain red with nothing painted on it, steel parts plain grey, trims solid blue" % (ESTILO_OBJ, forma),
            "negative_description": "emblem, symbol, cross, lion, text, person, hand, arm",
            "image_size": {"width": 64, "height": 64}, "no_background": True, "seed": 300,
            "detail": "highly detailed", "shading": "detailed shading", "outline": "single color black outline"},
            versao=1, assincrono=False, rotulo="escudo " + nome)
        img = p.imagens(r)[0]
        img = img.crop(img.getbbox())
        img.thumbnail(TAM_ESCUDO, Image.NEAREST)
        salvar(img, "obj_escudo_%s.png" % nome)
        print("  escudo %s %s" % (nome, r.get("usage")))
    if not os.path.exists(os.path.join(FONTE, "obj_lanca_%s.png" % nome)):
        r = p.pedir("/generate-image-pixflux", {
            "description": "%s, side view of %s lying perfectly horizontal, a long slender shaft that tapers toward the tip, the large round hand guard clearly visible near the left quarter, the tip pointing right, the grip and butt on the left" % (ESTILO_OBJ, pecas["lanca"].split(", couched")[0]),
            "negative_description": "person, hand, horse, diagonal, tilted, vertical",
            "image_size": {"width": 200, "height": ALTURA_LANCA.get(nome, 40)}, "no_background": True, "seed": SEMENTE_LANCA.get(nome, 302),
            "detail": "highly detailed", "shading": "detailed shading", "outline": "single color black outline"},
            versao=1, assincrono=False, rotulo="lanca " + nome)
        img = p.imagens(r)[0]
        img = img.crop(img.getbbox())
        salvar(img, "obj_lanca_%s.png" % nome)
        print("  lanca %s %s" % (nome, r.get("usage")))


def colar_objeto(img, obj, centro_x, centro_y):
    img.alpha_composite(obj, (int(centro_x - obj.width // 2), int(centro_y - obj.height // 2)))


def lanca_em(obj, mao_x, mao_y):
    """Lança no quadro de 320x160: a mão fica logo atrás da guarda (o disco, a
    coluna mais alta na metade de trás) e a ponta segue para a frente."""
    po = obj.load()
    alturas = [sum(1 for y in range(obj.height) if po[x, y][3] >= 128) for x in range(obj.width)]
    metade = max(1, obj.width // 2)
    disco = max(range(metade), key=lambda x: alturas[x])
    pega = max(0, disco - 4)
    meio = obj.height // 2
    q = Image.new("RGBA", (320, H))
    x0 = mao_x - pega
    corte = obj.crop((max(0, -x0), 0, obj.width, obj.height))
    q.alpha_composite(corte, (max(0, x0), mao_y - meio))
    return q


# ------------------------------------------------------------ separação

LIMIAR = 60  # diferença de cor (soma RGB) para "mudou"


def mudou(a, b):
    """Máscara (set de (x,y)) dos pixels opacos de a que diferem de b."""
    pa, pb = a.load(), b.load()
    m = set()
    for y in range(H):
        for x in range(W):
            c = pa[x, y]
            if not opaco(c):
                continue
            d = pb[x, y]
            if not opaco(d) or dist(c, d) > LIMIAR:
                m.add((x, y))
    return m


def limpar(m, minimo=6):
    """Tira componentes conexos pequenos (ruído de reamostragem)."""
    resto, out = set(m), set()
    while resto:
        s = resto.pop()
        comp, pilha = {s}, [s]
        while pilha:
            x, y = pilha.pop()
            for v in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if v in resto:
                    resto.discard(v)
                    comp.add(v)
                    pilha.append(v)
        if len(comp) >= minimo:
            out |= comp
    return out


def deslocamento(m, ref_m, raio_x=6, raio_y=14):
    """(dx, dy) que melhor sobrepõe a máscara m à ref_m."""
    melhor, arg = -1, (0, 0)
    for dy in range(-raio_y, raio_y + 1):
        for dx in range(-raio_x, raio_x + 1):
            n = sum(1 for (x, y) in m if (x - dx, y - dy) in ref_m)
            if n > melhor:
                melhor, arg = n, (dx, dy)
    return arg


def rotulos_ref(nome):
    """{(x,y): peça} da armadura do cavaleiro na referência: o que cada pintura
    tornou "não chave" (o corpo e o cavalo estavam em magenta e verde)."""
    anterior = carregar("ref_%s_base.png" % nome)
    rot = {}
    for peca in ["pernas", "peitoral", "elmo"]:
        atual = carregar("ref_%s_%s.png" % (nome, peca))
        pa, pb = atual.load(), anterior.load()
        mk = carregar("mascara_%s.png" % peca).load()
        for (x, y) in recorte_chave(atual, [[0, 0, W - 1, H - 1]]):
            if mk[x, y][0] < 128:
                continue
            antes = pb[x, y]
            if (x, y) in rot and not e_chave(antes) and dist(pa[x, y], antes) < 80:
                continue  # peça anterior só retocada
            if e_chave(antes) or dist(pa[x, y], antes) >= 40:
                rot[(x, y)] = peca
        anterior = atual
    return rot


def expandir(rot, raio):
    """Rótulo mais próximo (até `raio` px) para pixels sem rótulo."""
    out = dict(rot)
    borda = dict(rot)
    for _ in range(raio):
        nova = {}
        for (x, y), r in borda.items():
            for v in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if v not in out and v not in nova:
                    nova[v] = r
        out.update(nova)
        borda = nova
    return out


def desloc(k):
    """Deslocamento do cavaleiro no quadro k em relação ao galope 0 (pela sela)."""
    a, b = sela(k), sela(1)
    return a[0] - b[0], a[1] - b[1]


def separar(nome):
    """Camadas por peça e por quadro: {peca: [Image por quadro]} e os deslocamentos."""
    rot = rotulos_ref(nome)
    final = carregar("ref_%s_elmo.png" % nome).load()
    escudo = carregar("obj_escudo_%s.png" % nome)
    lanca = carregar("obj_lanca_%s.png" % nome)
    camadas = {pc: [] for pc in ORDEM_PECAS}
    desl = []
    for k in range(1 + N_GALOPE):
        dx, dy = desloc(k)
        desl.append((dx, dy))
        imgs = {pc: Image.new("RGBA", (W, H)) for pc in ORDEM_PECAS}
        pix = {pc: imgs[pc].load() for pc in ORDEM_PECAS}
        for (x, y), peca in rot.items():
            xx, yy = x + dx, y + dy
            if 0 <= xx < W and 0 <= yy < H:
                pix[peca][xx, yy] = final[x, y]
        capa = carregar("capa_%s_%d.png" % (nome, k))
        pcap = capa.load()
        mk = mascara_cavalo(k).load()
        for y in range(H):
            for x in range(W):
                if mk[x, y][0] > 127 and not e_chave(pcap[x, y]):
                    pix["caparacao"][x, y] = pcap[x, y]
        colar_objeto(imgs["escudo"], escudo, ANCORA_ESCUDO[0] + dx, ANCORA_ESCUDO[1] + dy)
        imgs["lanca"] = lanca_em(lanca, ANCORA_LANCA[0] + dx, ANCORA_LANCA[1] + dy)
        for pc in ORDEM_PECAS:
            camadas[pc].append(imgs[pc])
    return camadas, desl


def corpo_camadas(corpo):
    ref = carregar("ref_cavaleiro_%s.png" % corpo)
    pr = ref.load()
    pts = recorte_chave(ref, REGIAO_CAVALEIRO)
    out = []
    for k in range(1 + N_GALOPE):
        dx, dy = desloc(k)
        img = Image.new("RGBA", (W, H))
        pi = img.load()
        for (x, y) in pts:
            if 0 <= x + dx < W and 0 <= y + dy < H:
                pi[x + dx, y + dy] = pr[x, y]
        out.append(img)
    return out


# ------------------------------------------------- pele e cabelo do jogador

import colorsys  # noqa: E402

CABECA_COM_TRANCA = [64, 18, 100, 66]   # região da cabeça incluindo a trança


def _hsv(c):
    h, sa, v = colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)
    return h * 360, sa, v


def e_pele(c):
    h, sa, v = _hsv(c)
    return 5 <= h <= 40 and 0.15 <= sa <= 0.62 and v >= 0.42


MAOS = [94, 60, 110, 78]   # onde fica a mão da rédea (galope 0)


def separar_corpo(corpo):
    """Corpo do cavaleiro (galope 0) em três: pele (rosto e mãos), cabelo e o resto.
    Pele e cabelo saem em cinza normalizado: o jogo pinta com a pele e a cor de
    cabelo escolhidas na criação (materiais pele e cabelo)."""
    ref = carregar("ref_cavaleiro_%s.png" % corpo)
    pr = ref.load()
    pts = recorte_chave(ref, REGIAO_CAVALEIRO)
    x0, y0, x1, y1 = CABECA_COM_TRANCA

    def na(r, x, y):
        return r[0] <= x <= r[2] and r[1] <= y <= r[3]

    pele, cabelo = {}, set()
    escuros = set()
    for (x, y) in pts:
        c = pr[x, y]
        h, sa, v = _hsv(c)
        if (na(CABECA_COM_TRANCA, x, y) or na(MAOS, x, y)) and v >= 0.35 and sa >= 0.14 and (h <= 45 or h >= 350):
            pele[(x, y)] = c
        elif na(CABECA_COM_TRANCA, x, y) and v < 0.36:
            escuros.add((x, y))
    # Cabelo = áreas escuras preenchidas (o contorno de 1 px não sobrevive) + a borda delas.
    viz = ((1, 0), (-1, 0), (0, 1), (0, -1))
    miolo = {p for p in escuros if sum((p[0] + a, p[1] + b) in escuros for a, b in viz) >= 3}
    cabelo = miolo | {p for p in escuros if any((p[0] + a, p[1] + b) in miolo for a, b in viz)}
    cabelo = limpar({(x, y) for (x, y) in cabelo if y <= 48 or x <= 84}, 10)  # abaixo do pescoço, só a trança
    resto = {xy: pr[xy] for xy in pts if xy not in pele and xy not in cabelo}
    return {"pele": normalizar(pele, 0.62, 0.22), "cabelo": normalizar({xy: pr[xy] for xy in cabelo}, 0.5, 0.3), "resto": resto}


def normalizar(pixels, meio, faixa):
    """Cinza com o brilho reescalado: mediana -> `meio`, extremos -> meio±faixa."""
    if not pixels:
        return {}
    lum = sorted(0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2] for c in pixels.values())
    lo, med, hi = lum[int(len(lum) * 0.05)], lum[len(lum) // 2], lum[int(len(lum) * 0.95)]
    out = {}
    for xy, c in pixels.items():
        l = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
        if l >= med:
            t = meio + (l - med) / max(1.0, hi - med) * faixa
        else:
            t = meio - (med - l) / max(1.0, med - lo) * faixa
        g = max(0, min(255, int(round(t * 255))))
        out[xy] = (g, g, g, 255)
    return out


def camadas_de(pixels):
    """Folha de 9 quadros (deslocados pela sela) a partir de pixels do galope 0."""
    out = []
    for k in range(1 + N_GALOPE):
        dx, dy = desloc(k)
        img = Image.new("RGBA", (W, H))
        pi = img.load()
        for (x, y), c in pixels.items():
            if 0 <= x + dx < W and 0 <= y + dy < H:
                pi[x + dx, y + dy] = c
        out.append(img)
    return out


# --------------------------------------------------------- cor da casa

def classe_cor(c):
    """'principal' (vermelho), 'secundaria' (azul), 'metal' (aço) ou '' (original)."""
    r, g, b = c[0] / 255.0, c[1] / 255.0, c[2] / 255.0
    mx, mn = max(r, g, b), min(r, g, b)
    sat = 0.0 if mx == 0 else (mx - mn) / mx
    if mx - mn < 1e-6:
        h = 0.0
    elif mx == r:
        h = (60 * ((g - b) / (mx - mn))) % 360
    elif mx == g:
        h = 60 * ((b - r) / (mx - mn)) + 120
    else:
        h = 60 * ((r - g) / (mx - mn)) + 240
    if sat > 0.40 and mx > 0.22 and (h >= 340 or h <= 12):
        return "principal"
    if sat > 0.30 and mx > 0.20 and 195 <= h <= 260:
        return "secundaria"
    if sat < 0.18 and mx > 0.12:
        return "metal"
    return ""


MASCARA = {"principal": (255, 0, 0, 255), "secundaria": (0, 255, 0, 255), "metal": (0, 0, 255, 255)}


def mascara_de(img):
    m = Image.new("RGBA", img.size, (0, 0, 0, 255))
    pi, pm = img.load(), m.load()
    usada = False
    for y in range(img.height):
        for x in range(img.width):
            c = pi[x, y]
            if c[3] < 128:
                continue
            k = classe_cor(c)
            if k:
                pm[x, y] = MASCARA[k]
                usada = True
    return m if usada else None


# ------------------------------------------------------------- dano

def danificar(img, estagio, semente, desl):
    """Riscos (1), amassados (2), rachaduras e lascas (3) desenhados na peça,
    nos mesmos lugares em todos os quadros (seguem o deslocamento do cavaleiro)."""
    out = img.copy()
    po = out.load()
    rng = random.Random(semente)
    pts = [(x, y) for y in range(img.height) for x in range(img.width) if img.getpixel((x, y))[3] >= 128]
    if not pts:
        return out
    dx, dy = desl
    # As marcas são sorteadas no espaço do quadro 0 (sem deslocamento) e movidas.
    base = [(x - dx, y - dy) for (x, y) in pts]
    conj = set(pts)

    def tom(c, f):
        return (max(0, min(255, int(c[0] * f))), max(0, min(255, int(c[1] * f))), max(0, min(255, int(c[2] * f))), c[3])

    def ponto(x, y, f):
        xx, yy = x + dx, y + dy
        if (xx, yy) in conj:
            po[xx, yy] = tom(po[xx, yy], f)

    n_riscos = 2 + estagio * 2
    for _ in range(n_riscos):
        x0, y0 = rng.choice(base)
        ang = rng.uniform(-0.6, 0.6) + (0 if rng.random() < 0.5 else math.pi / 2)
        comp = rng.randint(3, 6)
        for t in range(comp):
            ponto(int(round(x0 + math.cos(ang) * t)), int(round(y0 + math.sin(ang) * t)), 1.45)
    if estagio >= 2:
        for _ in range(2 + estagio):
            x0, y0 = rng.choice(base)
            for ox in range(-1, 2):
                for oy in range(-1, 2):
                    ponto(x0 + ox, y0 + oy, 0.62 if (ox, oy) != (0, 0) else 0.45)
            ponto(x0 - 1, y0 - 2, 1.35)
    if estagio >= 3:
        x0, y0 = rng.choice(base)
        x, y = x0, y0
        for _ in range(9):
            ponto(x, y, 0.25)
            x += rng.choice((-1, 0, 1))
            y += 1
        # lasca: alguns pixels da borda somem
        bordas = [(x, y) for (x, y) in pts if any((x + a, y + b) not in conj for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
        rng2 = random.Random(semente + 7)
        if bordas:
            cx, cy = rng2.choice([(x - dx, y - dy) for (x, y) in bordas])
            for (x, y) in pts:
                if (x - dx - cx) ** 2 + (y - dy - cy) ** 2 <= 4:
                    po[x, y] = (0, 0, 0, 0)
    return out


# ------------------------------------------------------------- saída

def recortar(img, largura=QUADRO):
    return img.crop((0, 0, largura, H))


def escrever_folha(quadros, arquivo, largura=QUADRO, com_mascara=True):
    folha = Image.new("RGBA", (largura * len(quadros), H))
    for i, q in enumerate(quadros):
        folha.alpha_composite(recortar(q, largura) if q.width >= largura else q, (largura * i, 0))
    os.makedirs(SAIDA, exist_ok=True)
    folha.save(os.path.join(SAIDA, arquivo + ".png"))
    masc = os.path.join(SAIDA, arquivo + "_mascara.png")
    if com_mascara:
        m = mascara_de(folha)
        if m:
            m.save(masc)
            return
    if os.path.exists(masc):
        os.remove(masc)


def lanca_larga(img):
    """Lança: quadro 320x160 com a mesma origem (o quadro de trabalho começa em x=0)."""
    if img.width == 320:
        return img
    q = Image.new("RGBA", (320, H))
    q.alpha_composite(img, (0, 0))
    return q


def exportar_base():
    cav = folha_de("cavalo")
    for anim, idx in ANIMS.items():
        escrever_folha([cav[i] for i in idx], "cavalo_alazao_" + anim, com_mascara=False)
    for pel in PELAGENS:
        if tem_folha("cavalo_" + pel):
            cp = folha_de("cavalo_" + pel)
            for anim, idx in ANIMS.items():
                escrever_folha([cp[i] for i in idx], "cavalo_%s_%s" % (pel, anim), com_mascara=False)
    cabelos = {"masculino": "1", "feminino": "2"}  # curto e trança (opcoes_criacao.json)
    for corpo in ("masculino", "feminino"):
        if not os.path.exists(os.path.join(FONTE, "ref_cavaleiro_%s.png" % corpo)):
            continue
        partes = separar_corpo(corpo)
        for nome_arq, pix in (("corpo_%s" % corpo, partes["resto"]), ("rosto_%s_1" % corpo, partes["pele"]),
                              ("cabelo_%s" % cabelos[corpo], partes["cabelo"])):
            cam = camadas_de(pix)
            for anim, idx in ANIMS.items():
                escrever_folha([cam[i] for i in idx], "%s_%s" % (nome_arq, anim), com_mascara=False)
    print("base exportada")


def exportar_conjunto(nome):
    camadas, desl = separar(nome)
    # O conjunto não tem item de perna: as grevas vão na camada do peitoral.
    for i in range(len(camadas["peitoral"])):
        junto = camadas["pernas"][i].copy()
        junto.alpha_composite(camadas["peitoral"][i])
        camadas["peitoral"][i] = junto
    del camadas["pernas"]
    for peca, quadros in camadas.items():
        larg = 320 if peca == "lanca" else QUADRO
        for anim, idx in ANIMS.items():
            qs = [lanca_larga(quadros[i]) if peca == "lanca" else quadros[i] for i in idx]
            escrever_folha(qs, "%s_%s_%s" % (peca, nome, anim), largura=larg)
            if peca in ("elmo", "peitoral", "escudo"):
                for e in (1, 2, 3):
                    sem = hash((nome, peca, e)) & 0xFFFF
                    danif = [danificar(quadros[i], e, 1000 * e + len(peca) + sum(map(ord, nome)), desl[i]) for i in idx]
                    escrever_folha(danif, "%s_%s_d%d_%s" % (peca, nome, e, anim))
    pontos_conjunto(nome, camadas)
    print("conjunto %s exportado" % nome)


def centro(img):
    pts = [(x, y) for y in range(img.height) for x in range(img.width) if img.getpixel((x, y))[3] >= 128]
    if not pts:
        return None
    return (sum(x for x, _ in pts) / len(pts), sum(y for _, y in pts) / len(pts))


def pontos_conjunto(nome, camadas):
    """Pontos do brasão por quadro (relativos à origem), guardados por conjunto."""
    out = {}
    for anim, idx in ANIMS.items():
        out[anim] = {}
        for ponto, peca in (("brasao", "escudo"), ("brasao_peito", "peitoral"), ("brasao_manta", "caparacao")):
            lst = []
            for i in idx:
                img = camadas[peca][i]
                if peca == "caparacao":
                    # Na anca: a parte de trás do pano, longe da perna do cavaleiro.
                    img = img.crop((0, 0, 62, H))
                c = centro(img)
                lst.append([int(round(c[0] - OX)), int(round(c[1] - OY))] if c else [0, 0])
            out[anim][ponto] = lst
    arq = os.path.join(FONTE, "pontos_%s.json" % nome)
    json.dump(out, open(arq, "w", encoding="utf-8"), indent=1)


def caixas_conjunto(nome):
    """Caixas (relativas à origem) de elmo, peitoral, escudo e cavalo no quadro de galope 1."""
    camadas, _ = separar(nome)
    cav = folha_de("cavalo")
    res = {}
    for peca in ("elmo", "peitoral", "escudo"):
        b = camadas[peca][1].getbbox()
        res[peca] = [b[0] - OX, b[1] - OY, b[2] - b[0], b[3] - b[1]] if b else None
    b = cav[1].getbbox()
    res["cavalo"] = [b[0] - OX, b[1] - OY, b[2] - b[0], b[3] - b[1]]
    return res


if __name__ == "__main__":
    etapa = sys.argv[1] if len(sys.argv) > 1 else ""
    arg = sys.argv[2] if len(sys.argv) > 2 else ""
    if etapa == "base":
        etapa_base()
    elif etapa == "cavaleiro":
        etapa_cavaleiro(arg)
    elif etapa == "refs":
        etapa_conjunto(arg, so_refs=True)
    elif etapa == "conjunto":
        etapa_conjunto(arg)
    elif etapa == "pelagens":
        etapa_pelagens()
    elif etapa == "exportar_base":
        exportar_base()
    elif etapa == "exportar":
        exportar_conjunto(arg)
    elif etapa == "caixas":
        print(json.dumps(caixas_conjunto(arg)))
    else:
        print(__doc__ if __doc__ else "etapas: base | cavaleiro <corpo> | refs <conj> | conjunto <conj> | exportar_base | exportar <conj> | caixas <conj>")
