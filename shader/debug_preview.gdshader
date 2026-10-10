shader_type canvas_item;
render_mode unshaded;

uniform sampler2D debug_texture : filter_nearest, repeat_disable;
uniform bool texture_ready = false;
uniform int preview_mode = 1;
uniform mat4 camera_inverse_projection;
uniform vec2 depth_range_m = vec2(1.0, 10.0);

void fragment() {
	vec3 result = vec3(0.025, 0.03, 0.04);
	if (texture_ready) {
		vec4 sample_value = texture(debug_texture, UV);
		if (preview_mode == 1) {
			// RGBA16F: display independent outline/fill/glow coverage in RGB.
			result = clamp(sample_value.rgb, vec3(0.0), vec3(1.0));
		} else if (sample_value.r > 0.0) {
			// Camera3D.get_camera_projection() uses CPU OpenGL NDC (-1..1).
			// Forward+ reverse-Z texture: 1 = near, 0 = far. Undo GPU depth
			// correction before multiplying the *camera's* inverse projection.
			vec3 ndc = vec3(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0, 1.0 - 2.0 * sample_value.r);
			vec4 view_position = camera_inverse_projection * vec4(ndc, 1.0);
			float meters = -view_position.z / view_position.w;
			float scaled = clamp((meters - depth_range_m.x) / max(0.01, depth_range_m.y - depth_range_m.x), 0.0, 1.0);
			result = mix(vec3(0.15, 0.8, 1.0), vec3(1.0, 0.45, 0.1), scaled);
		}
	}
	COLOR = vec4(result, 1.0);
}
