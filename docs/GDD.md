# Torneio Medieval — Documento de Design

Oct 11, 2026 · @Marco Claude

## Visão geral

Jogo mobile de carreira de cavaleiro de torneio, em pixel art 2D: o jogador cria seu cavaleiro, disputa justas curtas e ativas e evolui sua vila entre uma disputa e outra. É o próximo projeto depois do Deep Iron; o lançamento sai só com a justa, e as outras modalidades chegam como atualizações.

O espírito vem do filme Coração de Cavaleiro (plebeu fingindo nobreza, a energia do torneio lotado, aqui num tom mais sombrio e adulto), mas nomes, personagens, enredo e trilha são todos originais.

**Pilares (toda decisão de design passa por eles):**

1. **Disputa curta, ativa e satisfatória.** Cerca de 1 minuto por justa; a habilidade do jogador decide mais que os status.
2. **Progresso visível.** Vila, cavalo, armadura e ferreiro mudam de visual conforme evoluem; armadura quebra e aparece quebrada.
3. **Justo para quem não paga.** O dinheiro compra tempo e visual exclusivo; poder pago tem teto e também pode ser conquistado jogando.
4. **Sessões curtas.** Tudo pensado para o celular: uma mão, 2 a 5 minutos por sessão, motivo para voltar ao longo do dia.

**O que evitamos (reclamações reais do gênero):** status valendo mais que habilidade, repetição, energia que trava o jogo, olhar para a interface em vez da cena e a sensação de só estar assistindo.

## Início do jogo

Os primeiros 5 minutos levam o jogador da criação do cavaleiro até a primeira vitória, sem nenhum timer no caminho.

1. **Criação do cavaleiro.** Nome e sobrenome (o nome da casa), corpo feminino ou masculino, e aparência montada com peças de pixel art prontas (rosto, cabelo, tom de pele). As armaduras servem nos dois corpos: o esqueleto de animação é o mesmo, só muda a base do corpo, o rosto e o cabelo.
2. **Brasão da casa.** Formato do escudo, símbolo, cor principal e cor secundária. As cores da casa pintam bandeiras, caparação e detalhes da armadura em todo o jogo.
3. **Cavalo inicial.** Três pelagens: alazão (avermelhado), preto e branco. Mesma força para os três; só muda o visual. Outras pelagens e raças entram depois como recompensa ou compra.
4. **Justa de exibição (automática).** O cavaleiro do jogador assiste da arquibancada a uma justa entre dois veteranos. O arauto narra e explica largada, galope, mira e impacto.
5. **Primeira justa (jogada).** Contra um rival fraco, com dicas na tela em cada fase. Vitória quase garantida.
6. **Primeira recompensa.** Um baú que abre na hora, com a primeira peça de armadura. Ela já aparece equipada no cavaleiro.
7. **Chegada à vila.** Só o estábulo, o campo de treino e o ferreiro estão abertos; os outros prédios são liberados por nível (ver A vila).

Regra do tutorial: no primeiro dia, todo timer termina em segundos, para o jogador aprender cada sistema sem esperar.

## Loop principal

O jogador alterna entre disputas curtas e cuidar da vila; os timers seguem correndo com o jogo fechado e trazem o jogador de volta.

&#91;embedded content: loop principal · disputa, recompensas, vila\]

Da vila, o jogador pode voltar direto à disputa a qualquer momento: nenhum timer bloqueia a justa.

## A justa

Uma justa tem 3 passadas de cerca de 15 segundos cada, com tudo numa única vista lateral elevada em 2.5D. A cerca corta a tela na horizontal: o jogador corre na pista de baixo, para a direita; o rival corre na pista de cima, para a esquerda.

**Fases de uma passada**

| Fase | Duração | Câmera | O que o jogador faz |
| --- | --- | --- | --- |
| Apresentação | 2 s (pula) | Aberta, os dois parados nas pontas | Nada; o arauto anuncia os nomes |
| Largada | 1 s | Aberta | Toca quando a bandeira baixa; a largada perfeita dá velocidade, precisão e golpe mais forte (ver Pontuação). Logo depois aparece "Largada perfeita!", "Boa largada" ou "Largada ruim", com o motivo e o efeito |
| Corrida | 4 a 5 s | Acompanha o cavaleiro e enquadra os dois quando o rival chega | Toca no compasso do galope; sem tirar o dedo, arrasta para subir ou baixar a lança (o arrasto não conta como toque); pode ativar a habilidade especial |
| Mira | 2 s | O mesmo plano da Corrida, fechando nos dois | Começa da altura escolhida na Corrida; arrasta para mirar e solta para golpear. A ponta segue o dedo com uma inércia leve |
| Impacto | 2 s | Corte para um close inclinado, em câmera lenta | Nada; lança estilhaça, peça voa, rival cai ou cambaleia |

**Pontuação**

- Capacete: 3 pontos. Peito: 2 pontos. Escudo: 1 ponto. Errar: 0.
- Derrubar o rival vence a justa na hora.
- **A largada decide a força do golpe.** A qualidade da largada da passada de quem bate define a base da chance de derrubar em cada zona e o teto dela (milésimos, em `impacto.json > derrubada > por_largada`):

  | Largada | Capacete | Peito | Escudo | Teto |
  | --- | --- | --- | --- | --- |
  | Perfeita | 450 | 380 | 180 | 750 |
  | Boa | 250 | 200 | 90 | 450 |
  | Ruim (lenta, queimada ou sem toque) | 40 | 30 | 10 | 80 |

  Por cima somam, sem mudar: Força de quem bate contra Equilíbrio de quem leva, velocidade, ritmo do galope, poder da lança, defesa da peça atingida e habilidades. Perto do teto da largada, cada ponto rende menos. Vale para o jogador e para o rival; a IA larga melhor ou pior conforme o perfil (o novato erra muito, o campeão acerta mais). Com status médios, um acerto no capacete derruba perto de 54% com largada perfeita, 32% com boa e 5% com ruim (`tools/simular_derrubada.gd`).
- Acertar o cavalo é falta: perde pontos e, na reincidência, é desclassificado.
- Empate após 3 passadas: passada extra decisiva.

**Habilidades especiais**

- Ativas (ex.: Investida): botão que carrega durante a corrida. Ao ativar, brilho e rastro no cavaleiro e o nome da habilidade em letreiro.
- Passivas (ex.: Bloqueio): disparam sozinhas no impacto. O escudo pisca, a lança do rival desvia e o letreiro aparece.
- Funcionam em ciclo: Investida vence Bloqueio, Bloqueio vence Golpe Pesado, Golpe Pesado vence Investida.

**Regras de arte**

- Um único ângulo de sprite; o rival é o mesmo desenho espelhado e um pouco menor.
- O brasão é uma camada separada, aplicada depois do espelhamento.
- Os sinais de jogo ficam no mundo (escudo brilha, cavalo bufa), não em círculos grandes na interface.
- Mira por cima do ombro, com o rival de frente, fica para o polimento; o protótipo usa zoom no mesmo ângulo.

## Progressão

O cavaleiro sobe de nível com XP das disputas, e os atributos crescem por treino e por equipamento. Regra de ouro: **status aumenta a janela de acerto, não acerta pelo jogador.**

**Atributos**

| Quem | Atributo | O que faz na justa |
| --- | --- | --- |
| Cavaleiro | Força | Chance de derrubar o rival quando acerta |
| Cavaleiro | Precisão | Tamanho da zona perfeita da mira |
| Cavaleiro | Equilíbrio | Resistência a cair quando é atingido |
| Cavalo | Velocidade | Força do impacto e tempo da corrida |
| Cavalo | Fôlego | Quantas passadas e justas seguidas antes de cansar |
| Cavalo | Temperamento | Tamanho da janela do ritmo do galope |
| Cavalo | Vínculo | Bônus geral pequeno que cresce usando o mesmo cavalo |
| Equipamento | Armadura, lança, escudo | Defesa por peça, poder e precisão, chance de bloqueio |

**Nível do cavaleiro**

- Ganha XP em toda disputa, mais na vitória e no modo manual.
- O nível libera prédios, ligas, o segundo espaço de habilidade especial e eventos.
- O nível não define o adversário do PvP (ver PvP); ele é progresso, não matchmaking.

**Treino sem travar o jogo**

- O treino ocupa uma **vaga de treino**, não o cavaleiro. Ele continua disputando enquanto treina.
- O cavalo é diferente: cavalo em treino ou cansado não corre. Por isso o estábulo guarda vários cavalos, e o jogador alterna entre eles.
- Cavalo cansado pode correr com penalidade de velocidade, em vez de bloquear a disputa. Nunca existe energia que impede de jogar.
- Uma vaga de treino grátis; a segunda é liberada por nível do campo de treino ou pelo VIP.

## Timers e ritmo

Nenhum timer passa de uma noite de sono (12 horas), e a disputa nunca espera timer nenhum. A curva começa em segundos e cresce devagar, para o jogador sentir progresso rápido no começo e ter motivo para voltar depois.

| Fase do jogador | Treino | Melhoria de prédio | Conserto | Baú comum |
| --- | --- | --- | --- | --- |
| Primeiro dia (tutorial) | segundos | segundos | segundos | instantâneo |
| Níveis 1 a 5 | 30 s a 5 min | 2 a 10 min | 1 a 3 min | 5 min |
| Níveis 6 a 10 | 15 a 60 min | 30 min a 2 h | 5 a 15 min | 15 min |
| Níveis 11 a 20 | 1 a 4 h | 2 a 6 h | 15 a 30 min | 30 min |
| Nível 21 em diante | 4 a 8 h | 6 a 12 h | 30 a 60 min | 1 h |

Os valores são o ponto de partida; o ajuste fino sai da planilha de economia.

**Como acelerar**

- Grátis: anúncio opcional corta 30 min, uma vez por timer; missões diárias dão aceleradores.
- Chaves: abrem baús na hora.
- Pago: gemas pulam qualquer timer; o VIP reduz todos os tempos.

**Notificações:** treino pronto, cavalo descansado, baú aberto, conserto pronto. Sempre opcionais e configuráveis.

## A vila

A tela principal é a vila vista de cima, sem andar livre: o jogador toca num prédio e entra nele. Cada prédio tem 4 a 5 estágios visuais, e o personagem que cuida dele também muda de aparência conforme evolui.

| Prédio | Libera no nível | Função | Quem cuida |
| --- | --- | --- | --- |
| Casa senhorial | 1 | Nível da vila; define o teto dos outros prédios | O próprio cavaleiro |
| Estábulo | 1 | Guarda cavalos, recupera fôlego, treina cavalos | Cavalariço |
| Campo de treino | 1 | Treina o cavaleiro; vagas de treino | Mestre de armas |
| Ferreiro | 1 | Lanças, ferraduras e materiais: funde sucata e minério em lingotes | Ferreira |
| Arena de torneios | 2 | Disputas PvE e circuito de torneios | Arauto |
| Armeiro | 3 | Cria, melhora e conserta armaduras; tela de Equipamentos e guarda-roupa visual | Armeiro |
| Loja | 4 | Compras, ofertas, passe da temporada | Mercador |
| Salão da liga | 6 | PvP, ranking e temporadas | Mestre da liga |
| Taverna | 8 | Missões diárias, rivais e apostas | Taverneira |

**Guarda-roupa visual (no armeiro):** o jogador escolhe a aparência de cada peça de forma independente dos status. Ele pode usar a armadura mais forte com o visual da que acha mais bonita. Isso protege a identidade do personagem e sustenta a venda de cosméticos.

**Momentos de vitrine:** entrar no estábulo mostra o cavalo com a armadura atual; peças danificadas aparecem rachadas ou amassadas; subir de nível um prédio tem uma pequena animação de obra.

**Vila viva:** a vila é para olhar, não só para tocar. Cada prédio mostra em 2.5D o que está acontecendo dentro dele, e o jogador pode abrir o jogo só para ver o próprio cavaleiro em ação.

| Onde | O que aparece |
| --- | --- |
| Campo de treino | O cavaleiro galopando contra o estafermo (o boneco giratório de treino de justa), com a armadura atual |
| Estábulo | O cavalo sendo escovado, comendo ou descansando; cavalo cansado aparece deitado |
| Armeiro | O armeiro martelando a peça na bigorna, faíscas, a armadura em produção no cavalete |
| Ferreiro | Forja acesa, fole, lança sendo torneada |
| Praça | Cavaleiros de outros jogadores da mesma ordem passando a cavalo |
| Casa senhorial | A bandeira da casa e a da ordem no alto da torre |

A vila também tem ciclo de dia e noite (tochas acesas à noite) e clima (chuva, neblina), sem nunca escurecer demais (ver Brilho mínimo e cores). Prédio ocioso mostra o personagem parado esperando, o que convida o jogador a dar uma tarefa.

### Interface legível no celular

- **Tamanhos mínimos (`tema_jogo.tres`):** texto de 22 px, títulos de 28 px (variação `Titulo` do tema) e todo botão ou ícone tocável com pelo menos 64×64 px. Números de atributos e de recursos podem ser maiores (28 px). Nenhuma tela usa texto menor por conta própria.
- **Vila aproximada:** a câmera da vila fica com zoom (`vila.json > camera`), então os prédios enchem a tela; o jogador arrasta o dedo para ver o resto, e só um toque curto abre o prédio. O nome de cada prédio lê 22 px na tela (o jogo divide pelo zoom).
- **Telas dos prédios:** ocupam a vista inteira (900×528 px na base de 960×540), com o campo de treino e o estábulo maiores. No estábulo, os atributos do cavalo aparecem grandes (nome e valor com barra até o teto), não escondidos em botão desabilitado.
- **Topo da vila:** retrato do cavaleiro (cabeça e elmo que usa), brasão da casa, nome, nível com a barra de experiência, ouro e gemas, e os botões de Missões, Ordem, Configurações e Baús em ícones de 72×72 px com "!" no canto quando há algo pendente. O retrato abre o perfil, e o perfil abre os Equipamentos. Moldura desenhada da interface.
- **Teste:** `tests/ui/legibilidade_check.gd` confere tamanhos de texto e de botão e se cada tela cabe na vista, em 16:9 (960×540) e 20:9 (1200×540).

### Brilho mínimo e cores

- **A arena da justa é a referência visual:** clara, saturada e chamativa, com tudo legível (grama amarelo-esverdeada, areia, madeira, bandeirolas vivas). A vila segue a mesma harmonia: grama, trilhas e prédios passam pelo shader `vivificar` (`ambiente.json > paleta`), e fios de bandeirolas nas cores da arena enfeitam os prédios.
- **Brilho mínimo:** a cor do mundo (hora do dia mais clima) nunca fica abaixo de 85% do brilho do dia em nenhum canal (`ambiente.json > brilho_minimo`), nem à noite nem com chuva ou neblina. A noite é azulada e as tochas acendem, mas a vila continua legível.

### Som dos prédios

- O som de um prédio (campo de treino, estábulo, armeiro, ferreiro) toca **só enquanto a tela daquele prédio está aberta**.
- Ao sair, ele para com um fade curto (cerca de 0,3 s).
- Na vila, toca só a trilha e o ambiente da própria vila (por exemplo, a chuva).
- Vale também para efeitos repetidos, como o martelo na bigorna e o galope do treino.
- **Estábulo:** sem som contínuo e sem ambiente (nada de loop de baia, galope ou passos). Ao tocar no cavalo, ele bufa ou relincha uma vez, com uma variação sorteada e no mínimo 2 s entre uma bufada e outra (`intervalo_min_s` do som no catálogo).
- **Ferreiro (e armeiro):** sem som contínuo (nada de fole nem martelo em laço). O martelo da oficina bate só no desenho; a bigorna soa uma martelada quando o jogador toca no ferreiro e quando uma peça ou lingote fica pronto com a tela aberta.
- Toda troca de tela para o ambiente da tela anterior. Uma tela aberta por cima (Equipamentos a partir da forja) para o som da de baixo, que volta quando ela fecha.

## Equipamentos e direção de arte

A tela de Equipamentos mostra o cavaleiro e o cavalo grandes, lado a lado, e cada peça trocada aparece na hora no personagem. A arte é pixel art de alta resolução, bem detalhada, com tom sombrio e adulto.

**Tela de Equipamentos**

- Duas abas: Cavaleiro e Cavalo. Em cada uma, o personagem em destaque no centro e os espaços de peça em volta, ligados à parte do corpo onde a peça vai.
- Tocar num espaço abre as peças disponíveis; ao passar por elas, o personagem já mostra como fica (pré-visualização antes de equipar).
- Botão para girar entre a vista lateral do jogo e a vista de frente, e para ver o conjunto montado no cavalo.
- Cada peça mostra status, raridade, durabilidade e se faz parte de um conjunto.
- O guarda-roupa visual fica aqui: status de uma peça com a aparência de outra.

**Espaços do cavaleiro**

| Espaço | Peça de época | Status ou visual |
| --- | --- | --- |
| Cabeça | Elmo | Status |
| Topo do elmo | Penacho ou cimeira com o símbolo da casa | Visual |
| Pescoço | Gorjal | Status |
| Tronco | Peitoral | Status |
| Ombros | Espaldares (ombreiras) | Status |
| Braços | Braçais | Status |
| Mãos | Manoplas | Status |
| Pernas | Coxotes e grevas | Status |
| Pés | Escarpes (sapatos de placa) | Status |
| Por cima da armadura | Sobreveste ou tabardo com o brasão | Visual |
| Costas | Capa | Visual |
| Braço do escudo | Escudo | Status |
| Arma | Lança | Status |

**Espaços do cavalo**

| Espaço | Peça de época | Status ou visual |
| --- | --- | --- |
| Cabeça | Testeira (armadura da cabeça) | Status |
| Pescoço | Crineira (armadura do pescoço) | Status |
| Peito | Peitoral do cavalo | Status |
| Garupa | Anca de placa | Status |
| Corpo | Caparação (a manta de tecido com o brasão) | Visual |
| Sela | Sela de justa, de encosto alto | Status |
| Rédeas | Freio e rédeas decoradas | Visual |
| Estribos | Estribos | Visual |
| Enfeites | Plumas na testeira, guizos, franjas | Visual |
| Pelagem | Alazão, preto, branco e outras | Visual |

**Direção de arte**

- Pixel art detalhada, quase realista, na linha de jogos como Blasphemous: muitos tons por material, metal com reflexo, tecido com dobra, sujeira e desgaste visíveis.
- Tom sombrio e adulto: céu nublado, paleta fechada, terra, ferro e couro. As cores da heráldica (bandeiras, brasões, caparações) são o que contrasta, para a arena continuar viva e o brasão do jogador se destacar.
- O desgaste aparece na arte: peça danificada fica amassada, riscada ou rachada.

**Tamanho dos sprites (para controlar o trabalho)**

- Na justa: cavaleiro montado com cerca de 128 a 160 px de altura, animado, só na vista lateral.
- Na tela de Equipamentos: retrato grande, em torno de 256 px, parado ou com animação mínima de respiração. O detalhe máximo fica onde o jogador olha de perto.
- Toda peça é uma camada desenhada sobre o mesmo esqueleto, nos dois tamanhos.
- Quanto maior e mais detalhado o pixel art, mais retoque manual cada peça pede; o número de peças no lançamento deve ser pequeno e crescer com atualizações.

## Forja: criar, melhorar e consertar

No armeiro, o jogador cria peças novas a partir de projetos e materiais, melhora as que já tem e conserta as danificadas. A forja é o segundo caminho para equipamento bom, além dos baús, e é o principal caminho de quem não paga.

**Materiais**

| Material | De onde vem |
| --- | --- |
| Lingote de ferro | Ferreiro (funde sucata e minério), baús, PvE |
| Lingote de aço | Ferreiro (a partir do ferro), regiões mais altas do PvE |
| Couro | PvE, baús, loja |
| Tecido nobre | Baús, eventos, loja |
| Ouro e prata de ornamento | Campeões do PvE, recompensas de liga |
| Fragmentos de peça | Itens repetidos dos baús |
| Projeto (planta da peça) | Campeões, eventos, passe da temporada, loja |

**Criar**

- Cada peça precisa de um projeto e de uma lista de materiais. A raridade da peça vem do projeto.
- Criar leva tempo de forja (fila própria, uma vaga grátis). O resultado tem uma pequena variação de status, o que dá motivo para tentar de novo.
- Projetos dos conjuntos com habilidade especial só vêm de campeões, eventos e temporadas; nunca só da loja.

**Melhorar**

- Níveis de +1 a +10 por peça, usando fragmentos, lingotes e ouro.
- Até +5 é garantido; de +6 em diante tem chance de falhar, mas nunca destrói a peça (só consome o material).
- O teto de melhoria segue o nível do armeiro, para o progresso acompanhar a vila.

**Consertar**

- Custa ouro e um pouco de material, proporcional ao dano. Peça quebrada (durabilidade zero) custa mais.

**Loja e equilíbrio:** a loja vende materiais e alguns projetos, com limite diário de compra. Assim quem paga acelera a forja, mas não pula as recompensas de campeões e eventos.

## Disputas PvE, baús e itens

O PvE é um circuito de torneios contra a máquina, organizado em regiões, e é a principal fonte de ouro, XP e baús.

**Circuito**

1. Feiras de vila
2. Torneios do condado
3. Torneios do ducado
4. Torneios do reino
5. Grande Torneio

Cada região tem 5 a 8 torneios. Cada torneio é uma chave de 3 a 5 rivais, terminando num campeão com personalidade (estilo de mira, habilidade favorita, provocação do arauto). Vencer o campeão libera a próxima região.

**Estrelas e modo automático**

- Cada disputa dá de 1 a 3 estrelas pelo desempenho (vitória, sem errar, derrubada).
- Com 3 estrelas, aquela disputa pode ser repetida no automático, para juntar recursos sem jogar.
- Campeões, finais e primeira luta contra um rival são sempre manuais. No manual, a recompensa é maior.

**Desafios especiais:** uma chance só (não dá para repetir), cavalo emprestado, sem escudo, chuva (janela de ritmo menor), justa noturna.

**Campeões**

Os 17 campeões do circuito e o nêmesis têm personalidade própria, que o jogador consegue ler e vencer:

- **Alcunha** (ex.: Martim, o Martelo, "o Sino das Capelas"), **frase de entrada** (dita na tela de duelo) e **frase de derrota** (quando cai).
- **Traço de luta:** um comportamento claro, feito só com o estilo da IA e a habilidade dele, sempre com um ponto fraco declarado. Traços: larga perfeito (mira solta), só mira o capacete (o Bloqueio desvia), nunca erra o peito (quase não derruba), bloqueia muito (a Investida atravessa), guarda a habilidade para a última passada (está sem ela nas duas primeiras), nunca perde o compasso (larga mal), joga no escudo (pontua pouco), tudo ou nada (erra um golpe em quatro) e, no nêmesis, rancoroso (volta mais forte a cada encontro).
- **Ficha do adversário** antes de toda justa do PvE e do PvP: retrato (provisório com a cor da casa até ter arte), nome, alcunha, brasão, habilidade (e qual a anula), traço com o ponto fraco e o poder dos dois lados com cor: verde favorável, amarelo parelha, vermelho difícil. Botão para ir aos Equipamentos e trocar antes de lutar.
- **Tela de duelo** antes de um campeão: os dois lados frente a frente, o arauto anunciando os dois e a frase de entrada do campeão.
- **Troféu:** a primeira vitória sobre um campeão expõe o troféu dele na estante da casa senhorial e dá uma peça cosmética dele (penacho, manta ou estandarte), só de aparência.
- **Revanche heroica:** campeão já vencido pode ser enfrentado de novo, uma vez por dia, mais forte a cada revanche vencida (até um teto) e com recompensa melhor (três vezes a de uma disputa de 3 estrelas da região, baú de ferro e ornamento).

**Baús**

| Baú | Tempo para abrir | De onde vem |
| --- | --- | --- |
| Madeira | 5 min | Vitórias comuns |
| Ferro | 1 h | Vitórias com 3 estrelas |
| Ouro | 4 h | Campeões e missões semanais |
| Real | 12 h | Fim de temporada e eventos |

- 4 espaços de baú; vitória com os espaços cheios dá só ouro.
- Chave abre qualquer baú na hora.
- Probabilidades de cada raridade sempre visíveis no baú.
- Garantia: a cada 10 baús de ferro ou melhores, um item raro ou superior.

**Itens**

- Peças: elmo, peitoral, ombreiras, escudo, lança e caparação do cavalo.
- Raridades: comum, incomum, raro, épico e lendário.
- Itens repetidos viram fragmentos, que o ferreiro usa para melhorar o nível de uma peça.
- Toda peça se desgasta com os impactos; com durabilidade zerada, perde os bônus até ser consertada.

## PvP, ligas e temporadas

No lançamento, o PvP é **assíncrono**: o jogador enfrenta o cavaleiro de outro jogador real, com o equipamento, os status e a habilidade dele, mas controlado pela IA. Tempo real fica para depois, se a base de jogadores crescer.

**Por que assíncrono**

|  | Tempo real | Assíncrono (fantasma) |
| --- | --- | --- |
| Espera por adversário | Precisa de muita gente online ao mesmo tempo | Nenhuma; sempre há fantasmas |
| Servidor | Partida ao vivo, latência, reconexão | Banco de dados com perfis e resultados |
| Custo e trabalho | Alto para um projeto pequeno | Baixo |
| Celular com sinal ruim | Partida cai | Funciona |

O Rival Knights, o concorrente mais próximo, usava esse mesmo modelo, com jogadores pareados por faixa e status.

**Como funciona**

- O jogador monta sua **configuração de defesa**: cavalo, equipamento e habilidade. O fantasma dele luta com ela.
- A IA do fantasma tem precisão média fixa; status e habilidade fazem a diferença, a sorte não.
- Quem ataca joga manualmente, sempre. Defesas vencidas também dão pontos ao defensor, para ele ter motivo de abrir o jogo.
- O resultado é calculado e conferido no servidor, nunca só no celular, para evitar trapaça.

**Pareamento**

- Pelos **pontos de liga** do jogador, com uma faixa de **poder** (soma de equipamento e atributos) como limite.
- Não pelo nível: o nível mede o tempo de jogo, não a força.

**Ligas e temporadas**

- Ligas: Bronze, Prata, Ouro, Platina, Diamante e Campeão, cada uma com divisões III, II e I.
- Temporadas de 4 semanas. No fim, recompensa pela liga (baú real e cosmético exclusivo da temporada) e reinício parcial dos pontos.
- Campeonatos de fim de semana: chave eliminatória com inscrição, aberta por liga.

**Backend sugerido:** Supabase (contas, saves na nuvem, perfis dos fantasmas, ranking e validação), já conectado a esta conta.

## Funções sociais

O lançamento já sai com ordens (as guildas do jogo), chat e amigos, porque um jogo online sem isso parece vazio e perde jogadores mais cedo.

**Ordens (guildas)**

- Até 30 membros, com líder, oficiais e membros; nome, brasão e bandeira próprios. A bandeira aparece na vila de cada membro.
- Ajuda nos timers: cada membro pode ajudar o treino ou a forja de outro, cortando alguns minutos. Quem ajuda ganha moeda da ordem.
- Doação de materiais entre membros, com limite diário.
- Torneio de Ordens semanal: a soma das vitórias de PvP dos membros dá a posição da ordem; recompensa para todos.
- Loja da ordem, paga com moeda da ordem: projetos e materiais, nada de gemas.
- Ranking de ordens por temporada.

**Chat**

- Chat da ordem (o principal) e chat global por idioma.
- Mensagens rápidas prontas ("Boa justa!", "Revanche?") para quem não quer digitar.
- Filtro de palavrões, botão de denúncia e de bloquear jogador; silenciamento automático de quem recebe muitas denúncias.

**Amigos e perfil**

- Lista de amigos por código ou pela ordem.
- Perfil público: cavaleiro, cavalo, brasão, liga, títulos e melhores resultados.
- Justa amistosa contra um amigo, sem valer pontos de liga.
- Presente diário entre amigos (um pouco de material).
- Replay curto da melhor justa, para compartilhar fora do jogo.

**Moderação:** filtro também nos nomes de cavaleiro, casa e ordem; denúncias chegam numa fila para revisão no painel do Supabase.

## Infraestrutura online

O servidor manda em tudo que vale algo: ouro, gemas, itens, timers e resultados de PvP. O celular só mostra e envia as ações do jogador. Esta é a maior diferença em relação ao Deep Iron, que roda local.

**Peças**

| Parte | Ferramenta | Papel |
| --- | --- | --- |
| Contas | Supabase Auth | Login anônimo no primeiro acesso; depois vincula Google Play Games ou Game Center sem perder o progresso |
| Banco | Supabase (Postgres) | Jogador, cavaleiro, cavalos, inventário, timers, ligas, partidas, compras |
| Regras do jogo no servidor | Supabase Edge Functions | Tudo que muda economia ou ranking passa por uma função: abrir baú, terminar treino, registrar justa, comprar |
| Configuração remota | Tabelas de balanceamento no banco | Status, preços, timers e probabilidades ajustáveis sem lançar atualização do app |
| Tarefas agendadas | Cron do banco | Abrir e fechar temporadas, eventos de fim de semana |
| Ambiente de teste | Branch do Supabase | Testar mudanças no banco antes de mexer no jogo de verdade |

**Segurança (nunca confiar no celular)**

- O app só tem a chave pública; a chave de serviço fica apenas nas Edge Functions.
- Regras de acesso por linha (RLS): cada jogador lê só os próprios dados e não escreve diretamente em nada da economia.
- Timers usam o relógio do servidor; mudar a hora do celular não acelera nada.
- Justa e PvP: o celular envia os toques (momento da largada, ritmo, ponto de mira), e o servidor recalcula o resultado com a mesma regra. Valores impossíveis são rejeitados.
- Compras validadas no servidor com o recibo da Google Play e da App Store antes de entregar qualquer item.
- Limite de chamadas por jogador, para evitar abuso e robôs.

**Conexão**

- O jogo exige internet, mas tolera sinal fraco: repete o envio, guarda a ação até confirmar e nunca perde uma vitória por queda de conexão.
- A justa em si roda no celular, sem atraso; só o resultado vai para o servidor.

**Obrigações**

- Política de privacidade e termos de uso (LGPD).
- Opção de excluir a conta dentro do app, exigida pelas lojas.
- Probabilidades dos baús visíveis.
- Backup automático do banco e registro de erros.

## Monetização e balanceamento

Quem paga evolui e sobe de liga mais rápido; quem não paga chega no mesmo lugar, só que mais devagar. Nenhum poder é exclusivo de quem paga, e todo status tem teto.

**O que se vende**

| Produto | O que dá | Também se ganha jogando? |
| --- | --- | --- |
| VIP (assinatura) | Segunda vaga de treino, recuperação de fôlego mais rápida, timers menores | Vaga extra sim, pelo nível do campo de treino |
| Passe da temporada | Trilha premium com cosméticos e recursos | Trilha grátis paralela |
| Itens e conjuntos com status | Armadura, lança, conjuntos com habilidade | Sim: torneios, fragmentos, eventos |
| Cosméticos | Brasões, caparações, pelagens, efeitos de vitória, frases do arauto | Alguns, como recompensa de temporada |
| Gemas e chaves | Pular timers, abrir baús | Em pequena quantidade, por missões |
| Ofertas de início | Pacote barato nos primeiros dias | Não |

**Regras de balanceamento**

- **Habilidades especiais:** 1 espaço no começo; o segundo libera numa liga alta, só jogando. No máximo uma por grupo (ofensiva ou defensiva).
- **Ciclo das habilidades:** Investida vence Bloqueio, Bloqueio vence Golpe Pesado, Golpe Pesado vence Investida. Nenhuma combinação perfeita.
- **Limite de uso:** cada habilidade dispara uma vez por justa, ou tem chance de 70%, nunca 100%.
- **Conjuntos:** 2 peças dão bônus pequeno; o conjunto completo libera a habilidade do conjunto.
- **Peças avulsas:** entre +2% e +5% num status.
- **Tetos:** acerto até 75%, bloqueio até 40%; perto do teto, cada ponto rende menos.
- **Teste de equilíbrio:** um jogador habilidoso com equipamento médio precisa conseguir vencer um pagante que joga mal.

Os percentuais exatos saem de uma planilha de simulação que compara quanto tempo um pagante e um jogador grátis levam para subir de liga.

**Anúncios e aceleração (sempre opcionais)**

Toda espera tem três saídas, e o jogador escolhe: esperar de graça, assistir a um anúncio ou pagar para pular. Nunca há anúncio forçado no meio do jogo.

| Opção | O que faz |
| --- | --- |
| Esperar | O timer corre normalmente, inclusive com o jogo fechado |
| Assistir anúncio | Corta 30 min de um timer, dobra a recompensa de uma vitória ou dá um baú de madeira extra; limite diário |
| Gemas | Pula qualquer timer na hora |
| VIP | Os mesmos benefícios dos anúncios sem precisar assistir, mais timers menores e segunda vaga de treino e de forja |

**Fontes de receita, da maior para a menor (padrão do gênero)**

1. Passe da temporada: barato, renovado a cada 4 semanas, compra recorrente.
2. VIP mensal: para o jogador fiel que quer pular sem anúncio.
3. Ofertas por tempo limitado: pacote de início, pacote ao subir de liga, pacote de evento.
4. Gemas avulsas, para pular timers.
5. Cosméticos: brasões, caparações, pelagens, efeitos de vitória, frases do arauto, bandeira da ordem.
6. Anúncios premiados, que rendem com quem nunca paga.

A compra impulsiva acontece no momento de emoção: logo depois de perder por pouco para um rival, ao abrir um projeto raro sem material suficiente, ou ao subir de liga. As ofertas aparecem nesses momentos, sem bloquear a tela.

## O que acrescentar

Sugestões que não estavam na conversa e que vale deixar previstas agora, mesmo entrando depois. A coluna Quando diz em que fase de produção cada uma entra.

| Sugestão | Por que | Quando |
| --- | --- | --- |
| Renome (fama) | Medida da ascensão do plebeu; libera convites para torneios maiores e reação da torcida | Fatia vertical |
| Rival recorrente (nêmesis) | Um nobre arrogante que aparece em cada região; dá história e emoção às finais | Fatia vertical |
| Companheiros com personalidade | Arauto, ferreira e escudeiro como amigos do protagonista; cada um dá um bônus e é a cara de um prédio | Fatia vertical |
| Missões diárias e semanais | Motivo para voltar todo dia; fonte grátis de chaves e aceleradores | Polimento |
| Recompensa de login | Retenção nos primeiros 7 dias | Polimento |
| Conquistas e títulos | Títulos como "O Inquebrável" aparecem no anúncio do arauto | Polimento |
| Progresso offline | O estábulo e o treino rendem com o jogo fechado | Fatia vertical |
| Save na nuvem | Login com Google Play Games e Game Center | Fatia vertical |
| Português e inglês | Textos fora do código desde o primeiro dia; traduzir depois custa caro | Protótipo |
| Acessibilidade | Modo canhoto, vibração opcional, tamanho de texto | Polimento |
| Ordens (clãs) | Jogadores se juntam, ajudam nos timers uns dos outros e disputam entre ordens | Lançamento |
| Trilha "rock medieval" original | Identidade do jogo; nada de música licenciada | Polimento |
| Métricas de jogo | Saber onde o jogador desiste, para ajustar dificuldade e timers | Fatia vertical |

**Ideias novas**

Acrescentadas depois do lançamento do circuito, a partir dos campeões.

| Ideia | Por que | Situação |
| --- | --- | --- |
| Traço de luta dos campeões | Cada campeão vira um quebra-cabeça legível, com ponto fraco, e não só números maiores | Feito (2026-10-18) |
| Ficha do adversário | O jogador decide o equipamento e a habilidade antes de lutar, em vez de descobrir na derrota | Feito, PvE e PvP |
| Tela de duelo com o arauto | Dá peso de final a cada campeão | Feito; falta voz própria do arauto |
| Troféus na casa senhorial | A casa mostra a carreira do plebeu; cada campeão vencido fica visível | Feito; troféus desenhados pendentes |
| Peça cosmética do campeão | Recompensa de vaidade que não mexe no equilíbrio | Feito; arte das peças pendente |
| Revanche heroica diária | Motivo para voltar a campeões vencidos sem repetir a mesma luta | Feito |

## Outras modalidades

Duelo de espada, arco e mêlée entram como atualizações, na mesma estrutura da justa: torneios próprios no circuito, ligas próprias no PvP e o mesmo cavaleiro, a mesma vila e o mesmo equipamento.

| Modalidade | Mecânica | Atributos que usa | Tela de apresentação |
| --- | --- | --- | --- |
| Justa | Ritmo do galope, mira e timing do golpe | Todos os do cavaleiro e do cavalo | Arauto e plaquinhas no topo |
| Duelo de espada | Deslizar o dedo para atacar e defender, com barra de stamina | Força, Precisão, Equilíbrio + Agilidade | Tela de VS dividida (já gerada) |
| Arco | Arrastar e soltar, com vento e distância | Precisão + Mira firme | Placar simples |
| Mêlée | A definir: ondas de adversários ou combate em grupo | Força, Equilíbrio, Agilidade | A definir |

Para não refazer nada depois: os atributos novos (Agilidade, Mira firme) já ficam previstos no sistema de status desde o protótipo, mesmo sem uso na justa.

## Plano de produção e pendências

A produção começa depois que o Deep Iron estiver praticamente finalizado, sempre pela justa.

1. **Protótipo:** só a justa. Um cavaleiro, um rival, a cerca, as 5 fases e a pontuação. Pergunta a responder: a justa é divertida sozinha?
2. **Fatia vertical:** criação de personagem, estábulo, campo de treino, ferreiro, uma armadura com 3 peças, a primeira região do PvE e o rival nêmesis.
3. **Lançamento:** vila completa, circuito de 5 regiões, baús, PvP assíncrono com ligas, loja, VIP e passe.
4. **Atualizações:** duelo de espada, depois arco, depois mêlée; ordens (clãs).

**Ferramentas**

| Ferramenta | Uso |
| --- | --- |
| Godot | Motor do jogo |
| Claude Code | Código em GDScript, interface, integração com o Supabase, Edge Functions |
| PixelLab | Sprites, animações e peças de armadura em camadas |
| Blender | Ajustes de arte quando precisar: referência de pose e ângulo, iluminação, conferir proporção do cavalo |
| ElevenLabs | Efeitos sonoros, vozes do arauto e trilha; conferir se o plano permite uso comercial |
| Gemini | Imagens de referência e mockups de tela |
| Supabase | Contas, banco e servidor |

**Pacote de prompts:** cada fase do plano ganha seu conjunto de prompts prontos (PixelLab, Claude Code, ElevenLabs), feito por partes, começando pelo protótipo da justa.

**Pendências**

- [ ] Nome do jogo e do protagonista
- [ ] Enredo: quem é o plebeu, por que finge ser nobre, quem é o nêmesis
- [ ] Planilha de economia: status, tetos, conjuntos, preços e timers finais
- [ ] Mecânica da mêlée
- [ ] Quantas formas, símbolos e cores o editor de brasão terá no lançamento
- [ ] Divisão exata do trabalho entre PixelLab e Claude Code
- [ ] Lista de habilidades especiais do lançamento

**Fontes**

- Rival Knights, PvP assíncrono e pareamento por faixa: [MobyGames](https://www.mobygames.com/game/rival-knights)
- Rival Knights, críticas de pay-to-win e repetição: [AppSpy](https://www.appspy.com/review/8612/rival-knights), [Pocket Gamer](https://www.pocketgamer.com/rival-knights/review/)
- Joust Legend, crítica de repetição: [The Sixth Axis](https://www.thesixthaxis.com/?p=197638)
- Opiniões de jogadores sobre jogar no automático: [r/AndroidGaming](https://redlib.ssps.io/r/AndroidGaming/comments/9ybanx/auto_play)
