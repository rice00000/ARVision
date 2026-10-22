shader_type spatial;
render_mode unshaded, depth_draw_never, shadows_disabled, fog_disabled;

// SimReality puts this on every mesh of the simulated room as an overlay. It
// re-grades what is already on screen the way Meta's passthrough filter grades
// the camera image. Virtual stimuli have no overlay, so they stay untouched, as
// on a Quest. Parameters are global so one View change reaches every mesh.

#include "res://reality/focus.gdshaderinc"

global uniform vec4 reality_filter; // brightness (-1..1), contrast, saturation, black & white
global uniform vec4 reality_edges;
global uniform vec4 reality_focus;
global uniform float reality_dim;

uniform sampler2D screen : hint_screen_texture, filter_nearest, repeat_disable;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float luma(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec3 gamma(vec2 uv) {
	return pow(max(textureLod(screen, uv, 0.0).rgb, vec3(0.0)), vec3(1.0 / 2.2));
}

void fragment() {
	vec3 color = gamma(SCREEN_UV);
	if (reality_filter.w > 0.5) {
		color = vec3(step(0.5, luma(color)));
	} else {
		color += reality_filter.x * 0.5;
		color = (color - 0.5) * reality_filter.y + 0.5;
		color = mix(vec3(luma(color)), color, reality_filter.z);
	}
	if (reality_edges.a > 0.0) {
		vec2 pixel = 1.0 / VIEWPORT_SIZE;
		float dx = luma(gamma(SCREEN_UV + vec2(pixel.x, 0.0))) - luma(gamma(SCREEN_UV - vec2(pixel.x, 0.0)));
		float dy = luma(gamma(SCREEN_UV + vec2(0.0, pixel.y))) - luma(gamma(SCREEN_UV - vec2(0.0, pixel.y)));
		color = mix(color, reality_edges.rgb, smoothstep(0.04, 0.15, length(vec2(dx, dy))) * reality_edges.a);
	}
	color *= 1.0 - reality_dim * (1.0 - focus_keep(reality_focus, CAMERA_POSITION_WORLD, world_position));
	ALBEDO = pow(clamp(color, 0.0, 1.0), vec3(2.2));
	ALPHA = 1.0;
}
