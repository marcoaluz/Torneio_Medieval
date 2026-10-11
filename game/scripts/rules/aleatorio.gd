class_name Aleatorio
extends RefCounted
## Gerador pseudoaleatório da regra da justa: xorshift32 com semente
## explícita. É o mesmo algoritmo na versão TypeScript (Parte 3), por isso
## não usa o RandomNumberGenerator do Godot. Vetores de teste em
## tests/shared/aleatorio.json.

const MASCARA := 0xFFFFFFFF
## Semente 0 trava o xorshift; troca por esta.
const SEMENTE_ZERO := 0x9E3779B9

var estado: int

func _init(semente: int) -> void:
	estado = semente & MASCARA
	if estado == 0:
		estado = SEMENTE_ZERO

## Próximo inteiro sem sinal de 32 bits.
func proximo() -> int:
	var x := estado
	x = (x ^ (x << 13)) & MASCARA
	x = x ^ (x >> 17)
	x = (x ^ (x << 5)) & MASCARA
	estado = x
	return x

## Inteiro em [minimo, maximo], inclusive.
func inteiro(minimo: int, maximo: int) -> int:
	if maximo <= minimo:
		return minimo
	return minimo + proximo() % (maximo - minimo + 1)

## Sorteio com chance em milésimos (0..1000): true com probabilidade chance/1000.
func chance_milesimos(chance: int) -> bool:
	return proximo() % 1000 < chance
