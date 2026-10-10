shader_type spatial;
// No ALPHA, screen texture, or emission: this stays in the opaque depth pass.
render_mode unshaded, depth_draw_opaque, cull_back, fog_disabled, shadows_disabled;
void fragment() {
	ALBEDO = vec3(0.0);
}
