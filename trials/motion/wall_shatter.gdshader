// Adapted from miwls, "simple glass broken" (CC0), Godot Shaders.
// Delay, gravity and rotation moved from screen reconstruction to real 3D
// Voronoi vertices. One mesh, no screen texture or per-piece physics.
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D picture : source_color, repeat_disable;
uniform bool has_picture = false;
uniform float age = 0.0;
uniform vec3 flow = vec3(1.0, 0.0, 0.0);
uniform vec3 gravity = vec3(0.0, -2.6, 0.0);
uniform vec2 size = vec2(2.4, 1.7);
varying float life;
varying float spread;

void vertex() {
	vec3 centre = vec3(CUSTOM0.xy, 0.0);
	float rnd = CUSTOM0.w;
	float delay = 0.24 + length(centre.xy / size) * 0.20 + rnd * 0.12;
	float t = max(0.0, age - delay);
	life = t;
	spread = smoothstep(0.0, 0.24, age);
	float a = (rnd - 0.5) * 3.5 * t;
	vec3 axis = normalize(vec3(rnd + 0.3, 0.5, 1.0 - rnd));
	vec3 p = VERTEX - centre;
	p *= 1.0 - 0.04 * smoothstep(0.0, 0.2, t);
	vec3 rotated = p * cos(a) + cross(axis, p) * sin(a) + axis * dot(axis, p) * (1.0 - cos(a));
	vec3 drift = vec3(centre.xy * 0.8, 0.3 + rnd * 0.2) + flow * 0.8;
	VERTEX = centre + rotated + drift * t + gravity * t * t * 0.5;
}

void fragment() {
	vec3 base = has_picture ? texture(picture, UV).rgb : vec3(0.72, 0.68, 0.59);
	float seam = (1.0 - smoothstep(0.0, 0.07, UV2.x)) * spread;
	ALBEDO = mix(base * COLOR.rgb, vec3(0.40, 0.25, 0.10), seam);
	EMISSION = vec3(0.26, 0.12, 0.025) * seam * (1.0 - smoothstep(0.0, 0.45, life));
	ALPHA = 1.0 - smoothstep(0.8, 1.5, life);
}
