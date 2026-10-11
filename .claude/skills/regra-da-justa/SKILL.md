---
name: regra-da-justa
description: Regras para mexer na regra do impacto e na simulação da justa do Torneio Medieval: manter determinística e pura, atualizar GDScript e TypeScript juntos e rodar os casos de teste compartilhados. Use SEMPRE que for criar ou editar a resolução de impacto, pontuação, derrubada, dano de peça, habilidades, IA do rival, validação de toques no servidor ou qualquer arquivo em game/scripts/rules, tests/shared ou na Edge Function da justa.
---

# Regra da justa

A mesma regra roda no celular (GDScript) e, a partir da Parte 3, no servidor (TypeScript, Edge Function) que recalcula cada justa e PvP antes de pagar qualquer coisa. Se as duas divergirem, ou o jogador é roubado ou o trapaceiro passa. Por isso a regra é um módulo puro, com um conjunto de casos de teste compartilhado.

## Regras de ouro

1. **Pura.** Código em `game/scripts/rules/`: sem nós, cenas, sinais, `Time`, `OS`, entrada de toque, tela nem acesso a arquivos. Recebe dados e devolve dados.
2. **Determinística.** Mesma entrada + mesma semente = mesmo resultado, sempre. Aleatoriedade só por gerador com semente explícita passada de fora (`RandomNumberGenerator` com `seed` fixa); nunca `randf()` global, nem relógio, nem ordem de dicionário como fonte de variação.
3. **Números vêm dos dados** (`game/data/balance/`), nunca fixos no código. Ver a skill `balanceamento`.
4. **Duas versões, um comportamento.** Toda mudança na regra é feita nas duas versões (GDScript e TypeScript) no mesmo commit, junto com casos de teste novos.
5. **Apresentação nunca decide.** Câmera, efeitos, som e animação só escutam sinais das fases e mostram o resultado que a regra já calculou.

## Entrada e saída

- Entrada: atributos dos dois cavaleiros e cavalos, equipamento, habilidade ativa, e os toques do jogador (qualidade da largada, ritmo médio, ponto da mira), mais a semente.
- Saída: zona atingida, pontos, derrubada (sim/não), dano em cada peça de armadura, habilidades disparadas.
- Regras do GDD: capacete 3, peito 2, escudo 1, erro 0; cavalo é falta; derrubada vence a justa; Força contra Equilíbrio decide derrubar. Resumo dos valores em `balanceamento`.

## Cuidados de paridade GDScript × TypeScript

- Ambos usam ponto flutuante de 64 bits, mas arredonde de forma explícita e igual (mesma função, mesmo ponto do cálculo) e prefira inteiros ou milésimos fixos para tempos, janelas e probabilidades.
- Não dependa de ordem de iteração de mapas; use listas ordenadas.
- Gerador de números aleatórios: implemente o **mesmo algoritmo simples** nos dois lados (por exemplo, um LCG ou xorshift com semente inteira), não o gerador nativo de cada linguagem, que não produz a mesma sequência.
- O servidor rejeita o impossível: tempo de reação desumano, mira perfeita repetida, valores fora de faixa. Essas checagens ficam no servidor, mas usam os mesmos limites dos dados.

## Casos de teste compartilhados

- Arquivo `tests/shared/` (JSON): lista de `{nome, entrada, semente, esperado}`. Os dois lados leem o mesmo arquivo.
- Cada mudança de regra acrescenta casos: um por zona, derrubada, falta, empate com passada extra, cada habilidade e cada teto de status.
- GDScript: script que estende `SceneTree` e sai com código 1 se algo divergir. Rode com `bash .claude/skills/run-torneio-medieval/driver.sh script res://tests/<script>.gd` (modelo em `tests/smoke/headless_check.gd`).
- TypeScript: rode o mesmo arquivo no teste da Edge Function. O teste falha se as duas versões divergirem.
- Teste de determinismo: rode o mesmo caso duas vezes com a mesma semente e exija saída idêntica; rode com semente diferente e exija que a variação venha só da semente.

## Antes de fechar uma mudança

Casos novos escritos, GDScript passando, TypeScript passando (quando existir), e o `/code-review` rodado. Se a mudança é na regra do impacto ou nas habilidades, registre a decisão em `docs/DECISOES.md`.
