// Estado inicial de um jogador novo (porte de ServicoJogador.novo_estado).
// A semente dos sorteios do jogador é escolhida pelo servidor (aleatória), não
// derivada do horário como no cliente.

import { copiar, inteiro, novo_id, VERSAO } from "./base.ts";
import type { Dados } from "./base.ts";

export function metas_novas(): Dados {
  return {
    renome: 0, dia: -1, diarias: [], semana: -1, semanais: [], login: { dias: 0, ultimo_dia: -1 },
    contadores: {}, sequencia: 0, conquistas: [], titulos: [], titulo: "", novas: [],
  };
}

export function liga_nova(criado_em: number): Dados {
  return {
    pontos: 0, melhor: "", temporada: 1, temporada_inicio: criado_em, defesa: {}, defesas: [],
    partidas: [], ultima_simulacao: criado_em, buscas: 0, adversario: {}, campeonato: {},
  };
}

export function loja_nova(): Dados {
  return {
    vip_ate: 0, passe: { temporada: 1, premium: false, xp: 0, gratis: [], premium_resgatados: [] },
    compras: [], cosmeticos: [], frase: "", vitoria: "", compras_dia: { dia: -1 }, ofertas: [], ultima_oferta: {},
  };
}

export function social_novo(): Dados {
  return {
    codigo: "", ordem: {}, pedidos: [], ajudei: { balde: -1, ids: [] },
    doacoes: { dia: -1, unidades: 0, atendidos: [] }, ajuda_moeda: { dia: -1, moeda: 0 }, moeda: 0,
    torneio: { semana: -1, vitorias: 0, participou: false, pendente: {} }, loja: { semana: -1, compras: {} },
    chat: { ordem: [], global: [], ultimo_envio: 0, sim_ordem: 0, sim_global: 0, contador: 0 },
    bloqueados: [], denuncias: [], amigos: [],
  };
}

/** `semente`: inteiro de 31 bits (a do GDScript é hash(criado_em) & 0x7FFFFFFF). */
export function novo_estado(bal: (nome: string) => Dados, agora: number, semente: number): Dados {
  const ini = bal("inicio");
  const e: Dados = {
    versao: VERSAO,
    criado_em: agora,
    proximo_id: 1,
    cavaleiro: {
      nome: "", corpo: "masculino", rosto: "1", cabelo: "1", pele: "media", cor_cabelo: "castanho",
      nivel: inteiro(ini["cavaleiro"]["nivel"]), xp: inteiro(ini["cavaleiro"]["xp"]),
      atributos: copiar(ini["cavaleiro"]["atributos"]), habilidades: [ini["cavaleiro"]["habilidade"]],
    },
    casa: { nome: "", cores: { principal: "azul_real", secundaria: "ouro_velho", metal: "ferro" }, brasao: {} },
    cavalos: [],
    cavalo_ativo: "",
    inventario: { ouro: inteiro(ini["ouro"]), gemas: inteiro(ini["gemas"]), materiais: copiar(ini["materiais"]), itens: [], projetos: [] },
    equipamento: {},
    visual: {},
    visual_trofeu: {},
    vila: { predios: {} },
    timers: [],
    pve: { regiao: "feiras", torneios: {}, trofeus: {} },
    tutorial: { passo: 0, concluido: false },
  };
  e["inventario"]["materiais"]["fragmentos"] = inteiro(e["inventario"]["materiais"]["fragmentos"] ?? 0);
  e["baus"] = { espacos: [], garantia: 0, chaves: inteiro(ini["chaves"] ?? 0), abertos: 0, sorteios: 0, semente: semente & 0x7FFFFFFF };
  e["metas"] = metas_novas();
  e["historia"] = { vistas: [] };
  e["config"] = { notificacoes: {} };
  e["liga"] = liga_nova(agora);
  e["loja"] = loja_nova();
  e["anuncios"] = { dia: -1, usados: 0, timers: [], ultima_vitoria: {} };
  e["social"] = social_novo();
  const cid = novo_id(e, "c");
  e["cavalos"].push({
    id: cid, nome: "", pelagem: "alazao", atributos: copiar(ini["cavalo"]["atributos"]),
    folego: inteiro(bal("treino")["folego_cavalo"]["maximo"]), folego_em: e["criado_em"],
  });
  e["cavalo_ativo"] = cid;
  const modelos = bal("itens")["modelos"];
  const por_modelo: Record<string, string> = {};
  for (const m of ini["itens"] as string[]) {
    const id = novo_id(e, "i");
    e["inventario"]["itens"].push({ id, modelo: m, nivel: 0, durabilidade: inteiro(modelos[m]["durabilidade_max"]) });
    por_modelo[m] = id;
  }
  for (const m of ini["equipar"] as string[]) e["equipamento"][modelos[m]["espaco"]] = por_modelo[m];
  for (const p of Object.keys(ini["predios"])) e["vila"]["predios"][p] = { nivel: inteiro(ini["predios"][p]) };
  return e;
}
