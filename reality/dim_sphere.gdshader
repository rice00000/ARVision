shader_type spatial;
render_mode unshaded, depth_draw_never, shadows_disabled, fog_disabled;

// A sphere around the head that darkens the passthrough image, evenly or
// everywhere but the spotlight. Virtual objects are nearer, so they stay bright.

#include "res://reality/focus.gdshaderinc"

uniform float dim = 0.0;
uniform vec4 focus = vec4(0.0);

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = dim * (1.0 - focus_keep(focus, CAMERA_POSITION_WORLD, world_position));
}
