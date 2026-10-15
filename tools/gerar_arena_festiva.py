# Arena festiva (clara), no estilo da imagem de referência do usuário: céu azul,
# arquibancada colorida, pistas de areia clara separadas por grama e cerca de
# madeira natural. Usa as mesmas rotinas de tools/gerar_arena.py (panorama,
# azulejo sem emenda) com outro estilo de prompt. A arte escura anterior fica
# guardada em game/art/fontes/arena/escura/.
# Arquibancada gerada; areia e cerca recoloridas da arte anterior (sem custo);
# grama gerada vista de cima. Rodar com `python -E -P tools/gerar_arena_festiva.py`.
import os
import random
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gerar_arena as g  # noqa: E402
from PIL import Image  # noqa: E402

g.ESTILO = ("High-detail pixel art, bright sunny medieval tournament festival, vibrant cheerful palette (clear sky blue, "
            "fresh grass green, warm light sand, saturated heraldic reds, blues, golds and purples), soft warm daylight, "
            "crisp pixel clusters, no anti-aliasing blur, side view, flat horizontal panorama")
g.NEG = "3D render, blurry, text, watermark, anime, modern elements, perspective vanishing point, dark, gloomy, night, overcast, rain"
g.FONTE = os.path.join(g.RAIZ, "game", "art", "fontes", "arena", "festiva")
SAIDA = g.SAIDA
GUARDA = os.path.join(g.RAIZ, "game", "art", "fontes", "arena", "escura")

# Faixas do chão (em px a partir do topo do chão, que começa em y=194 no mundo):
# pista do rival (pé em y=270 -> 76) e do jogador (y=340 -> 146); cerca 236-292 (42-98).
FAIXAS_CHAO = [("grama", 0, 16), ("areia", 16, 100), ("grama", 100, 124), ("areia", 124, 198), ("grama", 198, 346)]


def rampa(img, cores):
    """Recolore pela luz (luminância) numa rampa de cores: mantém o desenho, troca a paleta."""
    out = img.convert("RGBA").copy()
    px = out.load()
    n = len(cores) - 1
    for y in range(out.height):
        for x in range(out.width):
            r, g_, b, a = px[x, y]
            if a == 0:
                continue
            lum = (0.299 * r + 0.587 * g_ + 0.114 * b) / 255.0
            lum = min(max((lum - 0.08) / 0.55, 0.0), 1.0)  # a arte escura usa pouco da faixa: estica
            k = lum * n
            i0 = min(int(k), n - 1)
            f = k - i0
            c0, c1 = cores[i0], cores[i0 + 1]
            px[x, y] = (int(c0[0] + (c1[0] - c0[0]) * f), int(c0[1] + (c1[1] - c0[1]) * f), int(c0[2] + (c1[2] - c0[2]) * f), a)
    return out


AREIA = [(150, 112, 70), (196, 154, 98), (224, 190, 128), (240, 214, 160)]
MADEIRA = [(70, 44, 26), (118, 78, 44), (160, 112, 64), (196, 150, 96)]
GRAMA = [(52, 84, 38), (80, 120, 50), (112, 152, 62), (150, 182, 88)]  # verde calmo (a geração sai neon)


def fundo():
    """Arquibancada festiva repetida (o camarote gerado à parte destoava em escala e céu)."""
    arq = os.path.join(g.FONTE, "festa_arquibancada_azulejo.png")
    tile = Image.open(arq).convert("RGBA") if os.path.exists(arq) else g.azulejo(
        "festa_arquibancada", 320, 194, "a medieval tournament grandstand seen straight from the side: two tiers of "
        "wooden benches packed with a cheerful cheering crowd in colorful clothes with raised arms, colorful cloth "
        "bunting swags in blue, yellow, purple and red along the front rail, small heraldic shields, a few pennant "
        "flags on poles, bright blue sky with white clouds above the roof", 931)
    return g.repetir(tile, 1280)


def textura_grama():
    """Grama vista de cima, sem emenda (o pedido de lado desenhava paisagens inteiras)."""
    altura = 148
    r = g.p.pedir("/generate-image-pixflux", {"description": "pixel art seamless tileable texture seen straight from above, top-down: "
                  "short fresh bright green grass blades with small tufts and a few tiny yellow and white wildflowers, uniform pattern "
                  "filling the whole image edge to edge, crisp pixel clusters, no anti-aliasing",
                  "negative_description": "sky, horizon, clouds, people, horses, buildings, fence, stands, tents, trees, path, scene, perspective",
                  "image_size": {"width": 320, "height": altura}, "view": "high top-down", "no_background": False,
                  "seed": 981, "detail": "highly detailed", "shading": "flat shading", "outline": "lineless"},
                  versao=1, assincrono=False, rotulo="festa grama cima")
    t = g.p.imagens(r)[0].convert("RGBA").resize((320, altura), Image.NEAREST)
    t.save(os.path.join(g.FONTE, "festa_grama_cima.png"))
    return t


def chao():
    terra = Image.open(os.path.join(g.RAIZ, "game", "art", "fontes", "arena", "terra_azulejo.png")).convert("RGBA")
    areia = rampa(terra, AREIA)
    areia.save(os.path.join(g.FONTE, "festa_areia_rampa.png"))
    grama = rampa(textura_grama(), GRAMA)
    largura = 1280
    out = Image.new("RGBA", (largura, 346))
    rnd = random.Random(7)
    for tipo, y0, y1 in FAIXAS_CHAO:
        tile = g.repetir(areia if tipo == "areia" else grama, largura)
        for x in range(largura):
            # Borda irregular: tufos de grama avançam sobre a areia em colunas de 2 px.
            if x % 2 == 0:
                dy0 = rnd.randint(-3, 2) if tipo == "grama" and y0 > 0 else 0
                dy1 = rnd.randint(-2, 3) if tipo == "grama" and y1 < 346 else 0
            a, b = max(y0 + dy0, 0), min(y1 + dy1, 346)
            for y in range(a, b):
                out.putpixel((x, y), tile.getpixel((x % tile.width, y % tile.height)))
    return out


def cerca():
    """A cerca antiga (listrada) recolorida em madeira natural: mesma forma e altura."""
    return rampa(Image.open(os.path.join(GUARDA, "cerca.png")), MADEIRA)


def main():
    os.makedirs(g.FONTE, exist_ok=True)
    os.makedirs(GUARDA, exist_ok=True)
    for nome in ("fundo", "chao", "cerca"):
        atual = os.path.join(SAIDA, nome + ".png")
        guardado = os.path.join(GUARDA, nome + ".png")
        if os.path.exists(atual) and not os.path.exists(guardado):
            shutil.copy(atual, guardado)
    fundo().save(os.path.join(SAIDA, "fundo.png"))
    print("ok fundo")
    chao().save(os.path.join(SAIDA, "chao.png"))
    print("ok chao")
    cerca().save(os.path.join(SAIDA, "cerca.png"))
    print("ok cerca")


if __name__ == "__main__":
    main()
