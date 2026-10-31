shader_type spatial;
render_mode blend_mul, depth_draw_always, unshaded, cull_back, shadows_disabled, fog_disabled;

// The real hand's shape in passthrough. Where it is nearer than a virtual object,
// colour and alpha are multiplied to zero, so the passthrough (the real hand)
// shows; its depth then hides what is drawn behind it later. Where a virtual
// object is nearer, the depth test keeps it.
void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
