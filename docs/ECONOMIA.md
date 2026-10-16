# Simulação da economia (Pacote 3.12)

Script: `tools/simular_economia.gd` (modelo em `tools/simulacao_economia.gd`). Rodar com:

```
bash .claude/skills/run-torneio-medieval/driver.sh script res://tools/simular_economia.gd
```

Para rodar com menos sementes e mais rápido, use `TM_SEMENTES=10`. Com `TM_CATALOGO=original`, os baús sorteiam só as 35 peças dos 7 conjuntos de antes da 4.4 e as planilhas vão para `docs/economia/original/` (serve para medir o efeito do catálogo maior). O script grava duas planilhas, abertas direto no Excel em português (separador `;`, decimal `,`):

- `docs/economia/marcos.csv` — para cada perfil e marco: a mediana do dia em que chega, os quartis e quantos % das sementes chegam em 90 dias.
- `docs/economia/diario.csv` — média, dia a dia, de nível, poder (total e só atributos), melhoria média das peças, ouro, pontos de liga, liga, região, peças na coleção e peças raras ou melhores na coleção.

No terminal, o fim de cada perfil mostra também: peças na coleção, peças raras+ distintas nos dias 30/60/90, itens tirados de baú, raros+ por semana nos baús, % de repetidas e fragmentos vindos de repetidas.

No fim da execução, o script confere a meta do prompt (pagante primeiro, grátis depois, mas chega) e as metas de ritmo de `economia.json > simulacao > metas`.

## O que o modelo faz

Joga um cavaleiro dia a dia, em 2 sessões de 7,5 min (15 min/dia), cada uma com 5 justas de 1,5 min. Ele **não roda a justa de verdade**. Cada justa vira uma chance de vitória pela diferença de poder:

> chance = 0,55 + 0,02 × (poder do jogador − poder do rival) + habilidade, limitada entre 5% e 95%

O **poder** é a média dos 6 atributos (cavaleiro e cavalo) dividida por 2, mais o poder das peças equipadas nos 5 espaços que têm item no catálogo (elmo, peitoral, escudo, lança, caparação), pela raridade + melhoria, a mesma conta de `liga.gd`. O teto é 200. Até a 4.4 o modelo contava 6 peças (um espaço "ombreiras" que nunca existiu no jogo), com a tabela de poder antiga, e o teto era 212.

Entram no modelo:
- **PvE:** 5 regiões; o poder do rival sobe ao longo da região; o campeão dá baú de ouro e um projeto.
- **Liga:** pontos; o rival tem o poder típico daquela pontuação, limitado à faixa de pareamento. Entram também as defesas do fantasma e a temporada de 28 dias, com baú e reinício de 50%.
- **Baús:** 4 espaços, um abrindo por vez; chave semanal; garantia de raro a cada 10 baús de ferro ou melhores; a peça sai do catálogo real de `itens.json` como no `RegraBau` (raridade pelos pesos, depois um modelo entre todos os daquela raridade); peça repetida vira fragmento. Conjunto completo = todas as peças daquele conjunto no catálogo.
- **Melhoria +1 a +10:** chance de falha depois do +5; o teto segue o nível do armeiro.
- **Forja:** a partir de projetos (a primeira peça que falta do conjunto, em ordem alfabética), com lingotes vindos de sucata.
- **Treino:** vagas, custo e duração pelo nível, de `treino.json`.
- **Prédios:** custos e tempos de `vila.json`, com o teto dado pela casa senhorial.
- **Fôlego do cavalo**, missões diárias, passe (trilha grátis e premium), VIP e anúncios.

Os números vêm de `game/data/balance/`. O novo `economia.json` reúne os parâmetros dos sistemas da Parte 3 (baús, forja, liga, loja, passe, anúncios e missões) e as metas da simulação.

**Fora do modelo:**
- Repetir PvE no automático.
- Bônus de conjunto e habilidades (o poder conta só o status das peças).
- Materiais além de sucata e lingote.
- Efeitos dos prédios além do campo de treino (vaga extra) e do estábulo (fôlego).
- Gemas usadas em algo além de abrir baú.
- Ofertas da loja.

## Perfis

| Perfil | O que é |
| --- | --- |
| gratis | 15 min/dia, sem anúncios |
| gratis_anuncios | 15 min/dia, 5 anúncios/dia (1 baú de madeira extra, 2 vitórias dobradas, 2 cortes de 30 min) |
| pagante | 15 min/dia, VIP + passe premium |
| gratis_habilidoso / pagante_ruim | teste do GDD "habilidoso com equipamento médio vence pagante que joga mal" (±15% de chance) |
| so_vip / so_passe | separam o peso do VIP e do passe |

## Resultado (40 sementes, mediana do dia; — = não chega em 90 dias)

Atualizado em 2026-10-15: catálogo de 110 peças (4.4), modelo com os 5 espaços reais e a **S1 aplicada** (`poder_raridade` 4/6/10/14/20, era 3/5/8/12/17; ver "Catálogo de 110 peças" abaixo).

| Marco | Grátis | Grátis + anúncios | Pagante | Habilidoso grátis | Pagante ruim | Só VIP | Só passe |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Condado | 5 | 5 | 4 | 4 | 5 | 4 | 5 |
| Ducado | 30 | 22 | 14 | 20 | 16 | 14 | 20 |
| Reino | 53 | 36 | 25 | 33 | 33 | 30 | 35 |
| Grande Torneio | 82 | 62 | 48 | 61 | 71 | 54 | 60 |
| Campeão do Grande Torneio | — | — | — | — | — | — | — |
| Liga Prata | 9 | 8 | 8 | 8 | 10 | 8 | 9 |
| Liga Ouro | 18 | 16 | 13 | 14 | 16 | 13 | 17 |
| Liga Platina | 48 | 41 | 33 | 38 | 39 | 35 | 38 |
| Liga Diamante | — | — | 79 | 76 | — | 83 | — |
| Liga Campeão | — | — | — | — | — | — | — |
| 1º conjunto incomum completo | 9 | 9 | 8 | 8 | 8 | 7 | 9 |
| 1º conjunto raro completo | 62 | 43 | 21 | 60 | 26 | 31 | 50 |
| Nível 10 | 31 | 27 | 21 | 26 | 24 | 22 | 25 |
| Nível 15 | 70 | 61 | 53 | 60 | 61 | 57 | 59 |

**Meta do prompt:**
- O pagante chega primeiro em todos os marcos e o grátis com anúncios fica entre os dois.
- O grátis chega a todas as regiões em 90 dias (Grande Torneio no dia 82). Ficam para depois o campeão do Grande Torneio (ninguém chega) e as ligas Diamante e Campeão.
- O teste do GDD passa: o grátis habilidoso chega ao Grande Torneio no dia 61 e à Diamante no 76; o pagante que joga mal só chega ao Grande Torneio no 71 e não chega à Diamante.
- **4 metas de ritmo fora da tolerância** (eram 7 antes da 4.4):
  - conjunto incomum do grátis cedo (9; meta 15);
  - conjunto raro do grátis tarde (62; meta 45; ver sugestão 3 abaixo);
  - reino do pagante cedo (25; meta 38);
  - Diamante do pagante tarde (79; meta 60).

**No dia 90:**
- Grátis: nível 16,8 e poder 144 (72% do teto de 200).
- Pagante: nível 17,8 e poder 150.

### Resultado anterior (3.17, modelo com 6 peças e 35 modelos)

A receita da peça rara ficou em 13 lingotes de ferro equivalentes e 300 de ouro, então o primeiro conjunto raro do grátis passou do dia 32 para o dia 57. Tabela mantida para comparação.

| Marco | Grátis | Grátis + anúncios | Pagante | Habilidoso grátis | Pagante ruim | Só VIP | Só passe |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Condado | 6 | 5 | 4 | 4 | 5 | 4 | 6 |
| Ducado | 29 | 21 | 14 | 18 | 19 | 15 | 20 |
| Reino | 52 | 34 | 25 | 35 | 32 | 28 | 35 |
| Grande Torneio | 70 | 56 | 41 | 59 | 58 | 49 | 57 |
| Campeão do Grande Torneio | — | — | 88 | 76 | — | — | — |
| Liga Prata | 9 | 9 | 9 | 8 | 11 | 8 | 10 |
| Liga Ouro | 18 | 16 | 13 | 14 | 18 | 13 | 16 |
| Liga Platina | 51 | 39 | 35 | 38 | 42 | 36 | 39 |
| Liga Diamante | — | 76 | 66 | 71 | — | 72 | 72 |
| Liga Campeão | — | — | — | — | — | — | — |
| 1º conjunto incomum completo | 9 | 8 | 6 | 9 | 7 | 6 | 9 |
| 1º conjunto raro completo | 57 | 28 | 20 | 49 | 22 | 25 | 31 |
| Nível 10 | 31 | 26 | 21 | 27 | 25 | 22 | 26 |
| Nível 15 | 65 | 58 | 46 | 59 | 58 | 54 | 58 |

**Meta do prompt:**
- O pagante chega primeiro em todos os marcos e o grátis com anúncios fica entre os dois.
- O grátis chega a todas as regiões em 90 dias. Só o campeão do Grande Torneio e as ligas Diamante e Campeão ficam para depois.
- O teste do GDD passa: o grátis habilidoso é campeão do Grande Torneio no dia 76; o pagante que joga mal não chega lá em 90 dias.

**No dia 90:**
- Grátis: nível 17,6 e poder 152 (72% do teto).
- Pagante: nível 18,7 e poder 169.

## Catálogo de 110 peças (4.4, 2026-10-15)

O catálogo foi de 35 para 110 modelos: 25 comuns, 30 incomuns, 25 raros, 15 épicos e 15 lendários (eram 5, 10, 10, 5 e 5). Os pesos de raridade dos baús, a garantia e os fragmentos por repetida não mudaram.

**O que a simulação usava antes:** uma lista própria de 7 conjuntos × 6 espaços em `economia.json` (`conjuntos` e `espacos_conjunto`), e não o catálogo. Por isso ela deu o mesmo resultado antes e depois das 75 peças novas. Agora o modelo sorteia do catálogo real como o `RegraBau`. Ao fazer isso, apareceu um segundo erro: o 6º espaço ("ombreiras") não existe no jogo, que tem item só em 5 espaços. O poder do jogador no modelo antigo tinha uma peça a mais (de +8 no dia 10 a +19 no dia 90).

Para separar os dois efeitos, rodei três versões (40 sementes, mediana do dia):

| | Modelo antigo (6 espaços, lista própria) | Catálogo real, só as 35 peças antigas | Catálogo real, 110 peças |
| --- | --- | --- | --- |
| Ducado (grátis / anúncios / pagante) | 30 / 21 / 13 | 44 / 30 / 20 | 42 / 30 / 20 |
| Reino | 59 / 37 / 25 | 76 / 59 / 40 | 67 / 58 / 38 |
| Grande Torneio | 76 / 58 / 43 | — / — / — | — / — / — |
| Liga Platina | 63 / 39 / 35 | 74 / 54 / 39 | 69 / 56 / 39 |
| 1º conjunto incomum | 9 / 7 / 6 | 9 / 7 / 6 | 11 / 10 / 8 |
| 1º conjunto raro | 59 / 35 / 20 | 47 / 34 / 21 | 67 / 49 / 28 |
| Raros+ por semana nos baús | (não medido) | 2,4 / 2,7 / 3,7 | 2,4 / 2,7 / 3,7 |
| Peças raras+ distintas no dia 30 / 60 / 90 (grátis) | (não medido) | 7,5 / 10,4 / 13,1 | 9,3 / 15,2 / 23,9 |
| Peças raras+ distintas no dia 90 (anúncios / pagante) | (não medido) | 13,8 / 15,7 | 25,4 / 31,4 |
| Itens de baú repetidos (grátis / anúncios / pagante) | (não medido) | 93% / 95% / 95% | 78% / 83% / 84% |
| Fragmentos vindos de repetidas em 90 dias | (não medido) | 1089 / 1474 / 1650 | 923 / 1291 / 1469 |
| Metas fora da tolerância | 7 | 12 | 11 |

**Efeito do catálogo maior** (coluna do meio contra a da direita):
- **Peça rara+ chega no mesmo ritmo:** os baús continuam dando 2,4 raros+ por semana ao grátis (3,7 ao pagante), e a garantia segue a cada 10 baús de ferro+. Isso depende só dos pesos, que não mudaram.
- **A repetição caiu, não subiu.** Com 3× mais modelos por raridade, a chance de tirar um que já tem diminui: de 93% para 78% no grátis. Por isso as peças raras+ *novas* quase dobram (13 para 24 no dia 90 do grátis) e os fragmentos vindos de repetidas caem cerca de 15% (1089 para 923). A melhoria média das peças no dia 90 ficou igual (+6,3), então a queda ainda não segura a forja.
- **O conjunto completo atrasa.** Uma peça rara agora é 1 entre 25 modelos (antes 1 entre 10), então o baú quase não ajuda a fechar um conjunto. Quem fecha é a forja, pelo projeto. 1º conjunto raro: grátis 47 → 67, anúncios 34 → 49, pagante 21 → 28. O 1º incomum atrasa 2 dias.
- **O resto quase não muda** e até melhora um pouco (reino do grátis 76 → 67), porque as peças raras+ novas ocupam mais espaços cedo.

**Efeito da correção dos espaços** (coluna da esquerda contra a do meio): é o que mais pesa. Sem a 6ª peça, o poder fica uns 13% menor e o grátis perde o Grande Torneio em 90 dias. As faixas de poder das regiões e das ligas (`economia.json > regioes`, `ligas`) foram calibradas na 3.12 com essa peça a mais.

### Sugestões de ajuste do catálogo (S1 aplicada em 2026-10-15; as outras, para decidir)

Testei cada uma na simulação, trocando o `economia.json` só durante a execução (o arquivo voltou pelo git):

| Grátis / anúncios / pagante | Antes da S1 | S1 (aplicada) | S1 + S2 |
| --- | --- | --- | --- |
| Ducado | 42 / 30 / 20 | 30 / 22 / 14 | 30 / 22 / 14 |
| Reino | 67 / 58 / 38 | 53 / 36 / 25 | 58 / 35 / 26 |
| Grande Torneio | — / — / — | 82 / 62 / 48 | 79 / 58 / 47 |
| Liga Platina | 69 / 56 / 39 | 48 / 41 / 33 | 50 / 40 / 33 |
| Liga Diamante (pagante) | — | 79 | 81 |
| 1º conjunto raro | 67 / 49 / 28 | 62 / 43 / 21 | 60 / 28 / 18 |
| Nível 15 | 81 / 76 / 69 | 70 / 61 / 53 | 68 / 59 / 53 |
| Metas fora da tolerância | 11 | **4** | 5 |

1. **S1 — devolver o poder da peça que faltava. APLICADA (2026-10-15)**; o resultado no topo do documento é com ela. Em `economia.json > poder_raridade`: comum 3→4, incomum 5→6, raro 8→10, épico 12→14, lendário 17→20 (cerca de +20%, o que 5 peças precisam para valer o que 6 valiam). Volta o Grande Torneio para o grátis (dia 82; meta 80) e deixa 4 metas fora, menos que as 7 de antes. O teste do GDD continua passando: o habilidoso chega ao Grande Torneio no dia 61 e o pagante ruim no 71. Atenção: o `liga.gd` usa a mesma tabela no pareamento do jogo. Como todos sobem juntos, só a parte das peças pesa um pouco mais que a dos atributos.
   - **Alternativa:** abaixar as faixas de poder de cada região e o `poder_rival_base` da liga em cerca de 13%. Dá o mesmo efeito na simulação, mas mexe em mais números.
2. **S2 — receita rara mais barata** (`forja > receitas > raro`: lingote_ferro 10→6 e ouro 300→200; a sugestão da 3.15). Com S1, adianta o conjunto raro de anúncios e pagante (43→28 e 21→18), mas **não o do grátis** (62→60), e deixa o pagante cedo demais (meta 25). **Não recomendo agora.**
3. **O conjunto raro do grátis fica no dia ~60 em todas as variantes, e o freio é o ouro.** O grátis termina o dia 90 com uns 300 de ouro, porque prédios e treino levam tudo, e a forja espera sobrar ouro além da reserva. Testei mais sucata por vitória (S3, `sucata_por_vitoria` 2→3, número só da simulação) e não mudou nada (59). Opções que não testei:
   - aceitar a meta em ~60, já que o grátis agora ganha mais peças raras+ avulsas;
   - fazer o campeão de região dar o projeto e uma peça pronta do conjunto;
   - baixar só o ouro da receita rara (300→150), sem mexer nos lingotes.
4. **Limpeza:** `economia.json > espacos_conjunto` não é mais usado pelo modelo e pode sair. A lista `conjuntos` continua servindo ao passe premium (qual projeto dar) e ao `TM_CATALOGO=original`.
5. **Fragmentos:** com 15% menos fragmentos de repetidas, a melhoria das peças ainda não mudou (+6,3 no dia 90). Não precisa de ajuste agora. Se o catálogo crescer de novo, olhe `baus > fragmentos_por_repetida` e o `fragmentos` de cada baú.

## Ajustes feitos durante a simulação

Todos em `economia.json`, que é novo. Nenhum outro arquivo de balanceamento mudou.

1. **Liga com +20/−16 por vitória/derrota** (era +25/−12). Com +25/−12, a expectativa de pontos era sempre positiva e todos chegavam a Campeão no dia 15. Agora o jogador estabiliza na liga do seu poder, vencendo cerca de 44% das justas.
2. **Escala da liga:** o poder do rival é 40 + 0,1 por ponto, e a faixa de pareamento é ±15 de poder. Cada liga passa a corresponder a uma faixa de poder: Prata ~70, Ouro ~100, Platina ~130, Diamante ~160, Campeão ~190.
3. **Regiões** com poder e nível mínimo seguindo a curva do grátis: condado 66–106 (nível 5), ducado 106–126 (8), reino 126–144 (10), Grande Torneio 144–160 (12). Isso orienta o 3.13.
4. **Projetos dos campeões escalonados:** condado → ferro negro (raro), ducado → guarda real, reino → dragão, Grande Torneio → rei sol. Antes, o primeiro conjunto raro do grátis só vinha no dia ~64.
5. **Fragmentos mais escassos e melhorias mais caras**, e o teto de melhoria seguindo o armeiro (2 níveis de melhoria por nível do prédio). Antes, o grátis chegava perto do teto de poder no dia 60.
6. **Vaga de treino do VIP:** é a mesma segunda vaga que o campo de treino libera no nível 3, então não soma com ela.
7. **Passe premium e gemas do VIP mais leves.** Antes, o pagante chegava a cada marco em metade do tempo do grátis.
8. **Poder por raridade +20% (2026-10-15, S1):** `poder_raridade` 3/5/8/12/17 → 4/6/10/14/20, porque o jogo tem item em 5 espaços e as faixas de regiões e ligas foram calibradas com 6 peças.

## Sugestões de ajuste (3.12, para decidir; números do modelo antigo)

1. **Ouro sobrando a partir do dia ~45.** No dia 90 sobram 18 mil (pagante), 10 mil (com anúncios) e 2,7 mil (grátis). Os prédios param no nível 5 e os atributos batem no teto, então o ouro deixa de ter destino. Sugestões:
   - Prédios até o nível 10 em `vila.json`. A tabela de Timers do GDD já fala em melhorias de 6 a 12 h no nível 21 ou mais.
   - Ouro como custo das novas tentativas da forja (variação de status).
   - Cosméticos comprados com ouro.
2. **Atributos batem em 100** no dia ~60 (grátis) e no dia ~30 (pagante). Sugiro ganho decrescente no treino, por exemplo +2 até 60 e +1 acima (`treino.json`), ou custo de treino crescendo com o valor do atributo. Hoje o treino rende igual do começo ao fim.
3. **O condado é o muro do grátis:** ele passa 25 dias lá (dias 6 a 31), contra 9 do pagante. Qualquer reforço (anúncios, VIP ou passe) corta esse tempo quase pela metade. Para suavizar: reduzir o poder final do condado (106 para cerca de 100) ou dar uma peça rara no meio do condado (campeão de torneio intermediário).
4. **A vantagem do pagante ainda é grande no meio do PvE:** cerca de 2× no ducado. Separados, o VIP e o passe dão cada um uns 1,5×. Se a meta for por volta de 1,4×:
   - VIP com timers −15% (hoje −20%);
   - VIP com 100 gemas/mês (hoje 150);
   - ou passe premium com baú de ouro a cada 20 níveis.
   As metas de ritmo do pagante em `economia.json` estão nessa linha e hoje são o que fica fora da tolerância.
5. **5 anúncios por dia valem quase um passe:** levam ao ducado no dia 22 contra 31. Considere limite de 3 por dia, ou tirar o baú de madeira extra.
6. **Baús perdidos:** com os 4 espaços cheios, o grátis perde ~1,4 baú por semana. O GDD prevê isso (vitória com espaços cheios dá só ouro). A notificação de "baú aberto" (3.23) ajuda.
7. **Liga Campeão e nível 20** ficam além dos 90 dias para todos. É coerente com um jogo de meses, mas vale confirmar.

As metas de ritmo (`simulacao > metas`) são uma **proposta minha**. Confirme ou troque os dias, e o script passa a medir contra os seus números.

## Depois da 3.15 (forja)

- A receita da peça rara (`economia.json > forja > receitas > raro`) ficou mais cara que a da simulação original: o primeiro conjunto raro do grátis caiu do dia 32 para o 58 (meta proposta: 45). Para voltar ao alvo, use 8 lingotes de ferro e 200 de ouro na receita rara, ou dê mais sucata por vitória no condado e no ducado (`pve.json > materiais_vitoria`).
- O simulador conta só sucata e lingotes; couro, tecido nobre e ornamento ainda não limitam a forja no modelo.

