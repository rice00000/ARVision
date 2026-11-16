shader_type spatial;
// Every butterfly of a ButterflySwarm in one draw. Per instance (INSTANCE_CUSTOM):
// r = species index / 8, g = wing-beat phase / TAU, b = beats per second / 10.
// UV2.x: side (-1 left wing, 0 body, 1 right wing).
// The wings hinge on the body's axis (Z) and beat in the vertex stage; the
// fragment stage draws a forewing and a hindwing lobe, the base colour shading
// into the tip colour, a dark rim with pale spots.
render_mode cull_disabled, unshaded, depth_draw_opaque;

const int SPECIES = 5;
// Base, tip, rim and spot colours of each species, in ButterflySwarm.SPECIES order.
const vec3 WING_BASE[SPECIES] = vec3[](vec3(1.0, 0.55, 0.1), vec3(0.1, 0.35, 0.95), vec3(1.0, 0.92, 0.25), vec3(0.98, 0.95, 0.75), vec3(0.95, 0.35, 0.6));
const vec3 WING_TIP[SPECIES] = vec3[](vec3(0.95, 0.38, 0.04), vec3(0.25, 0.75, 1.0), vec3(0.85, 0.95, 0.35), vec3(0.95, 0.88, 0.55), vec3(1.0, 0.65, 0.8));
const vec3 WING_RIM[SPECIES] = vec3[](vec3(0.08, 0.06, 0.05), vec3(0.05, 0.06, 0.12), vec3(0.55, 0.45, 0.1), vec3(0.06, 0.06, 0.06), vec3(0.25, 0.05, 0.15));
const vec3 WING_SPOT[SPECIES] = vec3[](vec3(1.0, 0.97, 0.9), vec3(0.85, 0.95, 1.0), vec3(1.0, 0.6, 0.2), vec3(0.3, 0.55, 1.0), vec3(1.0));
const float WING_UP = 1.1;
const float WING_DOWN = -0.25;
const vec3 BODY = vec3(0.1, 0.08, 0.07);
const float RIM_WIDTH = 0.16;

varying flat int species;
varying float body;

void vertex() {
	species = clamp(int(INSTANCE_CUSTOM.r * 8.0 + 0.5), 0, SPECIES - 1);
	float side = UV2.x;
	body = 1.0 - abs(side);
	float beat = TIME * INSTANCE_CUSTOM.b * 10.0 * TAU + INSTANCE_CUSTOM.g * TAU;
	float open = mix(WING_DOWN, WING_UP, 0.5 + 0.5 * sin(beat)) * side;
	float x = VERTEX.x;
	VERTEX.x = x * cos(open) - VERTEX.y * sin(open);
	VERTEX.y = x * sin(open) + VERTEX.y * cos(open);
}

float lobe(vec2 p, vec2 centre, vec2 radius, float tilt) {
	vec2 d = p - centre;
	float c = cos(tilt);
	float s = sin(tilt);
	d = vec2(c * d.x - s * d.y, s * d.x + c * d.y) / radius;
	return length(d);
}

void fragment() {
	if (body > 0.5) {
		ALBEDO = BODY;
	} else {
		vec2 p = UV;
		float fore = lobe(p, vec2(0.48, 0.3), vec2(0.52, 0.27), -0.35);
		float hind = lobe(p, vec2(0.33, 0.7), vec2(0.36, 0.28), 0.3);
		float inside = min(fore, hind);
		if (inside > 1.0) {
			discard;
		}
		vec3 colour = mix(WING_BASE[species], WING_TIP[species], smoothstep(0.1, 0.9, p.x));
		float edge = smoothstep(1.0 - RIM_WIDTH - 0.03, 1.0 - RIM_WIDTH, inside);
		colour = mix(colour, WING_RIM[species], edge);
		float along = atan(p.y - 0.5, p.x) * 9.0;
		float spot = smoothstep(0.35, 0.2, length(vec2(fract(along) - 0.5, (inside - (1.0 - RIM_WIDTH * 0.5)) * 9.0)));
		colour = mix(colour, WING_SPOT[species], spot * edge);
		colour *= mix(0.7, 1.0, smoothstep(0.0, 0.25, p.x));
		ALBEDO = colour;
	}
}
