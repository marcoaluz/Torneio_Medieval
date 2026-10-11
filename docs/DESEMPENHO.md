# Desempenho (Pacote 3.25)

**Não havia celular Android nem APK nesta máquina:** as Android templates, o JDK e o SDK não estão instalados (veja `docs/ANDROID.md`). Por isso a medição foi feita no PC, com o mesmo renderer do celular (Compatibility/OpenGL), sem vsync, e convertida para um celular de entrada por estimativa. Rode no aparelho assim que der.

## Como medir

```
"D:\DEV\Godot\Godot_v4.7.2-stable_win64.exe" --path . --rendering-driver opengl3 res://tools/benchmark.tscn
```

O script `tools/benchmark.gd` faz o seguinte:
- mede o custo das chamadas do serviço que rodam com frequência;
- abre a justa, com um robô jogando, e a vila, 8 s cada;
- registra o tempo de carregamento, o tempo real de cada quadro (média, p95 e pior), as chamadas de desenho, os objetos e a memória;
- avisa quando há quadros acima de 16,6 ms.

A saída fica em `docs/desempenho/benchmark.txt`. Para medir o carregamento a frio de cada parte da vila, use `TM_BENCH_PARTES=1`.

## O que estava caro e foi corrigido

| Problema | Antes | Depois | Correção |
| --- | --- | --- | --- |
| `Balanceamento.carregar` relia e interpretava o JSON a cada chamada (88 lugares) | `pve` 2,0 ms por chamada | 0,3 ms (cópia) ou 0 ms (`ler`) | Cache: cada arquivo é lido uma vez, travado contra escrita (`make_read_only` em todos os níveis). `ler()`/`ler_json()` devolvem o dado compartilhado; `carregar()` devolve uma cópia. Serviços, personagem, brasão e paletas usam `ler`. Nenhum teste esbarrou em escrita. |
| `lado_para_justa()` (início de cada justa) | 14,7 ms | 0,2 ms | O mesmo cache |
| `missoes()`, `folego_cavalo()`, `proxima_cena()` (a vila chama a cada 0,25 s) | 2,5 ms; 2,3 ms; 0,6 ms | 0,05 ms; 0,02 ms; 0,004 ms | O mesmo cache. Antes, a vila travava ~10 ms a cada atualização. |
| Primeira troca de animação na corrida (texturas do galope lidas no meio da justa) | quadro de 29 ms | sem quadro lento | `CamadasPersonagem.pre_carregar()` chamado pela arena ao abrir |
| Tela de Equipamentos montada ao abrir a vila (retratos de 256 px) | +80 ms na abertura | 0 ms (só na primeira vez que abre) | A vila cria a tela sob demanda |

## Resultado (PC, OpenGL, 1280×720, sem vsync)

| | Justa | Vila |
| --- | --- | --- |
| Carregar a cena | 206 ms | 392 ms (era 512) |
| Tempo do quadro (média / p95) | 0,72 / 0,90 ms | 0,94 / 1,12 ms |
| Pior quadro depois de entrar | sem quadro acima de 16,6 ms | 3,3 ms |
| Chamadas de desenho | 57 | 129 |
| Memória (estática) | 43 MB | 49 MB |

**Num Android de entrada** (CPU 5 a 10 vezes mais lenta, GPU tipo Mali-G52 ou Adreno 610):
- O quadro da justa deve ficar entre 4 e 8 ms, dentro dos 16,6 ms dos 60 quadros. As 57 chamadas de desenho estão muito abaixo do limite de ~500 do celular.
- Carregar a vila deve levar entre 2 e 4 s e a justa entre 1 e 2 s. Esse custo vem principalmente da primeira renderização (texturas e shaders).

**O que conferir no aparelho:**
- a compilação de shader na primeira vez que cada efeito aparece. Ligue o Shader Baker no preset Android e, se precisar, desenhe os efeitos uma vez escondidos ao abrir a cena;
- o aquecimento da GPU com a vila animada por muitos minutos;
- a memória com a arte final.

## Tamanho do APK (estimativa)

- **Arte provisória:** 276 PNGs, 2,0 MB. Dados e textos: 0,3 MB. Áudio: nenhum ainda.
- **Template do Godot para Android:** roda Compatibility e é só arm64. Ainda não foi exportado aqui, por isso o número ainda não foi medido; a ordem de grandeza é de algumas dezenas de MB.
- **Com a arte final e o áudio:**
  - os sprites de 160 px em várias camadas e estágios de dano devem somar dezenas de MB em PNG sem perda (pixel art não deve usar compressão com perda);
  - a música deve ir em OGG.
  - Meta: APK abaixo de 150 MB, para o Google Play não exigir pacotes extras.
- **Para medir de verdade:** depois de instalar as templates, rode `--export-release "Android"` e confira o tamanho. O APK do Analyze APK do Android Studio mostra o que pesa.

## Modo economia de bateria

É uma opção em **Configurações** (`economia_bateria`; números em `game/data/ui/acessibilidade.json > bateria`):
- limita o jogo a 30 quadros por segundo; o normal fica travado em 60, em vez de ilimitado;
- reduz as partículas a 40%: chuva da vila, faíscas e lascas da justa, flâmulas da torcida.

A justa continua jogável a 30 quadros, porque a regra roda em milissegundos inteiros e não depende da taxa de quadros. A janela do compasso não muda, mas o toque passa a ser lido a cada ~33 ms: vale testar no aparelho se o ritmo fica justo.

Outras ideias para depois:
- desligar a animação da vila (cavaleiro treinando, fumaça) quando a economia estiver ligada;
- usar `OS.low_processor_usage_mode` nas telas paradas, que só redesenham quando algo muda.
