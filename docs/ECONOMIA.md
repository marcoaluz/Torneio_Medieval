# Simulação da economia (Pacote 3.12)

Script: `tools/simular_economia.gd` (modelo em `tools/simulacao_economia.gd`). Rodar com:

```
bash .claude/skills/run-torneio-medieval/driver.sh script res://tools/simular_economia.gd
```

Para rodar com menos sementes e mais rápido, use `TM_SEMENTES=10`. O script grava duas planilhas, abertas direto no Excel em português (separador `;`, decimal `,`):

- `docs/economia/marcos.csv` — para cada perfil e marco: a mediana do dia em que chega, os quartis e quantos % das sementes chegam em 90 dias.
- `docs/economia/diario.csv` — média, dia a dia, de nível, poder (total e só atributos), melhoria média das peças, ouro, pontos de liga, liga, região e peças na coleção.

No fim da execução, o script confere a meta do prompt (pagante primeiro, grátis depois, mas chega) e as metas de ritmo de `economia.json > simulacao > metas`.

## O que o modelo faz

Joga um cavaleiro dia a dia, em 2 sessões de 7,5 min (15 min/dia), cada uma com 5 justas de 1,5 min. Ele **não roda a justa de verdade**. Cada justa vira uma chance de vitória pela diferença de poder:

> chance = 0,55 + 0,02 × (poder do jogador − poder do rival) + habilidade, limitada entre 5% e 95%

O **poder** é a média dos 6 atributos (cavaleiro e cavalo) dividida por 2, mais o poder das 6 peças (raridade + melhoria). O teto é 212.

Entram no modelo:
- **PvE:** 5 regiões; o poder do rival sobe ao longo da região; o campeão dá baú de ouro e um projeto.
- **Liga:** pontos; o rival tem o poder típico daquela pontuação, limitado à faixa de pareamento. Entram também as defesas do fantasma e a temporada de 28 dias, com baú e reinício de 50%.
- **Baús:** 4 espaços, um abrindo por vez; chave semanal; garantia de raro a cada 10 baús de ferro ou melhores; peça repetida vira fragmento.
- **Melhoria +1 a +10:** chance de falha depois do +5; o teto segue o nível do armeiro.
- **Forja:** a partir de projetos, com lingotes vindos de sucata.
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

Atualizado depois da forja (3.15) e da correção do passe na simulação (3.17: os projetos do passe premium não eram entregues, por comparar número inteiro com número do JSON). A receita da peça rara ficou em 13 lingotes de ferro equivalentes e 300 de ouro, então o primeiro conjunto raro do grátis passou do dia 32 para o dia 57.

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

## Ajustes feitos durante a simulação

Todos em `economia.json`, que é novo. Nenhum outro arquivo de balanceamento mudou.

1. **Liga com +20/−16 por vitória/derrota** (era +25/−12). Com +25/−12, a expectativa de pontos era sempre positiva e todos chegavam a Campeão no dia 15. Agora o jogador estabiliza na liga do seu poder, vencendo cerca de 44% das justas.
2. **Escala da liga:** o poder do rival é 40 + 0,1 por ponto, e a faixa de pareamento é ±15 de poder. Cada liga passa a corresponder a uma faixa de poder: Prata ~70, Ouro ~100, Platina ~130, Diamante ~160, Campeão ~190.
3. **Regiões** com poder e nível mínimo seguindo a curva do grátis: condado 66–106 (nível 5), ducado 106–126 (8), reino 126–144 (10), Grande Torneio 144–160 (12). Isso orienta o 3.13.
4. **Projetos dos campeões escalonados:** condado → ferro negro (raro), ducado → guarda real, reino → dragão, Grande Torneio → rei sol. Antes, o primeiro conjunto raro do grátis só vinha no dia ~64.
5. **Fragmentos mais escassos e melhorias mais caras**, e o teto de melhoria seguindo o armeiro (2 níveis de melhoria por nível do prédio). Antes, o grátis chegava perto do teto de poder no dia 60.
6. **Vaga de treino do VIP:** é a mesma segunda vaga que o campo de treino libera no nível 3, então não soma com ela.
7. **Passe premium e gemas do VIP mais leves.** Antes, o pagante chegava a cada marco em metade do tempo do grátis.

## Sugestões de ajuste (para decidir)

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

