# Servidor (Parte 3: 3.1–3.11)

Estado do lado servidor e o que ainda falta. **Nada aqui foi publicado** nas Edge Functions do projeto Supabase `Torneio_Medieval` (`zhecikwngzhqajlpydrp`); só as migrações `contas_e_save` e `metricas` foram aplicadas (ver `docs/NUVEM.md`). Regras do projeto para o servidor: skill `supabase-jogo`.

## Regra em TypeScript (3.4, feito e testado)

`supabase/functions/_shared/regra/` é o porte, arquivo por arquivo, de `game/scripts/rules/` e `game/scripts/ai/ia_rival.gd`:

| TypeScript | GDScript | Casos compartilhados |
| --- | --- | --- |
| `aleatorio.ts` | `rules/aleatorio.gd` | `galope.json` (campo `aleatorio`) |
| `justa_fases.ts` | `rules/justa_fases.gd` | `justa_fases.json` |
| `galope.ts` | `rules/galope.gd` | `galope.json` |
| `mira.ts` | `rules/mira.gd` | `mira.json` |
| `impacto.ts` | `rules/impacto.gd` | `impacto.json` |
| `ia_rival.ts` | `ai/ia_rival.gd` | `ia_rival.json` |
| `justa.ts` | `rules/justa.gd` | `justa_referencia.json`, `justa_referencia_ia.json` |
| `conjuntos.ts` | `rules/conjuntos.gd` | `conjuntos.json` |
| `forja.ts` | `rules/forja.gd` | `forja.json` |
| `bau.ts` | `rules/bau.gd` | `baus.json` |
| `liga.ts` | `rules/liga.gd` | `liga.json` |
| `pve.ts` | `rules/pve.gd` | `desafios_pve.json` |
| `ordem.ts` | `rules/ordem.gd` | `ordem.json` |

- **Como rodar:** `cd supabase && node --test "tests/regra/*.test.ts"` (Node 24 roda `.ts` direto, apagando os tipos; por isso nada de `enum`, `namespace` nem parâmetros-propriedade nos arquivos). `bash tests/rodar_testes.sh` roda os dois lados juntos.
- **Os dois lados rodam os mesmos arquivos** de `tests/shared/`. As gravações da justa (`justa_referencia*.json`) são o teste mais forte: o TypeScript tem que reproduzir, evento por evento (formato `tipo|chave=valor` do `str()` do GDScript), a justa que o GDScript gravou, inteira e picada em 1, 17 e 33 ms.
- **Mudou a regra?** Mude os dois lados, regere os casos com o oráculo Python (ver "Armadilhas" no `CLAUDE.md` e a skill `regra-da-justa`) e regrave as referências com `TM_GRAVAR=1`; o teste dos dois lados falha se ficarem diferentes.
- **Convenções do porte:** nomes iguais aos do GDScript (snake_case) para comparar linha a linha; só inteiros, divisão com `Math.trunc`; `tem()` (chave própria) no lugar de `in` ao consultar tabelas por nome vindo de fora (evita `"constructor"`); nada de `Date.now()`, `Math.random()` nem estado global.
- **O que o teste já pegou:** laço `for` com limite recalculado depois de esvaziar a lista (`ordens_simuladas`); o GDScript avalia o limite uma vez.
