// Auxiliares do porte: o mesmo comportamento das funções inteiras do GDScript.

/** Divisão inteira que trunca em direção ao zero (GDScript `a / b` com ints). */
export function div(a: number, b: number): number {
  return Math.trunc(a / b);
}

/** clampi do GDScript: abaixo do mínimo = mínimo; acima do máximo = máximo (o mínimo vence se min > max). */
export function clampi(v: number, minimo: number, maximo: number): number {
  return v < minimo ? minimo : (v > maximo ? maximo : v);
}

/** Chave própria do objeto (não a herdada de Object.prototype: "constructor", "toString"...). */
export function tem(obj: unknown, chave: string): boolean {
  return typeof obj === "object" && obj !== null && Object.hasOwn(obj, chave);
}

/** Cópia profunda de dados JSON. */
export function copiar<T>(v: T): T {
  return JSON.parse(JSON.stringify(v));
}

/** Inteiro de um valor lido do JSON (o Godot lê tudo como float). */
export function inteiro(v: unknown): number {
  return Math.trunc(Number(v));
}
