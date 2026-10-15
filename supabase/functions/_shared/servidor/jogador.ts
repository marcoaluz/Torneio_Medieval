// Porte da economia solo do ServicoJogador (game/scripts/services/servico_jogador.gd)
// para o servidor (3.2): leituras, personagem, vila, treino, cavalos, conserto,
// forja, metas, loja, anúncios, história, baús e tutorial. O PvE está em pve.ts.
// Liga/PvP e social NÃO estão aqui: no servidor são relacionais (3.5/3.6/3.8).
// Mesmos nomes e mesma ordem de sorteios do GDScript; parity por cenários
// gravados (tests/shared/cenarios_servico.json).

import { Aleatorio } from "../regra/aleatorio.ts";
import * as Conjuntos from "../regra/conjuntos.ts";
import * as Forja from "../regra/forja.ts";
import * as Bau from "../regra/bau.ts";
import * as Liga from "../regra/liga.ts";
import {
  clampi, concluir, copiar, cavalo, cavalo_ativo, da_curva, dia_atual, div, equipado, erro, ESPACOS_REGRA, gastar_materiais,
  gemas, inteiro, item, item_ref, material, novo_id, ouro, pronto, semana_atual, semente_servico, tem,
} from "./base.ts";
import type { Dados, Resultado, Servico } from "./base.ts";

// ------------------------------------------------------------------ leitura

/** Fôlego atual do cavalo (valor + horário, recupera com o tempo). */
export function folego_cavalo(s: Servico, id = ""): number {
  const c = id === "" ? cavalo_ativo(s) : cavalo(s, id);
  if (Object.keys(c).length === 0) return 0;
  const f = s.bal("treino")["folego_cavalo"];
  const maximo = inteiro(f["maximo"]);
  const base = inteiro(c["folego"] ?? maximo);
  const desde = Math.max(s.agora() - inteiro(c["folego_em"] ?? s.agora()), 0);
  return Math.min(maximo, base + div(desde * recuperacao_por_hora(s), 3600));
}

export function cavalo_cansado(s: Servico, id = ""): boolean {
  return folego_cavalo(s, id) < inteiro(s.bal("treino")["folego_cavalo"]["cansado_abaixo_de"]);
}

export function recuperacao_por_hora(s: Servico): number {
  const f = s.bal("treino")["folego_cavalo"];
  let bonus = inteiro(f["bonus_recupera_por_nivel_estabulo_pct"]) * Math.max(predio_nivel(s, "estabulo") - 1, 0);
  bonus += bonus_companheiros(s, "folego_recupera_pct");
  if (vip_ativo(s)) bonus += inteiro(s.bal("economia")["vip"]["folego_recuperacao_extra_pct"]);
  return div(inteiro(f["recupera_por_hora"]) * (100 + bonus), 100);
}

export function cavalo_treinando(s: Servico, id: string): boolean {
  return s.estado["timers"].some((t: Dados) => t["tipo"] === "treino_cavalo" && (t["cavalo"] ?? "") === id);
}

/** Estágio de dano da peça (0 inteira, 1 riscada, 2 amassada, 3 rachada). */
export function estagio_dano(s: Servico, id: string): number {
  const it = item(s, id);
  if (Object.keys(it).length === 0) return 0;
  const maximo = inteiro(s.bal("itens")["modelos"][it["modelo"]]["durabilidade_max"]);
  if (maximo <= 0) return 0;
  const pct = div(inteiro(it["durabilidade"]) * 100, maximo);
  let e = 0;
  for (const limite of s.bal("desgaste")["estagios_pct"]) {
    if (pct < inteiro(limite)) e += 1;
  }
  return e;
}

/** Status que vale na justa: o base (do modelo, ou o sorteado na forja) com o bônus do nível. */
export function status_do_item(s: Servico, id: string): Dados {
  const it = item(s, id);
  if (Object.keys(it).length === 0) return {};
  const base = it["status"] ?? s.bal("itens")["modelos"][it["modelo"]]["status"];
  return Forja.status_com_nivel(base, inteiro(it["nivel"] ?? 0), inteiro(cfg_forja(s)["bonus_status_por_nivel_pct"]));
}

/** Efeito dos conjuntos equipados: {atributos, habilidades, contagem, total}. */
export function efeito_conjuntos(s: Servico): Dados {
  const modelos_eq: string[] = [];
  for (const esp of Object.keys(s.estado["equipamento"])) {
    const it = item(s, s.estado["equipamento"][esp]);
    if (Object.keys(it).length > 0) modelos_eq.push(it["modelo"]);
  }
  return Conjuntos.efeito(modelos_eq, s.bal("itens"));
}

export function habilidades_conhecidas(s: Servico): string[] {
  const r: string[] = [...s.bal("progressao")["habilidades"]["base"]];
  for (const h of efeito_conjuntos(s)["habilidades"]) {
    if (!r.includes(h)) r.push(h);
  }
  return r;
}

export function espacos_habilidade(s: Servico): number {
  const cfg = s.bal("progressao")["habilidades"];
  let n = inteiro(cfg["espacos_iniciais"]);
  const ligas: string[] = s.bal("economia")["ligas"]["nomes"];
  const melhor = String((s.estado["liga"] ?? {})["melhor"] ?? "");
  const por_liga = melhor !== "" && ligas.indexOf(melhor) >= ligas.indexOf(cfg["segundo_espaco_liga"]);
  if (por_liga || inteiro(s.estado["cavaleiro"]["nivel"]) >= inteiro(cfg["segundo_espaco_nivel"])) n += 1;
  return n;
}

export function habilidades_escolhidas(s: Servico): string[] {
  return [...(s.estado["cavaleiro"]["habilidades"] ?? [])];
}

/** As que valem na justa: escolhidas que ainda são conhecidas, até o número de espaços. */
export function habilidades_em_uso(s: Servico): string[] {
  const conhecidas = habilidades_conhecidas(s);
  const r: string[] = [];
  for (const h of habilidades_escolhidas(s)) {
    if (conhecidas.includes(h) && r.length < espacos_habilidade(s)) r.push(h);
  }
  return r;
}

/** Lado do jogador para a regra da justa: {cavaleiro, cavalo, equipamento, habilidades}. */
export function lado_para_justa(s: Servico): Dados {
  const equip: Dados = {};
  for (const espaco of ESPACOS_REGRA) {
    const it = equipado(s, espaco);
    if (Object.keys(it).length === 0) continue;
    const p = status_do_item(s, it["id"]);
    p["durabilidade"] = inteiro(it["durabilidade"]);
    equip[espaco] = p;
  }
  const cav = cavalo_ativo(s);
  const atr_cavalo: Dados = copiar(cav["atributos"] ?? {});
  if (cavalo_cansado(s)) {
    const pen = inteiro(s.bal("treino")["folego_cavalo"]["penalidade_velocidade_cansado_pct"]);
    atr_cavalo["velocidade"] = div(inteiro(atr_cavalo["velocidade"] ?? 0) * (100 - pen), 100);
  }
  const cav_atr: Dados = copiar(s.estado["cavaleiro"]["atributos"]);
  const bonus: Dados = efeito_conjuntos(s)["atributos"];
  const teto = inteiro(s.bal("treino")["teto_atributo"]);
  for (const k of Object.keys(bonus)) {
    if (tem(cav_atr, k)) cav_atr[k] = Math.min(inteiro(cav_atr[k]) + inteiro(bonus[k]), teto);
  }
  return { cavaleiro: cav_atr, cavalo: atr_cavalo, equipamento: equip, habilidades: habilidades_em_uso(s) };
}

/** Poder do cavaleiro equipado (mesma conta da liga). */
export function poder_jogador(s: Servico): number {
  const lado = lado_para_justa(s);
  const atr: number[] = [];
  for (const k of ["forca", "precisao", "equilibrio"]) atr.push(inteiro(lado["cavaleiro"][k]));
  for (const k of ["velocidade", "folego", "temperamento"]) atr.push(inteiro(lado["cavalo"][k] ?? 0));
  const modelos = s.bal("itens")["modelos"];
  const pecas: Dados[] = [];
  for (const esp of Object.keys(s.estado["equipamento"])) {
    const it = item(s, s.estado["equipamento"][esp]);
    if (Object.keys(it).length > 0) pecas.push({ raridade: modelos[it["modelo"]]["raridade"], nivel: inteiro(it["nivel"] ?? 0) });
  }
  return Liga.poder(atr, pecas, s.bal("economia"));
}

// ------------------------------------------------------------ habilidades

export function equipar_habilidades(s: Servico, lista: string[]): Resultado {
  if (lista.length > espacos_habilidade(s)) return erro("sem_espaco_habilidade");
  const conhecidas = habilidades_conhecidas(s);
  const defs = s.bal("impacto")["habilidades"];
  const grupos: Record<string, boolean> = {};
  for (const h of lista) {
    if (!conhecidas.includes(h) || !tem(defs, h)) return erro("habilidade_desconhecida");
    const g = String(defs[h]["grupo"]);
    if (tem(grupos, g)) return erro("uma_por_grupo");
    grupos[g] = true;
  }
  s.estado["cavaleiro"]["habilidades"] = [...lista];
  return concluir();
}

// --------------------------------------------------------------- comandos

/** Texto só com letras/espaços/apóstrofo/hífen, do tamanho certo, sem raiz ofensiva (ServicoNomes). */
export function validar_nome(s: Servico, nome: string): string {
  const d = s.bal("nomes_proibidos");
  const limpo = limpar_nome(nome);
  if ([...limpo].length < inteiro(d["tamanho_min"] ?? 2)) return "nome_curto";
  if ([...limpo].length > inteiro(d["tamanho_max"] ?? 20)) return "nome_longo";
  if (!/^[\p{L}' -]+$/u.test(limpo)) return "nome_caracteres";
  const norm = normalizar_nome(nome);
  for (const raiz of d["raizes"] ?? []) {
    if (norm.includes(raiz)) return "nome_ofensivo";
  }
  return "";
}

export function limpar_nome(nome: string): string {
  return nome.trim().replace(/\s+/g, " ");
}

const ACENTOS: Record<string, string> = {
  "á": "a", "à": "a", "â": "a", "ã": "a", "ä": "a", "é": "e", "ê": "e", "è": "e", "ë": "e",
  "í": "i", "î": "i", "ì": "i", "ï": "i", "ó": "o", "ô": "o", "õ": "o", "ò": "o", "ö": "o",
  "ú": "u", "û": "u", "ù": "u", "ü": "u", "ç": "c", "ñ": "n",
};
const TROCAS: Record<string, string> = { "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s" };

export function normalizar_nome(nome: string): string {
  let saida = "";
  for (let ch of nome.toLowerCase()) {
    if (tem(ACENTOS, ch)) ch = ACENTOS[ch];
    else if (tem(TROCAS, ch)) ch = TROCAS[ch];
    if (ch >= "a" && ch <= "z") saida += ch;
  }
  return saida;
}

export function criar_personagem(s: Servico, d: Dados): Resultado {
  for (const k of ["nome", "nome_casa", "corpo", "rosto", "cabelo", "pele", "cor_principal", "cor_secundaria", "pelagem"]) {
    if (!tem(d, k) || String(d[k]) === "") return erro("falta_" + k);
  }
  for (const k of ["nome", "nome_casa"]) {
    const e = validar_nome(s, String(d[k]));
    if (e !== "") return erro(e);
  }
  const cav = s.estado["cavaleiro"];
  cav["nome"] = limpar_nome(String(d["nome"]));
  cav["corpo"] = d["corpo"];
  cav["rosto"] = d["rosto"];
  cav["cabelo"] = d["cabelo"];
  cav["pele"] = d["pele"];
  cav["cor_cabelo"] = d["cor_cabelo"] ?? "castanho";
  s.estado["casa"]["nome"] = limpar_nome(String(d["nome_casa"]));
  s.estado["casa"]["cores"]["principal"] = d["cor_principal"];
  s.estado["casa"]["cores"]["secundaria"] = d["cor_secundaria"];
  for (const c of s.estado["cavalos"]) {
    if (c["id"] === s.estado["cavalo_ativo"]) c["pelagem"] = d["pelagem"];
  }
  return concluir();
}

export function definir_brasao(s: Servico, brasao: Dados): Resultado {
  s.estado["casa"]["brasao"] = copiar(brasao);
  return concluir();
}

export function equipar(s: Servico, id: string): Resultado {
  const it = item(s, id);
  if (Object.keys(it).length === 0) return erro("item_inexistente");
  const modelo = s.bal("itens")["modelos"][it["modelo"]] ?? {};
  if (Object.keys(modelo).length === 0) return erro("modelo_inexistente");
  s.estado["equipamento"][modelo["espaco"]] = id;
  return concluir();
}

export function definir_visual(s: Servico, espaco: string, id_visual: string): Resultado {
  if (id_visual === "") {
    delete s.estado["visual"][espaco];
  } else {
    const it = item(s, id_visual);
    if (Object.keys(it).length === 0) return erro("item_inexistente");
    if (s.bal("itens")["modelos"][it["modelo"]]["espaco"] !== espaco) return erro("espaco_errado");
    s.estado["visual"][espaco] = id_visual;
  }
  return concluir();
}

// ------------------------------------------------------------------- vila

export function predio_liberado(s: Servico, nome: string): boolean {
  const p = s.bal("vila")["predios"][nome] ?? {};
  return Object.keys(p).length > 0 && inteiro(s.estado["cavaleiro"]["nivel"]) >= inteiro(p["libera_nivel"]);
}

export function predio_nivel(s: Servico, nome: string): number {
  const preds = s.estado["vila"]["predios"];
  if (tem(preds, nome)) return inteiro(preds[nome]["nivel"]);
  return predio_liberado(s, nome) ? 1 : 0;
}

export function teto_predio(s: Servico, nome: string): number {
  const p = s.bal("vila")["predios"][nome];
  if (nome === "casa_senhorial") return inteiro(p["nivel_max"]);
  return Math.min(inteiro(p["nivel_max"]), predio_nivel(s, "casa_senhorial"));
}

export function timer_do_predio(s: Servico, nome: string, tipo = ""): Dados {
  for (const t of s.estado["timers"]) {
    if (t["alvo"] === nome && (tipo === "" || t["tipo"] === tipo)) return copiar(t);
  }
  return {};
}

export function timers_do_predio(s: Servico, nome: string): Dados[] {
  return s.estado["timers"].filter((t: Dados) => t["alvo"] === nome).map((t: Dados) => copiar(t));
}

export function pode_melhorar(s: Servico, nome: string): Resultado {
  const vila = s.bal("vila");
  if (!tem(vila["predios"], nome)) return erro("predio_inexistente");
  if (!predio_liberado(s, nome)) return erro("predio_bloqueado");
  if (Object.keys(timer_do_predio(s, nome, "melhoria")).length > 0) return erro("predio_ocupado");
  const nivel = predio_nivel(s, nome);
  if (nivel >= teto_predio(s, nome)) {
    return erro(nome !== "casa_senhorial" && nivel < inteiro(vila["predios"][nome]["nivel_max"]) ? "predio_no_teto" : "predio_no_maximo");
  }
  const m = vila["predios"][nome]["melhoria"][nivel - 1];
  if (ouro(s) < inteiro(m["ouro"])) return { ok: false, erro: "ouro_insuficiente", ouro: inteiro(m["ouro"]), segundos: inteiro(m["segundos"]) };
  return { ok: true, erro: "", ouro: inteiro(m["ouro"]), segundos: inteiro(m["segundos"]) };
}

export function garantir_predio(s: Servico, nome: string): void {
  if (!tem(s.estado["vila"]["predios"], nome)) s.estado["vila"]["predios"][nome] = { nivel: 1 };
}

export function melhorar_predio(s: Servico, nome: string): Resultado {
  const p = pode_melhorar(s, nome);
  if (!p.ok) return p;
  s.estado["inventario"]["ouro"] = ouro(s) - inteiro(p["ouro"]);
  const agora = s.agora();
  s.estado["timers"].push({
    id: novo_id(s.estado, "t"), tipo: "melhoria", alvo: nome,
    inicio_em: agora, termina_em: agora + duracao_timer(s, inteiro(p["segundos"])), nivel_novo: predio_nivel(s, nome) + 1,
  });
  garantir_predio(s, nome);
  _evento(s, "predio");
  const r = concluir();
  r["ouro"] = p["ouro"];
  return r;
}

/** Conclui um timer que já terminou (aplica o efeito e tira da lista). */
export function concluir_timer(s: Servico, id: string): Resultado {
  for (let i = 0; i < s.estado["timers"].length; i++) {
    const t = s.estado["timers"][i];
    if (t["id"] !== id) continue;
    if (!pronto(s, inteiro(t["termina_em"]))) return erro("timer_nao_terminou");
    const tr_cfg = s.bal("treino");
    let extra: Dados = {};
    switch (t["tipo"]) {
      case "melhoria":
        garantir_predio(s, t["alvo"]);
        s.estado["vila"]["predios"][t["alvo"]]["nivel"] = inteiro(t["nivel_novo"]);
        break;
      case "treino_cavaleiro": {
        const a = s.estado["cavaleiro"]["atributos"];
        a[t["atributo"]] = Math.min(inteiro(a[t["atributo"]]) + inteiro(tr_cfg["ganho_pontos"]), inteiro(tr_cfg["teto_atributo"]));
        break;
      }
      case "conserto": {
        const maximo = inteiro(s.bal("itens")["modelos"][item(s, t["item"])["modelo"]]["durabilidade_max"]);
        const it = item_ref(s, t["item"]);
        if (it) it["durabilidade"] = maximo;
        break;
      }
      case "treino_cavalo":
        for (const c of s.estado["cavalos"]) {
          if (c["id"] === t["cavalo"]) {
            const ac = c["atributos"];
            ac[t["atributo"]] = Math.min(inteiro(ac[t["atributo"]]) + inteiro(tr_cfg["ganho_pontos"]), inteiro(tr_cfg["teto_atributo"]));
          }
        }
        break;
      case "forja":
        extra = entregar_forja(s, t["modelo"]);
        break;
      case "fundicao": {
        const mats = s.estado["inventario"]["materiais"];
        mats[t["produto"]] = inteiro(mats[t["produto"]] ?? 0) + inteiro(t["quantidade"]);
        extra = { produto: t["produto"], quantidade: inteiro(t["quantidade"]) };
        break;
      }
    }
    s.estado["timers"].splice(i, 1);
    return { ...concluir(), ...extra };
  }
  return erro("timer_inexistente");
}

// ---------------------------------------------------- treino e cavalos

export function vagas_treino(s: Servico, predio: string): number {
  const v = s.bal("treino")["vagas"];
  // A vaga extra vem do prédio ou do VIP (é a mesma vaga; não somam).
  const extra = predio_nivel(s, predio) >= inteiro(v["extra_no_nivel_do_predio"]) || vip_ativo(s);
  return inteiro(v["base"]) + (extra ? 1 : 0);
}

export function treinos_em(s: Servico, predio: string): Dados[] {
  return timers_do_predio(s, predio).filter((t) => String(t["tipo"]).startsWith("treino_"));
}

export function duracao_treino(s: Servico): number {
  return da_curva(s, s.bal("treino")["duracao_por_nivel"]);
}

export function custo_treino(s: Servico): number {
  return da_curva(s, s.bal("treino")["custo_ouro_por_nivel"]);
}

export function treinar_cavaleiro(s: Servico, atributo: string): Resultado {
  const cfg = s.bal("treino");
  if (!(cfg["atributos_cavaleiro"] as string[]).includes(atributo)) return erro("atributo_invalido");
  if (!predio_liberado(s, "campo_treino")) return erro("predio_bloqueado");
  if (treinos_em(s, "campo_treino").length >= vagas_treino(s, "campo_treino")) return erro("sem_vaga");
  if (inteiro(s.estado["cavaleiro"]["atributos"][atributo]) >= inteiro(cfg["teto_atributo"])) return erro("atributo_no_teto");
  return iniciar_treino(s, "campo_treino", { tipo: "treino_cavaleiro", atributo });
}

export function treinar_cavalo(s: Servico, id: string, atributo: string): Resultado {
  const cfg = s.bal("treino");
  const c = cavalo(s, id);
  if (Object.keys(c).length === 0) return erro("cavalo_inexistente");
  if (!(cfg["atributos_cavalo"] as string[]).includes(atributo)) return erro("atributo_invalido");
  if (id === s.estado["cavalo_ativo"]) return erro("cavalo_ativo_em_uso");
  if (cavalo_treinando(s, id)) return erro("cavalo_ja_treinando");
  if (treinos_em(s, "estabulo").length >= vagas_treino(s, "estabulo")) return erro("sem_vaga");
  if (inteiro(c["atributos"][atributo]) >= inteiro(cfg["teto_atributo"])) return erro("atributo_no_teto");
  return iniciar_treino(s, "estabulo", { tipo: "treino_cavalo", cavalo: id, atributo });
}

function iniciar_treino(s: Servico, predio: string, extra: Dados): Resultado {
  const custo = custo_treino(s);
  if (ouro(s) < custo) return erro("ouro_insuficiente");
  s.estado["inventario"]["ouro"] = ouro(s) - custo;
  const agora = s.agora();
  const t = { id: novo_id(s.estado, "t"), alvo: predio, inicio_em: agora, termina_em: agora + duracao_timer(s, duracao_treino(s)), ...extra };
  s.estado["timers"].push(t);
  _evento(s, "treino");
  return concluir();
}

export function usar_cavalo(s: Servico, id: string): Resultado {
  if (Object.keys(cavalo(s, id)).length === 0) return erro("cavalo_inexistente");
  if (cavalo_treinando(s, id)) return erro("cavalo_ja_treinando");
  s.estado["cavalo_ativo"] = id;
  return concluir();
}

/** Novo cavalo no estábulo (recompensa ou compra: só o servidor chama). */
export function adicionar_cavalo(s: Servico, pelagem: string, atributos: Dados): Resultado {
  const f = s.bal("treino")["folego_cavalo"];
  const id = novo_id(s.estado, "c");
  s.estado["cavalos"].push({ id, nome: "", pelagem, atributos: copiar(atributos), folego: inteiro(f["maximo"]), folego_em: s.agora() });
  const r = concluir();
  r["id"] = id;
  return r;
}

/** Depois de uma justa: gasta o fôlego do cavalo e passa o desgaste das peças ao inventário. */
export function registrar_justa(s: Servico, resultado: Dados): Resultado {
  const fim: Dados = resultado["equipamento_final"] ?? {};
  for (const espaco of Object.keys(fim)) {
    const id: string = s.estado["equipamento"][espaco] ?? "";
    for (const it of s.estado["inventario"]["itens"]) {
      if (it["id"] === id && tem(fim[espaco], "durabilidade")) {
        it["durabilidade"] = clampi(inteiro(fim[espaco]["durabilidade"]), 0, inteiro(it["durabilidade"]));
      }
    }
  }
  const f = s.bal("treino")["folego_cavalo"];
  for (const c of s.estado["cavalos"]) {
    if (c["id"] === s.estado["cavalo_ativo"] && (resultado["gasta_folego"] ?? true)) {
      c["folego"] = Math.max(folego_cavalo(s, c["id"]) - inteiro(f["gasto_por_justa"]), 0);
      c["folego_em"] = s.agora();
    }
  }
  _evento(s, "justa");
  passe_xp(s, inteiro(s.bal("economia")["passe"]["xp_por_justa"]));
  return concluir();
}

// ---------------------------------------------------------------- conserto

export function item_em_conserto(s: Servico, id: string): Dados {
  for (const t of s.estado["timers"]) {
    if (t["tipo"] === "conserto" && (t["item"] ?? "") === id) return copiar(t);
  }
  return {};
}

export function custo_conserto(s: Servico, id: string): Dados {
  const it = item(s, id);
  const c = s.bal("desgaste")["conserto"];
  if (Object.keys(it).length === 0) return {};
  const maximo = inteiro(s.bal("itens")["modelos"][it["modelo"]]["durabilidade_max"]);
  const dano = Math.max(maximo - inteiro(it["durabilidade"]), 0);
  let ouro_c = div(dano * inteiro(c["ouro_por_ponto_milesimos"]), 1000);
  let qtd = div(dano + inteiro(c["pontos_por_material"]) - 1, inteiro(c["pontos_por_material"]));
  if (inteiro(it["durabilidade"]) === 0 && maximo > 0) {
    ouro_c = div(ouro_c * inteiro(c["quebrada_custo_pct"]), 100);
    qtd = div(qtd * inteiro(c["quebrada_custo_pct"]), 100);
  }
  return { ouro: ouro_c, material: c["material"], quantidade: qtd, segundos: da_curva(s, c["segundos_por_nivel"]), dano };
}

export function pode_consertar(s: Servico, id: string): Resultado {
  const custo = custo_conserto(s, id);
  if (Object.keys(custo).length === 0) return erro("item_inexistente");
  if (inteiro(custo["dano"]) === 0) return erro("item_inteiro");
  if (!predio_liberado(s, "armeiro")) return erro("predio_bloqueado");
  if (Object.keys(item_em_conserto(s, id)).length > 0) return erro("ja_em_conserto");
  const v = s.bal("desgaste")["conserto"]["vagas"];
  const vagas = inteiro(v["base"]) + (predio_nivel(s, "armeiro") >= inteiro(v["extra_no_nivel_do_predio"]) ? 1 : 0);
  if (timers_do_predio(s, "armeiro").filter((t) => t["tipo"] === "conserto").length >= vagas) return erro("sem_vaga");
  if (ouro(s) < inteiro(custo["ouro"])) return erro("ouro_insuficiente");
  if (inteiro(s.estado["inventario"]["materiais"][custo["material"]] ?? 0) < inteiro(custo["quantidade"])) return erro("material_insuficiente");
  return { ...custo, ok: true, erro: "" };
}

export function consertar(s: Servico, id: string): Resultado {
  const p = pode_consertar(s, id);
  if (!p.ok) return p;
  s.estado["inventario"]["ouro"] = ouro(s) - inteiro(p["ouro"]);
  const mats = s.estado["inventario"]["materiais"];
  mats[p["material"]] = inteiro(mats[p["material"]] ?? 0) - inteiro(p["quantidade"]);
  const agora = s.agora();
  s.estado["timers"].push({
    id: novo_id(s.estado, "t"), tipo: "conserto", alvo: "armeiro", item: id,
    inicio_em: agora, termina_em: agora + duracao_timer(s, inteiro(p["segundos"])),
  });
  return concluir();
}

// -------------------------------------------------------------- progresso

/** Ganha ouro e XP; sobe de nível pela tabela de progressao.json. Devolve os níveis ganhos. */
export function ganhar(s: Servico, ouro_ganho: number, xp_ganho: number): number[] {
  s.estado["inventario"]["ouro"] = ouro(s) + Math.max(ouro_ganho, 0);
  const cav = s.estado["cavaleiro"];
  cav["xp"] = inteiro(cav["xp"]) + Math.max(xp_ganho, 0);
  const tabela: number[] = s.bal("progressao")["xp_por_nivel"];
  const novos: number[] = [];
  while (inteiro(cav["nivel"]) < tabela.length && inteiro(cav["xp"]) >= inteiro(tabela[inteiro(cav["nivel"])])) {
    cav["nivel"] = inteiro(cav["nivel"]) + 1;
    novos.push(inteiro(cav["nivel"]));
  }
  return novos;
}

// ------------------------------------------------------------------- forja

export function cfg_forja(s: Servico): Dados {
  return s.bal("economia")["forja"];
}

export function projetos(s: Servico): string[] {
  return [...s.estado["inventario"]["projetos"]];
}

export function receita(s: Servico, modelo: string): Dados {
  const rar: string = s.bal("itens")["modelos"][modelo]["raridade"];
  return copiar(cfg_forja(s)["receitas"][rar]);
}

export function vagas_forja(s: Servico): number {
  const v = cfg_forja(s)["vagas_forja"];
  return inteiro(v["base"]) + (predio_nivel(s, "armeiro") >= inteiro(v["extra_no_nivel_do_predio"]) ? 1 : 0);
}

export function forja_em_andamento(s: Servico): Dados[] {
  return s.estado["timers"].filter((t: Dados) => t["tipo"] === "forja").map((t: Dados) => copiar(t));
}

export function pode_forjar(s: Servico, modelo: string): Resultado {
  const modelos = s.bal("itens")["modelos"];
  if (!tem(modelos, modelo)) return erro("modelo_inexistente");
  if (!predio_liberado(s, "armeiro")) return erro("predio_bloqueado");
  if (!(s.estado["inventario"]["projetos"] as string[]).includes(modelos[modelo]["conjunto"])) return erro("sem_projeto");
  if (forja_em_andamento(s).length >= vagas_forja(s)) return erro("forja_ocupada");
  const rec = receita(s, modelo);
  if (ouro(s) < inteiro(rec["ouro"])) return erro("ouro_insuficiente");
  for (const m of Object.keys(rec["materiais"])) {
    if (material(s, m) < inteiro(rec["materiais"][m])) return erro("material_insuficiente");
  }
  return concluir();
}

export function forjar(s: Servico, modelo: string): Resultado {
  const p = pode_forjar(s, modelo);
  if (!p.ok) return p;
  const rec = receita(s, modelo);
  s.estado["inventario"]["ouro"] = ouro(s) - inteiro(rec["ouro"]);
  gastar_materiais(s, rec["materiais"]);
  _evento(s, "forja");
  const agora = s.agora();
  s.estado["timers"].push({
    id: novo_id(s.estado, "t"), tipo: "forja", alvo: "armeiro", modelo,
    inicio_em: agora, termina_em: agora + duracao_timer(s, inteiro(rec["segundos"])),
  });
  return concluir();
}

export function entregar_forja(s: Servico, modelo: string): Dados {
  const m = s.bal("itens")["modelos"][modelo];
  const st = Forja.variar_status(m["status"], inteiro(cfg_forja(s)["variacao_status_pct"]), semente_servico(s));
  const id = novo_id(s.estado, "i");
  s.estado["inventario"]["itens"].push({ id, modelo, nivel: 0, durabilidade: inteiro(m["durabilidade_max"]), status: st });
  _evento(s, "peca_nova");
  return { item: id, modelo, status: st };
}

export function teto_melhoria(s: Servico): number {
  const m = s.bal("economia")["melhoria"];
  if (!predio_liberado(s, "armeiro")) return 0;
  return Math.min(inteiro(m["nivel_max"]), Math.max(predio_nivel(s, "armeiro"), 1) * inteiro(m["teto_por_nivel_armeiro"]));
}

export function custo_melhoria(s: Servico, id: string): Dados {
  const it = item(s, id);
  if (Object.keys(it).length === 0) return {};
  const m = s.bal("economia")["melhoria"];
  const n = inteiro(it["nivel"] ?? 0);
  if (n >= inteiro(m["nivel_max"])) return { nivel: n, teto: teto_melhoria(s), maximo: true };
  return {
    nivel: n, fragmentos: inteiro(m["custo_fragmentos"][n]), ouro: inteiro(m["custo_ouro"][n]),
    lingotes: inteiro(m["custo_lingotes"][n]), chance: inteiro(m["chance_sucesso_pct"][n]), teto: teto_melhoria(s), maximo: false,
  };
}

export function pode_melhorar_peca(s: Servico, id: string): Resultado {
  const c = custo_melhoria(s, id);
  if (Object.keys(c).length === 0) return erro("item_inexistente");
  if (!predio_liberado(s, "armeiro")) return erro("predio_bloqueado");
  if (c["maximo"]) return erro("nivel_maximo");
  if (inteiro(c["nivel"]) >= inteiro(c["teto"])) return erro("teto_armeiro");
  if (Object.keys(item_em_conserto(s, id)).length > 0) return erro("peca_em_uso");
  if (ouro(s) < inteiro(c["ouro"])) return erro("ouro_insuficiente");
  if (fragmentos(s) < inteiro(c["fragmentos"]) || material(s, "lingote_ferro") < inteiro(c["lingotes"])) return erro("material_insuficiente");
  return { ...c, ok: true, erro: "" };
}

export function melhorar_peca(s: Servico, id: string): Resultado {
  const p = pode_melhorar_peca(s, id);
  if (!p.ok) return p;
  s.estado["inventario"]["ouro"] = ouro(s) - inteiro(p["ouro"]);
  gastar_materiais(s, { fragmentos: inteiro(p["fragmentos"]), lingote_ferro: inteiro(p["lingotes"]) });
  const sucesso = Forja.melhoria_deu_certo(inteiro(p["nivel"]), s.bal("economia")["melhoria"], semente_servico(s));
  let nivel = inteiro(p["nivel"]);
  if (sucesso) {
    nivel += 1;
    const it = item_ref(s, id);
    if (it) it["nivel"] = nivel;
    _evento(s, "melhoria_peca");
    if (nivel >= inteiro(s.bal("economia")["melhoria"]["nivel_max"])) _evento(s, "melhoria_10");
  }
  return { ...concluir(), sucesso, nivel };
}

export function pode_fundir(s: Servico, produto: string, quantidade: number): Resultado {
  const f = cfg_forja(s);
  const origens: Record<string, string> = { lingote_ferro: "sucata", lingote_aco: "lingote_ferro" };
  const origem = tem(origens, produto) ? origens[produto] : "";
  if (origem === "" || quantidade <= 0) return erro("material_insuficiente");
  if (!predio_liberado(s, "ferreiro")) return erro("predio_bloqueado");
  if (s.estado["timers"].filter((t: Dados) => t["tipo"] === "fundicao").length >= inteiro(f["vagas_fundicao"])) return erro("forno_ocupado");
  const custo = quantidade * inteiro(produto === "lingote_ferro" ? f["lingote_por_sucata"] : f["aco_por_ferro"]);
  if (material(s, origem) < custo) return erro("material_insuficiente");
  const seg = div(quantidade * inteiro(f["fundir_segundos_por_lingote"]) * (100 + bonus_companheiros(s, "fundicao_tempo_pct")), 100);
  return { ok: true, erro: "", origem, custo, segundos: Math.max(seg, 1) };
}

export function fundir(s: Servico, produto: string, quantidade: number): Resultado {
  const p = pode_fundir(s, produto, quantidade);
  if (!p.ok) return p;
  gastar_materiais(s, { [p["origem"]]: inteiro(p["custo"]) });
  const agora = s.agora();
  s.estado["timers"].push({
    id: novo_id(s.estado, "t"), tipo: "fundicao", alvo: "ferreiro", produto, quantidade,
    inicio_em: agora, termina_em: agora + duracao_timer(s, inteiro(p["segundos"])),
  });
  return concluir();
}

export function fragmentos(s: Servico): number {
  return inteiro(s.estado["inventario"]["materiais"]["fragmentos"] ?? 0);
}

// ------------------------------------------------------------------ metas

export function renome(s: Servico): number {
  return inteiro(s.estado["metas"]["renome"]);
}

/** Sorteia as missões do dia/semana quando viram. */
export function atualizar_missoes(s: Servico): void {
  const m = s.estado["metas"];
  const cfg = s.bal("metas")["missoes"];
  if (inteiro(m["dia"]) !== dia_atual(s)) {
    m["dia"] = dia_atual(s);
    m["diarias"] = sortear_missoes(s, cfg["diarias"], inteiro(cfg["diarias_por_dia"]), dia_atual(s));
  }
  if (inteiro(m["semana"]) !== semana_atual(s)) {
    m["semana"] = semana_atual(s);
    m["semanais"] = sortear_missoes(s, cfg["semanais"], inteiro(cfg["semanais_por_semana"]), 100000 + semana_atual(s));
  }
  _evento_maximo(s, "sequencia", inteiro(m["sequencia"]));
}

function sortear_missoes(s: Servico, pool: Dados[], n: number, salt: number): Dados[] {
  const rng = new Aleatorio(inteiro(s.estado["baus"]["semente"]) + 7919 * salt);
  const ids: string[] = pool.map((x) => x["id"]);
  const res: Dados[] = [];
  while (res.length < Math.min(n, pool.length)) {
    const id = ids[rng.inteiro(0, ids.length - 1)];
    ids.splice(ids.indexOf(id), 1);
    res.push({ id, progresso: 0, resgatada: false });
  }
  return res;
}

export function resgatar_missao(s: Servico, id: string): Resultado {
  atualizar_missoes(s);
  for (const tipo of ["diarias", "semanais"]) {
    for (const mi of s.estado["metas"][tipo]) {
      if (mi["id"] !== id) continue;
      const d = (s.bal("metas")["missoes"][tipo] as Dados[]).filter((x) => x["id"] === id)[0];
      if (mi["resgatada"]) return erro("ja_resgatada");
      if (inteiro(mi["progresso"]) < inteiro(d["meta"])) return erro("missao_incompleta");
      mi["resgatada"] = true;
      const g = dar_recompensa(s, d["recompensa"]);
      return { ...concluir(), recompensa: g };
    }
  }
  return erro("missao_inexistente");
}

/** Login dos 7 primeiros dias: {dia (1 a 7; 0 = acabou), pode, recompensa}. */
export function login_hoje(s: Servico): Dados {
  const l = s.estado["metas"]["login"];
  const tabela: Dados[] = s.bal("metas")["login"];
  const feitos = inteiro(l["dias"]);
  if (feitos >= tabela.length) return { dia: 0, pode: false, recompensa: {} };
  return { dia: feitos + 1, pode: inteiro(l["ultimo_dia"]) !== dia_atual(s), recompensa: copiar(tabela[feitos]) };
}

export function resgatar_login(s: Servico): Resultado {
  const h = login_hoje(s);
  if (!h["pode"]) return erro("login_ja_resgatado");
  const l = s.estado["metas"]["login"];
  l["dias"] = inteiro(l["dias"]) + 1;
  l["ultimo_dia"] = dia_atual(s);
  const g = dar_recompensa(s, h["recompensa"]);
  return { ...concluir(), dia: h["dia"], recompensa: g };
}

export function definir_titulo(s: Servico, id: string): Resultado {
  if (id !== "" && !(s.estado["metas"]["titulos"] as string[]).includes(id)) return erro("titulo_bloqueado");
  s.estado["metas"]["titulo"] = id;
  return concluir();
}

/** Conta um evento: missões do dia/semana e contador das conquistas. */
export function _evento(s: Servico, nome: string, qtd = 1): void {
  if (!tem(s.estado, "metas")) return;
  atualizar_missoes(s);
  const m = s.estado["metas"];
  const cfg = s.bal("metas")["missoes"];
  for (const tipo of ["diarias", "semanais"]) {
    for (const mi of m[tipo]) {
      const d = (cfg[tipo] as Dados[]).filter((x) => x["id"] === mi["id"]);
      if (d.length > 0 && d[0]["evento"] === nome) mi["progresso"] = Math.min(inteiro(mi["progresso"]) + qtd, inteiro(d[0]["meta"]));
    }
  }
  const cont = m["contadores"];
  cont[nome] = inteiro(cont[nome] ?? 0) + qtd;
  checar_conquistas(s);
}

/** Contador que guarda o maior valor (ex.: melhor sequência de vitórias). */
export function _evento_maximo(s: Servico, nome: string, valor: number): void {
  const cont = s.estado["metas"]["contadores"];
  if (valor > inteiro(cont[nome] ?? 0)) {
    cont[nome] = valor;
    checar_conquistas(s);
  }
}

function checar_conquistas(s: Servico): void {
  const m = s.estado["metas"];
  const cont = m["contadores"];
  for (const c of s.bal("metas")["conquistas"] as Dados[]) {
    if ((m["conquistas"] as string[]).includes(c["id"]) || inteiro(cont[c["evento"]] ?? 0) < inteiro(c["meta"])) continue;
    m["conquistas"].push(c["id"]);
    m["novas"].push(c["id"]);
    if (tem(c, "titulo") && !(m["titulos"] as string[]).includes(c["titulo"])) m["titulos"].push(c["titulo"]);
    dar_recompensa(s, c["recompensa"] ?? {});
  }
}

/** Entrega uma recompensa {ouro, fragmentos, chaves, bau, xp}; devolve o que deu. */
export function dar_recompensa(s: Servico, r: Dados): Dados {
  const dado: Dados = copiar(r);
  if (tem(r, "fragmentos")) s.estado["inventario"]["materiais"]["fragmentos"] = fragmentos(s) + inteiro(r["fragmentos"]);
  if (tem(r, "chaves")) s.estado["baus"]["chaves"] = chaves(s) + inteiro(r["chaves"]);
  if (tem(r, "bau")) dado["bau_ganho"] = guardar_bau(s, String(r["bau"]));
  ganhar(s, inteiro(r["ouro"] ?? 0), inteiro(r["xp"] ?? 0));
  return dado;
}

// ------------------------------------------------------------------- loja

export function vip_ativo(s: Servico): boolean {
  return tem(s.estado, "loja") && inteiro(s.estado["loja"]["vip_ate"]) > s.agora();
}

/** Conteúdo entregue por compra/oferta: gemas, bau, ouro ou material. */
export function entregar_conteudo(s: Servico, c: Dados): Dados {
  const dado: Dados = {};
  for (const k of Object.keys(c)) {
    switch (k) {
      case "gemas":
        s.estado["inventario"]["gemas"] = gemas(s) + inteiro(c[k]);
        break;
      case "bau":
        dado["bau_ganho"] = guardar_bau(s, String(c[k]));
        break;
      case "ouro":
        ganhar(s, inteiro(c[k]), 0);
        break;
      default: {
        const mats = s.estado["inventario"]["materiais"];
        mats[k] = inteiro(mats[k] ?? 0) + inteiro(c[k]);
      }
    }
    dado[k] = c[k];
  }
  return dado;
}

/** Entrega de um produto PAGO (depois de validar o recibo no servidor, 3.7). */
export function entregar_compra(s: Servico, produto: string, teste = false): Resultado {
  const cfg = s.bal("loja");
  const lj = s.estado["loja"];
  let entregue: Dados = {};
  let achou = false;
  for (const g of cfg["gemas"] as Dados[]) {
    if (g["id"] === produto) {
      s.estado["inventario"]["gemas"] = gemas(s) + inteiro(g["gemas"]);
      entregue = { gemas: inteiro(g["gemas"]) };
      achou = true;
    }
  }
  if (produto === cfg["vip"]["id"]) {
    lj["vip_ate"] = Math.max(inteiro(lj["vip_ate"]), s.agora()) + inteiro(cfg["vip"]["dias"]) * 86400;
    const gm = inteiro(s.bal("economia")["vip"]["gemas_mes"]);
    s.estado["inventario"]["gemas"] = gemas(s) + gm;
    entregue = { vip_dias: inteiro(cfg["vip"]["dias"]), gemas: gm };
    achou = true;
  }
  if (produto === cfg["passe"]["id"]) {
    atualizar_passe(s);
    if (lj["passe"]["premium"]) return erro("ja_comprado");
    lj["passe"]["premium"] = true;
    entregue = { passe: true };
    achou = true;
  }
  for (const o of cfg["ofertas"] as Dados[]) {
    if (o["id"] === produto) {
      const ativa = (lj["ofertas"] as Dados[]).filter((x) => x["id"] === produto && inteiro(x["ate"]) > s.agora());
      if (ativa.length === 0) return erro("oferta_expirada");
      entregue = entregar_conteudo(s, o["conteudo"]);
      lj["ofertas"] = (lj["ofertas"] as Dados[]).filter((x) => x["id"] !== produto);
      achou = true;
    }
  }
  if (!achou) return erro("produto_inexistente");
  (lj["compras"] as Dados[]).push({ produto, quando: s.agora(), teste });
  return { ...concluir(), produto, entregue, teste };
}

export function comprar_com_gemas(s: Servico, id: string): Resultado {
  const cfg = s.bal("loja");
  const lj = s.estado["loja"];
  for (const c of cfg["cosmeticos"] as Dados[]) {
    if (c["id"] === id) {
      if ((lj["cosmeticos"] as string[]).includes(id)) return erro("ja_comprado");
      if (gemas(s) < inteiro(c["gemas"])) return erro("gemas_insuficientes");
      s.estado["inventario"]["gemas"] = gemas(s) - inteiro(c["gemas"]);
      lj["cosmeticos"].push(id);
      return concluir();
    }
  }
  for (const m of cfg["materiais"] as Dados[]) {
    if (m["material"] === id) {
      const cd = lj["compras_dia"];
      if (inteiro(cd["dia"] ?? -1) !== dia_atual(s)) {
        for (const k of Object.keys(cd)) delete cd[k];
        cd["dia"] = dia_atual(s);
      }
      if (inteiro(cd[id] ?? 0) >= inteiro(m["limite_dia"])) return erro("limite_diario");
      if (gemas(s) < inteiro(m["gemas"])) return erro("gemas_insuficientes");
      s.estado["inventario"]["gemas"] = gemas(s) - inteiro(m["gemas"]);
      cd[id] = inteiro(cd[id] ?? 0) + 1;
      const mats = s.estado["inventario"]["materiais"];
      mats[id] = inteiro(mats[id] ?? 0) + inteiro(m["quantidade"]);
      return concluir();
    }
  }
  return erro("produto_inexistente");
}

export function usar_cosmetico(s: Servico, id: string): Resultado {
  const lj = s.estado["loja"];
  if (id !== "" && !(lj["cosmeticos"] as string[]).includes(id)) return erro("cosmetico_bloqueado");
  let tipo = "";
  for (const c of s.bal("loja")["cosmeticos"] as Dados[]) {
    if (c["id"] === id) tipo = c["tipo"];
  }
  if (tipo === "frase_arauto" || id === "") lj["frase"] = id;
  if (tipo === "efeito_vitoria") lj["vitoria"] = id;
  return concluir();
}

export function custo_pular(s: Servico, restante_s: number): number {
  return Math.ceil(Math.max(restante_s, 0) / 3600.0) * inteiro(s.bal("loja")["gemas_por_hora_timer"]);
}

/** Termina agora um timer (treino, obra, forja...) ou o baú que está abrindo, com gemas. */
export function pular_com_gemas(s: Servico, id: string): Resultado {
  let alvo: Dados | null = null;
  let chave = "termina_em";
  for (const t of s.estado["timers"]) {
    if (t["id"] === id) alvo = t;
  }
  if (alvo === null) {
    alvo = bau_ref(s, id);
    chave = "abre_em";
  }
  if (alvo === null || inteiro(alvo[chave] ?? 0) <= 0) return erro("timer_inexistente");
  const custo = custo_pular(s, inteiro(alvo[chave]) - s.agora());
  if (gemas(s) < custo) return erro("gemas_insuficientes");
  s.estado["inventario"]["gemas"] = gemas(s) - custo;
  alvo[chave] = s.agora();
  return { ...concluir(), gemas: custo };
}

// Passe da temporada: XP por justa; a temporada é a da liga.
export function atualizar_passe(s: Servico): void {
  const p = s.estado["loja"]["passe"];
  const t = inteiro(s.estado["liga"]["temporada"]);
  if (inteiro(p["temporada"]) !== t) {
    for (const k of Object.keys(p)) delete p[k];
    Object.assign(p, { temporada: t, premium: false, xp: 0, gratis: [], premium_resgatados: [] });
  }
}

export function passe_xp(s: Servico, xp: number): void {
  if (!tem(s.estado, "loja")) return;
  atualizar_passe(s);
  s.estado["loja"]["passe"]["xp"] = inteiro(s.estado["loja"]["passe"]["xp"]) + xp;
}

export function recompensa_passe(s: Servico, nivel: number): Dados {
  const ps = s.bal("economia")["passe"];
  const g = ps["gratis"];
  const pr = ps["premium"];
  const rg: Dados = { ouro: inteiro(g["ouro_por_nivel"]) };
  if (nivel % inteiro(g["bau_ferro_a_cada"]) === 0) rg["bau"] = "ferro";
  const rp: Dados = { ouro: inteiro(pr["ouro_por_nivel"]), fragmentos: inteiro(pr["fragmentos_por_nivel"]) };
  if (nivel % inteiro(pr["bau_ouro_a_cada"]) === 0) rp["bau"] = "ouro";
  else if (nivel % inteiro(pr["bau_ferro_a_cada"]) === 0) rp["bau"] = "ferro";
  if ((pr["projeto_nos_niveis"] as number[]).some((x) => inteiro(x) === nivel)) rp["projeto"] = true;
  return { gratis: rg, premium: rp };
}

export function passe(s: Servico): Dados {
  atualizar_passe(s);
  const ps = s.bal("economia")["passe"];
  const p = s.estado["loja"]["passe"];
  return {
    temporada: inteiro(p["temporada"]), nivel: Math.min(inteiro(ps["niveis"]), div(inteiro(p["xp"]), inteiro(ps["xp_por_nivel"]))),
    xp: inteiro(p["xp"]), xp_nivel: inteiro(ps["xp_por_nivel"]), niveis: inteiro(ps["niveis"]), premium: p["premium"],
    gratis: [...p["gratis"]], premium_resgatados: [...p["premium_resgatados"]],
  };
}

export function resgatar_passe(s: Servico, nivel: number, trilha: string): Resultado {
  const info = passe(s);
  if (nivel < 1 || nivel > inteiro(info["nivel"])) return erro("nivel_do_passe_bloqueado");
  if (trilha === "premium" && !info["premium"]) return erro("passe_sem_premium");
  const lista: number[] = s.estado["loja"]["passe"][trilha === "gratis" ? "gratis" : "premium_resgatados"];
  if (lista.includes(nivel)) return erro("ja_resgatada");
  lista.push(nivel);
  const rec = recompensa_passe(s, nivel)[trilha];
  const dado = dar_recompensa(s, rec);
  if (rec["projeto"] ?? false) {
    for (const c of s.bal("economia")["conjuntos"] as Dados[]) {
      if (["raro", "epico"].includes(c["raridade"]) && !(s.estado["inventario"]["projetos"] as string[]).includes(c["nome"])) {
        s.estado["inventario"]["projetos"].push(c["nome"]);
        dado["projeto"] = c["nome"];
        break;
      }
    }
  }
  return { ...concluir(), recompensa: dado };
}

/** Ofertas (GDD): no gatilho, se não houve outra desse gatilho no intervalo. */
export function disparar_oferta(s: Servico, gatilho: string): void {
  if (!tem(s.estado, "loja")) return;
  const lj = s.estado["loja"];
  for (const o of s.bal("loja")["ofertas"] as Dados[]) {
    if (o["gatilho"] !== gatilho) continue;
    const ultima = inteiro(lj["ultima_oferta"][gatilho] ?? -999999999);
    if (s.agora() - ultima < inteiro(o["intervalo_s"])) return;
    lj["ultima_oferta"][gatilho] = s.agora();
    lj["ofertas"].push({ id: o["id"], ate: s.agora() + inteiro(o["duracao_s"]), vista: false });
  }
}

export function marcar_oferta_vista(s: Servico, id: string): Resultado {
  for (const x of s.estado["loja"]["ofertas"]) {
    if (x["id"] === id) x["vista"] = true;
  }
  return concluir();
}

export function derrota_por_pouco(s: Servico, eventos: Dados[]): boolean {
  for (const e of eventos) {
    if ((e["tipo"] ?? "") === "fim" && tem(e, "placar_jogador")) {
      return e["vencedor"] === 2 && (e["motivo"] ?? "") === "pontos" &&
        inteiro(e["placar_rival"]) - inteiro(e["placar_jogador"]) <= inteiro(s.bal("loja")["derrota_por_pouco_pontos"]);
    }
  }
  return false;
}

// --------------------------------------------------------------- anúncios

export function cfg_anuncios(s: Servico): Dados {
  return s.bal("economia")["anuncios"];
}

/** VIP: benefício sem assistir (economia.json > vip > beneficio_anuncios). */
export function anuncio_sem_assistir(s: Servico): boolean {
  return vip_ativo(s) && Boolean(s.bal("economia")["vip"]["beneficio_anuncios"]);
}

export function anuncios_restantes(s: Servico): number {
  const a = s.estado["anuncios"];
  const usados = inteiro(a["dia"]) === dia_atual(s) ? inteiro(a["usados"]) : 0;
  return Math.max(0, inteiro(cfg_anuncios(s)["limite_dia"]) - usados);
}

export function guardar_vitoria(s: Servico, ouro_g: number): void {
  s.estado["anuncios"]["ultima_vitoria"] = { ouro: ouro_g, quando: s.agora(), usada: false };
}

export function pode_recompensa_anuncio(s: Servico, tipo: string, alvo = ""): Resultado {
  if (anuncios_restantes(s) <= 0) return erro("limite_anuncios");
  switch (tipo) {
    case "cortar_timer": {
      if ((s.estado["anuncios"]["timers"] as string[]).includes(alvo)) return erro("timer_ja_cortado");
      let achou = false;
      for (const t of s.estado["timers"]) {
        achou = achou || (t["id"] === alvo && !pronto(s, inteiro(t["termina_em"])));
      }
      const b = bau_ref(s, alvo);
      achou = achou || (b !== null && inteiro(b["abre_em"]) > s.agora());
      if (!achou) return erro("timer_inexistente");
      break;
    }
    case "dobrar_vitoria": {
      const v = s.estado["anuncios"]["ultima_vitoria"];
      if (Object.keys(v).length === 0 || (v["usada"] ?? false) || s.agora() - inteiro(v["quando"]) > 600) return erro("sem_vitoria_para_dobrar");
      break;
    }
    case "bau_madeira_extra":
      if (baus(s).length >= inteiro(cfg_baus(s)["espacos"])) return erro("espacos_cheios");
      break;
    default:
      return erro("anuncio_inexistente");
  }
  return concluir();
}

/** Entrega o benefício (depois de conferir o anúncio assistido, ou direto para o VIP). */
export function recompensa_anuncio(s: Servico, tipo: string, alvo: string, token: string): Resultado {
  const p = pode_recompensa_anuncio(s, tipo, alvo);
  if (!p.ok) return p;
  if (token === "") return erro("anuncio_sem_comprovante");
  const a = s.estado["anuncios"];
  if (inteiro(a["dia"]) !== dia_atual(s)) {
    a["dia"] = dia_atual(s);
    a["usados"] = 0;
  }
  a["usados"] = inteiro(a["usados"]) + 1;
  const cfg = cfg_anuncios(s);
  let rec: Dados = {};
  switch (tipo) {
    case "cortar_timer": {
      const corte = inteiro(cfg["cortar_minutos"]) * 60;
      a["timers"].push(alvo);
      for (const t of s.estado["timers"]) {
        if (t["id"] === alvo) t["termina_em"] = Math.max(s.agora(), inteiro(t["termina_em"]) - corte);
      }
      const b = bau_ref(s, alvo);
      if (b !== null) b["abre_em"] = Math.max(s.agora(), inteiro(b["abre_em"]) - corte);
      rec = { minutos: inteiro(cfg["cortar_minutos"]) };
      break;
    }
    case "dobrar_vitoria": {
      const v = a["ultima_vitoria"];
      const extra = inteiro(v["ouro"]) * (inteiro(cfg["dobrar_vitoria"]) - 1);
      v["usada"] = true;
      ganhar(s, extra, 0);
      rec = { ouro: extra };
      break;
    }
    case "bau_madeira_extra":
      rec = { bau_ganho: guardar_bau(s, "madeira") };
      break;
  }
  return { ...concluir(), recompensa: rec };
}

// ---------------------------------------------------------------- história

export function cfg_historia(s: Servico): Dados {
  return s.bal("historia");
}

export function marcar_cena_vista(s: Servico, id: string): Resultado {
  if (!tem(cfg_historia(s)["cenas"], id)) return erro("cena_inexistente");
  if (!(s.estado["historia"]["vistas"] as string[]).includes(id)) s.estado["historia"]["vistas"].push(id);
  return concluir();
}

export function companheiros(s: Servico): string[] {
  const h = cfg_historia(s);
  const r: string[] = [];
  for (const c of Object.keys(h["companheiros"])) {
    if ((s.estado["historia"]["vistas"] as string[]).includes(h["companheiros"][c]["entra_na_cena"])) r.push(c);
  }
  return r;
}

/** Soma do bônus `tipo` dos companheiros presentes (em %). */
export function bonus_companheiros(s: Servico, tipo: string): number {
  if (!tem(s.estado, "historia")) return 0;
  const h = cfg_historia(s);
  let t = 0;
  for (const c of companheiros(s)) t += inteiro(h["companheiros"][c]["bonus"][tipo] ?? 0);
  return t;
}

// ------------------------------------------------------------------- baús

export function cfg_baus(s: Servico): Dados {
  return s.bal("economia")["baus"];
}

export function baus(s: Servico): Dados[] {
  return copiar(s.estado["baus"]["espacos"]);
}

export function chaves(s: Servico): number {
  return inteiro(s.estado["baus"]["chaves"]);
}

function bau_ref(s: Servico, id: string): Dados | null {
  for (const b of s.estado["baus"]["espacos"]) {
    if (b["id"] === id) return b;
  }
  return null;
}

export function bau_abrindo(s: Servico): Dados {
  for (const b of s.estado["baus"]["espacos"]) {
    if (inteiro(b["abre_em"]) > 0) return copiar(b);
  }
  return {};
}

export function bau_pronto(s: Servico, id: string): boolean {
  const b = bau_ref(s, id);
  return b !== null && inteiro(b["abre_em"]) > 0 && pronto(s, inteiro(b["abre_em"]));
}

/** Ganha um baú (só o servidor chama: vitória, recompensa, compra). */
export function ganhar_bau(s: Servico, tipo: string): Resultado {
  if (!tem(cfg_baus(s)["tipos"], tipo)) return erro("bau_inexistente");
  return { ...concluir(), ...guardar_bau(s, tipo) };
}

export function guardar_bau(s: Servico, tipo: string): Dados {
  const cfg = cfg_baus(s);
  const esp: Dados[] = s.estado["baus"]["espacos"];
  if (esp.length >= inteiro(cfg["espacos"])) {
    const consolo = inteiro(cfg["tipos"][tipo]["ouro"][0]);
    ganhar(s, consolo, 0);
    return { id: "", tipo, cheio: true, ouro: consolo };
  }
  const id = novo_id(s.estado, "b");
  esp.push({ id, tipo, abre_em: 0 });
  return { id, tipo, cheio: false, ouro: 0 };
}

export function comecar_abrir(s: Servico, id: string): Resultado {
  const b = bau_ref(s, id);
  if (b === null) return erro("bau_inexistente");
  if (inteiro(b["abre_em"]) > 0) return erro("bau_ja_abrindo");
  if (Object.keys(bau_abrindo(s)).length > 0) return erro("outro_bau_abrindo");
  b["abre_em"] = s.agora() + Math.max(duracao_timer(s, inteiro(cfg_baus(s)["tipos"][b["tipo"]]["segundos"])), 1);
  return concluir();
}

/** Abre um baú pronto, ou na hora gastando uma chave. Entrega ouro, fragmentos e peças. */
export function abrir_bau(s: Servico, id: string, com_chave = false): Resultado {
  const b = bau_ref(s, id);
  if (b === null) return erro("bau_inexistente");
  if (com_chave) {
    if (chaves(s) <= 0) return erro("sem_chave");
  } else if (!bau_pronto(s, id)) {
    return erro("bau_fechado");
  }
  const cfg = cfg_baus(s);
  const modelos = s.bal("itens")["modelos"];
  const possui: string[] = s.estado["inventario"]["itens"].map((it: Dados) => it["modelo"]);
  const bs = s.estado["baus"];
  const r = Bau.abrir(b["tipo"], cfg, modelos, possui, inteiro(bs["garantia"]), inteiro(bs["semente"]) + inteiro(bs["abertos"]));
  if (com_chave) bs["chaves"] = chaves(s) - 1;
  bs["garantia"] = r.garantia;
  bs["abertos"] = inteiro(bs["abertos"]) + 1;
  const ix = (bs["espacos"] as Dados[]).indexOf(b);
  if (ix >= 0) bs["espacos"].splice(ix, 1);
  s.estado["inventario"]["materiais"]["fragmentos"] = fragmentos(s) + r.fragmentos;
  const itens: Dados[] = [];
  for (const it of r.itens) {
    const novo: Dados = { ...it, id: "" };
    if (!it.repetida) {
      novo["id"] = novo_id(s.estado, "i");
      s.estado["inventario"]["itens"].push({ id: novo["id"], modelo: it.modelo, nivel: 0, durabilidade: inteiro(modelos[it.modelo]["durabilidade_max"]) });
      _evento(s, "peca_nova");
    }
    itens.push(novo);
  }
  _evento(s, "bau_aberto");
  ganhar(s, r.ouro, 0);
  return { ...concluir(), tipo: b["tipo"], ouro: r.ouro, fragmentos: r.fragmentos, itens };
}

/** Sorteio do serviço (baú de madeira por vitória): semente do save + contador. */
export function sorteio_milesimos(s: Servico, chance: number): boolean {
  return new Aleatorio(semente_servico(s)).chance_milesimos(chance);
}

// ------------------------------------------------------- tempo e tutorial

/** Duração real de um timer: no primeiro dia tudo termina em segundos; o VIP reduz. */
export function duracao_timer(s: Servico, segundos: number): number {
  const pd = s.bal("inicio")["primeiro_dia"];
  if (s.agora() - inteiro(s.estado["criado_em"] ?? 0) < inteiro(pd["duracao_s"])) return Math.min(segundos, inteiro(pd["timer_max_s"]));
  if (vip_ativo(s)) return div(segundos * (100 - inteiro(s.bal("economia")["vip"]["timer_reducao_pct"])), 100);
  return segundos;
}

export const TUTORIAL_CONCLUIDO = 6;

export function definir_passo_tutorial(s: Servico, passo: number): Resultado {
  s.estado["tutorial"]["passo"] = clampi(passo, 0, TUTORIAL_CONCLUIDO);
  if (passo >= TUTORIAL_CONCLUIDO) s.estado["tutorial"]["concluido"] = true;
  return concluir();
}

/** Recompensa do tutorial (uma vez só): ouro, XP até o nível 2 e a peça do primeiro baú, equipada. */
export function recompensa_tutorial(s: Servico): Resultado {
  const t = s.estado["tutorial"];
  if (t["recompensa_dada"] ?? false) return { ok: true, erro: "", item: t["item_bau"] ?? "", modelo: "", niveis: [] };
  const cfg = s.bal("inicio")["tutorial"];
  const modelo: string = cfg["item_bau"];
  const modelos = s.bal("itens")["modelos"];
  const maximo = inteiro(modelos[modelo]["durabilidade_max"]);
  const id = novo_id(s.estado, "i");
  s.estado["inventario"]["itens"].push({ id, modelo, nivel: 0, durabilidade: maximo });
  s.estado["equipamento"][modelos[modelo]["espaco"]] = id;
  const niveis = ganhar(s, inteiro(cfg["ouro"]), inteiro(cfg["xp"]));
  t["recompensa_dada"] = true;
  t["item_bau"] = id;
  return { ...concluir(), item: id, modelo, niveis };
}

// ------------------------------------------------------------ configuração

export function definir_config(s: Servico, chave: string, valor: unknown): Resultado {
  const a = s.bal("acessibilidade");
  if (!tem(a["padrao"], chave)) return erro("opcao_inexistente");
  if (chave === "texto" && !tem(a["tamanhos_texto"], String(valor))) return erro("opcao_invalida");
  if (chave === "idioma" && !(a["idiomas"] as string[]).includes(String(valor))) return erro("opcao_invalida");
  if (chave.startsWith("volume_") && !(Number.isInteger(valor) && (valor as number) >= 0 && (valor as number) <= 100)) {
    return erro("opcao_invalida");
  }
  if (!tem(s.estado, "config")) s.estado["config"] = { notificacoes: {} };
  s.estado["config"][chave] = valor;
  return concluir();
}

export function definir_notificacao(s: Servico, tipo: string, ligada: boolean): Resultado {
  if (!tem(s.estado, "config")) s.estado["config"] = { notificacoes: {} };
  s.estado["config"]["notificacoes"][tipo] = ligada;
  return concluir();
}
