---
name: estilo-arte
description: Regras de arte do Torneio Medieval (pixel art sombria): prefixo de estilo e prefixo negativo para o PixelLab, tamanhos de quadro, camadas em tons de cinza, brasão separado, paleta da casa e como importar o resultado no Godot. Use SEMPRE que for gerar, pedir, revisar, nomear ou importar qualquer sprite, animação, ícone, prédio, retrato, arena ou interface do jogo, mesmo que o pedido nem mencione "estilo".
---

# Estilo de arte

O jogo inteiro precisa ter uma cara só, e a arte vem de várias gerações de IA e retoques. Por isso todo prompt de arte começa igual e toda peça segue as mesmas regras de encaixe. Detalhes e prompts prontos de cada peça (A1–A7, B1–B10, C1–C7) estão em `docs/PACOTE_DE_PROMPTS.md`; o design em `docs/GDD.md` (seção Equipamentos e direção de arte).

## Prompts (em inglês, os geradores respondem melhor)

Cole no início de TODO prompt do PixelLab:

```
High-detail pixel art, dark medieval tone, gritty and mature, muted
earthy palette (iron grey, worn leather brown, mud, overcast sky),
heraldic colors as the only saturated accents, rim light from an
overcast sky, visible wear, scratches and dirt on metal, cloth with
folds, crisp pixel clusters, no anti-aliasing blur, no outlines thicker
than 1 pixel, side view facing right, transparent background.
```

Prefixo negativo, quando a ferramenta aceitar:

```
cartoon, chibi, cute, bright saturated colors everywhere, 3D render,
blurry, smooth gradients, text, watermark, modern elements,
fantasy glowing armor, anime
```

Para prédios e vila (vista de cima) troque "side view facing right" por "top-down three-quarter view". Rival: "side view facing left" (ou espelhe depois, ver abaixo).

## Gerar pelo script

`python -I tools/gerar_arte.py --simular` lista o que falta; sem `--simular` gera (chave `PIXELLAB_API_KEY` em `.chaves.env`, fora do git). Cobre prédios da vila (cada estágio parte do anterior, mesma semente) e retratos da história, sempre com a **paleta do jogo forçada** (`color_image` montada de `paletas.json`: cores da casa, metais, neutros, peles, cabelos e `mundo`), para tudo combinar. Os estágios brutos ficam em `game/art/fontes/vila/` e `tools/montar_folhas_vila.gd` monta as folhas. Cores da casa sorteadas seguem a regra das tinturas (`paletas.json > tinturas`: metal com cor, nunca cor com cor).

## Tamanhos de quadro

Resolução base do jogo: **960×540** (ver `docs/DECISOES.md`). Em celulares mais largos a altura fica 540 e a largura cresce (20:9 → 1200, 21:9 → ~1260): o que é essencial cabe em 960×540, mas fundos e cenários precisam se estender até 1280 de largura.

| Uso | Quadro | Obs. |
| --- | --- | --- |
| Cavaleiro montado (justa) | 160×160 | animado, só vista lateral |
| Cavaleiro a pé (vila, treino) | 96×96 | animações curtas |
| Retrato em Equipamentos | 256×256 | parado ou respiração |
| Cavalo em Equipamentos | 256×192 | parado ou respiração |
| Ícone de peça | 64×64 | fundo transparente |
| Prédio da vila | 192×192 | 4 a 5 estágios |
| Retrato de NPC | 128×128 | 2 a 3 expressões |
| Fundo da arena | **1280×540** | 960×540 é a área segura; celulares até 21:9 mostram até ~1260 de largura. O Pacote dizia 640×360 |

Se o plano do PixelLab limitar o tamanho, gere no maior permitido mantendo a proporção. Confirme o máximo antes de gerar lotes.

## Regras de camada (o sistema de personagem depende disto)

- Peças de armadura e de cavalo saem em **tons de cinza**; o shader do jogo aplica cor principal, secundária e de metal da casa. Peça colorida quebra a troca de paleta.
- Todas as peças partem do mesmo esqueleto: mesma pose base, mesmo quadro, mesma posição do quadril. Peça fora do encaixe aparece deslocada em algum quadro da animação.
- O **brasão nunca vem desenhado na peça**: é camada separada, aplicada pelo jogo depois do espelhamento do rival (senão o símbolo sai invertido).
- O rival é o mesmo desenho espelhado e um pouco menor; não gere um segundo conjunto.
- Cada peça tem versão danificada em 3 estágios (riscada, amassada, rachada), mesmo quadro e posição.
- Sinais de jogo ficam no mundo (escudo brilha, cavalo bufa), não em círculos grandes de interface.

## Importar no Godot

- Pasta por tipo em `game/art/{sprites,tiles,ui,shaders}`. Nome: `entidade_estado.png` em minúsculas com sublinhado (`cavaleiro_galope.png`, `armadura_ferro_negro_peito.png`). Estágios de dano: sufixo `_d1`, `_d2`, `_d3`.
- Filtro nearest já é o padrão do projeto; não troque por textura. Sem mipmaps, compressão lossless.
- Animação como `SpriteFrames` a partir de folhas de quadros iguais; mesmo número de quadros em todas as camadas de uma animação.
- Depois de importar, valide com `/run-torneio-medieval` (`driver.sh shot <cena>`) e olhe o PNG: pixel borrado ou camada deslocada aparece logo.
- Retoque obrigatório antes de exportar: cavalo com a mesma altura em todos os quadros e a lança saindo sempre do mesmo ponto da mão. Se a IA errar a proporção, use a silhueta do Blender como referência e gere de novo.
