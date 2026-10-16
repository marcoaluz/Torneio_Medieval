# Arte das peças novas do catálogo (itens.json com 110 modelos): os 4 conjuntos
# novos pelo pipeline normal (tools/gerar_personagem.py e gerar_personagem_pe.py)
# e as 55 peças avulsas pintadas e exportadas só no espaço delas (uma peça
# avulsa não precisa do conjunto inteiro):
#   elmo/peitoral: pintura localizada na justa (sobre o corpo em magenta), na
#                  vila (referência + caminhada em grade) e no retrato;
#   escudo:        um objeto gerado (o mesmo pedido serve os três tamanhos);
#   lança:         um objeto gerado (só a justa tem lança);
#   caparação:     pintada no galope e levada aos quadros em grades (só a justa).
# Rodar com `python -E -P tools/gerar_pecas_novas.py [visual ...]` (sem argumento:
# todas as que faltam). Gasta gerações; o cache evita pagar de novo.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gerar_personagem as g  # noqa: E402
import gerar_personagem_pe as pe  # noqa: E402
from PIL import Image  # noqa: E402

SPRITES = os.path.join(g.RAIZ, "game", "art", "sprites", "personagem")
ESCUDO = " held on the left arm, its face painted plain"
LANCA = ", couched under the right arm and pointing forward"

CONJUNTOS_NOVOS = {
    "falcao_justa": {
        "caparacao": "a light cloth caparison with a short feathered crest and a bright plume on the horse's head, trimmed edges",
        "pernas": "light polished steel greaves and knee cops",
        "peitoral": "a light tournament half-plate breastplate with small rounded pauldrons and a falcon-feather trim",
        "elmo": "a sleek steel jousting helm shaped like a falcon's head with a beak-like visor and swept-back wings",
        "escudo": "a small light freeshield with a curved steel rim shaped like falcon wings" + ESCUDO,
        "lanca": "a slender light precision jousting lance with feather-like fluting and a small steel vamplate" + LANCA,
    },
    "corvo_sombrio": {
        "caparacao": "a dark ragged cloth caparison with feather-like dagged edges and a blackened steel chanfron with a raven beak spike",
        "pernas": "blackened steel plate leg armor with small spikes at the knees",
        "peitoral": "blackened dark steel plate armor with spiked pauldrons and feather-shaped lames",
        "elmo": "a blackened dark steel helm with a raven-beak shaped visor and a crest of black feathers",
        "escudo": "a dark heater shield with a blackened steel rim shaped like raven wings" + ESCUDO,
        "lanca": "a dark jousting lance with blackened steel bands and a raven-wing vamplate" + LANCA,
    },
    "campeao_invicto": {
        "caparacao": "a royal cloth caparison with gold filigree borders and a gilded gold chanfron with a laurel crest",
        "pernas": "polished plate leg armor with gold filigree trim",
        "peitoral": "royal polished plate armor covered in gold filigree with laurel motifs and fluted pauldrons",
        "elmo": "a gilded gold champion's helm with a laurel wreath crest and a lion-face visor",
        "escudo": "a heater shield with a gilded gold rim with lion paws and laurel leaves" + ESCUDO,
        "lanca": "a ceremonial jousting lance with gilded gold spiral bands and a gold laurel vamplate" + LANCA,
    },
    "corcel_ancestral": {
        "caparacao": "an ancient pale ghostly cloth caparison with flowing ragged ends and a steel chanfron with curled ram horns",
        "pernas": "ancient steel leg armor with dragon-scale plates",
        "peitoral": "mythic steel dragon armor of overlapping scales with horned pauldrons",
        "elmo": "an ancient steel helm with large curled ram horns and a dragon-scale crest",
        "escudo": "a heater shield with a silver steel rim shaped like griffin wings and claws" + ESCUDO,
        "lanca": "an ancient dragon jousting lance with scale-patterned shaft and a fang-shaped steel vamplate" + LANCA,
    },
}

AVULSOS = {
    # elmo
    "grande_elmo": ("elmo", "a flat-topped steel great helm with narrow eye slits and breathing holes"),
    "sallet": ("elmo", "a steel sallet helmet with a long tail and a movable visor raised slightly"),
    "conico_nasal": ("elmo", "a conical steel helmet with a long nasal guard bar over the nose"),
    "barbuta": ("elmo", "a rectangular iron barbute helmet with a T-shaped face opening"),
    "bascinete_malha": ("elmo", "a pointed steel bascinet helmet with a mail aventail hanging over the shoulders"),
    "morriao": ("elmo", "a parade morion helmet with a tall curved comb and upturned brims"),
    "boca_de_sapo": ("elmo", "a heavy frog-mouth jousting helm with a protruding lower plate and a narrow sight slit"),
    "borgonheta": ("elmo", "a burgonet helmet with a peak, cheek plates and a reinforced eye visor"),
    "armet_polido": ("elmo", "a polished steel armet helmet with a rounded visor and a chin plate"),
    "pluma_real": ("elmo", "a steel tournament helm crowned with a tall royal plume of feathers"),
    "alado": ("elmo", "an ornate steel helmet with two spread metal wings on the sides"),
    # peitoral
    "cota_simples": ("peitoral", "a simple long mail hauberk shirt with a belt"),
    "couro_batido": ("peitoral", "a hardened boiled leather breastplate with riveted shoulder straps"),
    "aco_escovado": ("peitoral", "a brushed steel cuirass with simple rounded pauldrons"),
    "aco_fosco": ("peitoral", "a rustic matte steel cuirass with plain riveted plates"),
    "esmalte_heraldico": ("peitoral", "a steel breastplate with enamelled painted panels and trims"),
    "brigantina": ("peitoral", "a brigandine of overlapping riveted plates under cloth with steel shoulder guards"),
    "couraca_de_justa": ("peitoral", "a heavy rounded tilting cuirass with a lance rest hook on the right side"),
    "laminado": ("peitoral", "a flexible laminated breastplate made of horizontal steel bands"),
    "maximiliano": ("peitoral", "a fluted Maximilian full plate cuirass with ridged pauldrons and plate arms"),
    "ombreira_assimetrica": ("peitoral", "a steel breastplate with one large reinforced pauldron on the left shoulder"),
    "guardiao_do_sol": ("peitoral", "a steel cuirass with a radiant sun emblem embossed on the chest and golden trims"),
    # escudo
    "heater": ("escudo", "a classic heater shield with a steel rim" + ESCUDO),
    "quadriculado": ("escudo", "a heater shield with a checkered painted border band around the edge" + ESCUDO),
    "triangular": ("escudo", "a long narrow triangular shield with a steel rim" + ESCUDO),
    "aco_liso": ("escudo", "a plain polished steel heater shield with a thick steel rim" + ESCUDO),
    "paves": ("escudo", "a tall rectangular pavise shield with a raised central ridge" + ESCUDO),
    "oval": ("escudo", "an oval tournament shield with a steel rim" + ESCUDO),
    "borda_latao": ("escudo", "a heater shield with a reinforced brass-colored rim and rivets" + ESCUDO),
    "targe": ("escudo", "a round targe shield with a central steel boss and studs" + ESCUDO),
    "javali": ("escudo", "a heater shield with a steel boar-head boss in the center" + ESCUDO),
    "cruz_de_ferro": ("escudo", "a heater shield with iron cross-shaped reinforcement straps" + ESCUDO),
    "grande_torneio": ("escudo", "an ornate tournament heater shield with a decorated steel rim and corner fittings" + ESCUDO),
    # lança
    "competicao": ("lanca", "a standard wooden competition jousting lance with a plain steel vamplate" + LANCA),
    "estocada_curta": ("lanca", "a short thick jousting lance with a small round vamplate" + LANCA),
    "empunhadura_aco": ("lanca", "a jousting lance with a steel-reinforced grip and a steel vamplate" + LANCA),
    "treino_acolchoada": ("lanca", "a training jousting lance with a padded cloth-wrapped tip" + LANCA),
    "espiral": ("lanca", "a spiral fluted jousting lance with painted spiral bands" + LANCA),
    "fita_de_honra": ("lanca", "a jousting lance with a long honor ribbon tied near the vamplate" + LANCA),
    "penacho": ("lanca", "a decorated jousting lance with a feather plume at the base" + LANCA),
    "freixo": ("lanca", "a solid ash wood jousting lance with visible wood grain and a steel vamplate" + LANCA),
    "coronel": ("lanca", "a jousting lance with a three-pronged coronel crown tip and a steel vamplate" + LANCA),
    "aneis_de_metal": ("lanca", "a heavy elite jousting lance wrapped with steel rings along the shaft" + LANCA),
    "dupla_reforcada": ("lanca", "a very thick heavy tournament pole lance with double steel reinforcement bands" + LANCA),
    # caparação
    "azul_e_ouro": ("caparacao", "a full cloth caparison draped over the horse's body down to the knees with a decorative border"),
    "cla_rival": ("caparacao", "a full cloth caparison with large quartered panels and a trimmed hem"),
    "xadrez_real": ("caparacao", "a full cloth caparison with a checkered pattern and a trimmed border"),
    "malha_equina": ("caparacao", "light mail barding of steel rings covering the horse's neck and body"),
    "sol_nascente": ("caparacao", "a cloth caparison with a large rising sun pattern on the flank and rays along the hem"),
    "estandartes": ("caparacao", "a cloth caparison with small hanging banners along the sides"),
    "protecao_pernas": ("caparacao", "articulated steel leg guards on the horse's legs and a short cloth saddle blanket"),
    "peitoral_correntes": ("caparacao", "a leather horse peytral across the chest hung with metal chains and a saddle blanket"),
    "chanfrao": ("caparacao", "a steel chanfron head plate with a spike on the horse's face and a short saddle blanket"),
    "sela_segura": ("caparacao", "a large high-backed tournament saddle with a tall cantle and a padded saddle blanket"),
    "placas_equinas": ("caparacao", "full steel plate barding covering the horse's head, neck, chest and flanks"),
}


def existe_sprite(pasta, arquivo):
    return os.path.exists(os.path.join(SPRITES, pasta, arquivo + ".png"))


# ------------------------------------------------------------------ justa

def escrever_justa(esp, v, quadros, desl, dano):
    larg = 320 if esp == "lanca" else g.QUADRO
    for anim, idx in g.ANIMS.items():
        qs = [g.lanca_larga(quadros[i]) if esp == "lanca" else quadros[i] for i in idx]
        g.escrever_folha(qs, "%s_%s_%s" % (esp, v, anim), largura=larg)
        if dano:
            for e in (1, 2, 3):
                dan = [g.danificar(quadros[i], e, 1000 * e + len(esp) + sum(map(ord, v)), desl[i]) for i in idx]
                g.escrever_folha(dan, "%s_%s_d%d_%s" % (esp, v, e, anim))


def justa_corpo(v, esp, desc):
    """Elmo ou peitoral avulso: só a peça pintada sobre o corpo em magenta."""
    pintar = ["pernas", "peitoral"] if esp == "peitoral" else ["elmo"]
    atual = g.base_armadura()
    g.salvar(atual, "ref_%s_base.png" % v)
    for i, peca in enumerate(["pernas", "peitoral", "elmo"]):
        if peca in pintar:
            d = ("plain steel leg armor matching this armor: " + desc) if peca == "pernas" else desc
            texto = "pixel art, side view facing right, the rider wearing %s; %s" % (d, g.CORES)
            atual = g.pintar(atual, g.mascara_silhueta(peca), texto, 200 + i, "%s %s" % (v, peca))
        g.salvar(atual, "ref_%s_%s.png" % (v, peca))
    rot = g.rotulos_ref(v)
    final = g.carregar("ref_%s_elmo.png" % v).load()
    quadros, desl = [], []
    for k in range(1 + g.N_GALOPE):
        dx, dy = g.desloc(k)
        desl.append((dx, dy))
        img = Image.new("RGBA", (g.W, g.H))
        px = img.load()
        for (x, y), peca in rot.items():
            if peca in pintar and 0 <= x + dx < g.W and 0 <= y + dy < g.H:
                px[x + dx, y + dy] = final[x, y]
        quadros.append(img)
    escrever_justa(esp, v, quadros, desl, True)


def objeto_escudo(v):
    """Mesmo pedido que gerar_personagem.objetos (e gerar_personagem_pe.escudo usa o cache)."""
    g.CONJUNTOS.setdefault(v, {})["escudo"] = AVULSOS[v][1] if v in AVULSOS else CONJUNTOS_NOVOS[v]["escudo"]
    if not os.path.exists(os.path.join(g.FONTE, "obj_escudo_%s.png" % v)):
        g.CONJUNTOS[v].setdefault("lanca", "x" + LANCA)  # objetos() pede as duas chaves
        tinha_lanca = os.path.exists(os.path.join(g.FONTE, "obj_lanca_%s.png" % v))
        if not tinha_lanca:
            Image.new("RGBA", (4, 4)).save(os.path.join(g.FONTE, "obj_lanca_%s.png" % v))  # não gerar lança
        g.objetos(v)
        if not tinha_lanca:
            os.remove(os.path.join(g.FONTE, "obj_lanca_%s.png" % v))
    return g.carregar("obj_escudo_%s.png" % v)


def justa_escudo(v):
    obj = objeto_escudo(v)
    quadros, desl = [], []
    for k in range(1 + g.N_GALOPE):
        dx, dy = g.desloc(k)
        desl.append((dx, dy))
        img = Image.new("RGBA", (g.W, g.H))
        g.colar_objeto(img, obj, g.ANCORA_ESCUDO[0] + dx, g.ANCORA_ESCUDO[1] + dy)
        quadros.append(img)
    escrever_justa("escudo", v, quadros, desl, True)


def justa_lanca(v):
    g.CONJUNTOS.setdefault(v, {})["lanca"] = AVULSOS[v][1]
    g.CONJUNTOS[v].setdefault("escudo", "x" + ESCUDO)
    if not os.path.exists(os.path.join(g.FONTE, "obj_lanca_%s.png" % v)):
        Image.new("RGBA", (4, 4)).save(os.path.join(g.FONTE, "obj_escudo_%s.png" % v))  # não gerar escudo
        g.objetos(v)
        os.remove(os.path.join(g.FONTE, "obj_escudo_%s.png" % v))
    obj = g.carregar("obj_lanca_%s.png" % v)
    quadros = [g.lanca_em(obj, g.ANCORA_LANCA[0] + g.desloc(k)[0], g.ANCORA_LANCA[1] + g.desloc(k)[1]) for k in range(1 + g.N_GALOPE)]
    escrever_justa("lanca", v, quadros, [(0, 0)] * len(quadros), False)


def justa_caparacao(v):
    g.CONJUNTOS.setdefault(v, {})["caparacao"] = AVULSOS[v][1]
    g.caparacao(v)
    quadros = []
    for k in range(1 + g.N_GALOPE):
        capa = g.carregar("capa_%s_%d.png" % (v, k)).load()
        mk = g.mascara_cavalo(k).load()
        img = Image.new("RGBA", (g.W, g.H))
        px = img.load()
        for y in range(g.H):
            for x in range(g.W):
                if mk[x, y][0] > 127 and not g.e_chave(capa[x, y]):
                    px[x, y] = capa[x, y]
        quadros.append(img)
    escrever_justa("caparacao", v, quadros, [(0, 0)] * len(quadros), False)


# ----------------------------------------------------- vila e retrato (a pé)

def regiao(esp, sil, f):
    if esp == "elmo":
        return {(x, y) for (x, y) in sil if y <= f["pescoco"] + 2}
    return {(x, y) for (x, y) in sil if y >= f["pescoco"] - 2}


def pe_corpo(t, v, esp, desc):
    c = pe.CFG[t]
    lado = c["lado"]
    base = pe.carregar("corpo_%s_masculino_0.png" % t)
    folga = (2, max(3, lado // 24)) if esp == "elmo" else (3, 0)
    d = desc if esp == "elmo" else desc + ", with plain matching leg armor"
    texto = "pixel art, the standing knight wearing %s; %s" % (d, g.CORES)
    m = pe.mascara_de(regiao(esp, pe.silhueta(base), pe.faixas(base)), lado, *folga)
    atual = pe.pintar(pe.chaveado(base), m, texto, 520, "%s %s %s" % (t, v, esp))
    pe.salvar(atual, "peca_%s_%s_0.png" % (t, v))
    if c["caminhada"]:
        quadros = [pe.carregar("corpo_%s_masculino_%d.png" % (t, k)) for k in range(1, 1 + c["caminhada"])]
        col = 3
        lin = (len(quadros) + 1 + col - 1) // col
        img = Image.new("RGBA", (lado * col, lado * lin))
        msk = Image.new("RGB", (lado * col, lado * lin), (0, 0, 0))
        img.alpha_composite(atual, (0, 0))
        cantos = [((i % col) * lado, (i // col) * lado) for i in range(1, len(quadros) + 1)]
        for q, (cx, cy) in zip(quadros, cantos):
            img.alpha_composite(pe.chaveado(q), (cx, cy))
            msk.paste(pe.mascara_de(regiao(esp, pe.silhueta(q), pe.faixas(q)), lado, *folga), (cx, cy))
        desc_g = ("pixel art sprite sheet of the same knight walking; paint on every figure exactly the same %s as the top-left knight: "
                  "%s; %s" % ("helmet" if esp == "elmo" else "body armor", d, g.CORES))
        r = pe.p.pedir("/inpaint-v3", {"description": desc_g, "inpainting_image": pe.p.quadro(img), "mask_image": pe.p.quadro(msk.convert("RGBA")),
                                        "seed": 530, "no_background": True, "crop_to_mask": True}, rotulo="%s %s caminhada" % (t, v))
        novo = pe.p.imagens(r)[0]
        if novo.size != img.size:
            novo = novo.resize(img.size, Image.NEAREST)
        for k, (cx, cy) in enumerate(cantos, 1):
            pe.salvar(novo.crop((cx, cy, cx + lado, cy + lado)), "peca_%s_%s_%d.png" % (t, v, k))
    # Exportar: só a peça, por quadro.
    corpo_m = pe.quadros_corpo(t, "masculino")
    if c["caminhada"]:
        arm = [pe.carregar("peca_%s_%s_%d.png" % (t, v, k)) for k in range(1 + c["caminhada"])]
    else:
        arm = [atual, pe.respirar(atual, pe.faixas(base)["cintura"])]
    imgs = []
    for a, cm in zip(arm, corpo_m):
        f = pe.faixas(cm)
        pa = a.load()
        out = Image.new("RGBA", (lado, lado))
        po = out.load()
        for y in range(lado):
            for x in range(lado):
                cc = pa[x, y]
                if cc[3] < 128 or g.e_chave(cc):
                    continue
                if (esp == "elmo") == (y <= f["pescoco"]):
                    po[x, y] = cc
        imgs.append(out)
    escrever_pe(t, esp, v, imgs)


def pe_escudo(t, v):
    objeto_escudo(v)  # garante o pedido em cache e a descrição registrada
    pe.escudo(t, v)
    c = pe.CFG[t]
    lado = c["lado"]
    esc = pe.carregar("escudo_%s_%s.png" % (t, v))
    imgs = []
    for cm in pe.quadros_corpo(t, "masculino"):
        f = pe.faixas(cm)
        tronco = [(x, y) for (x, y) in pe.silhueta(cm) if f["pescoco"] <= y <= f["cintura"]]
        cx = min(x for x, _ in tronco) + int(lado * 0.02)
        cy = (f["pescoco"] + f["cintura"]) // 2 + int(lado * 0.04)
        e = Image.new("RGBA", (lado, lado))
        e.alpha_composite(esc, (cx - esc.width // 2, cy - esc.height // 2))
        imgs.append(e)
    escrever_pe(t, "escudo", v, imgs)


def escrever_pe(t, esp, v, imgs):
    for anim, idx in pe.CFG[t]["anims"].items():
        pe.escrever([imgs[i] for i in idx], "%s_%s_%s" % (esp, v, anim), t)
        for e in (1, 2, 3):
            dan = [g.danificar(imgs[i], e, 1000 * e + len(esp) + sum(map(ord, v)), (0, 0)) for i in idx]
            pe.escrever(dan, "%s_%s_d%d_%s" % (esp, v, e, anim), t)


# ------------------------------------------------------------------ fluxo

def fazer_avulso(v):
    esp, desc = AVULSOS[v]
    if existe_sprite("justa", "%s_%s_parado" % (esp, v)) and (esp in ("lanca", "caparacao") or all(existe_sprite(t, "%s_%s_parado" % (esp, v)) for t in ("vila", "equipamentos"))):
        return
    if esp in ("elmo", "peitoral"):
        justa_corpo(v, esp, desc)
        for t in ("vila", "equip"):
            pe_corpo(t, v, esp, desc)
    elif esp == "escudo":
        justa_escudo(v)
        for t in ("vila", "equip"):
            pe_escudo(t, v)
    elif esp == "lanca":
        justa_lanca(v)
    else:
        justa_caparacao(v)
    print("ok %s (%s)" % (v, esp))


def fazer_conjunto(nome):
    if all(existe_sprite(t, "elmo_%s_parado" % nome) for t in ("justa", "vila", "equipamentos")):
        return
    g.CONJUNTOS[nome] = CONJUNTOS_NOVOS[nome]
    g.etapa_conjunto(nome)
    g.exportar_conjunto(nome)
    for t in ("vila", "equip"):
        pe.etapa_conjunto(t, nome)
    print("ok conjunto %s (falta exportar vila/equip)" % nome)


def main():
    pedidos = sys.argv[1:] or (list(CONJUNTOS_NOVOS) + list(AVULSOS))
    conj = [n for n in pedidos if n in CONJUNTOS_NOVOS]
    for n in conj:
        fazer_conjunto(n)
    if conj:
        # gerar_personagem_pe.exportar refaz as folhas de todos os conjuntos de CONJUNTOS (determinístico).
        for n in CONJUNTOS_NOVOS:
            g.CONJUNTOS[n] = CONJUNTOS_NOVOS[n]
        for t in ("vila", "equip"):
            pe.exportar(t)
    for v in pedidos:
        if v in AVULSOS:
            fazer_avulso(v)


if __name__ == "__main__":
    main()
