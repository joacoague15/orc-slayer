shader_type canvas_item;
render_mode unshaded;

uniform float palette_levels : hint_range(2.0, 16.0) = 6.0;
uniform float contrast : hint_range(0.5, 2.0) = 1.08;
uniform float saturation : hint_range(0.0, 2.0) = 0.95;
uniform float shadow_tint : hint_range(0.0, 1.0) = 0.12;

vec3 apply_saturation(vec3 color, float amount) {
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	return mix(vec3(gray), color, amount);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 color = source.rgb;
	color = (color - 0.5) * contrast + 0.5;
	color = apply_saturation(color, saturation);
	color = floor(color * palette_levels + 0.5) / palette_levels;
	color = mix(color, color * vec3(0.82, 0.92, 0.78), shadow_tint);
	COLOR = vec4(clamp(color, 0.0, 1.0), source.a);
}
