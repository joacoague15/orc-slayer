// shaders/spectral.gdshader
// Aspecto espectral del Warlord: espíritu orco.
// - Tinte etéreo verde-cian que respira
// - Rim glow donde el sprite se recorta contra el fondo
// - Ondulación sutil del cuerpo (UV) como humo
// - Transparencia parcial con shimmer
// Respeta `modulate` (los tintes rojo/dorado de los estados del boss se
// multiplican encima del efecto), capturándolo en vertex() porque en Godot 4
// canvas_item no expone MODULATE en fragment().
shader_type canvas_item;

uniform vec4 spectral_tint : source_color = vec4(0.4, 1.0, 0.78, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.5;
uniform float rim_strength : hint_range(0.0, 4.0) = 1.5;
uniform float alpha_base : hint_range(0.0, 1.0) = 0.86;
uniform float wave_amount : hint_range(0.0, 0.02) = 0.0035;
uniform float wave_speed : hint_range(0.0, 10.0) = 2.2;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	// Ondulación: el cuerpo "fluye" como humo, más marcada hacia arriba.
	vec2 uv = UV;
	uv.x += sin(TIME * wave_speed + UV.y * 9.0) * wave_amount * (1.0 - UV.y * 0.5);
	vec4 tex = texture(TEXTURE, uv);

	// Rim: borde detectado por la caída de alpha contra los vecinos.
	vec2 px = TEXTURE_PIXEL_SIZE * 4.0;
	float a_n = min(
		min(texture(TEXTURE, uv + vec2(px.x, 0.0)).a, texture(TEXTURE, uv - vec2(px.x, 0.0)).a),
		min(texture(TEXTURE, uv + vec2(0.0, px.y)).a, texture(TEXTURE, uv - vec2(0.0, px.y)).a));
	float rim = clamp(tex.a - a_n, 0.0, 1.0);

	float breath = 0.5 + 0.5 * sin(TIME * 1.8);
	vec3 col = mix(tex.rgb, tex.rgb * spectral_tint.rgb * 1.6 + spectral_tint.rgb * 0.15, tint_strength);
	col += spectral_tint.rgb * rim * rim_strength * (0.75 + 0.25 * breath);

	float shimmer = 0.93 + 0.07 * sin(TIME * 2.6 + uv.y * 5.0);
	COLOR = vec4(col, tex.a * alpha_base * shimmer) * v_modulate;
}
