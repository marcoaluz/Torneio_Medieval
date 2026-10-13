// Gerador pseudoaleatório da regra da justa: xorshift32 com semente
// explícita. Porte de game/scripts/rules/aleatorio.gd; os vetores de teste
// estão em tests/shared/galope.json (campo "aleatorio").
//
// Convenções do porte (valem para todos os arquivos desta pasta):
//  - nomes iguais aos do GDScript (snake_case), para o código dos dois lados
//    ser comparável linha a linha;
//  - só inteiros; divisão inteira com Math.trunc (GDScript trunca em direção
//    ao zero); sem enum/namespace (Node roda TypeScript apagando os tipos);
//  - nada de Date.now(), Math.random() nem estado global.

export const MASCARA = 0xFFFFFFFF;
const SEMENTE_ZERO = 0x9E3779B9;

export class Aleatorio {
  estado: number;

  constructor(semente: number) {
    this.estado = semente >>> 0;
    if (this.estado === 0) this.estado = SEMENTE_ZERO;
  }

  /** Próximo inteiro sem sinal de 32 bits. */
  proximo(): number {
    let x = this.estado;
    x = (x ^ (x << 13)) >>> 0;
    x = (x ^ (x >>> 17)) >>> 0;
    x = (x ^ (x << 5)) >>> 0;
    this.estado = x;
    return x;
  }

  /** Inteiro em [minimo, maximo], inclusive. */
  inteiro(minimo: number, maximo: number): number {
    if (maximo <= minimo) return minimo;
    return minimo + (this.proximo() % (maximo - minimo + 1));
  }

  /** true com probabilidade chance/1000. */
  chance_milesimos(chance: number): boolean {
    return this.proximo() % 1000 < chance;
  }
}
