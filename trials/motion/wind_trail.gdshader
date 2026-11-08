// Adapted from dip, "Dynamic Wind Trail With Loops" (CC0), Godot Shaders.
// Kept: a thin tube bent by a travelling wave, a twist and a loop. Changed: the
// tube spans one sweep (local Y from where it set off to the hand), the loop
// winds around that path and closes at both ends, and it fades toward the tail.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform vec3 colour : source_color = vec3(1.0);
uniform float strength = 0.0;
uniform float time_scale = 9.0;
uniform float wave_amplitude = 0.012;
uniform float wave_frequency = 9.0;
uniform float twist_amplitude = 0.01;
uniform float twist_frequency = 14.0;
uniform float loop_radius = 0.035;
uniform float loop_count = 1.5;
// One material, several strands: each node sets its own.
instance uniform float extra_offset_time = 0.0;
instance uniform float extra_loop_radius = 0.0;
varying float along;

void vertex() {
	along = VERTEX.y + 0.5; // 0 where the sweep set off, 1 at the hand
	float t = TIME * time_scale + extra_offset_time;
	float open = sin(PI * along); // the wind leaves the path and rejoins it
	float angle = along * TAU * loop_count - t;
	vec3 loop = vec3(cos(angle), 0.0, sin(angle)) * (loop_radius + extra_loop_radius) * open;
	vec3 wave = vec3(sin(along * twist_frequency - t) * twist_amplitude, 0.0,
		sin(along * wave_frequency - t) * wave_amplitude) * open;
	VERTEX += loop + wave;
}

void fragment() {
	float soft = pow(abs(dot(NORMAL, VIEW)), 1.5); // tube edges thin out like air
	ALBEDO = colour;
	ALPHA = strength * soft * smoothstep(0.0, 0.7, along);
}
