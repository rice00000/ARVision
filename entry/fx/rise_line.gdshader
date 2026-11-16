shader_type spatial;
// A thin, soft line of light at height `line_y` (world) on whatever it overlays: as `line_y`
// climbs, the object seems drawn up from the table by it. Used as material_overlay for 1-2 s.
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;

uniform float line_y = 0.0;
uniform float width = 0.012;
uniform vec4 tint : source_color = vec4(1.0, 0.9, 0.62, 1.0);
uniform float strength = 0.55;
uniform float fade = 1.0;

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float below = line_y - world_y;   // > 0: already drawn
	float a = strength * exp(-pow(below / width, 2.0));
	a += below > 0.0 ? 0.12 * exp(-below / 0.05) : 0.0;   // a little warmth just under the line
	a *= fade;
	if (a < 0.003) {
		discard;
	}
	ALBEDO = tint.rgb;
	ALPHA = min(a, 0.6);
}
