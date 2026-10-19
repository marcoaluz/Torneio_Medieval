// Formato dos argumentos de cada comando público. O cliente é hostil: nada
// chega nas funções de regra sem passar por aqui (tipo, tamanho, chaves
// perigosas). Letras: s texto, n inteiro, b booleano, a lista, o objeto,
// x qualquer escalar; sufixo ? = opcional (só no fim).

// deno-lint-ignore no-explicit-any
type Dados = Record<string, any>;

export const ESQUEMA: Record<string, string> = {
  criar_personagem: "o",
  definir_brasao: "o",
  equipar: "s",
  definir_visual: "ss",
  usar_peca_trofeu: "ss",
  equipar_habilidades: "a",
  melhorar_predio: "s",
  concluir_timer: "s",
  treinar_cavaleiro: "s",
  treinar_cavalo: "ss",
  usar_cavalo: "s",
  consertar: "s",
  forjar: "s",
  melhorar_peca: "s",
  fundir: "sn",
  resgatar_missao: "s",
  resgatar_login: "",
  definir_titulo: "s",
  comecar_abrir: "s",
  abrir_bau: "sb?",
  comprar_com_gemas: "s",
  usar_cosmetico: "s",
  pular_com_gemas: "s",
  resgatar_passe: "ns",
  marcar_oferta_vista: "s",
  recompensa_anuncio: "sss",
  marcar_cena_vista: "s",
  definir_passo_tutorial: "n",
  recompensa_tutorial: "",
  definir_config: "sx",
  definir_notificacao: "sb",
  disputa_automatica: "sn",
  iniciar_disputa: "sn",
  iniciar_revanche: "s",
  concluir_disputa_conferida: "a",
  abandonar_disputa: "",
  salvar_defesa: "",
  procurar_adversario: "",
  concluir_pvp_conferido: "a",
  comprar_recibo: "sss",
  criar_ordem: "sos",
  entrar_ordem: "s",
  sair_ordem: "",
  dissolver_ordem: "",
  agir_sobre_membro: "ss",
  passar_lideranca: "s",
  editar_ordem: "so",
  pedir_ajuda: "s",
  ajudar_pedido: "s",
  doar: "ssn",
  torneio_semana: "",
  resgatar_torneio: "",
  comprar_da_ordem: "s",
  chat_enviar: "ssss",
  adicionar_amigo_por_codigo: "s",
  remover_amigo: "s",
};

const PERIGOSAS = ["__proto__", "constructor", "prototype"];

/** Confere um valor (texto curto, profundidade e tamanho limitados, sem chaves perigosas). */
function valor_seguro(v: unknown, limites: Dados, profundidade = 0): boolean {
  if (profundidade > limites["profundidade_max"]) return false;
  if (typeof v === "string") return v.length <= limites["texto_max"];
  if (typeof v === "number") return Number.isFinite(v);
  if (typeof v === "boolean" || v === null) return true;
  if (Array.isArray(v)) {
    return v.length <= Math.max(limites["lista_max"], 400) && v.every((x) => valor_seguro(x, limites, profundidade + 1));
  }
  if (typeof v === "object") {
    const chaves = Object.keys(v as Dados);
    if (chaves.length > limites["lista_max"]) return false;
    return chaves.every((k) => !PERIGOSAS.includes(k) && k.length <= 60 && valor_seguro((v as Dados)[k], limites, profundidade + 1));
  }
  return false;
}

/** "" se os argumentos servem para o comando; senão o código do erro. */
export function validar_argumentos(tipo: string, args: unknown, limites: Dados): string {
  const forma = ESQUEMA[tipo];
  if (forma === undefined) return "comando_inexistente";
  if (!Array.isArray(args)) return "argumentos_invalidos";
  const letras = forma.replaceAll("?", "");
  const obrigatorios = forma.split("?")[0].length - (forma.includes("?") ? 1 : 0);
  if (args.length < obrigatorios || args.length > letras.length) return "argumentos_invalidos";
  if (!valor_seguro(args, limites)) return "argumentos_invalidos";
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    switch (letras[i]) {
      case "s": if (typeof a !== "string") return "argumentos_invalidos"; break;
      case "n": if (!Number.isInteger(a)) return "argumentos_invalidos"; break;
      case "b": if (typeof a !== "boolean") return "argumentos_invalidos"; break;
      case "a": if (!Array.isArray(a)) return "argumentos_invalidos"; break;
      case "o": if (typeof a !== "object" || a === null || Array.isArray(a)) return "argumentos_invalidos"; break;
      case "x": if (typeof a === "object" && a !== null) return "argumentos_invalidos"; break;
    }
  }
  return "";
}
