shader_type spatial;
render_mode unshaded, cull_disabled;
uniform bool space = false;
uniform float age = 0.0;
uniform float opacity = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float angle = atan(p.y, p.x);
	float edge = 0.86 + 0.025 * sin(angle * 13.0) + 0.025 * sin(angle * 7.0);
	float r = length(p);
	float grow = smoothstep(0.05, 0.40, age);
	if (r > edge * grow) discard;
	float rim = smoothstep(edge - 0.07, edge, r);
	vec3 colour = vec3(0.12, 0.10, 0.08);
	if (space) {
		colour = mix(vec3(0.025, 0.018, 0.08), vec3(0.17, 0.07, 0.28), 1.0 - r);
		vec2 cell = floor(UV * 40.0);
		float star = step(0.984, fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453));
		star *= 1.0 - smoothstep(0.06, 0.13, length(fract(UV * 40.0) - 0.5));
		colour += vec3(0.8, 0.8, 0.65) * star;
	}
	ALBEDO = mix(colour, vec3(0.65, 0.40, 0.12), rim);
	ALPHA = opacity * grow * (space ? 1.0 : 0.62);
}
