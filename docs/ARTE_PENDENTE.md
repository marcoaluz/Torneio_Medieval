# Arte pendente: campeões do PvE

Gerado em 2026-10-18 junto com os traços dos campeões. **Gerar gasta crédito do PixelLab: só com o aval do usuário.**

## Retratos (campeões × 3 expressões)

O jogo procura `game/art/sprites/retratos/{retrato}_{expressão}.png` (128×128) e, sem arte, mostra o provisório (quadro na cor da casa com o brasão e a inicial). Expressões: **neutro** (ficha do adversário), **debochado** (tela de duelo), **derrotado** (reservado para a derrota). O Rei Sancho usa o retrato `rei` da história e o Corvo usa `nemesis`; só faltam as expressões novas deles.

Para gerar tudo de uma vez (pula o que já existe):

```
python -I tools/gerar_arte.py --grupo campeoes --simular   # confere a lista, sem gastar
python -I tools/gerar_arte.py --grupo campeoes             # gera (gasta crédito)
python -I tools/gerar_arte.py --grupo campeoes --so martim_martelo   # só um
```

Configuração de cada pedido (igual à dos retratos da história): `/generate-image-pixflux`, 128×128, `view: side`, `detail: highly detailed`, `shading: detailed shading`, `outline: selective outline`, negativo da skill estilo-arte, `color_image` com a paleta do jogo mais as duas cores da casa, semente fixa por personagem.

Prefixo de estilo (vai antes de todo prompt):

> High-detail pixel art, dark medieval tone, gritty and mature, muted earthy palette (iron grey, worn leather brown, mud, overcast sky), heraldic colors as the only saturated accents, rim light from an overcast sky, visible wear, scratches and dirt, crisp pixel clusters, no anti-aliasing blur, no outlines thicker than 1 pixel

Negativo:

> cartoon, chibi, cute, bright saturated colors everywhere, 3D render, blurry, smooth gradients, text, watermark, modern elements, fantasy glowing armor, anime

| # | Arquivo | Campeão | Casa | Semente | Prompt (depois do prefixo) |
| --- | --- | --- | --- | --- | --- |
| 1 | `game/art/sprites/retratos/nemesis_derrotado.png` | Corvo de Ribanegra | preto_carvao/vermelho_sangue | 2003 | portrait bust, head and shoulders, facing right, a menacing knight called the Raven, black armor with crow feathers on the helm, visor up, cruel smile, defeated and humbled expression, bruised face, looking down, dented helmet, plain dark background |
| 2 | `game/art/sprites/retratos/campeao_valdemar_neutro.png` | Valdemar, o Campeão | ouro_velho/azul_real | 3000 | portrait bust, head and shoulders, facing right, a cocky village fair champion knight in his forties, blond moustache, open bascinet with the visor raised, old gold and royal blue surcoat, calm neutral expression, plain dark background |
| 3 | `game/art/sprites/retratos/campeao_valdemar_debochado.png` | Valdemar, o Campeão | ouro_velho/azul_real | 3000 | portrait bust, head and shoulders, facing right, a cocky village fair champion knight in his forties, blond moustache, open bascinet with the visor raised, old gold and royal blue surcoat, mocking smirk, one eyebrow raised, plain dark background |
| 4 | `game/art/sprites/retratos/campeao_valdemar_derrotado.png` | Valdemar, o Campeão | ouro_velho/azul_real | 3000 | portrait bust, head and shoulders, facing right, a cocky village fair champion knight in his forties, blond moustache, open bascinet with the visor raised, old gold and royal blue surcoat, defeated and humbled expression, bruised face, looking down, dented helmet, plain dark background |
| 5 | `game/art/sprites/retratos/martim_martelo_neutro.png` | Martim, o Martelo | azul_real/branco_osso | 3007 | portrait bust, head and shoulders, facing right, a burly brute of a knight with a broken nose and a shaved head, great helm under his arm, royal blue and bone-white tabard, calm neutral expression, plain dark background |
| 6 | `game/art/sprites/retratos/martim_martelo_debochado.png` | Martim, o Martelo | azul_real/branco_osso | 3007 | portrait bust, head and shoulders, facing right, a burly brute of a knight with a broken nose and a shaved head, great helm under his arm, royal blue and bone-white tabard, mocking smirk, one eyebrow raised, plain dark background |
| 7 | `game/art/sprites/retratos/martim_martelo_derrotado.png` | Martim, o Martelo | azul_real/branco_osso | 3007 | portrait bust, head and shoulders, facing right, a burly brute of a knight with a broken nose and a shaved head, great helm under his arm, royal blue and bone-white tabard, defeated and humbled expression, bruised face, looking down, dented helmet, plain dark background |
| 8 | `game/art/sprites/retratos/dama_isolda_gaviao_neutro.png` | Dama Isolda Gavião | verde_floresta/ouro_velho | 3004 | portrait bust, head and shoulders, facing right, a lean sharp-eyed lady knight with a hawk feather on her helm, hair tied back, forest green and old gold surcoat, calm neutral expression, plain dark background |
| 9 | `game/art/sprites/retratos/dama_isolda_gaviao_debochado.png` | Dama Isolda Gavião | verde_floresta/ouro_velho | 3004 | portrait bust, head and shoulders, facing right, a lean sharp-eyed lady knight with a hawk feather on her helm, hair tied back, forest green and old gold surcoat, mocking smirk, one eyebrow raised, plain dark background |
| 10 | `game/art/sprites/retratos/dama_isolda_gaviao_derrotado.png` | Dama Isolda Gavião | verde_floresta/ouro_velho | 3004 | portrait bust, head and shoulders, facing right, a lean sharp-eyed lady knight with a hawk feather on her helm, hair tied back, forest green and old gold surcoat, defeated and humbled expression, bruised face, looking down, dented helmet, plain dark background |
| 11 | `game/art/sprites/retratos/sir_egas_muro_neutro.png` | Sir Egas, o Muro | purpura/ouro_velho | 3012 | portrait bust, head and shoulders, facing right, a massive broad-shouldered knight with a thick black beard and a huge kite shield behind him, purple and old gold tabard, calm neutral expression, plain dark background |
| 12 | `game/art/sprites/retratos/sir_egas_muro_debochado.png` | Sir Egas, o Muro | purpura/ouro_velho | 3012 | portrait bust, head and shoulders, facing right, a massive broad-shouldered knight with a thick black beard and a huge kite shield behind him, purple and old gold tabard, mocking smirk, one eyebrow raised, plain dark background |
| 13 | `game/art/sprites/retratos/sir_egas_muro_derrotado.png` | Sir Egas, o Muro | purpura/ouro_velho | 3012 | portrait bust, head and shoulders, facing right, a massive broad-shouldered knight with a thick black beard and a huge kite shield behind him, purple and old gold tabard, defeated and humbled expression, bruised face, looking down, dented helmet, plain dark background |
| 14 | `game/art/sprites/retratos/conde_rodrigo_alvar_neutro.png` | Conde Rodrigo de Alvar | prata/azul_real | 3001 | portrait bust, head and shoulders, facing right, a haughty count with a trimmed grey goatee and a fur-trimmed cloak over polished armor, silver and royal blue heraldry, calm neutral expression, plain dark background |
| 15 | `game/art/sprites/retratos/conde_rodrigo_alvar_debochado.png` | Conde Rodrigo de Alvar | prata/azul_real | 3001 | portrait bust, head and shoulders, facing right, a haughty count with a trimmed grey goatee and a fur-trimmed cloak over polished armor, silver and royal blue heraldry, mocking smirk, one eyebrow raised, plain dark background |
| 16 | `game/art/sprites/retratos/conde_rodrigo_alvar_derrotado.png` | Conde Rodrigo de Alvar | prata/azul_real | 3001 | portrait bust, head and shoulders, facing right, a haughty count with a trimmed grey goatee and a fur-trimmed cloak over polished armor, silver and royal blue heraldry, defeated and humbled expression, bruised face, looking down, dented helmet, plain dark background |
| 17 | `game/art/sprites/retratos/sir_henrique_lamina_neutro.png` | Sir Henrique Lâmina | azul_real/branco_osso | 3014 | portrait bust, head and shoulders, facing right, a slim young knight with slicked dark hair and a thin scar on the cheek, elegant fluted armor, royal blue and bone-white, calm neutral expression, plain dark background |
| 18 | `game/art/sprites/retratos/sir_henrique_lamina_debochado.png` | Sir Henrique Lâmina | azul_real/branco_osso | 3014 | portrait bust, head and shoulders, facing right, a slim young knight with slicked dark hair and a thin scar on the cheek, elegant fluted armor, royal blue and bone-white, mocking smirk, one eyebrow raised, plain dark background |
| 19 | `game/art/sprites/retratos/sir_henrique_lamina_derrotado.png` | Sir Henrique Lâmina | azul_real/branco_osso | 3014 | portrait bust, head and shoulders, facing right, a slim young knight with slicked dark hair and a thin scar on the cheek, elegant fluted armor, royal blue and bone-white, defeated and humbled expression, bruised face, looking down, dented helmet, plain dark background |
| 20 | `game/art/sprites/retratos/dama_mafalda_tormenta_neutro.png` | Dama Mafalda Tormenta | verde_floresta/ouro_velho | 3005 | portrait bust, head and shoulders, facing right, a fierce northern lady knight with wild red hair and a storm-grey cloak, visor half lowered, forest green and old gold, calm neutral expression, plain dark background |
| 21 | `game/art/sprites/retratos/dama_mafalda_tormenta_debochado.png` | Dama Mafalda Tormenta | verde_floresta/ouro_velho | 3005 | portrait bust, head and shoulders, facing right, a fierce northern lady knight with wild red hair and a storm-grey cloak, visor half lowered, forest green and old gold, mocking smirk, one eyebrow raised, plain dark background |
| 22 | `game/art/sprites/retratos/dama_mafalda_tormenta_derrotado.png` | Dama Mafalda Tormenta | verde_floresta/ouro_velho | 3005 | portrait bust, head and shoulders, facing right, a fierce northern lady knight with wild red hair and a storm-grey cloak, visor half lowered, forest green and old gold, defeated and humbled expression, bruised face, looking down, dented helmet, plain dark background |
| 23 | `game/art/sprites/retratos/sir_bermudo_touro_neutro.png` | Sir Bermudo, o Touro | purpura/ouro_velho | 3011 | portrait bust, head and shoulders, facing right, a huge bull-necked knight with a horned helm and a thick red beard, purple and old gold tabard, calm neutral expression, plain dark background |
| 24 | `game/art/sprites/retratos/sir_bermudo_touro_debochado.png` | Sir Bermudo, o Touro | purpura/ouro_velho | 3011 | portrait bust, head and shoulders, facing right, a huge bull-necked knight with a horned helm and a thick red beard, purple and old gold tabard, mocking smirk, one eyebrow raised, plain dark background |
| 25 | `game/art/sprites/retratos/sir_bermudo_touro_derrotado.png` | Sir Bermudo, o Touro | purpura/ouro_velho | 3011 | portrait bust, head and shoulders, facing right, a huge bull-necked knight with a horned helm and a thick red beard, purple and old gold tabard, defeated and humbled expression, bruised face, looking down, dented helmet, plain dark background |
| 26 | `game/art/sprites/retratos/duque_afonso_montargil_neutro.png` | Duque Afonso de Montargil | prata/azul_real | 3006 | portrait bust, head and shoulders, facing right, a proud duke in gilded armor with a ducal coronet on his helm, clean-shaven, silver and royal blue heraldry, calm neutral expression, plain dark background |
| 27 | `game/art/sprites/retratos/duque_afonso_montargil_debochado.png` | Duque Afonso de Montargil | prata/azul_real | 3006 | portrait bust, head and shoulders, facing right, a proud duke in gilded armor with a ducal coronet on his helm, clean-shaven, silver and royal blue heraldry, mocking smirk, one eyebrow raised, plain dark background |
| 28 | `game/art/sprites/retratos/duque_afonso_montargil_derrotado.png` | Duque Afonso de Montargil | prata/azul_real | 3006 | portrait bust, head and shoulders, facing right, a proud duke in gilded armor with a ducal coronet on his helm, clean-shaven, silver and royal blue heraldry, defeated and humbled expression, bruised face, looking down, dented helmet, plain dark background |
| 29 | `game/art/sprites/retratos/sir_gil_implacavel_neutro.png` | Sir Gil, o Implacável | azul_real/branco_osso | 3013 | portrait bust, head and shoulders, facing right, a silent knight in plain blued-steel armor, closed visor with only cold eyes visible through the slit, royal blue and bone-white, calm neutral expression, plain dark background |
| 30 | `game/art/sprites/retratos/sir_gil_implacavel_debochado.png` | Sir Gil, o Implacável | azul_real/branco_osso | 3013 | portrait bust, head and shoulders, facing right, a silent knight in plain blued-steel armor, closed visor with only cold eyes visible through the slit, royal blue and bone-white, mocking smirk, one eyebrow raised, plain dark background |
| 31 | `game/art/sprites/retratos/sir_gil_implacavel_derrotado.png` | Sir Gil, o Implacável | azul_real/branco_osso | 3013 | portrait bust, head and shoulders, facing right, a silent knight in plain blued-steel armor, closed visor with only cold eyes visible through the slit, royal blue and bone-white, defeated and humbled expression, bruised face, looking down, dented helmet, plain dark background |
| 32 | `game/art/sprites/retratos/dama_brites_escarpa_neutro.png` | Dama Brites da Escarpa | verde_floresta/ouro_velho | 3002 | portrait bust, head and shoulders, facing right, a stern weathered lady knight with short grey hair and a heavy tower shield, forest green and old gold, calm neutral expression, plain dark background |
| 33 | `game/art/sprites/retratos/dama_brites_escarpa_debochado.png` | Dama Brites da Escarpa | verde_floresta/ouro_velho | 3002 | portrait bust, head and shoulders, facing right, a stern weathered lady knight with short grey hair and a heavy tower shield, forest green and old gold, mocking smirk, one eyebrow raised, plain dark background |
| 34 | `game/art/sprites/retratos/dama_brites_escarpa_derrotado.png` | Dama Brites da Escarpa | verde_floresta/ouro_velho | 3002 | portrait bust, head and shoulders, facing right, a stern weathered lady knight with short grey hair and a heavy tower shield, forest green and old gold, defeated and humbled expression, bruised face, looking down, dented helmet, plain dark background |
| 35 | `game/art/sprites/retratos/sir_tristao_ferro_velho_neutro.png` | Sir Tristão Ferro-Velho | purpura/ouro_velho | 3015 | portrait bust, head and shoulders, facing right, an old veteran knight with a white beard, many scars and patched old-fashioned armor, purple and old gold, calm neutral expression, plain dark background |
| 36 | `game/art/sprites/retratos/sir_tristao_ferro_velho_debochado.png` | Sir Tristão Ferro-Velho | purpura/ouro_velho | 3015 | portrait bust, head and shoulders, facing right, an old veteran knight with a white beard, many scars and patched old-fashioned armor, purple and old gold, mocking smirk, one eyebrow raised, plain dark background |
| 37 | `game/art/sprites/retratos/sir_tristao_ferro_velho_derrotado.png` | Sir Tristão Ferro-Velho | purpura/ouro_velho | 3015 | portrait bust, head and shoulders, facing right, an old veteran knight with a white beard, many scars and patched old-fashioned armor, purple and old gold, defeated and humbled expression, bruised face, looking down, dented helmet, plain dark background |
| 38 | `game/art/sprites/retratos/principe_fernando_aurora_neutro.png` | Príncipe Fernando de Aurora | prata/azul_real | 3008 | portrait bust, head and shoulders, facing right, a young arrogant prince with golden curls and an ornate sunburst helm, silver and royal blue heraldry, calm neutral expression, plain dark background |
| 39 | `game/art/sprites/retratos/principe_fernando_aurora_debochado.png` | Príncipe Fernando de Aurora | prata/azul_real | 3008 | portrait bust, head and shoulders, facing right, a young arrogant prince with golden curls and an ornate sunburst helm, silver and royal blue heraldry, mocking smirk, one eyebrow raised, plain dark background |
| 40 | `game/art/sprites/retratos/principe_fernando_aurora_derrotado.png` | Príncipe Fernando de Aurora | prata/azul_real | 3008 | portrait bust, head and shoulders, facing right, a young arrogant prince with golden curls and an ornate sunburst helm, silver and royal blue heraldry, defeated and humbled expression, bruised face, looking down, dented helmet, plain dark background |
| 41 | `game/art/sprites/retratos/sir_aurelio_invicto_neutro.png` | Sir Aurélio, o Invicto | azul_real/branco_osso | 3009 | portrait bust, head and shoulders, facing right, a legendary knight in his prime, a lance decorated with a hundred colored ribbons behind him, royal blue and bone-white, calm neutral expression, plain dark background |
| 42 | `game/art/sprites/retratos/sir_aurelio_invicto_debochado.png` | Sir Aurélio, o Invicto | azul_real/branco_osso | 3009 | portrait bust, head and shoulders, facing right, a legendary knight in his prime, a lance decorated with a hundred colored ribbons behind him, royal blue and bone-white, mocking smirk, one eyebrow raised, plain dark background |
| 43 | `game/art/sprites/retratos/sir_aurelio_invicto_derrotado.png` | Sir Aurélio, o Invicto | azul_real/branco_osso | 3009 | portrait bust, head and shoulders, facing right, a legendary knight in his prime, a lance decorated with a hundred colored ribbons behind him, royal blue and bone-white, defeated and humbled expression, bruised face, looking down, dented helmet, plain dark background |
| 44 | `game/art/sprites/retratos/dama_elvira_sangue_real_neutro.png` | Dama Elvira Sangue-Real | verde_floresta/ouro_velho | 3003 | portrait bust, head and shoulders, facing right, a cold aristocratic lady knight with pale skin, braided dark hair and a thin circlet, forest green and old gold, calm neutral expression, plain dark background |
| 45 | `game/art/sprites/retratos/dama_elvira_sangue_real_debochado.png` | Dama Elvira Sangue-Real | verde_floresta/ouro_velho | 3003 | portrait bust, head and shoulders, facing right, a cold aristocratic lady knight with pale skin, braided dark hair and a thin circlet, forest green and old gold, mocking smirk, one eyebrow raised, plain dark background |
| 46 | `game/art/sprites/retratos/dama_elvira_sangue_real_derrotado.png` | Dama Elvira Sangue-Real | verde_floresta/ouro_velho | 3003 | portrait bust, head and shoulders, facing right, a cold aristocratic lady knight with pale skin, braided dark hair and a thin circlet, forest green and old gold, defeated and humbled expression, bruised face, looking down, dented helmet, plain dark background |
| 47 | `game/art/sprites/retratos/sir_baltasar_escudo_ouro_neutro.png` | Sir Baltasar Escudo-de-Ouro | purpura/ouro_velho | 3010 | portrait bust, head and shoulders, facing right, a wealthy knight with a gleaming golden shield and rings over his gauntlets, purple and old gold, calm neutral expression, plain dark background |
| 48 | `game/art/sprites/retratos/sir_baltasar_escudo_ouro_debochado.png` | Sir Baltasar Escudo-de-Ouro | purpura/ouro_velho | 3010 | portrait bust, head and shoulders, facing right, a wealthy knight with a gleaming golden shield and rings over his gauntlets, purple and old gold, mocking smirk, one eyebrow raised, plain dark background |
| 49 | `game/art/sprites/retratos/sir_baltasar_escudo_ouro_derrotado.png` | Sir Baltasar Escudo-de-Ouro | purpura/ouro_velho | 3010 | portrait bust, head and shoulders, facing right, a wealthy knight with a gleaming golden shield and rings over his gauntlets, purple and old gold, defeated and humbled expression, bruised face, looking down, dented helmet, plain dark background |
| 50 | `game/art/sprites/retratos/rei_debochado.png` | Rei Sancho, o Justador | prata/azul_real | 2004 | portrait bust, head and shoulders, facing right, an old king who loves jousting, grey beard, golden crown, fur mantle over armor, mocking smirk, one eyebrow raised, plain dark background |
| 51 | `game/art/sprites/retratos/rei_derrotado.png` | Rei Sancho, o Justador | prata/azul_real | 2004 | portrait bust, head and shoulders, facing right, an old king who loves jousting, grey beard, golden crown, fur mantle over armor, defeated and humbled expression, bruised face, looking down, dented helmet, plain dark background |

## Peças de troféu (arte das camadas)

Peças só de aparência dadas na primeira vitória sobre cada campeão (`itens.json > pecas_trofeu`). Arte em camadas como as demais peças (skill estilo-arte e `docs/PERSONAGEM.md` > Geração automática), nos tamanhos justa (160), vila (96) e equipamentos (256), com máscara de cor. Hoje: as mantas usam uma caparação já desenhada (`visual_provisorio`); penachos e estandartes não aparecem no boneco até ter arte. O estandarte é uma camada nova (flâmula presa na lança): precisa entrar em `game/data/personagem/camadas.json`.

| Peça | Espaço | Campeão | Cores da casa | Descrição para a arte |
| --- | --- | --- | --- | --- |
| Estandarte do Rei das Feiras (`trofeu_campeao_valdemar`) | estandarte | Valdemar, o Campeão | ouro_velho/azul_real | long swallow-tailed pennon tied below the lance tip, in the house colors |
| Penacho do Sino (`trofeu_martim_martelo`) | cimeira | Martim, o Martelo | azul_real/branco_osso | tall plume crest on top of the helm in the house colors |
| Penacho de Penas de Gavião (`trofeu_dama_isolda_gaviao`) | cimeira | Dama Isolda Gavião | verde_floresta/ouro_velho | tall plume crest on top of the helm in the house colors |
| Manta da Porta Fechada (`trofeu_sir_egas_muro`) | caparacao | Sir Egas, o Muro | purpura/ouro_velho | full cloth horse caparison in the house colors with a wide border |
| Estandarte de Alvar (`trofeu_conde_rodrigo_alvar`) | estandarte | Conde Rodrigo de Alvar | prata/azul_real | long swallow-tailed pennon tied below the lance tip, in the house colors |
| Penacho de Aço (`trofeu_sir_henrique_lamina`) | cimeira | Sir Henrique Lâmina | azul_real/branco_osso | tall plume crest on top of the helm in the house colors |
| Manta da Tormenta (`trofeu_dama_mafalda_tormenta`) | caparacao | Dama Mafalda Tormenta | verde_floresta/ouro_velho | full cloth horse caparison in the house colors with a wide border |
| Manta do Touro (`trofeu_sir_bermudo_touro`) | caparacao | Sir Bermudo, o Touro | purpura/ouro_velho | full cloth horse caparison in the house colors with a wide border |
| Estandarte de Montargil (`trofeu_duque_afonso_montargil`) | estandarte | Duque Afonso de Montargil | prata/azul_real | long swallow-tailed pennon tied below the lance tip, in the house colors |
| Penacho Negro da Sombra (`trofeu_sir_gil_implacavel`) | cimeira | Sir Gil, o Implacável | azul_real/branco_osso | tall plume crest on top of the helm in the house colors |
| Estandarte do Rochedo (`trofeu_dama_brites_escarpa`) | estandarte | Dama Brites da Escarpa | verde_floresta/ouro_velho | long swallow-tailed pennon tied below the lance tip, in the house colors |
| Manta do Veterano (`trofeu_sir_tristao_ferro_velho`) | caparacao | Sir Tristão Ferro-Velho | purpura/ouro_velho | full cloth horse caparison in the house colors with a wide border |
| Penacho da Aurora (`trofeu_principe_fernando_aurora`) | cimeira | Príncipe Fernando de Aurora | prata/azul_real | tall plume crest on top of the helm in the house colors |
| Estandarte das Cem Fitas (`trofeu_sir_aurelio_invicto`) | estandarte | Sir Aurélio, o Invicto | azul_real/branco_osso | long swallow-tailed pennon tied below the lance tip, in the house colors |
| Manta de Sangue Real (`trofeu_dama_elvira_sangue_real`) | caparacao | Dama Elvira Sangue-Real | verde_floresta/ouro_velho | full cloth horse caparison in the house colors with a wide border |
| Estandarte Dourado (`trofeu_sir_baltasar_escudo_ouro`) | estandarte | Sir Baltasar Escudo-de-Ouro | purpura/ouro_velho | long swallow-tailed pennon tied below the lance tip, in the house colors |
| Penacho Real (`trofeu_rei_sancho_justador`) | cimeira | Rei Sancho, o Justador | prata/azul_real | tall plume crest on top of the helm in the house colors |

## Outros pendentes

- **Troféus da estante:** hoje cada lugar mostra o brasão do campeão num botão. Um troféu desenhado por campeão (taça, elmo ou lança quebrada sobre um pedestal, 64×64) deixaria a estante com cara de casa senhorial.
- **Voz do arauto (ElevenLabs, gasta crédito):** a tela de duelo usa a fala `senhoras_e_senhores`. Falas novas sugeridas: "Contra o campeão!" e "A revanche!" (entrariam em `game/data/audio/sons.json > voz > falas`).

## Prédios da vila redesenhados no estilo da arena (9 prédios, 4 a 5 estágios)

**Por quê:** os prédios atuais (`game/art/sprites/vila/*.png`) vêm de uma geração anterior: cada um tem uma base de terra recortada que parece uma ilha flutuante sobre a grama, e os telhados são todos marrons. A arena da justa (clara, saturada, madeira, bandeirolas vivas) é a referência. Até haver crédito, a vila já se aproxima disso por código: terreiro contínuo de terra sob cada prédio que cobre a borda da base, caminhos entre os prédios e telhados tingidos pelo shader `vivificar` com as cores abaixo (`game/data/vila/ambiente.json > paleta > telhados`). Quando a arte nova chegar, a base some e o tingimento por código pode ser desligado (`forca_telhado` 0), porque a telha já virá colorida.

**Como gerar** (gasta crédito do PixelLab: só com o aval do usuário; os estágios 2 a 5 usam o 1 como `init_image`, como em `tools/gerar_arte.py`): apagar `game/art/fontes/vila/<prédio>_*.png` do que for refazer, `python -I tools/gerar_arte.py --grupo vila --so <prédio>` depois de trocar os textos de `PREDIOS` e `ESTAGIOS` pelos prompts abaixo, e `bash .claude/skills/run-torneio-medieval/driver.sh script res://tools/montar_folhas_vila.gd` para montar as folhas. Conferir as capturas com `bash tools/capturar_menus.sh`.

**Prefixo de estilo** (antes de todo prompt; é o da skill `estilo-arte`, com a luz da arena):

> High-detail pixel art, dark medieval tone, gritty and mature, muted earthy palette (iron grey, worn leather brown, mud, overcast sky), heraldic colors as the only saturated accents, rim light from an overcast sky, visible wear, scratches and dirt, crisp pixel clusters, no anti-aliasing blur, no outlines thicker than 1 pixel, bright saturated daylight like a festive jousting arena (yellow-green grass, warm sand, light timber), vivid heraldic roof colors

**Sufixo obrigatório** (acaba com a base flutuante):

> single building only, top-down three-quarter view, sitting directly on flat ground with NO base, NO floating island, NO diorama block, NO dirt platform, NO terrain tile, NO cast shadow plate, transparent background, no trees, no people

**Negativo:**

> cartoon, chibi, cute, bright saturated colors everywhere, 3D render, blurry, smooth gradients, text, watermark, modern elements, fantasy glowing armor, anime, floating island, diorama base, terrain block, dirt platform, ground tile, cliff, trees, bushes, dull brown roof

Parâmetros de cada pedido: `/generate-image-pixflux`, `view: high top-down`, `no_background: true`, `detail: highly detailed`, `shading: detailed shading`, `outline: selective outline`, `color_image` com a paleta do jogo mais a cor do telhado. Tamanho de cada quadro: o de `vila.json > tamanho` × 1,3 / × 1,7 arredondado a 8 (ver `tamanho_predio`).

| Prédio | Estágios | Quadro | Cor do telhado | Prompt (depois do prefixo, antes do sufixo) |
| --- | --- | --- | --- | --- |
| Casa senhorial (`casa_senhorial`) | 5 | 192x160 | `#d8362f` (bright vermilion red) | a lord's manor house with a small tower and a banner pole, red roof tiles with a white trim |
| Estábulo (`estabulo`) | 4 | 168x136 | `#2f6bc4` (bright cobalt blue) | a horse stable with open stalls, hay bales and a fenced paddock, blue shingle roof |
| Campo de treino (`campo_treino`) | 4 | 184x136 | `#3f9a4a` (leaf green) | a jousting practice shed with a wooden quintain, weapon rack and a fence, green shingle roof |
| Ferreiro (`ferreiro`) | 4 | 144x128 | `#6a7a96` (slate blue-grey) | a blacksmith workshop with a stone forge chimney, anvil and bellows under a slate blue-grey roof |
| Arena de torneios (`arena`) | 5 | 224x168 | `#8a45b0` (violet purple) | a small jousting arena with a tilt barrier, wooden stands and pennants, violet and white striped canvas roof |
| Loja (`loja`) | 4 | 144x128 | `#f0bf30` (golden yellow) | a merchant stall shop with a golden yellow and white striped awning, crates and barrels |
| Salão da liga (`salao_liga`) | 4 | 160x136 | `#d8362f` (bright vermilion red) | a guild hall of champions with heraldic banners and a stone entrance, bright red roof |
| Sede da ordem (`guilda`) | 4 | 160x136 | `#2f6bc4` (bright cobalt blue) | a knights' order hall, a stately timber and stone lodge with a wide double door, a plain bare wooden signboard and an empty flagpole, no heraldry, blue roof |
| Armeiro (`armeiro`) | 4 | 160x136 | `#3f9a4a` (leaf green) | an armorer's workshop with armor stands, shields on the walls and a workbench, green shingle roof |

**Estágios** (o prompt do prédio + uma destas linhas; estágio 1 é o mais humilde, e os de 4 estágios pulam o primeiro da lista de 5):

- Prédios de 5 estágios:
  1. tiny humble one-room version, rough timber walls and a sagging roof, patched and poor
  2. small modest version, timber frame with plaster walls and a wooden shingle roof
  3. medium sturdy version, stone ground floor with timber upper floor
  4. large prosperous version, dressed stone walls, two floors, small heraldic banners
  5. grand imposing version, fine stonework, three floors with a tower, tall roof, large banners and iron details
- Prédios de 4 estágios:
  1. small modest version, timber frame with plaster walls and a wooden shingle roof
  2. medium sturdy version, stone ground floor with timber upper floor
  3. large prosperous version, dressed stone walls, two floors, small heraldic banners
  4. grand imposing version, fine stonework, tall roof, large banners and iron details

**Regras do resultado:** o prédio termina na linha do chão (nada de borda de terra: a vila põe o terreiro por baixo); telhado nas cores da tabela, nunca marrom; nada de brasão desenhado na sede da ordem (o jogo põe o estandarte); mesma luz vinda do alto à esquerda nos 9; o mesmo prédio mantém a silhueta de um estágio ao outro.

