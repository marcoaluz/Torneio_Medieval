# Dados do jogador

Modelo de dados e save local (prompt 2.4). Código: `game/scripts/services/servico_jogador.gd` (autoload **Jogador**), `servico_tempo.gd`, `servico_nomes.gd`. Dados de partida: `game/data/balance/inicio.json` e `itens.json`.

## Regras

- **Só o serviço muda o estado.** As telas leem cópias (`cavaleiro()`, `itens()`, `equipado()`...) e pedem mudanças por comandos (`criar_personagem`, `definir_brasao`, `equipar`, `definir_visual`...). Cada comando valida, muda, salva e emite `mudou(secao)`, e devolve `{ok, erro}`.
- **Pronto para o servidor.** Na Parte 3, os comandos que valem algo (ouro, gemas, itens, timers, XP, PvE) viram chamadas a Edge Functions com a mesma assinatura, e o servidor passa a ser o dono do estado: o save local vira só cache. Nenhuma tela escreve ouro, item ou timer.
- **Tudo com versão.** O save tem `versao`; `ServicoJogador.migrar()` sobe saves antigos, um passo por versão.
- **Timers como horário de término** (segundos Unix, `ServicoTempo.agora()`): nunca "faltam X segundos". Hoje o relógio é o do celular; na Parte 3, o do servidor.
- **Save seguro.** Grava em `.tmp`, guarda o anterior em `.bak` e troca; se o principal estiver estragado, lê o `.bak`.

## Estrutura (versão 1)

```
versao, criado_em, proximo_id
cavaleiro: nome, corpo (masculino|feminino), rosto, cabelo, pele, cor_cabelo,
           nivel, xp, atributos {forca, precisao, equilibrio}, habilidade
casa: nome, cores {principal, secundaria, metal}, brasao {...}         (2.3)
cavalos: [{id, nome, pelagem, atributos {velocidade, folego, temperamento, vinculo}}]
cavalo_ativo: id
inventario: ouro, gemas, materiais {sucata, lingote_ferro, couro, ...},
            itens [{id, modelo, nivel, durabilidade, status?}] (modelo -> itens.json;
                  status só nas peças forjadas, com a variação sorteada; 3.15)
            projetos [conjunto]          (v2, 3.13: projetos ganhos dos campeões de região)
            materiais.fragmentos         (v3, 3.14: peças repetidas dos baús)
baus: espacos [{id, tipo, abre_em (0 = fechado)}], garantia, chaves,    (v3, 3.14)
      abertos, sorteios, semente (sorteios determinísticos; o servidor assume na Parte 3)
equipamento: {espaco: id}        visual (guarda-roupa): {espaco: id}
vila: predios {nome: {nivel, ...}}                                     (2.5)
timers: [{id, tipo, alvo, inicio_em, termina_em, ...}]                 (2.7)
        tipos: melhoria, treino_cavaleiro, treino_cavalo, conserto,
        forja {modelo} e fundicao {produto, quantidade} (3.15)
pve: regiao (a última aberta), torneios {id: {proxima, concluido,     (2.10, 3.13)
     estrelas, falhou (desafio de uma chance perdido)}}, encontros {rival: n}
tutorial: passo, concluido                                             (2.11)
```

- `lado_para_justa()` monta o lado da regra (`{cavaleiro, cavalo, equipamento, habilidade}`) a partir das peças equipadas: o `status` do modelo mais a durabilidade atual (peça com 0 perde os bônus na regra).
- `visual_das_pecas()` dá a variante de arte de cada espaço, já com o guarda-roupa aplicado; a arena veste o cavaleiro do jogador com ela, com as cores da casa e com a pelagem.

## Tabelas no servidor (Parte 3, rascunho)

`jogador` (id = auth.uid, versao, criado_em), `cavaleiro`, `casa`, `cavalo`, `item` (dono, modelo, nivel, durabilidade), `equipamento` (dono, espaco, item, item_visual), `predio`, `timer` (termina_em pelo relógio do servidor), `pve_progresso`, `tutorial`. Leitura só do próprio jogador (RLS); escrita de economia só por Edge Function.
