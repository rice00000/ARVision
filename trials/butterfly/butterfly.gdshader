shader_type spatial;
// Every butterfly of a ButterflySwarm in one draw. Per instance (INSTANCE_CUSTOM):
// r = species index / 8, g = wing-beat phase / TAU, b = beats per second / 10.
// UV2.x: how much of the wing beat a vertex follows (-1 left wing, 0 body, 1 right wing).
// The wings hinge on the body's axis (Z) and beat in the vertex stage. The skin
// is a monarch's; other species turn its orange to their own colour, leaving the
// black veins and white spots as they are.
render_mode cull_disabled, unshaded, depth_draw_opaque;

uniform sampler2D skin : source_color, filter_linear_mipmap, repeat_disable;

const int SPECIES = 5;
// Per species, in ButterflySwarm.SPECIES order: hue turn, saturation and brightness scale.
const float HUE[SPECIES] = float[](0.0, 0.5, 0.07, 0.0, -0.12);
const float SATURATION[SPECIES] = float[](1.0, 1.0, 1.0, 0.25, 0.75);
const float VALUE[SPECIES] = float[](1.0, 0.95, 1.1, 1.1, 1.05);
const float WING_UP = 1.1;
const float WING_DOWN = -0.25;

varying flat int species;

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void vertex() {
	species = clamp(int(INSTANCE_CUSTOM.r * 8.0 + 0.5), 0, SPECIES - 1);
	float beat = TIME * INSTANCE_CUSTOM.b * 10.0 * TAU + INSTANCE_CUSTOM.g * TAU;
	float open = mix(WING_DOWN, WING_UP, 0.5 + 0.5 * sin(beat)) * UV2.x;
	float x = VERTEX.x;
	VERTEX.x = x * cos(open) - VERTEX.y * sin(open);
	VERTEX.y = x * sin(open) + VERTEX.y * cos(open);
}

void fragment() {
	vec4 texel = texture(skin, UV);
	vec3 hsv = rgb_to_hsv(texel.rgb);
	// Only the coloured scales change; black and white stay.
	float coloured = smoothstep(0.35, 0.6, hsv.y);
	vec3 turned = hsv_to_rgb(vec3(fract(hsv.x + HUE[species]), hsv.y * SATURATION[species], min(1.0, hsv.z * VALUE[species])));
	ALBEDO = mix(texel.rgb, turned, coloured);
	ALPHA = texel.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
