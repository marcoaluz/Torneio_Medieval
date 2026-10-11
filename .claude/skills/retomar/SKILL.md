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
