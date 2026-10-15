# Personagem em camadas

Como o cavaleiro e o cavalo são montados no jogo, e como exportar as peças do PixelLab para encaixarem sem retrabalho. Decidido no prompt 2.1.

## Arquitetura

- **Uma camada por espaço de equipamento.** Cada camada é um `Sprite2D` com uma *folha de quadros*: todos os quadros da animação lado a lado, do mesmo tamanho. Todas as peças de um tamanho usam **o mesmo quadro e a mesma origem** (o chão entre as patas do cavalo, ou entre os pés na vila). Por isso uma peça desenhada sobre a base encaixa em qualquer corpo.
- **Esqueleto comum = mesma pose em cada quadro.** Não há ossos (`Skeleton2D`): pixel art detalhada deforma mal com ossos, e o PixelLab entrega quadros prontos. O "esqueleto" é a pose da base (corpo e cavalo), quadro a quadro; toda peça é desenhada por cima dela.
- **`CamadasPersonagem`** (`game/scripts/presentation/personagem/camadas_personagem.gd`) lê `game/data/personagem/camadas.json`, cria as camadas, toca a mesma animação em todas e põe **o mesmo quadro em todas ao mesmo tempo** (nunca saem de sincronia). Serve aos três tamanhos; só muda `tamanho`:

  | tamanho | quadro | origem | animações hoje |
  | --- | --- | --- | --- |
  | justa | 160×160 (lança 320×160) | (80, 160) | parado, galope |
  | vila | 96×96 | (48, 96) | parado, andar |
  | equipamentos | 256×256 | (128, 256) | parado, respirar |

- **Encaixes (justa).** Na justa, cada camada vai para um nó do `cavaleiro.tscn` (`Visual/Cavalo`, `Visual/Cavalo/Manta`, `Visual/Cavaleiro/Corpo`, `.../Peito`, `.../Capacete`, `.../Escudo`, `Visual/Lanca`). Esses nós são também as zonas da mira, os pontos dos efeitos e o que cai na derrubada: quem mexe neles mexe nas camadas de dentro. A camada é deslocada para a origem do quadro coincidir com a origem do cavaleiro.
- **Cores da casa por shader** (`game/art/shaders/paleta_casa.gdshader`). A peça vem em tons de cinza e o cinza vira um *mapa de gradiente* da cor: escuro = sombra, meio = a cor, claro = brilho. Materiais: `original` (não troca; o cavalo já vem na pelagem), `principal`, `secundaria`, `metal`, `neutro` (couro, madeira), `pele`, `cabelo`. Cada camada tem um material padrão em `camadas.json`. A **máscara** opcional (`..._mascara.png`, mesmo tamanho) pinta por pixel: vermelho = principal, verde = secundária, azul = metal; preto = material padrão da camada. As cores ficam em `game/data/personagem/paletas.json`.
- **Brasão separado.** É o nó `Visual/Cavaleiro/Escudo/Brasao`, que desfaz o espelhamento do rival (o símbolo nunca sai invertido). A cada quadro ele vai para o **ponto de encaixe** do brasão daquele quadro (`game/data/personagem/pontos.json`), então acompanha o escudo no sobe e desce do galope. A textura do brasão chega no 2.3.
- **Peças trocáveis.** Os arquivos têm chaves: `peitoral_{peitoral}` vira `peitoral_ferro_negro` com `vestir({"peitoral": "ferro_negro"})`. Peça sem arte (ou "nenhuma", como capa) simplesmente não aparece. Os estágios de dano (2.9) entram como variantes `_d1`, `_d2`, `_d3`.
- **Arte provisória** gerada por código (`tools/gerar_arte_provisoria.gd`) no mesmo formato, para provar o sistema; a arte real só substitui os PNG.

## Como exportar do PixelLab

1. **Comece pela base**, no tamanho final (B1, B3 do Pacote): corpo feminino e masculino só de gambeson, cavalo sem arreio em cada pelagem. Gere todos os quadros de cada animação **com o mesmo canvas** (160×160 na justa) e o chão no mesmo pixel (linha de baixo, x = 80).
2. **Cada peça sobre a base** (B4, B5): use a base como imagem de referência, "same canvas size and position", só a peça desenhada, fundo transparente, **em tons de cinza** (o jogo pinta). Nada de brasão desenhado na peça.
3. **Quadros**: o mesmo número de quadros em todas as camadas de uma animação (galope: hoje 4; o B3 pede 8, e então todas as peças do galope terão 8; mude `quadros` em `camadas.json`).
4. **Monte a folha**: os quadros lado a lado, da esquerda para a direita, sem espaço entre eles (no Aseprite: *Export Sprite Sheet → Horizontal Strip*, sem padding nem trim). A lança usa canvas mais largo (320×160) com a mesma origem.
5. **Máscara de cor (se a peça mistura tecido e metal)**: uma camada a mais no Aseprite, pintada em vermelho/verde/azul puros por cima das áreas (principal/secundária/metal), exportada como folha igual com o sufixo `_mascara`. Peça de um material só não precisa.
6. **Pontos de encaixe**: numa camada a mais, um pixel **vermelho puro** (#FF0000) no centro do escudo em cada quadro (brasão); verde puro (#00FF00) na ponta da lança (reservado). Exporte como `pontos_<animação>.png` e rode `tools/extrair_pontos.gd`.
7. **Nomes**: `game/art/sprites/personagem/<tamanho>/<camada>_<variante>_<animação>.png`, em minúsculas com sublinhado. Exemplos: `peitoral_ferro_negro_galope.png`, `peitoral_ferro_negro_galope_mascara.png`, `cavalo_preto_parado.png`, `peitoral_ferro_negro_galope_d2.png` (dano, 2.9).
8. **Retoque obrigatório** antes de exportar: cavalo com a mesma altura em todos os quadros, a lança saindo sempre do mesmo ponto da mão, sem pixel semitransparente na borda (o filtro é nearest).
9. **Depois de importar**: `tools/extrair_pontos.gd` (se houver pontos novos), `tests/personagem/camadas_check.gd` e uma captura da vitrine (`tests/personagem/vitrine.tscn`). Se a peça nova mudou o desenho das zonas de acerto, ajuste os retângulos em `game/data/balance/mira.json` para baterem com a arte.

## Geração automática no PixelLab (2026-10-15)

A arte do cavaleiro, do cavalo e dos 7 conjuntos foi gerada por script, nos três tamanhos, mantendo esta arquitetura de camadas. Ferramentas (rodar com `python -E -P`, o Pillow está na pasta do usuário):

- **Justa** — `tools/gerar_personagem.py` (`base`, `cavaleiro <corpo>`, `pelagens`, `conjunto <c>`, `exportar_base`, `exportar <c>`):
  - Cavalo: galope de 8 quadros (PixMiniMax, ciclo que fecha no mesmo quadro) e parado; quadro de trabalho 256×160 com a origem do jogo em (80, 160).
  - Cavaleiro e armadura são **rígidos**: pintados uma vez sobre o galope 0 e levados a cada quadro pela posição da sela (`casar_sela`), como em muitos jogos 2D.
  - **Recorte por cor**: o PixelLab pinta (inpaint-v3, só dentro da máscara) sobre o cavalo em verde e o corpo em magenta; o que não é verde nem magenta é a peça nova, separada sem ambiguidade.
  - Caparação (deforma com o cavalo): pintada em grades 2×2 de 512×320 com o quadro pronto num canto como exemplo.
  - Escudo (pequeno, no ombro, de frente para o brasão) e lança são objetos gerados à parte e presos ao braço e à mão.
  - Pelagens preto e branco: o PixelLab repinta um quadro só para dizer o que é pelo; o tom vem de uma rampa pela luz original (mesma em todos os quadros).
  - Pele e cabelo saem em camadas próprias, em cinza normalizado (materiais `pele` e `cabelo`): valem a pele e a cor de cabelo da criação. Cabelo 1 = curto, 2 = trança.
- **Vila (96) e retrato de Equipamentos (256)** — `tools/gerar_personagem_pe.py` (`base`, `conjunto`, `exportar`): caminhada de 8 quadros (PixMiniMax) e armadura de cada conjunto pintada na referência e levada à caminhada numa grade; a respiração do retrato é o tronco descendo 1 px.
- **Cor da casa**: as peças ficam na cor original com a máscara `_mascara` (vermelho = principal, verde = secundária, azul = metal; o resto, como couro, madeira e o dourado do Rei Sol, fica original). Os prompts pedem tecido vermelho, debrum azul e aço cinza para a máscara sair certa.
- **Dano** `_d1.._d3`: riscos, amassados e rachadura desenhados por código sobre a própria peça, nos mesmos lugares em todos os quadros.
- **Zonas da mira** (`mira.json` v3) medidas na arte nova; casos compartilhados e gravações regravados.
- Brutos e referências em `game/art/fontes/personagem/` (o cache das respostas fica fora do git). Para refazer uma peça: apague o bruto e rode a etapa de novo.
