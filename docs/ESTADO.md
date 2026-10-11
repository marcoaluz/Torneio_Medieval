# Estado atual

**Parte 1 — Protótipo · prompt 1.3 (Largada e galope): concluído.** Próximo: 1.4.
O usuário pediu (2026-10-11) para executar **todos os prompts do Pacote em sequência**, sem parar para revisão; ele analisa tudo depois. Parar só antes de gastar crédito ou mexer em serviço externo (PixelLab, ElevenLabs, criar projeto/migração no Supabase, lojas).

## Como validar tudo
- `bash tests/rodar_testes.sh`: roda todos os `tests/**/*_check.gd` headless (hoje 6 arquivos, 105 checagens, todos passam).
- Demo jogável sem mão: `tests/arena/justa_robo_demo.tscn` (robô larga e toca no compasso; log com prefixo ROBO).
- Capturas: `bash .claude/skills/run-torneio-medieval/driver.sh shot res://game/scenes/arena/arena.tscn <quadro> <png>` (30 quadros = 1 s de jogo).

## Sistemas prontos
- **Base (1.0):** 960×540, Compatibility, nearest, snap de pixel, landscape, `aspect=expand` (20:9 → 1200×540). Traduções em `game/i18n/textos.csv` (pt_BR/en). O toque é emulado pelo mouse (`emulate_touch_from_mouse`), então o código só trata `InputEventScreenTouch`/`ScreenDrag`.
- **Arena (1.1):** `game/scenes/arena/arena.tscn` (cena principal). A cerca fica em y≈236–292, o rival na pista de cima (pés y=270, escala 0.85, espelhado) e o jogador na de baixo (pés y=470). Marcadores `Pistas/{Jogador,Rival}/{Inicio,Fim}` (x 90↔870); cenário de x −160 a 1120.
- **Cavaleiro:** `cavaleiro.tscn`/`cavaleiro.gd`, quadro 160×160, origem no chão. Encaixes `Visual/Cavalo`, `Visual/Cavalo/Manta`, `Visual/Cavaleiro/{Peito,Capacete,Escudo}` (alvos da mira, via `ponto_alvo()`) e `Visual/Lanca`; o `Brasao` desfaz o espelho. A arte provisória está em `game/scripts/presentation/provisorio/`.
- **Câmera:** `CameraArena`: `plano_aberto()`, `seguir(alvo)`, `focar(ponto, zoom)`, `focar_alvo(no, zoom)`.
- **Fases (1.2):** a regra pura `game/scripts/rules/justa_fases.gd` (`JustaFases`, tempo em ms inteiros, devolve eventos) com dados em `game/data/balance/justa.json` (versão 1: 3 passadas, 1 extra, fases 2000/1000/4500/2000/2000 ms). Os casos compartilhados ficam em `tests/shared/justa_fases.json` (15 casos, gerados por um oráculo independente) e o executor GDScript em `tests/rules/justa_fases_check.gd` (inteiro e picado em 17 ms). O `ControladorJusta` (`controlador_justa.gd`, nó `Arena/Justa`) emite `fase_mudou` mais um sinal por fase (`apresentacao_comecou`...`impacto_comecou`), `passada_terminou` e `justa_terminou`; ele troca a câmera e move os cavaleiros (encontro no meio no fim da Mira, câmera lenta 0.3). Um toque pula a Apresentação. O resultado da passada entra por `registrar_resultado()` (vem da 1.5). O loader é `game/scripts/services/balanceamento.gd`.
- **Largada e galope (1.3):** regra pura `game/scripts/rules/galope.gd` (`Galope`: largada perfeita/boa/ruim/queimada pela reação à bandeira; compasso de 500 ms; janela 70 ms + Temperamento, com teto de 180 ms; toques "no_tempo" / "fora_do_tempo" / "rapido_demais" / "perdido"; o fôlego vale a justa inteira e, sem fôlego, erro tira velocidade). Dados em `game/data/balance/galope.json` (versão 1). `game/scripts/rules/aleatorio.gd` é um xorshift32 com semente, para sortear a bandeira. `game/scripts/rules/justa.gd` (`Justa`) junta fases, galope e sorteio; o jogador só manda `tocar()`. A Corrida termina quando a soma das distâncias chega a `distancia_total − distancia_mira` (850 de 1000), com teto de 6 s (`justa.json` passou para a versão 2). Normal: 4,1–5,0 s. O rival corre em velocidade nominal fixa (`automatico`) até a IA da 1.6. Casos: `tests/shared/galope.json` (oráculo Python independente: aleatório, largada, galope), `tests/rules/justa_simulacao_check.gd` (determinismo, passo de 1/33 ms, propriedades) e a gravação de referência `tests/shared/justa_referencia.json` (semente + toques → eventos; regravar com `TM_GRAVAR=1`). Na cena: `Arauto` (`arauto.tscn`, bandeira levanta e baixa), barra de distância (`game/scenes/ui/barra_distancia.tscn`, a pista inteira, com o brilho do compasso e um lampejo para o resultado do toque), e sinais novos `bandeira_baixou`, `largada_avaliada`, `toque_galope`, `corrida_terminou`.

## Pendências / bugs
- **Decisão de design pendente:** o GDD diz "passada extra decisiva". Implementei passadas extras até `passadas_extras_max` (1 nos dados); se ainda empatar, a justa termina empatada (`motivo "empate"`). Confirmar com o usuário.
- A versão TypeScript de `JustaFases` (e o executor de `tests/shared/`) nasce na Parte 3.
- Rival em escala 0.85 (não inteira): com sprites, os pixels podem ficar irregulares (alternativa: 0.875).
- O escudo fica do mesmo lado nos dois cavaleiros (só espelhamento, como pede o GDD); rever no polimento.
- Pendências do GDD (Plano de produção): nome do jogo e do protagonista, enredo, planilha de economia (3.12), mêlée, editor de brasão, habilidades do lançamento.
- As skills do projeto (`estilo-arte`, `som`, `balanceamento`, `regra-da-justa`, `supabase-jogo`) têm valores propostos por mim, marcados com (*).
- Nada foi testado em celular ainda (1.9).

- `bonus_precisao_pct` da largada perfeita já está nos dados (+10), mas só será usado na 1.4/1.5.
- O fôlego cai 10 por passada e não se recupera entre justas; a recuperação no estábulo é da Parte 2.

## Próximo passo
Prompt 1.4 do Pacote (Mira e golpe), Opus 5.5, medium. Na Mira (câmera lenta e zoom no rival, que já existe), o jogador segura, arrasta a ponta da lança sobre o rival e solta para golpear. Zonas: capacete, peito, escudo e cavalo (falta); Precisão aumenta a área efetiva de cada zona. O sinal de alvo é discreto, um brilho leve no próprio rival. A geometria das zonas e a avaliação do ponto (qual zona, com Precisão) ficam puras em `rules/`, com casos em `tests/shared/`; o toque na Mira hoje é ignorado por `Justa.tocar()`. Depois, a 1.5 (regra do impacto).
