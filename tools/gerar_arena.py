# Cenário da arena gerado no PixelLab, na mesma escala de pixel dos cavaleiros.
# Faixas largas (1280 px, mais que o máximo de uma geração) saem como panorama:
# o primeiro trecho por texto (pixflux) e cada trecho seguinte por pintura
# localizada (inpaint-v3) vendo os últimos 128 px do anterior, sem emenda.
# Rodar com `python -E -P tools/gerar_arena.py`. Saída em game/art/sprites/arena/.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_cliente as p  # noqa: E402
from PIL import Image  # noqa: E402

RAIZ = p.RAIZ
FONTE = os.path.join(RAIZ, "game", "art", "fontes", "arena")
SAIDA = os.path.join(RAIZ, "game", "art", "sprites", "arena")
ESTILO = ("High-detail pixel art, dark medieval tone, gritty and mature, muted earthy palette (iron grey, worn leather brown, "
          "mud, overcast sky), heraldic colors as the only saturated accents, rim light from an overcast sky, crisp pixel "
          "clusters, no anti-aliasing blur, side view, flat horizontal panorama")
NEG = "cartoon, chibi, cute, bright saturated colors, 3D render, blurry, text, watermark, anime, modern elements, perspective vanishing point"
TRECHO = 320
CONTEXTO = 128

FAIXAS = {
    "fundo": (194, False, [
        "a medieval tournament grandstand seen from the side: tiers of wooden benches packed with a cheering medieval crowd in muted clothes, an overcast grey sky above, the left end of the stands with a wooden support frame and a hanging heraldic banner",
        "more tiers of wooden benches packed with a medieval crowd, hanging heraldic banners in deep crimson and dark blue along the front rail, overcast sky above",
        "the central royal box of the tournament grandstand: a raised wooden box with a crimson cloth canopy and gold fringe, nobles seated, large heraldic banners, overcast sky above",
        "more tiers of wooden benches packed with a medieval crowd, hanging heraldic banners along the front rail, the right end of the stands with a wooden frame, overcast sky above",
    ]),
    "chao": (346, False, [
        "the ground of a medieval jousting list seen from the side and slightly above: trampled packed dirt and sand with hoof prints, scattered straw, small pebbles, subtle muddy patches",
    ] * 4),
    "cerca": (56, True, [
        "the tilt barrier of a medieval jousting list: a long low wooden fence of thick horizontal planks on sturdy posts, painted in faded alternating dark crimson and off-white stripes, worn and scratched",
    ] * 4),
}


def panorama(nome, altura_final, transparente, descricoes, seed):
    """Gera com altura múltipla de 4 (exigência do PixelLab) e corta no fim."""
    os.makedirs(FONTE, exist_ok=True)
    altura = (altura_final + 3) // 4 * 4
    total = TRECHO * len(descricoes)
    canvas = Image.new("RGBA", (total, altura))
    r = p.pedir("/generate-image-pixflux", {"description": ESTILO + ", " + descricoes[0], "negative_description": NEG,
                                            "image_size": {"width": TRECHO, "height": altura}, "no_background": transparente,
                                            "seed": seed, "detail": "highly detailed", "shading": "detailed shading",
                                            "outline": "selective outline"}, versao=1, assincrono=False, rotulo=nome + " 0")
    primeiro = p.imagens(r)[0].resize((TRECHO, altura), Image.NEAREST)
    canvas.alpha_composite(primeiro, (0, 0))
    print("  %s trecho 0 %s" % (nome, r.get("usage")))
    for i in range(1, len(descricoes)):
        x0 = i * TRECHO
        img = Image.new("RGBA", (CONTEXTO + TRECHO, altura))
        img.alpha_composite(canvas.crop((x0 - CONTEXTO, 0, x0, altura)), (0, 0))
        msk = Image.new("RGB", img.size, (0, 0, 0))
        msk.paste((255, 255, 255), (CONTEXTO, 0, CONTEXTO + TRECHO, altura))
        r = p.pedir("/inpaint-v3", {"description": ESTILO + ", continue the same scene to the right seamlessly: " + descricoes[i],
                                     "inpainting_image": p.quadro(img), "mask_image": p.quadro(msk.convert("RGBA")),
                                     "seed": seed + i, "no_background": transparente, "crop_to_mask": True}, rotulo="%s %d" % (nome, i))
        novo = p.imagens(r)[0]
        if novo.size != img.size:
            novo = novo.resize(img.size, Image.NEAREST)
        canvas.alpha_composite(novo.crop((CONTEXTO, 0, CONTEXTO + TRECHO, altura)), (x0, 0))
        print("  %s trecho %d %s" % (nome, i, r.get("_usage")))
    canvas = canvas.crop((0, 0, total, altura_final))
    canvas.save(os.path.join(FONTE, nome + ".png"))
    return canvas


def azulejo(nome, largura, altura_final, desc, seed, transparente=False):
    """Trecho que se repete sem emenda: gera, desloca meia largura (a emenda vai
    para o meio) e repinta só a faixa do meio vendo os dois lados."""
    altura = (altura_final + 3) // 4 * 4
    r = p.pedir("/generate-image-pixflux", {"description": ESTILO + ", " + desc, "negative_description": NEG,
                                            "image_size": {"width": largura, "height": altura}, "no_background": transparente,
                                            "seed": seed, "detail": "highly detailed", "shading": "detailed shading",
                                            "outline": "selective outline"}, versao=1, assincrono=False, rotulo=nome + " azulejo")
    t = p.imagens(r)[0].resize((largura, altura), Image.NEAREST)
    meio = largura // 2
    desloc = Image.new("RGBA", (largura, altura))
    desloc.alpha_composite(t.crop((meio, 0, largura, altura)), (0, 0))
    desloc.alpha_composite(t.crop((0, 0, meio, altura)), (largura - meio, 0))
    banda = 48
    msk = Image.new("RGB", (largura, altura), (0, 0, 0))
    msk.paste((255, 255, 255), (meio - banda // 2, 0, meio + banda // 2, altura))
    r = p.pedir("/inpaint-v3", {"description": ESTILO + ", the same scene continuing seamlessly: " + desc,
                                 "inpainting_image": p.quadro(desloc), "mask_image": p.quadro(msk.convert("RGBA")),
                                 "seed": seed + 1, "no_background": transparente, "crop_to_mask": True}, rotulo=nome + " emenda")
    novo = p.imagens(r)[0].resize((largura, altura), Image.NEAREST)
    pm, pn, pd = msk.load(), novo.load(), desloc.load()
    for y in range(altura):
        for x in range(largura):
            if pm[x, y][0] > 127:
                pd[x, y] = pn[x, y]
    out = desloc.crop((0, 0, largura, altura_final))
    out.save(os.path.join(FONTE, nome + "_azulejo.png"))
    return out


def repetir(tile, largura_total):
    out = Image.new("RGBA", (largura_total, tile.height))
    for x in range(0, largura_total, tile.width):
        out.alpha_composite(tile, (x, 0))
    return out


def fundo():
    """Arquibancada repetida e o camarote real no centro (bordas repintadas)."""
    h = 194
    tile = azulejo("arquibancada", 320, h, "a medieval tournament grandstand seen straight from the side: two tiers of wooden benches "
                   "under a plain wooden roof, packed with a medieval crowd in muted clothes, a front railing hung with small "
                   "heraldic pennants in deep crimson and dark blue, overcast grey sky above the roof", 731)
    pano = repetir(tile, 1280)
    hh = (h + 3) // 4 * 4
    r = p.pedir("/generate-image-pixflux", {"description": ESTILO + ", the royal box of a medieval tournament grandstand seen straight from the side: "
                                            "a raised wooden box under a crimson cloth canopy with gold fringe, the king and nobles seated, large "
                                            "heraldic banners hanging in front, overcast grey sky above",
                                            "negative_description": NEG, "image_size": {"width": 256, "height": hh}, "no_background": False,
                                            "seed": 741, "detail": "highly detailed", "shading": "detailed shading", "outline": "selective outline"},
                versao=1, assincrono=False, rotulo="camarote")
    cam = p.imagens(r)[0].resize((256, hh), Image.NEAREST).crop((0, 0, 256, h))
    x0 = 640 - 128
    pano.alpha_composite(cam, (x0, 0))
    # Bordas do camarote: repinta 40 px de cada lado vendo o camarote e a arquibancada.
    for borda in (x0, x0 + 256):
        a0 = borda - 160
        img = pano.crop((a0, 0, a0 + 320, h)).resize((320, hh)) if hh != h else pano.crop((a0, 0, a0 + 320, h))
        img = Image.new("RGBA", (320, hh)); img.alpha_composite(pano.crop((a0, 0, a0 + 320, h)), (0, 0))
        msk = Image.new("RGB", (320, hh), (0, 0, 0)); msk.paste((255, 255, 255), (140, 0, 180, hh))
        r = p.pedir("/inpaint-v3", {"description": ESTILO + ", blend the royal box into the grandstand seamlessly, wooden posts and crowd",
                                     "inpainting_image": p.quadro(img), "mask_image": p.quadro(msk.convert("RGBA")),
                                     "seed": 751 + borda, "no_background": False, "crop_to_mask": True}, rotulo="camarote borda %d" % borda)
        novo = p.imagens(r)[0].resize((320, hh), Image.NEAREST)
        pano.alpha_composite(novo.crop((140, 0, 180, h)), (a0 + 140, 0))
    return pano


def chao():
    tile = azulejo("terra", 320, 346, "seamless ground texture seen from above: trampled packed brown dirt and sand of a jousting list, "
                   "hoof prints, a few scattered straw bits and small pebbles, subtle darker muddy patches, no objects, no people, "
                   "no fences, no tents, uniform texture filling the whole image", 761)
    return repetir(tile, 1280)


def main():
    os.makedirs(SAIDA, exist_ok=True)
    for nome, func in (("fundo", fundo), ("chao", chao)):
        destino = os.path.join(SAIDA, nome + ".png")
        if not os.path.exists(destino):
            func().save(destino)
            print("ok %s" % nome)
    for n, (nome, (altura, transp, descs)) in enumerate(FAIXAS.items()):
        if nome != "cerca":
            continue
        destino = os.path.join(SAIDA, nome + ".png")
        if os.path.exists(destino):
            continue
        img = panorama(nome, altura, transp, descs, 700 + n * 10)
        img.save(destino)
        print("ok %s %s" % (nome, img.size))


if __name__ == "__main__":
    main()
