shader_type canvas_item;
render_mode unshaded, blend_mix;

// Numeric data: deliberately no source_color conversion on this sampler.
uniform sampler2D coverage_texture : hint_default_transparent, filter_nearest, repeat_disable;
uniform vec4 outline_color : source_color = vec4(1.0);
uniform vec4 fill_color : source_color = vec4(1.0, 0.85, 0.4, 1.0);
uniform float outline_alpha = 1.0;
uniform float fill_alpha = 0.25;
uniform float glow_strength = 0.12;
uniform int mode = 1;
uniform bool ready = false;

void fragment() {
	vec4 coverage = ready ? texture(coverage_texture, UV) : vec4(0.0);
	float line_a = clamp(coverage.r * outline_alpha * outline_color.a, 0.0, 1.0);
	float glow_a = clamp(coverage.b * glow_strength * outline_alpha * outline_color.a, 0.0, 1.0);
	float outer_a = 1.0 - (1.0 - line_a) * (1.0 - glow_a);
	float inner_a = mode == 2 ? clamp(coverage.g * fill_alpha * fill_color.a, 0.0, 1.0) : 0.0;
	float result_a = outer_a + inner_a * (1.0 - outer_a);
	vec3 premultiplied = outline_color.rgb * outer_a + fill_color.rgb * inner_a * (1.0 - outer_a);
	COLOR = vec4(premultiplied / max(result_a, 0.000001), result_a);
}
