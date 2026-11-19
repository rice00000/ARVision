shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 track_colour : source_color;
uniform vec4 fill_colour : source_color;

// Dimensions relative to the bubble's radius, with the arc centred at the bottom.
const float RADIUS = 0.82;
const float HALF_SWEEP = 0.55;
const float HALF_WIDTH = 0.06;

float arc_distance(vec2 point, float angle, float end_angle) {
	float nearest = clamp(angle, -HALF_SWEEP, end_angle);
	return length(point - RADIUS * vec2(sin(nearest), -cos(nearest)));
}

void fragment() {
	vec2 point = (UV - 0.5) * vec2(2.0, -2.0);
	if (point.y > -0.6) {
		discard;
	}
	float angle = atan(point.x, -point.y);
	if (arc_distance(point, angle, HALF_SWEEP) > HALF_WIDTH) {
		discard;
	}
	float fill = 0.0;
	if (progress > 0.0) {
		float end_angle = mix(-HALF_SWEEP, HALF_SWEEP, progress);
		fill = 1.0 - smoothstep(0.045, 0.055, arc_distance(point, angle, end_angle));
	}
	ALBEDO = mix(track_colour.rgb, fill_colour.rgb, fill);
}
