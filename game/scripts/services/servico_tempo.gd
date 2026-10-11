class_name ServicoTempo
extends RefCounted
## Relógio dos timers do jogo. Todo timer é guardado como horário de término
## (segundos Unix) e a tela só mostra a contagem. Hoje usa o relógio do
## celular; na Parte 3 passa a usar o horário do servidor (mudar a hora do
## celular não acelera nada). Os testes adiantam o relógio com `deslocamento`.

static var deslocamento := 0

static func agora() -> int:
	return int(Time.get_unix_time_from_system()) + deslocamento

## Segundos que faltam (0 se já terminou).
static func restante(termina_em: int) -> int:
	return maxi(termina_em - agora(), 0)

static func pronto(termina_em: int) -> bool:
	return agora() >= termina_em
