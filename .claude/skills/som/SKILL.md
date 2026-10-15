---
name: som
description: Convenções de som do Torneio Medieval: como gerar no ElevenLabs (variações, duração), nomes, formato e volume dos arquivos, sorteio de variações, loops e onde ligar cada som no jogo (fases da justa, vila, interface, voz do arauto, música). Use SEMPRE que for gerar, pedir, nomear, importar ou ligar qualquer efeito sonoro, música ou voz, mesmo que o pedido só diga "coloca um som aqui".
---

# Som

Os prompts e durações de cada som estão em `docs/PACOTE_DE_PROMPTS.md` (tabelas das Partes 1, 2 e 3). Esta skill fixa o que o Pacote deixa em aberto. Os valores marcados (*) são padrões propostos desta skill, registrados em `docs/DECISOES.md`; mude lá se mudar aqui.

## Gerar (ElevenLabs)

- **Catálogo único:** `game/data/audio/sons.json` (id, pasta, barramento, loop, variação de tom, volume relativo, prompt, duração). Som novo entra ali primeiro.
- **Gerar:** `python -I tools/gerar_sons.py --simular` (lista o que falta, sem gastar) e depois sem `--simular` (`--so id1,id2`, `--grupo sons|musicas|voz`, `--voz-id`). Chave em `ELEVENLABS_API_KEY` ou em `.chaves.env` na raiz (fora do git). Não sobrescreve arquivo existente.
- **Combinar:** o sufixo de estilo do catálogo vai em todo prompt (mesmo espaço acústico, timbre quente); músicas e vinhetas em Ré.

- Gere **3 a 4 variações** de cada efeito e fique com as melhores. Sons que repetem muito (galope, impacto, botão) sorteiam entre as variações no jogo; um som único cansa em minutos.
- Prompts em inglês. Confira se o plano permite uso comercial antes de usar qualquer arquivo no lançamento.
- Música: tema original de "rock medieval" (tambores, gaita, rabeca, alaúde com guitarra distorcida e bateria). Nada de música licenciada.
- Voz do arauto: voz própria grave, teatral e rouca, em português e inglês. Grave só títulos genéricos ("Acerto no elmo!", "Derrubado!"); o nome do cavaleiro aparece escrito na tela, nunca falado.

## Arquivos (*)

- Pasta: `game/audio/sfx/<categoria>/`, `game/audio/music/`, `game/audio/voice/<pt_BR|en>/`.
- Nome: minúsculas com sublinhado, variações numeradas: `impacto_escudo_01.ogg`, `impacto_escudo_02.ogg`. Voz: `arauto_derrubado_01.ogg`.
- Formato: **MP3** (o ElevenLabs entrega assim e o Godot importa direto; sem ffmpeg nesta máquina) para música, loops e sons acima de 0,5 s; **WAV** só para sons curtíssimos de interface (toque no tempo, botão), onde a latência importa. OGG Vorbis também é aceito.
- Loops (galope, torcida, forja, chuva, estábulo, temas): emenda sem clique; no Godot, marque loop na importação.
- Normalização: pico de efeitos em −3 dBFS, música por volta de −14 LUFS, para o volume relativo ser decidido nos barramentos e não arquivo a arquivo.

## No Godot

- Barramentos (*): `Master` > `Musica`, `SFX`, `Voz`, `Ambiente`, `UI`. Volume do jogador por barramento nas configurações; nunca ajuste ganho dentro do código de cena.
- Variações: um serviço único de áudio recebe o nome do som (`impacto_escudo`) e sorteia entre os arquivos numerados, com leve variação de tom. Não repita a mesma variação duas vezes seguidas.
- Ligue som por **sinal**, não por chamada direta: a máquina de fases da justa emite um sinal por fase e a apresentação escuta (Largada → trompete e bandeira; Corrida → galope em loop; Impacto → impacto por zona, torcida; derrubada → queda). Assim a regra da justa continua pura (ver `regra-da-justa`).
- Estado do som da vila acompanha o estado visual: forja ligada só com forja em andamento, estábulo em loop só dentro do estábulo, chuva conforme o clima.
- Efeitos de interface e de feedback ao toque entram na mesma hora do gesto (o galope depende do ritmo do toque); teste a latência num celular real.
- Nomes de som e textos de legenda não ficam no código solto: ids em um arquivo de dados (`game/data/`).
