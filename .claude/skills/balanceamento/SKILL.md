---
name: balanceamento
description: Onde ficam os números de balanceamento do Torneio Medieval, os tetos de status, a regra de ouro (status aumenta a janela de acerto, não acerta pelo jogador) e como rodar a simulação de economia 3.12. Use SEMPRE que for criar, mudar ou ler qualquer número do jogo (janelas de tempo, zonas, status, preços, timers, probabilidades de baú, durabilidade, XP, recompensas), mesmo que seja "só trocar um valor".
---

# Balanceamento

Design completo em `docs/GDD.md` (seções Progressão, Timers e ritmo, Forja, Monetização e balanceamento). O objetivo: a habilidade do jogador decide mais que os status, e quem paga ganha tempo e visual, não poder sem teto.

## Regra de ouro

**Status aumenta a janela de acerto, não acerta pelo jogador.** Precisão aumenta a área da zona; Temperamento aumenta a janela do compasso; Força só pesa na chance de derrubar *quando o jogador acerta*. Nunca crie um status que converte erro em acerto. É isso que sustenta o pilar "justo para quem não paga".

## Onde ficam os números

- **Todo número de balanceamento mora em `game/data/balance/`** (JSON ou Resource), nunca fixo no código. Nem constante "só por enquanto": o servidor vai ler as mesmas tabelas (Parte 3, balanceamento remoto com versão no Supabase).
- Estruture por assunto: justa (durações das fases, janelas, zonas, pontos), atributos, equipamento e conjuntos, habilidades, treino/prédios/timers, baús, PvE, preços.
- Todo arquivo de dados tem campo de versão.
- O código lê, valida e falha alto se faltar chave; não use valor padrão silencioso no código.
- Ao mudar um número, diga no commit qual e por quê, e registre decisões de peso em `docs/DECISOES.md`.

## Valores do GDD (ponto de partida; o ajuste fino sai da simulação)

- Passada ≈ 15 s; fases: Apresentação 2 s, Largada 1 s, Corrida 4–5 s, Mira 2 s, Impacto 2 s. Justa = 3 passadas; empate → passada extra decisiva.
- Pontos: capacete 3, peito 2, escudo 1, erro 0; derrubar vence na hora; acertar o cavalo é falta (perde pontos; na reincidência, desclassificado).
- Atributos do cavaleiro: Força, Precisão, Equilíbrio. Do cavalo: Velocidade, Fôlego, Temperamento, Vínculo (bônus geral pequeno).
- **Tetos:** acerto até 75%, bloqueio até 40%; perto do teto cada ponto rende menos (retorno decrescente). Peças avulsas dão +2% a +5% em um status.
- Habilidades: 1 espaço no começo, 2º liberado em liga alta jogando; no máximo uma por grupo (ofensiva ou defensiva). Cada uma dispara uma vez por justa ou com 70% de chance, nunca 100%. Ciclo Investida > Bloqueio > Golpe Pesado > Investida, sem combinação perfeita.
- Conjuntos: 2 peças dão bônus pequeno; completo libera a habilidade do conjunto.
- Timers: nenhum passa de uma noite de sono (12 h); curva começa em segundos e cresce devagar (tabela no GDD). Primeiro dia: tudo em segundos.
- Baús: madeira 5 min, ferro 1 h, ouro 4 h, real 12 h; garantia de raro ou melhor a cada 10 baús de ferro ou melhores; probabilidades sempre visíveis ao jogador.
- Forja: melhoria +1 a +10, garantida até +5, chance de falha depois, sem destruir a peça.

## Teste de equilíbrio

Um jogador habilidoso com equipamento médio precisa conseguir vencer um pagante que joga mal. Se uma mudança quebrar isso, ela está errada, não o teste.

## Simulação de economia (prompt 3.12)

Script que lê os dados de `game/data/balance/` e simula 90 dias de três jogadores: grátis (15 min/dia), grátis com anúncios, pagante (VIP + passe). Mede em quantos dias cada um chega a cada liga, região do PvE e primeiro conjunto completo. Meta: pagante chega primeiro, grátis chega depois, mas chega. Saída: planilha de resultados e sugestão de ajustes. Rode-o depois de qualquer mudança em preços, timers, recompensas ou probabilidades. O script ainda não existe; ele nasce no prompt 3.12 e deve ser rodado com o driver (`/run-torneio-medieval`, comando `script`) quando for GDScript, ou documentado aqui quando existir.
