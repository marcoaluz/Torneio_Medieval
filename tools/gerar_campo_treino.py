# Arte da cena do campo de treino (PixelLab): o fundo do campo e os alvos de
# cada atributo do cavaleiro, em peças separadas para o jogo animar:
#   força      -> estafermo: poste + braço giratório (escudo numa ponta, saco na outra)
#   precisão   -> argola: poste com forca + a argola solta (sai voando no acerto)
#   equilíbrio -> obstáculo de tronco (o cavalo salta)
# Saída em game/art/sprites/campo_treino/. Só gera o que falta (apague para refazer).
# Rodar com `python -E -P tools/gerar_campo_treino.py` (gasta gerações).
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_cliente as p  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAIDA = os.path.join(RAIZ, "game", "art", "sprites", "campo_treino")
ESTILO = ("High-detail pixel art, dark medieval tone, gritty and mature, muted earthy palette (old timber, worn leather, "
          "iron grey, mud), crisp pixel clusters, no anti-aliasing blur, no outlines thicker than 1 pixel")
NEGATIVO = "cartoon, chibi, cute, 3D render, blurry, smooth gradients, text, watermark, modern elements, people, horse"

FUNDO = ("%s. Side view of a medieval jousting practice yard on an overcast afternoon: a long flat packed-dirt riding lane "
         "across the whole foreground, completely empty, a low wooden fence behind the lane, weapon racks with practice lances, "
         "straw bales and a small wooden shed in the background, muddy grass, distant trees and a castle wall, soft grey sky, "
         "no people, no horses, no targets in the lane, no text" % ESTILO)

PECAS = {
    # nome: (largura, altura, descrição)
    "estafermo_poste": (64, 112, "a single sturdy wooden quintain post standing upright on a small wooden cross base, "
                                  "an iron pivot cap at the very top, nothing attached, side view"),
    "estafermo_braco": (112, 40, "a single horizontal wooden beam floating in the air with no legs and no supports, a red heater shield "
                                 "hanging flat on its left end and a brown leather sack dangling on a short rope from its right end, "
                                 "an iron ring at the center of the beam, side view"),
    "argola_poste": (64, 112, "a tall wooden gallows-like ring post for lance practice, an upright pole on a cross base with a short "
                              "horizontal arm at the top reaching to the right and a small iron hook hanging at the arm's tip, side view"),
    "argola": (32, 32, "a single small iron ring for jousting ring practice, round metal hoop with a little leather loop, front view"),
    "tronco": (96, 40, "a low jumping obstacle for horses: two short wooden trestles holding a thick horizontal log, side view"),
}


def sem_pes(img):
    """O PixelLab insiste em pôr pés no braço do estafermo: apaga, nas pontas, o
    que passa acima e abaixo da viga (a linha quase toda opaca)."""
    w, h = img.size
    px = img.load()
    cheia = [y for y in range(h) if sum(1 for x in range(w) if px[x, y][3] > 0) > w * 0.8]
    y0, y1 = min(cheia), max(cheia)
    colunas = [x for x in range(w) if any(px[x, y][3] > 0 for y in range(0, y0 - 1))]
    grupos = []
    for x in colunas:
        if grupos and x == grupos[-1][-1] + 1:
            grupos[-1].append(x)
        else:
            grupos.append([x])
    for g in grupos:
        if g[-1] > w * 0.25 and g[0] < w * 0.75:
            continue  # o pino do meio e a alça da argola ficam
        for x in range(max(g[0] - 1, 0), min(g[-1] + 2, w)):
            for y in list(range(0, y0)) + list(range(y1 + 1, h)):
                px[x, y] = (0, 0, 0, 0)
    return img


def main():
    os.makedirs(SAIDA, exist_ok=True)
    arq = os.path.join(SAIDA, "fundo.png")
    if not os.path.exists(arq):
        r = p.pedir("/create-image-pixen", {"description": FUNDO, "image_size": {"width": 384, "height": 216},
                                            "seed": 1701, "detail": "highly detailed"}, rotulo="campo_fundo")
        p.imagens(r)[0].convert("RGBA").save(arq)
        print("ok fundo")
    for nome, (w, h, desc) in PECAS.items():
        arq = os.path.join(SAIDA, nome + ".png")
        if os.path.exists(arq):
            continue
        corpo = {"description": "%s, %s, transparent background" % (ESTILO, desc), "negative_description": NEGATIVO,
                 "image_size": {"width": w, "height": h}, "no_background": True, "view": "side",
                 "detail": "highly detailed", "shading": "detailed shading", "outline": "selective outline",
                 "seed": 1710 + sorted(PECAS).index(nome)}
        r = p.pedir("/generate-image-pixflux", corpo, versao=1, assincrono=False, rotulo="campo_" + nome)
        img = p.imagens(r)[0].convert("RGBA")
        if nome == "estafermo_braco":
            img = sem_pes(img)
        img.save(arq)
        print("ok", nome, img.getbbox())


if __name__ == "__main__":
    main()
