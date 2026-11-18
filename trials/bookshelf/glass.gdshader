shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

// Use the triangle's normal so the glass follows the facets of each imported mesh.
void fragment() {
	vec3 view = normalize(VIEW);
	vec3 normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(normal, view) < 0.0) {
		normal = -normal;
	}
	float edge = pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), 2.0);
	vec3 reflection = reflect(-view, normal);
	float sheen = smoothstep(0.80, 0.98, dot(reflection, normalize(vec3(-0.38, 0.61, 0.72))));
	float highlight = max(edge, sheen * 0.64);
	ALBEDO = vec3(mix(0.43, 0.96, highlight));
	ALPHA = mix(0.25, 0.66, highlight);
}
