# Ícones das peças (48x48) recortados da própria arte das camadas, sem gastar
# geração: elmo, peitoral e escudo do retrato de Equipamentos; lança e
# caparação da justa. Um ícone por visual de conjunto e espaço:
# game/art/sprites/icones/<espaco>_<visual>.png (o jogo acha pelo modelo do item).
# Rodar com `python -E -P tools/gerar_icones_itens.py`.
import json
import os

from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(RAIZ, "game", "art", "sprites", "personagem")
SAIDA = os.path.join(RAIZ, "game", "art", "sprites", "icones")
LADO = 48


def quadro(arq, largura):
    return Image.open(arq).convert("RGBA").crop((0, 0, largura, Image.open(arq).height))


def icone(img, girar=0):
    img = img.crop(img.getbbox())
    if girar:
        img = img.rotate(girar, expand=True, resample=Image.NEAREST)
        img = img.crop(img.getbbox())
    escala = min((LADO - 4) / img.width, (LADO - 4) / img.height)
    if escala < 1:
        img = img.resize((max(1, int(img.width * escala)), max(1, int(img.height * escala))), Image.NEAREST)
    out = Image.new("RGBA", (LADO, LADO))
    out.alpha_composite(img, ((LADO - img.width) // 2, (LADO - img.height) // 2))
    return out


def main():
    os.makedirs(SAIDA, exist_ok=True)
    itens = json.load(open(os.path.join(RAIZ, "game", "data", "balance", "itens.json"), encoding="utf-8"))
    feitos = set()
    for m in itens["modelos"].values():
        esp, vis = m["espaco"], m["visual"]
        if (esp, vis) in feitos:
            continue
        if esp in ("elmo", "peitoral", "escudo"):
            arq = os.path.join(P, "equipamentos", "%s_%s_parado.png" % (esp, vis))
            larg = 256
            girar = 0
        elif esp == "lanca":
            arq = os.path.join(P, "justa", "lanca_%s_parado.png" % vis)
            larg = 320
            girar = 35  # a lança deitada vira diagonal, cabe no quadrado
        else:
            arq = os.path.join(P, "justa", "%s_%s_parado.png" % (esp, vis))
            larg = 160
            girar = 0
        if not os.path.exists(arq):
            continue
        icone(quadro(arq, larg), girar).save(os.path.join(SAIDA, "%s_%s.png" % (esp, vis)))
        feitos.add((esp, vis))
    print("ícones: %d" % len(feitos))


if __name__ == "__main__":
    main()
