// Regra do impacto da justa (pura, determinística). Porte de
// game/scripts/rules/impacto.gd; casos em tests/shared/impacto.json.
//
// Ordem fixa dos sorteios (igual ao GDScript): golpe do jogador e depois o do
// rival; em cada um, (1) bloqueio da habilidade do defensor, se houver,
// (2) bloqueio do escudo, se ainda não bloqueou, (3) derrubada. Só inteiros;
// toda divisão é feita com números não negativos (trunca).

import type { Aleatorio } from "./aleatorio.ts";
import { clampi, div, tem } from "./util.ts";

// deno-lint-ignore no-explicit-any
type Cfg = Record<string, any>;
// deno-lint-ignore no-explicit-any
type Dados = Record<string, any>;

export const ERRO = "erro";

export function validar(cfg: Cfg): string {
  const grupos: Record<string, string[]> = {
    pontos: [],
    falta: ["zona", "penalidade_pontos", "faltas_para_desclassificar"],
    bloqueio: ["zonas", "vira_zona", "base_milesimos", "teto_milesimos"],
    derrubada: ["base_por_zona_milesimos", "forca_menos_equilibrio_milesimos", "velocidade_por_pct_milesimos",
      "ritmo_max_milesimos", "poder_lanca_milesimos", "defesa_peca_milesimos", "teto_milesimos"],
    dano: ["base_por_zona", "peca_por_zona", "velocidade_por_pct_milesimos", "defesa_reduz_por_ponto_milesimos",
      "minimo", "lanca_por_contato"],
    habilidades: [],
  };
  for (const g of Object.keys(grupos)) {
    const v = cfg[g];
    if (typeof v !== "object" || v === null || Array.isArray(v)) return `falta o grupo "${g}"`;
    for (const k of grupos[g]) {
      if (!(k in v)) return `falta "${g}.${k}"`;
    }
  }
  for (const k of ["teto_suave_joelho_pct", "habilidade_carga_ms"]) {
    if (!(k in cfg)) return `falta "${k}"`;
  }
  for (const z of ["capacete", "peito", "escudo", "cavalo", ERRO]) {
    if (!(z in cfg["pontos"])) return `falta "pontos.${z}"`;
  }
  for (const nome of Object.keys(cfg["habilidades"])) {
    for (const k of ["vence", "tipo", "derrubada_bonus_milesimos", "dano_bonus_pct", "bloqueio_milesimos"]) {
      if (!(k in cfg["habilidades"][nome])) return `falta "habilidades.${nome}.${k}"`;
    }
    if (!tem(cfg["habilidades"], familia(cfg, nome))) return `familia desconhecida em "habilidades.${nome}"`;
  }
  return "";
}

/** Teto suave: até `joelho_pct` do teto passa inteiro; acima, cada ponto rende menos. Negativo vira 0. */
export function suave(valor: number, teto: number, joelho_pct: number): number {
  if (valor <= 0 || teto <= 0) return 0;
  const joelho = div(teto * joelho_pct, 100);
  if (valor <= joelho) return valor;
  const excesso = valor - joelho;
  const resto = teto - joelho;
  if (resto <= 0) return teto;
  return joelho + div(excesso * resto, excesso + resto);
}

/** Atributo de uma peça equipada; 0 se a peça não existe ou está quebrada. */
export function stat(equipamento: unknown, peca: string, chave: string): number {
  if (!tem(equipamento, peca)) return 0;
  const p = (equipamento as Dados)[peca];
  if (Math.trunc(p["durabilidade"] ?? 0) <= 0) return 0;
  return Math.trunc(p[chave] ?? 0);
}

/** Precisão usada na Mira: a do cavaleiro mais a da lança. */
export function precisao_efetiva(lado: Dados): number {
  return Math.trunc(lado["cavaleiro"]["precisao"]) + stat(lado["equipamento"], "lanca", "precisao");
}

export function familia(cfg: Cfg, nome: string): string {
  return String(cfg["habilidades"][nome]["familia"] ?? nome);
}

function _ativas(cfg: Cfg, lado: Dados): string[] {
  let lista: unknown[] = [];
  if (Array.isArray(lado["habilidades"])) {
    lista = lado["habilidades"];
  } else if (typeof lado["habilidade"] === "object" && lado["habilidade"] !== null) {
    lista = [lado["habilidade"]];
  }
  const res: string[] = [];
  for (const h of lista) {
    const d = h as Dados;
    if (typeof h === "object" && h !== null && (d["ativa"] ?? false) && tem(cfg["habilidades"], String(d["nome"] ?? ""))) {
      res.push(String(d["nome"]));
    }
  }
  return res;
}

/** Habilidades em efeito para `lado`, na ordem dele: ativas e não anuladas pelas ativas do outro. */
export function habilidades_em_efeito(cfg: Cfg, lado: Dados, outro: Dados): string[] {
  const minhas = _ativas(cfg, lado);
  const dele = _ativas(cfg, outro);
  const res: string[] = [];
  for (const h of minhas) {
    let anulada = false;
    for (const o of dele) {
      if (cfg["habilidades"][o]["vence"] === familia(cfg, h)) anulada = true;
    }
    if (!anulada) res.push(h);
  }
  return res;
}

export function habilidade_em_efeito(cfg: Cfg, lado: Dados, outro: Dados): string {
  const hs = habilidades_em_efeito(cfg, lado, outro);
  return hs.length > 0 ? hs[0] : "";
}

export function resolver(cfg: Cfg, entrada: Dados, rng: Aleatorio): Dados {
  const j = entrada["jogador"];
  const r = entrada["rival"];
  const hj = habilidades_em_efeito(cfg, j, r);
  const hr = habilidades_em_efeito(cfg, r, j);
  const res_j = _golpe(cfg, j, r, hj, hr, rng);
  const res_r = _golpe(cfg, r, j, hr, hj, rng);
  return { jogador: res_j, rival: res_r };
}

function _soma(cfg: Cfg, hs: string[], chave: string): number {
  let t = 0;
  for (const h of hs) t += Math.trunc(cfg["habilidades"][h][chave] ?? 0);
  return t;
}

/** Golpe de `a` (com as habilidades `ha` em efeito) em `d` (com `hd`). */
function _golpe(cfg: Cfg, a: Dados, d: Dados, ha: string[], hd: string[], rng: Aleatorio): Dados {
  const zona: string = a["zona"] ?? ERRO;
  const r: Dados = {
    zona, zona_final: zona, bloqueado: false, bloqueio_por: "", falta: false,
    pontos: 0, chance_derrubar_milesimos: 0, derrubou: false, habilidade: ha.length > 0 ? ha[0] : "",
    habilidades: [...ha], habilidade_bloqueio: "", dano: {}, dano_lanca: 0,
  };
  if (zona === ERRO || !tem(cfg["pontos"], zona)) {
    r["zona"] = ERRO;
    r["zona_final"] = ERRO;
    return r;
  }
  const joelho = Math.trunc(cfg["teto_suave_joelho_pct"]);
  const equip_d = d["equipamento"];
  const equip_a = a["equipamento"];

  if (zona === cfg["falta"]["zona"]) {
    r["falta"] = true;
    r["pontos"] = -Math.trunc(cfg["falta"]["penalidade_pontos"]);
    _aplicar_dano(cfg, r, a, d, zona, []);
    return r;
  }

  // Bloqueio: primeiro a habilidade do defensor, depois o escudo.
  const b = cfg["bloqueio"];
  if ((b["zonas"] as string[]).includes(zona)) {
    let hb = "";
    for (const h of hd) {
      const bh = Math.trunc(cfg["habilidades"][h]["bloqueio_milesimos"]);
      if (bh > 0 && (hb === "" || bh > Math.trunc(cfg["habilidades"][hb]["bloqueio_milesimos"]))) hb = h;
    }
    if (hb !== "") {
      if (rng.chance_milesimos(Math.trunc(cfg["habilidades"][hb]["bloqueio_milesimos"]))) {
        r["bloqueado"] = true;
        r["bloqueio_por"] = "habilidade";
        r["habilidade_bloqueio"] = hb;
      }
    }
    if (!r["bloqueado"]) {
      const chance = suave(Math.trunc(b["base_milesimos"]) + stat(equip_d, "escudo", "bloqueio_milesimos"),
        Math.trunc(b["teto_milesimos"]), joelho);
      if (rng.chance_milesimos(chance)) {
        r["bloqueado"] = true;
        r["bloqueio_por"] = "escudo";
      }
    }
    if (r["bloqueado"]) r["zona_final"] = b["vira_zona"];
  }
  const zf: string = r["zona_final"];
  r["pontos"] = Math.trunc(cfg["pontos"][zf]);

  // Derrubada.
  const dr = cfg["derrubada"];
  if (tem(dr["base_por_zona_milesimos"], zf)) {
    const peca: string = cfg["dano"]["peca_por_zona"][zf] ?? "";
    const vel_pct = _velocidade_pct(a);
    let chance = Math.trunc(dr["base_por_zona_milesimos"][zf]);
    chance += (Math.trunc(a["cavaleiro"]["forca"]) - Math.trunc(d["cavaleiro"]["equilibrio"])) * Math.trunc(dr["forca_menos_equilibrio_milesimos"]);
    chance += (vel_pct - 100) * Math.trunc(dr["velocidade_por_pct_milesimos"]);
    chance += div(Math.trunc(dr["ritmo_max_milesimos"]) * clampi(Math.trunc(a["ritmo_milesimos"] ?? 0), 0, 1000), 1000);
    chance += stat(equip_a, "lanca", "poder") * Math.trunc(dr["poder_lanca_milesimos"]);
    chance -= stat(equip_d, peca, "defesa") * Math.trunc(dr["defesa_peca_milesimos"]);
    chance += _soma(cfg, ha, "derrubada_bonus_milesimos");
    chance += _soma(cfg, hd, "exposicao_milesimos"); // o defensor arriscou (golpe do campeão)
    chance -= _soma(cfg, hd, "derrubada_reducao_milesimos"); // o defensor segura melhor (fantasma do corcel)
    chance = suave(chance, Math.trunc(dr["teto_milesimos"]), joelho);
    r["chance_derrubar_milesimos"] = chance;
    r["derrubou"] = rng.chance_milesimos(chance);
  }

  _aplicar_dano(cfg, r, a, d, zf, ha);
  return r;
}

/** Velocidade no choque em % da nominal (100 = nominal). */
function _velocidade_pct(a: Dados): number {
  const nominal = Math.trunc(a["velocidade_nominal"] ?? 0);
  if (nominal <= 0) return 100;
  return div(Math.max(Math.trunc(a["velocidade"] ?? nominal), 0) * 100, nominal);
}

function _aplicar_dano(cfg: Cfg, r: Dados, a: Dados, d: Dados, zona: string, ha: string[]): void {
  const dn = cfg["dano"];
  if (!tem(dn["base_por_zona"], zona)) return;
  const peca: string = dn["peca_por_zona"][zona];
  const extra = Math.max(_velocidade_pct(a) - 100, 0);
  let dano = div(Math.trunc(dn["base_por_zona"][zona]) * (1000 + extra * Math.trunc(dn["velocidade_por_pct_milesimos"])), 1000);
  if (ha.length > 0) dano = div(dano * (100 + _soma(cfg, ha, "dano_bonus_pct")), 100);
  const reducao = div(stat(d["equipamento"], peca, "defesa") * Math.trunc(dn["defesa_reduz_por_ponto_milesimos"]), 1000);
  r["dano"] = { [peca]: Math.max(dano - reducao, Math.trunc(dn["minimo"])) };
  r["dano_lanca"] = Math.trunc(dn["lanca_por_contato"]);
}
