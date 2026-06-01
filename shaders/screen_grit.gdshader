shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float scanline_strength : hint_range(0.0, 0.4) = 0.08;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float noise_strength : hint_range(0.0, 0.2) = 0.025;
uniform float chromatic_aberration : hint_range(0.0, 0.01) = 0.0015;
uniform float posterize_levels : hint_range(2.0, 32.0) = 14.0;
uniform float contrast : hint_range(0.5, 2.0) = 1.08;
uniform float saturation : hint_range(0.0, 2.0) = 0.92;

float random(vec2 value) {
	return fract(sin(dot(value, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 apply_saturation(vec3 color, float amount) {
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	return mix(vec3(gray), color, amount);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered_uv = uv * 2.0 - 1.0;
	vec2 aberration_offset = centered_uv * chromatic_aberration;
	
	vec3 color;
	color.r = texture(screen_texture, uv + aberration_offset).r;
	color.g = texture(screen_texture, uv).g;
	color.b = texture(screen_texture, uv - aberration_offset).b;
	
	color = (color - 0.5) * contrast + 0.5;
	color = apply_saturation(color, saturation);
	color = floor(color * posterize_levels) / posterize_levels;
	
	float scanline = 1.0 - scanline_strength * (0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159));
	float vignette = 1.0 - vignette_strength * smoothstep(0.2, 1.15, dot(centered_uv, centered_uv));
	float noise = (random(FRAGCOORD.xy + TIME * 60.0) - 0.5) * noise_strength;
	
	color = color * scanline * vignette + noise;
	COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}
