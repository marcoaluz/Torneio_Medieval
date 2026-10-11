# Torneio Medieval — Pacote de Prompts

Oct 11, 2026 · @Marco Claude

## Como usar este pacote

Siga as partes na ordem: só passe para a próxima quando a anterior estiver jogável. Cada prompt é para colar como está, trocando só o que estiver entre colchetes.

1. **Antes de tudo:** exporte o Documento de Design como Markdown e salve na raiz do projeto como `docs/GDD.md`. Todos os prompts do Claude Code apontam para ele.
2. **Claude Code:** um prompt por sessão ou por tarefa. Ao terminar, rode o jogo, teste no celular real e faça commit no git antes do próximo prompt.
3. **PixelLab:** comece sempre pelo prefixo de estilo da seção Guia de estilo. Gere, escolha a melhor variação, retoque no editor e só então exporte.
4. **ElevenLabs:** gere de 3 a 4 variações de cada som e fique com a melhor. Confira se o seu plano permite uso comercial.
5. **Blender:** use quando a IA errar proporção ou ângulo. Monte uma pose simples do cavalo e do cavaleiro, renderize em silhueta e use como referência no PixelLab.
6. **Gemini:** mockups de tela e referências visuais antes de gerar a arte final.

Convenções: textos do jogo nunca dentro do código (sempre em arquivos de tradução, português e inglês); números de balanceamento sempre em arquivos de dados, nunca fixos no código.

## Modelo e esforço no Claude Code

Regra geral: Opus 5.5 em esforço médio para o dia a dia e em esforço alto para as decisões difíceis de arquitetura e segurança; Haiku 5.5 para tarefas pequenas. Cada prompt deste pacote traz a indicação ao lado.

| Tipo de tarefa | Modelo | Esforço | Exemplos |
| --- | --- | --- | --- |
| Arquitetura e decisões difíceis | Opus 5.5 (`/model opus`) | high | Estrutura do projeto, servidor autoritativo, simulação da justa no servidor, banco e regras de acesso |
| Revisão de segurança antes de lançar | Opus 5.5 | high ou xhigh | Auditoria de RLS, Edge Functions, compras e trapaça |
| Sistema novo com escopo claro | Opus 5.5 (`/model opus`) | medium | Fases da justa, forja, baús, ligas, ordens |
| Corrigir bug em código existente | Opus 5.5 | high | Justa que trava, save que perde dados |
| Telas e interface | Sonnet 5.5 (`/model sonnet`) | medium | Vila, tela de Equipamentos, loja, menus |
| Ajustes pequenos | Haiku 5.5 (`/model haiku`) | low | Renomear, trocar um número, mover um botão, textos |

**Detalhes que ajudam**

- Opus 5.5, Sonnet 5.5 e Haiku 5.5 começam em esforço médio. Para mudar, use `/effort` com o nível (`low`, `medium`, `high`, `xhigh`, `max`).
- `max` raramente compensa: rende pouco a mais e tende a pensar demais. Teste antes de usar como padrão.
- Para uma pergunta difícil isolada, escreva `ultrathink` no prompt; o esforço da sessão não muda.
- O alias `opusplan` usa Opus no modo de planejamento e Sonnet na execução; bom para sistemas grandes onde você quer aprovar o plano antes.
- Nas tarefas de esforço alto, descreva o resultado que quer e peça um plano antes de ele implementar, ou use o modo de planejamento.
- Se um dia o Fable 5.1 ficar disponível no seu plano, ele pode substituir o Opus nas tarefas marcadas com esforço alto.

Fonte: [Configuração de modelo do Claude Code](https://code.claude.com/docs/en/model-config)

## Passagem de contexto entre contas

Como o desenvolvimento vai alternar entre três contas do Claude, tudo que o próximo Claude precisa saber mora **dentro do repositório**, versionado no git, e nunca só na conversa. Qualquer conta que abrir o projeto lê os mesmos arquivos e continua de onde a outra parou.

**Arquivos de contexto (criados no prompt 1.0)**

| Arquivo | O que guarda | Quem atualiza |
| --- | --- | --- |
| `CLAUDE.md` | Regras fixas do projeto, curtas: onde fica cada coisa, convenções, o que nunca fazer, e a instrução de ler `docs/ESTADO.md` ao começar | Só quando uma regra muda |
| `docs/GDD.md` | Documento de Design exportado | Quando o design muda |
| `docs/ESTADO.md` | Situação atual: parte e prompt em andamento, o que já funciona, o que está quebrado, próximo passo exato | Ao fim de toda tarefa |
| `docs/DECISOES.md` | Decisões técnicas tomadas, com data e motivo, para ninguém desfazer sem saber | Quando uma decisão é tomada |
| `docs/SESSOES.md` | Diário curto: uma linha por sessão (data, conta, o que foi feito) | Ao fim de toda sessão |

**Regra no CLAUDE.md (o prompt 1.0 já pede para escrever)**

```
## Continuidade entre sessões
- Ao começar qualquer sessão: leia docs/ESTADO.md e as últimas
  entradas de docs/SESSOES.md antes de fazer qualquer coisa.
- Ao terminar qualquer tarefa: rode /passagem.
- Se o limite de uso estiver perto, pare no próximo ponto estável e
  rode /passagem antes de qualquer outra coisa.
- Nunca deixe trabalho sem commit no fim de uma sessão.
```

**Skill `/passagem`** (fica em `.claude/skills/passagem/SKILL.md`, criada no prompt 1.0)

```
---
name: passagem
description: Atualiza o contexto do projeto para a próxima sessão ou
  conta continuar. Use ao terminar uma tarefa, ao fim da sessão ou
  quando o limite de uso estiver perto.
---

1. Atualize docs/ESTADO.md:
   - Parte e prompt do Pacote de Prompts em andamento
   - O que foi concluído nesta sessão
   - O que está funcionando e foi testado
   - Bugs conhecidos e coisas pela metade, com o arquivo onde estão
   - Próximo passo exato, escrito como o prompt que a próxima sessão
     deve executar
2. Se alguma decisão técnica foi tomada, acrescente em docs/DECISOES.md
   com data e motivo.
3. Acrescente uma linha em docs/SESSOES.md: data, o que foi feito, o
   próximo passo.
4. Se uma regra fixa do projeto mudou, atualize o CLAUDE.md.
5. Faça commit de tudo com uma mensagem que resuma a sessão.
6. Mostre um resumo de 5 linhas do que ficou registrado.
```

**Skill `/retomar`** (`.claude/skills/retomar/SKILL.md`)

```
---
name: retomar
description: Retoma o trabalho a partir do contexto salvo. Use no
  início de toda sessão, especialmente ao trocar de conta.
---

## Estado atual
!`cat docs/ESTADO.md`

## Últimas sessões
!`tail -n 10 docs/SESSOES.md`

## Últimos commits
!`git log --oneline -10`

Resuma em poucas linhas onde o projeto está, aponte qualquer
inconsistência entre o estado registrado e os commits, e proponha o
próximo passo. Não comece a implementar antes de eu confirmar.
```

**Como trocar de conta:** na conta que está acabando, rode `/passagem`. Na próxima conta, abra o mesmo projeto e rode `/retomar`. As skills ficam no repositório, então aparecem igual nas três contas.

## Skills recomendadas

Skills ensinam o Claude Code a fazer um tipo de tarefa do jeito certo e só carregam quando são usadas. Use poucas e boas: cada skill instalada ocupa um pouco de contexto em toda sessão.

**Instalar (de terceiros)**

| Skill | Para quê | Como instalar |
| --- | --- | --- |
| [GodotPrompter](https://www.sourcepulse.org/projects/31409234) | Pacote de skills para Godot 4.3+: arquitetura, sistemas de jogo, interface, build e uma revisão de código com checklist específico de Godot | `claude plugins marketplace add jame581/skillsmith` e depois `claude plugins install godot-prompter@skillsmith` |
| [skill-creator](https://code.claude.com/docs/en/skills) | Oficial da Anthropic: cria e testa skills próprias do projeto | `/plugin install skill-creator@claude-plugins-official` |

Use só um pacote de Godot: o GodotPrompter já cobre GDScript, cenas e boas práticas. Existe também o Claude-Code-Game-Studios, com dezenas de agentes imitando um estúdio inteiro, mas para um projeto solo ele pesa mais do que ajuda; não recomendo. Antes de instalar qualquer skill de terceiros, leia o `SKILL.md`: uma skill pode liberar ferramentas para si mesma.

**Já vêm no Claude Code**

| Skill | Quando usar |
| --- | --- |
| `/run-skill-generator` | Uma vez, no começo: ensina o Claude Code a abrir e rodar o projeto Godot, para o `/run` e o `/verify` funcionarem |
| `/verify` | Depois de cada sistema: roda o jogo e confere se a mudança funciona |
| `/code-review` | Antes de fechar cada parte do plano |
| `/security-review` | Na Parte 3, junto com a auditoria 3.11 |

**Criar no projeto (com o skill-creator, em `.claude/skills/`)**

Não existe skill pronta boa para PixelLab, ElevenLabs ou para o estilo deste jogo, então vale criar as nossas. Todas ficam no repositório e servem às três contas.

| Skill | Conteúdo |
| --- | --- |
| `passagem` e `retomar` | As de continuidade, acima |
| `estilo-arte` | Prefixo de estilo, prefixo negativo, tamanhos, regras de camada e como importar no Godot o que vier do PixelLab |
| `som` | Convenções de nome, volume e formato dos arquivos do ElevenLabs, variações sorteadas, onde ligar cada som |
| `balanceamento` | Onde ficam os dados, tetos de status, regra de ouro (status aumenta janela, não acerta pelo jogador), como rodar a simulação 3.12 |
| `regra-da-justa` | Regras para mexer na regra do impacto: manter determinística, atualizar GDScript e TypeScript juntos, rodar os casos de teste compartilhados |
| `supabase-jogo` | Nunca escrever economia pelo cliente, sempre Edge Function, RLS em toda tabela nova, testar na branch antes da produção |

O Supabase em si é usado pelo conector já ligado à sua conta, não por skill.

## Guia de estilo da arte

Todo prompt de arte começa com o mesmo prefixo, para o jogo inteiro sair com uma cara só. Os prompts de arte ficam em inglês porque os geradores respondem melhor assim.

**Prefixo de estilo (colar no início de todo prompt do PixelLab)**

```
High-detail pixel art, dark medieval tone, gritty and mature, muted
earthy palette (iron grey, worn leather brown, mud, overcast sky),
heraldic colors as the only saturated accents, rim light from an
overcast sky, visible wear, scratches and dirt on metal, cloth with
folds, crisp pixel clusters, no anti-aliasing blur, no outlines thicker
than 1 pixel, side view facing right, transparent background.
```

**Prefixo negativo (quando a ferramenta aceitar)**

```
cartoon, chibi, cute, bright saturated colors everywhere, 3D render,
blurry, smooth gradients, text, watermark, modern elements,
fantasy glowing armor, anime
```

**Tamanhos**

| Uso | Tamanho do quadro | Observação |
| --- | --- | --- |
| Cavaleiro montado na justa | 160 × 160 px | Animado, só vista lateral |
| Cavaleiro a pé (vila, treino) | 96 × 96 px | Animações curtas |
| Retrato na tela de Equipamentos | 256 × 256 px | Parado ou só respiração |
| Cavalo sozinho na tela de Equipamentos | 256 × 192 px | Parado ou só respiração |
| Ícone de peça | 64 × 64 px | Fundo transparente |
| Prédio da vila | 192 × 192 px | 4 a 5 estágios por prédio |
| Retrato de NPC | 128 × 128 px | 2 a 3 expressões |

Confira no PixelLab os tamanhos que o seu plano permite; se o máximo for menor, gere no maior tamanho disponível e mantenha a mesma proporção.

**Regras de camada**

- Peças de armadura e de cavalo são geradas em tons de cinza, para o shader do jogo aplicar as cores da casa.
- Toda peça segue o mesmo esqueleto: mesma pose base, mesmo quadro, mesma posição do quadril.
- O brasão nunca vem desenhado na peça; ele é uma camada separada aplicada pelo jogo.

**Paleta da casa:** cada casa tem cor principal, secundária e de metal (ferro, aço escurecido, latão). O jogo troca a paleta por shader.

## Parte 1 — Protótipo: Claude Code

Objetivo da parte: uma justa jogável no celular, com arte provisória (retângulos servem). Pergunta a responder no fim: a justa é divertida sozinha?

**1.0 · Estrutura do projeto** — Opus 5.5, high

```
Leia docs/GDD.md inteiro. Vamos começar um jogo mobile em Godot 4 com
GDScript, landscape, pixel art. Quero a estrutura de pastas e a base do
projeto pensadas para o jogo completo descrito no GDD, mesmo que agora só
vamos fazer a justa:
- pastas para cenas, scripts, dados de balanceamento (JSON ou Resource),
  traduções (pt_BR e en), arte, sons
- configuração de pixel art (filtro nearest, snap de pixel, resolução base
  e escala para celulares de proporções diferentes)
- um arquivo CLAUDE.md na raiz resumindo as regras do projeto: textos só em
  arquivos de tradução, números de balanceamento só em arquivos de dados,
  lógica da justa separada da apresentação (ela vai rodar também no
  servidor no futuro)
- git inicializado com .gitignore de Godot
Crie também o sistema de continuidade descrito na seção Passagem de
contexto do Pacote de Prompts: docs/ESTADO.md, docs/DECISOES.md,
docs/SESSOES.md, a seção Continuidade entre sessões no CLAUDE.md e as
skills de projeto passagem e retomar em .claude/skills/.
Me mostre o plano antes de criar os arquivos. No fim, rode /passagem.
```

**1.1 · Cena da arena** — Opus 5.5, medium

```
Crie a cena da justa conforme a seção A justa do docs/GDD.md: vista
lateral elevada 2.5D, cerca horizontal cortando a tela ao meio, pista de
baixo (jogador, corre para a direita) e pista de cima (rival, corre para a
esquerda, desenhado espelhado e um pouco menor). Use retângulos coloridos
como arte provisória, com nós já preparados para trocar pelos sprites
depois. Inclua arquibancada de fundo e uma câmera que consiga: plano
aberto, seguir o cavaleiro e dar zoom num ponto.
```

**1.2 · Fases da passada** — Opus 5.5, medium

```
Implemente uma máquina de estados para uma passada da justa com as fases
do GDD: Apresentação, Largada, Corrida, Mira, Impacto. Cada fase com
duração vinda do arquivo de dados. Uma justa tem 3 passadas e passada
extra em caso de empate. A câmera muda em cada fase como descrito na
tabela de fases. Deixe um sinal (signal) para cada mudança de fase, para
som e efeitos se conectarem depois.
```

**1.3 · Largada e galope** — Opus 5.5, medium

```
Implemente a entrada do jogador na Largada e na Corrida:
- Largada: o arauto baixa a bandeira; tocar logo depois dá largada
  perfeita, boa ou ruim, com janelas de tempo vindas dos dados
- Corrida: o galope tem um compasso; tocar no tempo certo mantém ou
  aumenta a velocidade, tocar fora do tempo ou rápido demais cansa o
  cavalo (stamina)
- o atributo Temperamento do cavalo aumenta a janela do compasso
Use toque na tela inteira, com uma mão. Mostre o compasso como um brilho
na barra de distância de baixo, não numa barra separada.
```

**1.4 · Mira e golpe** — Opus 5.5, medium

```
Implemente a fase de Mira: câmera lenta e zoom no rival por cerca de 2
segundos. O jogador segura o dedo e arrasta para mover a ponta da lança
sobre o rival; ao soltar, golpeia. Zonas: capacete, peito, escudo e
cavalo (falta). O atributo Precisão aumenta a área efetiva de cada zona.
Os sinais de alvo ficam discretos no próprio rival (brilho leve), sem
círculos grandes na tela.
```

**1.5 · Regra do impacto** — Opus 5.5, high

```
Crie a regra que resolve um impacto da justa como um módulo puro em
GDScript, sem nenhuma dependência de cena, nó ou tempo real. Entrada:
atributos dos dois cavaleiros e cavalos, equipamento, habilidade ativa e
os valores dos toques (qualidade da largada, ritmo médio, ponto da mira).
Saída: zona atingida, pontos, se houve derrubada, dano em cada peça de
armadura. Regras do GDD: capacete 3, peito 2, escudo 1, cavalo é falta,
derrubada vence a justa, Força contra Equilíbrio para derrubar. Tudo
numérico vem dos dados. Deve ser determinístico: mesma entrada e mesma
semente geram o mesmo resultado, porque o servidor vai recalcular a
justa com a mesma regra. Inclua testes que provem isso.
```

**1.6 · Rival controlado pela máquina** — Opus 5.5, medium

```
Crie a IA do rival. Ela produz os mesmos tipos de entrada que o jogador
(qualidade da largada, ritmo, ponto da mira) e passa pela mesma regra do
impacto. Parâmetros nos dados: precisão média, variação, zona preferida
(alguns miram alto, outros no peito) e se acelera cedo ou tarde. Crie 3
perfis de exemplo: novato, equilibrado e agressivo.
```

**1.7 · Interface da justa** — Sonnet 5.5, medium

```
Crie a interface da justa: plaquinhas no topo com retrato, nome, barra
de armadura e barra de stamina do cavalo (jogador à esquerda, rival à
direita), placar e "Passada 1/3" no centro, barra de distância embaixo
com um ícone de cavalo em cada ponta, botão redondo de habilidade no
canto inferior direito. Textos via arquivo de tradução. Precisa caber em
celulares de 16:9 a 20:9 sem cortar nada.
```

**1.8 · Sensação de impacto** — Opus 5.5, medium

```
Adicione a sensação de impacto: congelamento curto no choque (hit-stop),
tremor de câmera proporcional à força, partículas de lasca de madeira da
lança, faíscas no metal, peça de armadura voando quando o dano for alto,
vibração do celular opcional, e o rival caindo do cavalo na derrubada.
Tudo ligado aos sinais das fases, com intensidades nos dados.
```

**1.9 · Teste no celular** — Sonnet 5.5, medium

```
Configure a exportação Android do projeto para eu instalar no meu celular
e testar: modelo de exportação, permissões mínimas, orientação landscape,
ícone provisório. Me passe o passo a passo para gerar o APK e instalar.
Adicione um contador de FPS que só aparece em modo de depuração.
```

**1.10 · Painel de ajuste** — Sonnet 5.5, low

```
Crie um painel de depuração, só no modo de desenvolvimento, para eu mudar
em tempo real os números da justa (janelas de tempo, tamanhos das zonas,
perfil do rival, atributos) e salvar no arquivo de dados.
```

## Parte 1 — Protótipo: arte

Só o mínimo para a justa: um cavaleiro montado completo (sem camadas ainda), um cavalo, a arena e os efeitos. A arte em camadas começa na Parte 2. Todos os prompts abaixo vão depois do prefixo de estilo.

**Referência no Blender (opcional, antes do PixelLab):** pose simples de cavalo galopando de perfil com um cavaleiro de lança baixa, renderizada em silhueta preta sobre branco, 160 × 160 px. Use como imagem de referência de pose.

**A1 · Cavaleiro montado, parado**

```
A jousting knight mounted on a warhorse, full plate armor in greyscale
tones, closed great helm, lance held upright, kite shield on the left arm,
horse with a plain greyscale caparison reaching the knees, standing still,
full body of horse and rider in frame, 160x160.
```

**A2 · Animação de galope com lança baixa** (a partir de A1)

```
Same knight and horse, galloping to the right, lance lowered and couched
under the arm pointing forward, 8-frame gallop cycle, rider bobbing with
the horse's stride, caparison and plume swaying.
```

**A3 · Animação de impacto e derrubada**

```
Same knight and horse. Animation 1: lance hit receiving, rider rocked
backward, shield arm pushed back, 4 frames. Animation 2: rider knocked off
the horse, falling backward to the ground, horse continues forward, 8
frames.
```

**A4 · Lança estilhaçando**

```
Wooden jousting lance tip shattering into splinters on impact, burst of
wood fragments and dust, 6 frames, side view.
```

**A5 · Arena (fundo)**

```
Wide medieval tournament ground background, side view slightly from above,
wooden grandstands packed with a crowd in muted clothing, tattered heraldic
banners as the only strong colors, overcast grey sky, muddy dirt track,
distant castle silhouette, 640x360, layered for parallax: sky, castle,
grandstands, track.
```

**A6 · Cerca de justa**

```
Long wooden tilt barrier for jousting, weathered planks and posts, mud at
the base, side view slightly from above, tileable horizontally, 64x48.
```

**A7 · Arauto com bandeira**

```
Medieval herald standing on a wooden platform holding a flag, animation of
raising and dropping the flag to start the joust, 6 frames, 64x96.
```

**Retoque:** no PixelLab ou no seu editor, confira se o cavalo tem a mesma altura em todos os quadros e se a lança sai sempre do mesmo ponto da mão. Se a IA errar a proporção do cavalo, use a silhueta do Blender como referência e gere de novo.

## Parte 1 — Protótipo: som

Efeitos sonoros no gerador de efeitos do ElevenLabs. Gere de 3 a 4 variações de cada um; no jogo, sons repetidos (galope, impacto) sorteiam entre as variações para não cansar.

| Som | Prompt | Duração |
| --- | --- | --- |
| Galope | Heavy warhorse galloping on packed muddy dirt, armor and harness rattling, steady rhythm, close perspective | 4 s, em loop |
| Largada | Herald trumpet short fanfare, medieval brass, outdoor reverb | 2 s |
| Bandeira | Cloth flag snapping down sharply in the wind | 1 s |
| Impacto no escudo | Wooden lance striking a steel shield, loud crack, metallic ring | 1 s |
| Impacto no capacete | Wooden lance hitting a steel helmet, sharp metallic clang, heavy | 1 s |
| Lança estilhaçando | Wooden lance shattering into splinters, explosive wood crack | 1,5 s |
| Derrubada | Armored knight falling off a horse onto mud, heavy metal clatter, thud | 2 s |
| Torcida (fundo) | Medieval tournament crowd murmuring, outdoor, distant, loop | 10 s, em loop |
| Torcida explode | Medieval crowd erupting in cheers after a hit, outdoor | 3 s |
| Torcida decepcionada | Medieval crowd groaning in disappointment | 2 s |
| Cavalo bufando | Warhorse snorting and blowing, tired | 2 s |
| Toque no tempo | Soft leather saddle creak with a subtle percussive thump | 0,3 s |

**Voz do arauto (provisória):** uma voz grave e teatral do catálogo de vozes, falando em português: "Senhoras e senhores!", "Preparem-se!", "Acerto no elmo!", "Derrubado!". As falas definitivas, com o nome do cavaleiro, ficam para a Parte 2.

## Parte 2 — Fatia vertical: Claude Code

Objetivo da parte: os primeiros 30 minutos do jogo completos, do personagem criado até vencer o campeão da primeira região, com a vila funcionando.

**2.1 · Personagem em camadas e cores da casa** — Opus 5.5, high

```
Leia as seções Equipamentos e direção de arte e Guia de estilo do
docs/GDD.md. Projete o sistema de personagem em camadas para o cavaleiro
e o cavalo: um esqueleto de animação comum, base de corpo feminina ou
masculina, e uma camada por espaço de equipamento (lista no GDD), todas
sincronizadas quadro a quadro. As peças vêm em tons de cinza e um shader
de troca de paleta aplica cor principal, secundária e de metal da casa.
O brasão é uma camada separada aplicada depois do espelhamento do rival.
O mesmo sistema precisa servir a três tamanhos: justa (160 px), vila (96
px) e tela de Equipamentos (256 px). Proponha a arquitetura antes de
implementar e diga como eu devo exportar as peças do PixelLab.
```

**2.2 · Criação de personagem** — Sonnet 5.5, medium

```
Crie a tela de criação de personagem do GDD: corpo feminino ou masculino,
rosto, cabelo, tom de pele, nome e nome da casa, cores da casa e pelagem
do cavalo inicial (alazão, preto, branco). Pré-visualização ao vivo do
cavaleiro montado. Filtro de nomes ofensivos com lista em arquivo de
dados. Botão para sortear tudo.
```

**2.3 · Editor de brasão** — Sonnet 5.5, medium

```
Crie o editor de brasão: formato do escudo, divisão do campo (liso,
partido, cortado, esquartelado), símbolo e posição, cores. As opções
vêm de arquivos de dados para eu adicionar mais depois. O brasão gera uma
textura usada no escudo, na sobreveste, na caparação e nas bandeiras.
```

**2.4 · Dados do jogador** — Opus 5.5, medium

```
Crie o modelo de dados do jogador (cavaleiro, casa, cavalos, inventário,
equipamento, vila, timers, progresso do PvE) e um save local. Prepare
para o futuro servidor: todo dado com versão, timers guardados como
horário de término, e nenhuma regra de economia escrita direto na tela,
só em serviços que depois vão virar chamadas ao servidor.
```

**2.5 · Vila** — Sonnet 5.5, medium

```
Crie a vila vista de cima conforme A vila no GDD, sem andar livre: tocar
num prédio abre a tela dele. Prédios da fatia vertical: casa senhorial,
estábulo, campo de treino, armeiro, ferreiro e arena. Cada prédio tem
estágios visuais por nível, um balão com o timer quando está ocupado e um
ícone quando algo está pronto. Liberação de prédios por nível conforme a
tabela do GDD.
```

**2.6 · Vila viva** — Opus 5.5, medium

```
Adicione a vila viva do GDD: o cavaleiro treinando contra o estafermo no
campo de treino com a armadura atual, o cavalo no estábulo (escovado,
comendo, deitado quando cansado), o armeiro martelando quando há forja em
andamento, personagens parados quando o prédio está ocioso. Ciclo de dia
e noite pelo horário do celular, com tochas à noite, e clima sorteado
(limpo, nublado, chuva, neblina).
```

**2.7 · Treino, cavalos e fôlego** — Opus 5.5, medium

```
Implemente o treino conforme Progressão e Timers no GDD: o treino ocupa
uma vaga, não o cavaleiro; cavalo em treino não corre; cavalo cansado
pode correr com penalidade; fôlego recupera com o tempo; várias pelagens
e cavalos no estábulo. Timers usam horário de término e continuam com o
jogo fechado. Curva de tempo por nível vinda dos dados. Notificação local
quando algo termina.
```

**2.8 · Tela de Equipamentos** — Sonnet 5.5, medium

```
Crie a tela de Equipamentos dentro do armeiro: abas Cavaleiro e Cavalo,
retrato grande no centro, espaços de peça em volta ligados à parte do
corpo. Tocar num espaço lista as peças; passar por uma já mostra no
personagem antes de equipar. Cada peça mostra status, raridade,
durabilidade e conjunto. Inclua o guarda-roupa visual (aparência de uma
peça com os status de outra).
```

**2.9 · Desgaste e conserto** — Opus 5.5, medium

```
Ligue o dano por peça que a regra do impacto já calcula ao inventário:
durabilidade cai, a peça muda de aparência (riscada, amassada, rachada)
em três estágios, e com durabilidade zero perde os bônus. Conserto no
armeiro com custo e tempo vindos dos dados.
```

**2.10 · Primeira região do PvE** — Opus 5.5, medium

```
Implemente a primeira região do circuito (Feiras de vila) conforme
Disputas PvE no GDD: 5 torneios em chave, rivais com perfis diferentes,
um campeão final e o rival nêmesis. Estrelas de 1 a 3 por disputa;
com 3 estrelas libera repetir no automático (o automático simula a justa
pela mesma regra, com precisão média). Campeões e primeira luta são
sempre manuais. Recompensas de ouro e XP vindas dos dados.
```

**2.11 · Início do jogo** — Opus 5.5, medium

```
Monte o fluxo de Início do jogo do GDD: criação, brasão, cavalo, justa
de exibição automática vista da arquibancada com o arauto explicando,
primeira justa jogada com dicas por fase, primeiro baú instantâneo e
chegada à vila. No primeiro dia, todos os timers terminam em segundos.
Permita pular o tutorial para quem reinstalar.
```

**2.12 · Conta e save na nuvem** — Opus 5.5, high

```
Integre o jogo com o Supabase para conta e save: login anônimo no
primeiro acesso, com opção de vincular Google Play Games depois sem
perder progresso. Salve o estado do jogador no banco com regras de acesso
(RLS) para que cada jogador só leia e escreva os próprios dados. Ainda
não é a economia no servidor (isso é a Parte 3), mas desenhe as tabelas
já pensando nela. Use o conector do Supabase para criar o projeto e as
migrações.
```

**2.13 · Métricas** — Sonnet 5.5, medium

```
Adicione registro de eventos de jogo (início do tutorial, cada passo
do tutorial, justa iniciada e terminada, prédio melhorado, desistência)
numa tabela do Supabase, para eu ver onde os jogadores param.
```

## Parte 2 — Fatia vertical: arte

Aqui começa a arte em camadas. A ordem importa: primeiro as bases (corpo e cavalo nus), depois cada peça desenhada sobre a base, sempre no mesmo quadro e na mesma pose. Todos os prompts vão depois do prefixo de estilo.

**B1 · Bases do cavaleiro** (gerar para os dois corpos e nos três tamanhos)

```
Base body for a layered character system: [female | male] knight in a
plain grey padded gambeson only, no armor, neutral pose seated on a horse
saddle (rider only, horse hidden), arms in jousting position, side view
facing right, [160x160 | 96x96 standing | 256x256 portrait].
```

**B2 · Rostos e cabelos** (retrato 256 px, depois reduzir)

```
Set of 6 [female | male] medieval faces for a knight portrait, weathered
and mature, varied ages and features, neutral expression, head and neck
only, same position and size in every frame, transparent background.
```

```
Set of 8 medieval hairstyles as separate layers ([female | male]): short
cropped, long tied back, braided, shaved sides, curly, bald with beard
(male), long loose, under a coif. Greyscale for palette swap. Same head
position as the faces.
```

**B3 · Cavalo base** (uma vez por pelagem)

```
Warhorse base for a layered system, muscular destrier, no tack or armor,
[chestnut red | black | white grey] coat, side view facing right, poses:
standing, 8-frame gallop, idle breathing, [160x160 | 256x192 portrait].
```

**B4 · Modelo de prompt para peça de armadura do cavaleiro**

```
Armor layer only: [PEÇA], [ESTILO], greyscale for palette swap, fitted
exactly to the [female | male] knight base pose in the reference image,
nothing else drawn, same canvas size and position, side view facing right.
```

Peças da fatia vertical (um conjunto inicial completo, em três estilos):

| \[PEÇA\] | \[ESTILO\] — conjunto Escudeiro | \[ESTILO\] — conjunto Vigia | \[ESTILO\] — conjunto Ferro Negro |
| --- | --- | --- | --- |
| great helm with eye slit | plain riveted iron, dented | rounded bascinet with mail aventail | blackened steel, angular, tall crest mount |
| gorget | leather and iron plates | mail collar | blackened steel |
| breastplate | iron with leather straps | brigandine with rivets | fluted blackened steel |
| pauldrons | small round iron | layered lames | large spiked edge |
| vambraces and gauntlets | leather with iron splints | mail and plate | articulated blackened steel |
| cuisses and greaves | padded with iron knee | half plate | full articulated steel |
| sabatons | leather boots with iron toe | plate | pointed blackened steel |
| tabard (cloth over armor) | short, frayed edges | long, belted | long, split, heavy cloth |
| cape | none | short shoulder cape | long tattered cape |
| kite shield | wooden with iron rim | heater shield | large jousting targe with notch |
| jousting lance | plain wood | painted spiral | dark wood with iron vamplate |

Para cada peça, gere também a versão danificada em três estágios:

```
Same armor layer, damage stage [1 scratched | 2 dented | 3 cracked and
bent], same canvas and position.
```

**B5 · Modelo de prompt para peça do cavalo**

```
Horse equipment layer only: [PEÇA], [ESTILO], greyscale for palette swap,
fitted exactly to the warhorse base in the reference image, nothing else
drawn, same canvas size and position, side view facing right.
```

| \[PEÇA\] | Conjunto inicial |
| --- | --- |
| chanfron (head armor) | plain iron plate with eye guards |
| crinet (neck armor) | overlapping iron lames |
| peytral (chest armor) | iron plate with leather straps |
| crupper (hindquarter armor) | iron plates |
| caparison (full cloth cover) | long cloth to the knees, split at the legs |
| high-backed jousting saddle | dark leather and wood |
| bridle and reins | plain leather / decorated with studs |
| stirrups | iron |
| decorations | plume on the chanfron, small bells, fringe |

**B6 · Ícones de peça**

```
Inventory icon of [PEÇA E ESTILO], three-quarter view, centered,
dramatic side light, 64x64, transparent background.
```

**B7 · Prédios da vila** (cinco estágios por prédio)

```
Top-down three-quarter view medieval [PRÉDIO], dark gritty tone, muted
stone and timber, stage [1 to 5]: [1 ruined shack | 2 small timber
building | 3 timber and stone | 4 stone with banners | 5 fortified and
ornate], 192x192, transparent background.
```

Prédios: manor house, stable, training yard with quintain, armorer's workshop, blacksmith forge, tournament arena entrance.

**B8 · Animações da vila viva**

```
Knight on horseback charging a rotating quintain (training dummy with
shield and swinging sandbag) in a muddy training yard, top-down
three-quarter view, 8 frames, 96x96.
```

```
Armorer hammering a breastplate on an anvil, sparks flying, forge glow,
top-down three-quarter view, 6 frames, 64x64.
```

```
Stable hand brushing a horse, horse shifting weight, 6 frames, 96x96.
Horse lying down resting, slow breathing, 4 frames, 96x96.
```

**B9 · Retratos de NPC** (128 px, expressões neutra, feliz e brava)

```
Portrait of a medieval [cavalariço: young stable hand | mestre de armas:
scarred veteran master-at-arms | armeiro: burly armorer with leather apron
| ferreira: female blacksmith with soot on her face | arauto: theatrical
herald with feathered cap], weathered and mature, dark tone, 128x128.
Three expressions: neutral, pleased, angry.
```

Os personagens de NPC mudam de aparência conforme o prédio evolui: gere uma versão mais bem vestida para os estágios 3 e 5.

**B10 · Rivais e nêmesis**

```
Mounted rival knight for a jousting game, [arrogant young noble in
polished ornate armor | brutish veteran in battered black armor | cunning
knight with a fox heraldry], side view facing left, 160x160, same pose
as the player base.
```

## Parte 2 — Fatia vertical: som e música

A trilha mistura o peso medieval sombrio com energia de rock: instrumentos de época (tambores, gaita de fole, rabeca, alaúde) com guitarra distorcida e bateria por baixo. Gere a música pelo gerador de música do ElevenLabs; se ele não atender, guarde os prompts para outra ferramenta.

**Música**

| Faixa | Prompt | Duração |
| --- | --- | --- |
| Tema da vila | Dark medieval folk, slow and atmospheric, hurdy-gurdy and lute over low drones, distant church bell, calm but brooding, seamless loop | 2 min, loop |
| Tema da justa | Medieval rock anthem, war drums and distorted guitars, bagpipe melody, driving 140 bpm, epic and gritty, seamless loop | 2 min, loop |
| Final de torneio | Same as the joust theme but heavier and faster, choir chants, rising tension | 2 min, loop |
| Vitória | Short triumphant medieval rock sting, brass and guitar, crowd roar | 5 s |
| Derrota | Short somber medieval sting, low strings and a single drum | 4 s |
| Subir de nível | Bright fanfare with bells and a guitar chord | 3 s |

**Efeitos da vila e da interface**

| Som | Prompt |
| --- | --- |
| Tocar num prédio | Heavy wooden door creak opening, short |
| Botão | Soft leather and metal click |
| Equipar peça | Plate armor buckle being fastened, metallic |
| Moedas | Handful of medieval coins clinking into a leather pouch |
| Martelo na bigorna | Blacksmith hammer striking hot iron on an anvil, ringing |
| Forja | Bellows pumping and fire roaring in a forge, loop |
| Estábulo | Horses shifting in straw, soft snorts, loop |
| Campo de treino | Lance striking a quintain shield, sandbag swinging and thudding |
| Treino pronto | Short horn call in the distance |
| Obra no prédio | Hammering, sawing and stones being placed, 3 s |
| Chuva na vila | Steady rain on wooden roofs and mud, loop |

**Voz do arauto (definitiva)**

Crie uma voz própria no ElevenLabs (grave, teatral, rouca) e gere as falas em português e inglês. Para o nome do cavaleiro, grave os títulos genéricos e deixe o nome aparecer escrito na tela:

- "Senhoras e senhores!" · "Da casa de..." · "Preparem as lanças!" · "Acerto no elmo!" · "Acerto no peito!" · "No escudo!" · "Derrubado!" · "Falta! Atingiu o cavalo!" · "Vitória!" · "Uma passada decisiva!"

## Parte 3 — Lançamento: servidor e banco

Aqui o servidor passa a mandar em tudo que vale algo. É a parte mais delicada do projeto; por isso a maioria dos prompts usa o Opus 5.5 em esforço alto. Um detalhe técnico importante: as Edge Functions do Supabase rodam em TypeScript, não em GDScript, então a regra da justa terá duas versões, e um conjunto de casos de teste compartilhado garante que as duas dão sempre o mesmo resultado.

**3.1 · Banco completo e regras de acesso** — Opus 5.5, high

```
Leia Infraestrutura online, Funções sociais, PvP e Monetização no
docs/GDD.md. Desenhe o banco completo no Supabase para o lançamento:
jogador, cavaleiro, casa, cavalos, inventário, equipamento, vila, timers,
PvE, baús, forja, ligas, temporadas, partidas, defesas de PvP, ordens,
chat, amigos, denúncias, compras e eventos de métricas. Regras de acesso
(RLS) em todas as tabelas: o jogador lê os próprios dados e nunca
escreve diretamente em nada que envolva economia ou ranking. Escreva
como migrações e aplique primeiro numa branch de teste do Supabase.
```

**3.2 · Economia no servidor** — Opus 5.5, high

```
Mova toda a economia para Edge Functions: iniciar e concluir treino,
melhorar prédio, abrir baú (com garantia de raro a cada 10 e
probabilidades dos dados), forjar, melhorar e consertar peça, gastar
gemas para pular timer, recompensas de anúncio com limite diário. Timers
pelo relógio do servidor. Cada função valida tudo, é idempotente (repetir
a mesma chamada não entrega duas vezes) e tem limite de chamadas por
jogador. Atualize o jogo para chamar essas funções em vez de mudar os
dados localmente.
```

**3.3 · Balanceamento remoto** — Opus 5.5, medium

```
Mova os arquivos de dados de balanceamento para tabelas no Supabase,
com versão. O jogo baixa a versão atual ao abrir e guarda em cache para
funcionar com sinal fraco. Eu quero mudar status, preços, timers e
probabilidades no painel do Supabase sem lançar atualização do app.
```

**3.4 · Justa conferida no servidor** — Opus 5.5, high

```
Porte a regra do impacto (o módulo puro da Parte 1) para TypeScript numa
Edge Function. Crie um arquivo de casos de teste compartilhado (entradas
e resultados esperados) que roda contra a versão GDScript e a versão
TypeScript, e falha se elas divergirem. O jogo envia os toques da justa;
o servidor recalcula, rejeita valores impossíveis (tempo de reação
desumano, mira perfeita repetida) e só então entrega recompensas.
```

**3.5 · PvP assíncrono** — Opus 5.5, high

```
Implemente o PvP assíncrono da seção PvP do GDD: configuração de defesa
do jogador (cavalo, equipamento, habilidade) salva como retrato no
servidor; pareamento por pontos de liga com limite de faixa de poder;
o atacante joga a justa manualmente contra a IA do fantasma; o servidor
confere e atualiza os pontos dos dois. Defesas vencidas também dão
pontos ao defensor. Registre cada partida para eu investigar denúncias.
```

**3.6 · Ligas, temporadas e campeonatos** — Opus 5.5, medium

```
Implemente ligas (Bronze a Campeão, divisões III a I), temporadas de 4
semanas com recompensas e reinício parcial, e campeonatos de fim de
semana em chave eliminatória. Abertura e fechamento por tarefa agendada
no banco. Ranking de jogadores e de ordens.
```

**3.7 · Compras** — Opus 5.5, high

```
Integre compras no aplicativo para Android e iOS no Godot: gemas, VIP
mensal, passe da temporada e ofertas. Toda compra é validada no servidor
com o recibo da Google Play ou da App Store antes de entregar qualquer
coisa; trate reembolso, renovação e cancelamento do VIP, compra repetida
e restaurar compras. Nada é entregue só porque o celular disse que pagou.
```

**3.8 · Ordens, chat e amigos no servidor** — Opus 5.5, medium

```
Implemente no Supabase o lado servidor das Funções sociais do GDD: ordens
(cargos, entrada, expulsão, ajuda nos timers, doação com limite, torneio
semanal, loja da ordem), chat da ordem e global por idioma usando
Realtime, mensagens rápidas, amigos, presentes, justa amistosa.
Moderação: filtro de palavras no servidor, denúncia, bloqueio,
silenciamento automático e fila de denúncias para eu revisar.
```

**3.9 · Obrigações** — Sonnet 5.5, medium

```
Adicione: exclusão de conta dentro do app (apaga ou anonimiza os dados
no servidor), tela de política de privacidade e termos de uso, consentimento
de anúncios conforme a região, e as probabilidades de cada baú visíveis
na tela do baú.
```

**3.10 · Operação** — Sonnet 5.5, medium

```
Configure: branch de teste do Supabase separada da produção, backup
automático, registro de erros do jogo e das Edge Functions, e um painel
simples (consultas salvas) com jogadores ativos por dia, compras,
denúncias abertas e onde os jogadores desistem.
```

**3.11 · Auditoria de segurança antes de lançar** — Opus 5.5, xhigh

```
Faça uma auditoria de segurança completa do jogo antes do lançamento:
regras de acesso de todas as tabelas, todas as Edge Functions, chaves
expostas no app, possibilidades de duplicar itens ou moedas, trapaça na
justa e no PvP, abuso de chat e de compras. Liste cada problema com
gravidade e corrija os graves.
```

## Parte 3 — Lançamento: sistemas do jogo

Tudo que o jogador vê e toca no lançamento. Cada sistema chama as Edge Functions da seção anterior; nenhum mexe na economia sozinho.

**3.12 · Simulação da economia** — Opus 5.5, high (fazer antes dos outros)

```
Crie um script de simulação da economia do jogo a partir dos dados de
balanceamento e das regras do docs/GDD.md. Simule 90 dias de três
jogadores: grátis que joga 15 minutos por dia, grátis que vê anúncios, e
pagante com VIP e passe. Mostre em quantos dias cada um chega a cada
liga, a cada região do PvE e ao primeiro conjunto completo. Meta: o
pagante chega primeiro, o grátis chega depois, mas chega. Gere uma
planilha com os resultados e sugira ajustes de números.
```

**3.13 · Circuito completo do PvE** — Opus 5.5, medium

```
Expanda o PvE para as 5 regiões do GDD (vila, condado, ducado, reino,
Grande Torneio), com 5 a 8 torneios cada, campeões com personalidade e
os desafios especiais (uma chance só, cavalo emprestado, sem escudo,
chuva, justa noturna). Tudo vindo de dados, para eu criar torneios novos
sem mexer no código.
```

**3.14 · Baús e itens** — Opus 5.5, medium

```
Implemente no jogo os baús do GDD (madeira, ferro, ouro, real), os 4
espaços, chave, a animação de abrir, raridades de item, itens repetidos
virando fragmentos e a tela que mostra as probabilidades. A abertura é
feita pela Edge Function; o jogo só mostra o resultado.
```

**3.15 · Forja** — Opus 5.5, medium

```
Implemente a forja da seção Forja do GDD no armeiro e o ferreiro: criar
peça a partir de projeto e materiais (com pequena variação de status),
melhorar de +1 a +10 (garantido até +5, com chance de falha depois, sem
destruir a peça), consertar, fundir lingotes no ferreiro. Fila própria
de forja. Animação do armeiro trabalhando enquanto a peça é feita.
```

**3.16 · Habilidades especiais e conjuntos** — Opus 5.5, high

```
Implemente as habilidades especiais do GDD: ativas (botão que carrega na
corrida) e passivas (disparam no impacto), o ciclo Investida > Bloqueio >
Golpe Pesado > Investida, um espaço no começo e o segundo liberado em
liga alta, limite de uma por grupo. Bônus de conjunto: 2 peças dão bônus,
conjunto completo libera a habilidade. Tetos de status com retorno
decrescente. O efeito visual e o letreiro aparecem sempre que uma
habilidade dispara. A regra vale nas duas versões da justa (GDScript e
TypeScript), com casos de teste novos.
```

**3.17 · Telas de PvP e liga** — Sonnet 5.5, medium

```
Crie as telas do salão da liga: liga e divisão atuais, pontos, botão de
procurar adversário mostrando o cavaleiro dele antes da justa, montagem
da configuração de defesa, histórico de defesas, ranking de jogadores e
de ordens, recompensas da temporada e campeonatos de fim de semana.
```

**3.18 · Loja, VIP, passe e ofertas** — Sonnet 5.5, medium

```
Crie a loja: gemas, VIP, passe da temporada (trilha grátis e premium lado
a lado), cosméticos, materiais com limite diário e ofertas por tempo
limitado. As ofertas aparecem nos momentos definidos no GDD (depois de
perder por pouco, ao subir de liga, ao abrir um projeto sem material),
sempre como janela que fecha com um toque, nunca bloqueando o jogo.
```

**3.19 · Anúncios premiados** — Sonnet 5.5, medium

```
Integre anúncios premiados (rewarded) no Godot para Android e iOS, só
opcionais: cortar 30 minutos de um timer, dobrar recompensa de vitória,
baú de madeira extra, com limite diário vindo dos dados. A recompensa só
é entregue quando o servidor confirma. Jogador VIP ganha os mesmos
benefícios sem assistir. Nenhum anúncio forçado em lugar nenhum.
```

**3.20 · Telas sociais** — Sonnet 5.5, medium

```
Crie as telas de ordem (membros, cargos, pedidos de ajuda, doações,
torneio semanal, loja da ordem, criar e editar brasão da ordem), chat
(ordem e global, mensagens rápidas, denunciar e bloquear), amigos e
perfil público com cavaleiro, cavalo, brasão, liga e títulos. Bandeira
da ordem na torre da casa senhorial e cavaleiros da ordem passando pela
praça da vila.
```

**3.21 · Renome, missões, conquistas e títulos** — Opus 5.5, medium

```
Implemente Renome (fama que sobe com vitórias e libera convites e reação
da torcida), missões diárias e semanais, recompensa de login de 7 dias,
conquistas e títulos que o arauto anuncia antes da justa.
```

**3.22 · História, companheiros e nêmesis** — Opus 5.5, medium

```
[Preencher quando o enredo estiver decidido.] Implemente as cenas curtas
de história entre regiões, com retratos e falas, os três companheiros
(arauto, ferreira, escudeiro) com seus bônus e o nêmesis recorrente que
reaparece em cada região com falas próprias.
```

**3.23 · Notificações** — Sonnet 5.5, medium

```
Adicione notificações push pelo servidor (treino pronto, cavalo
descansado, baú aberto, forja pronta, ajuda da ordem, temporada
terminando), todas desligáveis uma a uma nas configurações.
```

**3.24 · Inglês e acessibilidade** — Haiku 5.5, low

```
Traduza todos os textos do arquivo pt_BR para en mantendo o tom
medieval. Adicione nas configurações: modo canhoto (inverte botões),
vibração liga e desliga, tamanho de texto.
```

**3.25 · Desempenho em celular fraco** — Opus 5.5, high

```
Analise o desempenho do jogo num Android de entrada: quadros por segundo
na justa e na vila, memória, tempo de carregamento e tamanho do APK.
Corrija o que estiver abaixo de 60 quadros na justa e proponha um modo
de economia de bateria.
```

## Parte 3 — Lançamento: arte e som

Mais conjuntos, as regiões, baús, interface e o restante dos sons. Os modelos de prompt B4 a B6 da Parte 2 continuam valendo para cada peça nova.

**C1 · Conjuntos de armadura do lançamento** (usar o modelo B4 com estes estilos)

| Conjunto | Raridade | \[ESTILO\] |
| --- | --- | --- |
| Escudeiro, Vigia, Ferro Negro | Comum a incomum | Já feitos na Parte 2 |
| Corvo | Raro | blackened steel with feather-shaped lames, raven crest |
| Javali | Raro | heavy rounded plates, tusk ornaments on the helm |
| Lobo Cinzento | Épico | grey steel with fur mantle, wolf-head pauldrons |
| Cervo Real | Épico | gilded edges on dark steel, antler crest |
| Dragão de Ferro | Lendário | dark steel scales, horned great helm, ember-red cloth |
| Sol Poente | Lendário (temporada) | burnished bronze and steel, radiant crest, torn crimson cape |

Cada conjunto também ganha a versão de cavalo (testeira, crineira, peitoral, anca e caparação) no modelo B5.

**C2 · Pelagens extras de cavalo** (modelo B3)

Tordilho (dapple grey), baio (bay), palomino escuro, malhado (piebald), negro azeviche com crina longa (lendário).

**C3 · Arenas das regiões** (modelo A5 trocando o cenário)

| Região | Cenário |
| --- | --- |
| Feiras de vila | muddy village green, small wooden stands, farm houses |
| Condado | stone town walls, larger stands, market stalls |
| Ducado | castle courtyard, stone stands, many banners |
| Reino | royal tiltyard, royal box with canopy, huge crowd |
| Grande Torneio | grand cathedral city at dusk, torches, massive crowd |
| Justa noturna | any arena at night lit by braziers and torches |
| Chuva | any arena in heavy rain, puddles, darker crowd |

**C4 · Baús**

```
Medieval treasure chest, [wooden with iron bands | iron reinforced |
gold trimmed | royal ornate with crown emblem], closed and opening
animation 6 frames, glow from inside when open, 96x96.
```

**C5 · Materiais e moedas** (ícones 64 px)

Lingote de ferro, lingote de aço, couro, tecido nobre, ouro de ornamento, fragmento de peça, projeto (pergaminho com desenho de armadura), chave, gema, moeda de ouro, moeda da ordem.

**C6 · Interface**

```
Medieval game UI kit, dark iron and worn leather frames, parchment
panels, buttons in normal, pressed and disabled states, tab headers,
progress bar, close button, rarity frames (grey, green, blue, purple,
gold), pixel art, consistent 9-slice borders.
```

**C7 · Efeitos das habilidades**

```
Pixel art VFX, side view: [Investida: speed lines and dust trail behind
a charging horse | Bloqueio: shield flash with a deflection spark burst
| Golpe Pesado: heavy shockwave ring on impact], 6 frames, 128x128.
```

**C8 · Sons do lançamento**

| Som | Prompt |
| --- | --- |
| Abrir baú | Heavy chest lid creaking open, then a shimmering reveal chime |
| Item lendário | Deep choir swell with a ringing bell |
| Forja concluída | Quenching hot steel in water, hiss, then a satisfied hammer tap |
| Melhoria falhou | Dull clank and a short disappointed metal scrape |
| Habilidade Investida | Rushing wind and pounding hooves accelerating |
| Habilidade Bloqueio | Bright metallic ring of a parry |
| Habilidade Golpe Pesado | Deep boom with crunching metal |
| Mensagem no chat | Soft quill scratch |
| Ordem venceu torneio | War horn and distant cheering |
| Subir de liga | Rising brass fanfare with drums |

**C9 · Música do lançamento:** um tema por região, variando o tema da justa (vila mais rústica, Reino mais orquestral, Grande Torneio com coro), e um tema calmo para a tela da liga.

## Parte 4 — Atualizações: espada, arco e mêlée

Cada modalidade nova segue o mesmo caminho da justa: regra pura e determinística primeiro, depois cena, depois versão no servidor. Os prompts abaixo são o ponto de partida; detalhar quando chegar a hora.

**4.1 · Duelo de espada** — Opus 5.5, high (regra) e Opus 5.5, medium (cena)

```
Leia Outras modalidades no docs/GDD.md. Crie o duelo de espada: deslizar
o dedo em direções para atacar e defender, barra de stamina, atributos
Força, Precisão, Equilíbrio e Agilidade. Mesma estrutura da justa: regra
pura e determinística com casos de teste, porte para TypeScript, cena
separada da regra, tela de VS dividida na entrada. Torneios e liga
próprios no circuito.
```

**4.2 · Arco e flecha** — Opus 5.5, medium

```
Crie a modalidade de arco: arrastar e soltar para mirar e atirar, vento e
distância variando, atributos Precisão e Mira firme. Mesma estrutura das
outras modalidades (regra pura, servidor, torneios próprios).
```

**4.3 · Mêlée** — Opus 5.5, high

```
[Preencher depois de decidir a mecânica: ondas de adversários ou combate
em grupo.]
```

**Arte para as modalidades novas**

```
Knight on foot in full armor, [sword and shield | longbow], side view
facing right, animations: idle, attack in 4 directions, block, hit,
dodge, fall, 8 frames each, 128x128, same layered armor system as the
mounted knight.
```

## Checklist antes de começar

- [ ] Deep Iron praticamente finalizado
- [ ] Documento de Design exportado como `docs/GDD.md` dentro do projeto
- [ ] Godot 4 instalado e exportação Android testada com um projeto vazio
- [ ] Claude Code atualizado (`claude update`) e o modelo do primeiro prompt selecionado
- [ ] Conta no PixelLab, ElevenLabs e Supabase; conferir uso comercial nos planos
- [ ] Repositório git criado para o jogo
- [ ] Celular Android de teste à mão (de preferência um modelo de entrada)
- [ ] Decidir o nome provisório do projeto para pastas e repositório

Primeiro passo: prompt 1.0 da Parte 1, no Opus 5.5 com esforço alto.
