shader_type canvas_item;
// Clareia e satura a arte da vila para combinar com a arena da justa (clara,
// saturada, tudo legível). gama < 1 levanta as sombras; brilho multiplica;
// saturacao > 1 aviva as cores; tom mistura a cor numa direção (grama mais
// amarelada, como a da arena). Valores em game/data/vila/ambiente.json > paleta.
uniform float gama = 1.0;
uniform float brilho = 1.0;
uniform float saturacao = 1.0;
uniform vec3 tom : source_color = vec3(1.0);
// Telhado: telhas (pixels quentes, marrom-alaranjados, na parte de cima do
// quadro) puxados para a cor de um prédio, mantendo a luz e a sombra da arte.
uniform vec3 cor_telhado : source_color = vec3(1.0);
uniform float forca_telhado = 0.0;
uniform float y_telhado = 0.44;

void fragment() {
	vec3 c = pow(max(COLOR.rgb, vec3(0.0)), vec3(gama)) * brilho;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturacao) * tom;
	if (forca_telhado > 0.0 && UV.y < y_telhado) {
		float quente = step(1.12, c.r / max(c.g, 0.001)) * step(1.10, c.g / max(c.b, 0.001)) * step(0.14, l) * step(l, 0.85);
		float lum = dot(c, vec3(0.299, 0.587, 0.114));
		vec3 alvo = cor_telhado * clamp(lum * 1.7 + 0.12, 0.0, 1.25);
		c = mix(c, alvo, quente * forca_telhado);
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), COLOR.a);
}
