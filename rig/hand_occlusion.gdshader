shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, shadow_to_opacity;

// Write depth and transparent colour together, revealing the real hand in passthrough.
void fragment() {
	ALBEDO = vec3(0.0);
}
