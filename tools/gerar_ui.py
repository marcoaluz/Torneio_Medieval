# Interface do jogo gerada no PixelLab (generate-ui-v2): molduras que esticam sem
# deformar os cantos (9-slice no tema do Godot), peças da justa e ícones.
# Rodar com `python -E -P tools/gerar_ui.py <etapa>`:
#   gerar      pede o que falta (4 variações por peça; cache: não gasta de novo)
#   prancha    monta uma imagem com todas as variações numeradas (para escolher)
#   exportar   recorta a variação escolhida (ESCOLHA) em game/art/ui/ e faz os
#              estados do botão por código (sob o dedo, apertado, desligado)
# Todas com a mesma paleta (madeira escura, ferro, ouro velho) para combinar com
# a vila e o cavaleiro.
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_cliente as p  # noqa: E402
from PIL import Image, ImageDraw, ImageEnhance  # noqa: E402

RAIZ = p.RAIZ
FONTE = os.path.join(RAIZ, "game", "art", "fontes", "ui")
SAIDA = os.path.join(RAIZ, "game", "art", "ui")
PALETA = "dark brown wood, dark iron, muted old gold, deep crimson accents"
BASE = "pixel art medieval game UI, dark and gritty, crisp pixels, no text, no letters, front view, "

PECAS = {
    # nome: (largura, altura, descrição)
    "botao": (128, 40, "a horizontal button plank of dark weathered oak with small iron corner rivets and a thin worn gold trim line, flat empty center"),
    "painel": (160, 160, "a dialog window frame of dark leather and oak with iron corner brackets and a thin worn gold inner trim, dark empty interior"),
    "campo": (128, 32, "a recessed dark text input slot with a thin iron rim, very dark empty interior"),
    "aba": (112, 36, "a tab label shaped like a small hanging wooden sign with iron rivets, dark empty center"),
    "placar": (176, 52, "an ornate heraldic score plaque of dark iron with gold filigree corners, dark empty center"),
    "plaquinha": (208, 60, "a nameplate frame of dark oak and iron with a small round empty portrait slot on the left and a long empty name area"),
    "barra": (256, 24, "a long horizontal progress bar frame of dark iron with rivets at both ends, empty dark track inside"),
    "botao_habilidade": (64, 64, "a round medallion button of dark iron with an engraved gold rim, empty dark center"),
    "letreiro": (256, 48, "a heraldic banner ribbon of dark crimson cloth with frayed ends and gold trim, empty center for text"),
    "icone_ouro": (32, 32, "icon of a small stack of gold coins"),
    "icone_gema": (32, 32, "icon of a faceted crimson gemstone"),
    "icone_renome": (32, 32, "icon of a golden laurel wreath"),
    "icone_bau": (32, 32, "icon of a small iron-bound wooden treasure chest"),
    "icone_config": (32, 32, "icon of an iron cogwheel"),
    "icone_missoes": (32, 32, "icon of a rolled parchment scroll with a red wax seal"),
    "icone_ordem": (32, 32, "icon of a small heraldic war banner on a pole"),
    "icone_fragmentos": (32, 32, "icon of broken steel armor shards"),
    "icone_ferro": (32, 32, "icon of an iron ingot"),
    "icone_aco": (32, 32, "icon of a polished steel ingot"),
    "icone_sucata": (32, 32, "icon of a pile of rusty scrap metal"),
    "icone_chave": (32, 32, "icon of an old iron key"),
}

# Variação escolhida de cada peça (índice na prancha) e as bordas do 9-slice.
ESCOLHA = {}
BORDAS = {"botao": 12, "painel": 36, "campo": 8, "aba": 10, "placar": 16, "plaquinha": 16, "barra": 10, "letreiro": 20}


def arq(nome, i):
    return os.path.join(FONTE, "%s_%d.png" % (nome, i))


def gerar():
    os.makedirs(FONTE, exist_ok=True)
    for nome, (w, h, desc) in PECAS.items():
        if os.path.exists(arq(nome, 0)):
            continue
        r = p.pedir("/generate-ui-v2", {"description": BASE + desc, "image_size": {"width": w, "height": h},
                                        "seed": 7, "no_background": True, "color_palette": PALETA}, rotulo=nome)
        for i, im in enumerate(p.imagens(r)):
            im.save(arq(nome, i))
        print("ok %s (%s)" % (nome, r.get("usage_cost_usd")))


def prancha():
    linhas = []
    for nome in PECAS:
        ims = [Image.open(arq(nome, i)).convert("RGBA") for i in range(8) if os.path.exists(arq(nome, i))]
        if ims:
            linhas.append((nome, ims))
    esc = 2
    larg = max(sum(im.width * esc + 10 for im in ims) + 140 for _, ims in linhas)
    alt = sum(max(im.height for im in ims) * esc + 10 for _, ims in linhas)
    g = Image.new("RGBA", (larg, alt), (46, 40, 36, 255))
    d = ImageDraw.Draw(g)
    y = 0
    for nome, ims in linhas:
        d.text((4, y + 4), nome, fill=(255, 230, 150, 255))
        x = 140
        for i, im in enumerate(ims):
            g.alpha_composite(im.resize((im.width * esc, im.height * esc), Image.NEAREST), (x, y))
            d.text((x + 2, y + 2), str(i), fill=(120, 255, 120, 255))
            x += im.width * esc + 10
        y += max(im.height for im in ims) * esc + 10
    return g


def recortar(im):
    return im.crop(im.getbbox())


def sem_enfeite_no_meio(im, borda):
    """Borda de cima e de baixo sem o enfeite central (brasão, selo): copia um
    trecho liso da borda, junto do canto, por toda a largura entre os cantos.
    Assim o 9-slice estica sem repetir o enfeite."""
    out = im.copy()
    w, h = im.size
    liso = im.crop((borda, 0, borda + 6, borda))
    liso_b = im.crop((borda, h - borda, borda + 6, h))
    for x in range(borda, w - borda, 6):
        larg = min(6, w - borda - x)
        out.paste(liso.crop((0, 0, larg, borda)), (x, 0))
        out.paste(liso_b.crop((0, 0, larg, borda)), (x, h - borda))
    return out


def estados_botao(im):
    """Sob o dedo (um pouco mais claro), apertado (mais escuro, desce 1 px) e
    desligado (sem cor e escuro): do mesmo desenho, então combinam."""
    sob = ImageEnhance.Brightness(im).enhance(1.12)
    ap = ImageEnhance.Brightness(im).enhance(0.8)
    apertado = Image.new("RGBA", im.size)
    apertado.alpha_composite(ap, (0, 1))
    deslig = ImageEnhance.Brightness(ImageEnhance.Color(im).enhance(0.25)).enhance(0.7)
    return {"sob": sob, "apertado": apertado, "desligado": deslig}


def exportar():
    os.makedirs(SAIDA, exist_ok=True)
    escolha = json.load(open(os.path.join(FONTE, "escolha.json"), encoding="utf-8"))
    info = {}
    for nome in PECAS:
        i = int(escolha.get(nome, 0))
        if not os.path.exists(arq(nome, i)):
            print("  falta %s (gere de novo)" % nome)
            continue
        im = recortar(Image.open(arq(nome, i)).convert("RGBA"))
        if nome == "painel":
            im = sem_enfeite_no_meio(im, BORDAS["painel"])
        im.save(os.path.join(SAIDA, nome + ".png"))
        info[nome] = {"tamanho": list(im.size), "borda": BORDAS.get(nome, 0)}
        if nome == "plaquinha":
            im.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(SAIDA, nome + "_espelhada.png"))
        if nome in ("botao", "aba"):
            for estado, img in estados_botao(im).items():
                img.save(os.path.join(SAIDA, "%s_%s.png" % (nome, estado)))
    json.dump(info, open(os.path.join(SAIDA, "ui.json"), "w", encoding="utf-8"), indent=1)
    print("exportado: %d peças" % len(info))


if __name__ == "__main__":
    etapa = sys.argv[1] if len(sys.argv) > 1 else ""
    if etapa == "gerar":
        gerar()
    elif etapa == "prancha":
        prancha().save(sys.argv[2])
    elif etapa == "exportar":
        exportar()
