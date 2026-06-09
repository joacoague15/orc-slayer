// shaders/arena_fog.gdshader
// Niebla radial que cubre todo lo que está por fuera de la ronda del arena.
//
// Se aplica sobre un quad world-space centrado en el centro del arena. Adentro
// del arena la niebla es totalmente transparente (no molesta al jugador ni a
// los enemigos); desde el borde de la ronda hacia afuera se vuelve niebla
// oscura, con un borde "wispy" animado para dar atmósfera tétrica.
shader_type canvas_item;

uniform float fog_inner = 870.0;   // distancia (px de mundo) donde empieza la niebla
uniform float fog_outer = 1150.0;  // distancia donde la niebla es total
uniform float quad_size = 4000.0;  // tamaño del quad en px de mundo (para mapear UV -> mundo)
uniform vec4 fog_color : source_color = vec4(0.04, 0.05, 0.07, 1.0);
uniform float fog_max_alpha = 1.0;

uniform float noise_freq = 0.004;  // frecuencia del ruido (features de la niebla)
uniform float noise_speed = 14.0;  // velocidad de deriva de la niebla (px/s aprox)
uniform float edge_wobble = 1.0;   // cuánto desordena el ruido el borde (0..1 del feather)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * value_noise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	// Posición del fragmento relativa al centro del arena, en px de mundo.
	vec2 offset = (UV - 0.5) * quad_size;
	float dist = length(offset);

	// Ruido animado que desordena el borde de la niebla (deriva con el tiempo).
	float n = fbm(offset * noise_freq + vec2(TIME * noise_speed * noise_freq, TIME * noise_speed * noise_freq * 0.6));
	float feather = fog_outer - fog_inner;
	float wobble = (n - 0.5) * feather * edge_wobble;

	float a = smoothstep(fog_inner, fog_outer, dist + wobble) * fog_max_alpha;
	COLOR = vec4(fog_color.rgb, a);
}
