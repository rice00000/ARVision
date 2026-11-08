// The hole behind the wall pieces: the pieces' own outline, no rim. Darker just
// inside the edge (COLOR.r runs 1 at the centre to 0 at the edge), so it reads deep.
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform bool space = false;
uniform float opacity = 1.0;

void fragment() {
	float depth = mix(0.45, 1.0, smoothstep(0.0, 0.3, COLOR.r));
	vec3 colour = vec3(0.12, 0.10, 0.08);
	if (space) {
		colour = mix(vec3(0.025, 0.018, 0.08), vec3(0.17, 0.07, 0.28), COLOR.r);
		vec2 cell = floor(UV * 40.0);
		float star = step(0.984, fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453));
		star *= 1.0 - smoothstep(0.06, 0.13, length(fract(UV * 40.0) - 0.5));
		colour += vec3(0.8, 0.8, 0.65) * star;
	}
	ALBEDO = colour * depth;
	ALPHA = opacity * (space ? 1.0 : 0.85);
}
