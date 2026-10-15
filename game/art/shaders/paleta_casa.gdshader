shader_type canvas_item;
// Troca de paleta das camadas do personagem (cores da casa).
// A camada vem em tons de cinza (ou colorida, com material original e máscara):
// o brilho vira um mapa de gradiente da cor do
// material (escuro = sombra, meio = a cor, claro = brilho). Onde houver
// máscara, R = cor principal, G = secundária, B = metal; o que sobrar usa o
// material padrão da camada. Material 0 ("original") não troca nada (cavalo
// já vem na pelagem certa).
// Índices de material: 0 original, 1 principal, 2 secundária, 3 metal,
// 4 neutro, 5 pele, 6 cabelo.

uniform vec4 cores[7];
uniform int material_padrao = 0;
uniform bool usa_mascara = false;
uniform sampler2D mascara : filter_nearest;
// Quanto o brilho clareia em direção ao branco (0 a 1).
uniform float brilho = 0.55;
// Quanto a sombra escurece (multiplicador da cor no preto).
uniform float sombra = 0.18;

vec3 rampa(vec3 cor, float l) {
	if (l < 0.5) {
		return mix(cor * sombra, cor, l * 2.0);
	}
	return mix(cor, mix(cor, vec3(1.0), brilho), (l - 0.5) * 2.0);
}

// No Godot 4 o COLOR do fragment já vem multiplicado pela textura: guardamos
// só a cor do vértice (modulate dos efeitos) para não multiplicar duas vezes.
varying vec4 cor_vertice;

void vertex() {
	cor_vertice = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (material_padrao == 0 && !usa_mascara) {
		COLOR = tex * cor_vertice;
	} else {
		// Brilho = o canal mais forte: no cinza é igual ao próprio cinza; na arte
		// colorida (tecido vermelho, aço) mantém a luz do desenho original.
		float l = max(tex.r, max(tex.g, tex.b));
		vec3 pesos = usa_mascara ? texture(mascara, UV).rgb : vec3(0.0);
		float resto = clamp(1.0 - pesos.r - pesos.g - pesos.b, 0.0, 1.0);
		vec3 base = material_padrao == 0 ? tex.rgb : rampa(cores[material_padrao].rgb, l);
		vec3 cor = rampa(cores[1].rgb, l) * pesos.r + rampa(cores[2].rgb, l) * pesos.g
			+ rampa(cores[3].rgb, l) * pesos.b + base * resto;
		COLOR = vec4(cor, tex.a) * cor_vertice;
	}
}
