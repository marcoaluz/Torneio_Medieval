shader_type canvas_item;
// Clareia e satura a arte da vila para combinar com a arena da justa (clara,
// saturada, tudo legível). gama < 1 levanta as sombras; brilho multiplica;
// saturacao > 1 aviva as cores; tom mistura a cor numa direção (grama mais
// amarelada, como a da arena). Valores em game/data/vila/ambiente.json > paleta.
uniform float gama = 1.0;
uniform float brilho = 1.0;
uniform float saturacao = 1.0;
uniform vec3 tom : source_color = vec3(1.0);

void fragment() {
	vec3 c = pow(max(COLOR.rgb, vec3(0.0)), vec3(gama)) * brilho;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturacao) * tom;
	COLOR = vec4(clamp(c, 0.0, 1.0), COLOR.a);
}
