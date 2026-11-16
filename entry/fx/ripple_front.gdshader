shader_type spatial;
// The reveal's front of light, drawn ON a surface (a PlaneMesh lying in the surface's frame:
// the table top, the scanned floor, a scanned wall). The front is where the distance from the
// socket equals `radius`: a soft band, a faint afterglow behind it, and the surface's own edges
// lit where the front touches them. Unshaded, alpha-blended, no depth write: a few ALU per pixel.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 origin;                     // the socket, world
uniform float radius = 0.0;              // the front, metres from origin
uniform float band = 0.09;               // half-width of the bright band, metres
uniform vec4 tint : source_color = vec4(1.0, 0.86, 0.55, 1.0);
uniform float strength = 0.35;           // the band's alpha at its peak (never above 0.35: no flash)
uniform float afterglow = 0.10;          // alpha just behind the front, fading inward
uniform float fade = 1.0;                // 1 = on, tweened to 0 at the end
uniform vec2 half_size = vec2(0.5);      // the plane's half extents (local X, Z)
uniform float edge_width = 0.03;         // lit border width, metres (0 = none)
uniform float edge_strength = 0.30;
uniform float far_from = 99.0;           // beyond this distance from origin the light gets fainter...
uniform float far_to = 100.0;            // ...down to far_alpha of itself at this distance
uniform float far_alpha = 0.5;
uniform float cap_y = 99.0;              // nothing above this world height (walls: hip height)
uniform bool has_hole = false;           // a rectangle left dark (the floor under the table)
uniform mat4 hole_inverse;               // world -> hole frame (its plane is local XZ)
uniform vec2 hole_half = vec2(0.0);

varying vec3 world_pos;
varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = distance(world_pos, origin);
	float behind = radius - d;   // > 0 inside the front
	float front = exp(-pow(behind / band, 2.0));
	float glow = behind > 0.0 ? afterglow * exp(-behind / 0.35) : 0.0;
	// The plane's border, lit where the (wider) front touches it.
	float inset = min(half_size.x - abs(local_pos.x), half_size.y - abs(local_pos.z));
	float border = edge_width > 0.0 ? 1.0 - smoothstep(0.0, edge_width, inset) : 0.0;
	float touch = exp(-pow(behind / (band * 3.0), 2.0)) + (behind > 0.0 ? 0.35 * exp(-behind / 0.6) : 0.0);
	float a = strength * front + glow + edge_strength * border * touch;
	a *= mix(1.0, far_alpha, smoothstep(far_from, far_to, d));
	a *= 1.0 - smoothstep(cap_y - 0.25, cap_y, world_pos.y);
	if (has_hole) {
		vec3 h = (hole_inverse * vec4(world_pos, 1.0)).xyz;
		vec2 out_by = abs(h.xz) - hole_half;
		a *= smoothstep(0.0, 0.06, max(out_by.x, out_by.y));
	}
	a = clamp(a * fade, 0.0, 0.45);
	if (a < 0.003) {
		discard;
	}
	ALBEDO = tint.rgb;
	ALPHA = a;
}
