// Shared by the passthrough dim sphere and the simulated room's filter, so a
// spotlight covers the same part of the view on both: everything within the
// cone from the eye to a sphere of radius focus.w around focus.xyz is spared.
// Returns 1 inside the spotlight, 0 outside (and 0 when there is no focus).
float focus_keep(vec4 focus, vec3 eye, vec3 world_point) {
	if (focus.w <= 0.0) {
		return 0.0;
	}
	vec3 to_focus = focus.xyz - eye;
	float half_angle = atan(focus.w, length(to_focus));
	float angle = acos(clamp(dot(normalize(world_point - eye), normalize(to_focus)), -1.0, 1.0));
	return 1.0 - smoothstep(half_angle * 0.85, half_angle * 1.15, angle);
}
