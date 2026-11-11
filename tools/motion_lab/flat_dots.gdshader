shader_type particles;
render_mode disable_velocity;

uniform vec3 flow_direction = vec3(1.0, 0.0, 0.0);
uniform float speed = 0.3;
uniform vec3 half_size = vec3(0.8, 0.5, 0.0);
uniform int dot_count = 200;
uniform int signal_count = 180;
uniform uint trial_seed = 42u;
uniform float dot_lifetime = 0.8;
// Trial block (Nov 9): optional circular aperture. Off = the original rectangle, unchanged.
uniform bool circular = false;
uniform float aperture_radius = 0.2;

uint hash_value(uint value) {
	value = (value ^ (value >> 16u)) * 2246822519u;
	value = (value ^ (value >> 13u)) * 3266489917u;
	return value ^ (value >> 16u);
}
float random_value(uint value) {
	return float(hash_value(value) & 16777215u) / 16777216.0;
}
vec3 random_position(uint seed) {
	if (circular) {   // uniform over the disc
		float r = max(aperture_radius, 0.01) * sqrt(random_value(seed));
		float a = random_value(seed + 1u) * TAU;
		return vec3(r * cos(a), r * sin(a), 0.0);
	}
	return vec3((vec2(random_value(seed), random_value(seed + 1u)) * 2.0 - 1.0)
		* max(half_size.xy, vec2(0.01)), 0.0);
}
vec3 random_direction(uint seed) {
	float angle = random_value(seed + 1u) * TAU;
	return vec3(cos(angle), sin(angle), 0.0);
}
void start() {
	uint seed = hash_value(NUMBER + trial_seed * 1013u);
	TRANSFORM = mat4(1.0);
	TRANSFORM[3].xyz = random_position(seed);
	CUSTOM.xyz = random_direction(seed + 3u);
	CUSTOM.w = random_value(seed + 5u);
	USERDATA1.x = 0.0;
	COLOR = vec4(1.0);
}
void process() {
	uint dots = uint(max(dot_count, 1));
	uint rank = (INDEX + trial_seed % dots) % dots;
	vec3 direction = int(rank) < signal_count ? flow_direction : CUSTOM.xyz;
	vec3 position = TRANSFORM[3].xyz + direction * speed * DELTA;
	CUSTOM.w += DELTA / max(dot_lifetime, 0.05);
	if (CUSTOM.w >= 1.0) {
		CUSTOM.w = fract(CUSTOM.w);
		USERDATA1.x += 1.0;
		uint seed = hash_value(NUMBER + trial_seed + uint(USERDATA1.x) * 7919u);
		position = random_position(seed);
		CUSTOM.xyz = random_direction(seed + 3u);
	}
	if (circular) {   // leaving the circle: re-enter at the opposite edge
		float r = max(aperture_radius, 0.01);
		float out_by = length(position.xy);
		if (out_by > r) {
			position.xy = -position.xy / out_by * (2.0 * r - out_by);
		}
		TRANSFORM[3].xyz = vec3(position.xy, 0.0);
	} else {
		vec2 bounds = max(half_size.xy, vec2(0.01));
		TRANSFORM[3].xyz = vec3(mod(position.xy + bounds, bounds * 2.0) - bounds, 0.0);
	}
}
