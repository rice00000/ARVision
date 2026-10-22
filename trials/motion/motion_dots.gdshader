shader_type particles;
render_mode disable_velocity;
// 3D random-dot motion. The trial sets the uniforms once per round; every dot
// has the same look and speed, only its direction differs. Authored by Megan
// (Mgharv) for XRVision, ported here.

uniform vec3 flow_direction = vec3(1.0, 0.0, 0.0); // the answer, in cloud space; keep nonzero
uniform float speed : hint_range(0.01, 2.0) = 0.3;
uniform bool competing_flow = false; // noise dots all go the opposite way instead of every which way
uniform vec3 half_size = vec3(0.8, 0.5, 0.8);
uniform int dot_count = 200;
uniform int signal_count = 140; // exactly this many dots follow flow_direction
uniform uint trial_seed = 1u;
uniform float dot_lifetime = 0.8; // seconds before a dot jumps to a new place (and noise dots to a new direction)

uniform float alignment : hint_range(0.0, 1.0) = 0.0; // success: every dot joins the flow, stretched into streaks

// Integer hashing avoids the precision problems of large sine-based seeds.
uint hash_value(uint value) {
	value = (value ^ (value >> 16u)) * 2246822519u;
	value = (value ^ (value >> 13u)) * 3266489917u;
	return value ^ (value >> 16u);
}
float random_value(uint value) {
	return float(hash_value(value) & 16777215u) / 16777216.0;
}
vec3 random_position(uint seed) {
	return (vec3(random_value(seed), random_value(seed + 1u),
		random_value(seed + 2u)) * 2.0 - 1.0) * max(half_size, vec3(0.01));
}
// Uniform on the sphere.
vec3 random_direction(uint seed) {
	float z = random_value(seed) * 2.0 - 1.0;
	float angle = random_value(seed + 1u) * TAU;
	float radius = sqrt(max(0.0, 1.0 - z * z));
	return vec3(radius * cos(angle), radius * sin(angle), z);
}
vec3 safe_direction(vec3 value) {
	return length(value) > 0.0001 ? normalize(value) : vec3(1.0, 0.0, 0.0);
}
void start() {
	uint seed = hash_value(NUMBER + trial_seed * 1013u);
	TRANSFORM = mat4(1.0);
	TRANSFORM[3].xyz = random_position(seed);
	CUSTOM.xyz = random_direction(seed + 3u);
	CUSTOM.w = random_value(seed + 5u); // stagger the first lifetime across the cloud
	USERDATA1.x = 0.0;
	COLOR = vec4(1.0);
}
void process() {
	vec3 bounds = max(half_size, vec3(0.01));
	vec3 target = safe_direction(flow_direction);
	// A cyclic index shift gives an exact signal count without depth or colour cues.
	uint dots = uint(max(dot_count, 1));
	uint rank = (INDEX + trial_seed % dots) % dots;
	vec3 direction = target;
	if (int(rank) >= signal_count) {
		direction = competing_flow ? -target : CUSTOM.xyz;
	}
	// Noise joins the flow only after the answer has been given.
	VELOCITY = mix(direction, target, alignment) * speed;
	CUSTOM.w += DELTA / max(dot_lifetime, 0.05);
	vec3 position = TRANSFORM[3].xyz + VELOCITY * DELTA;
	if (CUSTOM.w >= 1.0) {
		CUSTOM.w = fract(CUSTOM.w);
		USERDATA1.x += 1.0;
		uint seed = hash_value(NUMBER + trial_seed + uint(USERDATA1.x) * 7919u);
		position = random_position(seed);
		CUSTOM.xyz = random_direction(seed + 3u);
	}
	TRANSFORM[3].xyz = mod(position + bounds, bounds * 2.0) - bounds;
	// Stretch the dots into short wind streaks during success feedback.
	vec3 up = abs(target.y) > 0.95 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 side = normalize(cross(up, target));
	TRANSFORM[0].xyz = side;
	TRANSFORM[1].xyz = cross(target, side);
	TRANSFORM[2].xyz = target * mix(1.0, 4.0, alignment);
}
