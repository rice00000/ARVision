shader_type particles;
render_mode disable_velocity;
// 3D random-dot motion. The trial sets the uniforms once per round; every dot
// has the same look and speed, only its direction differs. Authored by Megan
// (Mgharv) for XRVision, ported here.

uniform vec3 flow_direction = vec3(1.0, 0.0, 0.0); // the answer, in cloud space; keep nonzero
uniform float speed : hint_range(0.01, 2.0) = 0.3;
uniform bool competing_flow = false; // noise dots all go the opposite way instead of every which way
uniform vec3 half_size = vec3(0.8, 0.5, 0.8); // where every dot is fully lit
uniform float margin = 0.12; // a shell outside half_size where dots fade in and out, each at its own depth
uniform int dot_count = 200;
uniform int signal_count = 140; // exactly this many dots follow flow_direction
uniform uint trial_seed = 1u;
uniform float dot_lifetime = 0.8; // seconds before a dot jumps to a new place (and noise dots to a new direction)
uniform float fade_seconds = 0.08; // a dot fades out before its jump and in after it

uniform float alignment : hint_range(0.0, 1.0) = 0.0; // success: every dot joins the flow, stretched into streaks
uniform float flight_progress = -1.0;
uniform vec3 flight_target = vec3(0.0);
uniform vec3 flight_across = vec3(0.0);
uniform vec3 flight_up = vec3(0.0);

// Integer hashing avoids the precision problems of large sine-based seeds.
uint hash_value(uint value) {
	value = (value ^ (value >> 16u)) * 2246822519u;
	value = (value ^ (value >> 13u)) * 3266489917u;
	return value ^ (value >> 16u);
}
float random_value(uint value) {
	return float(hash_value(value) & 16777215u) / 16777216.0;
}
vec3 outer_bounds() {
	return max(half_size, vec3(0.01)) + margin;
}
vec3 random_position(uint seed) {
	return (vec3(random_value(seed), random_value(seed + 1u),
		random_value(seed + 2u)) * 2.0 - 1.0) * outer_bounds();
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
void orient_streak(inout mat4 pose, vec3 target, float stretch) {
	vec3 up = abs(target.y) > 0.95 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 side = normalize(cross(up, target));
	pose[0].xyz = side;
	pose[1].xyz = cross(target, side);
	pose[2].xyz = target * mix(1.0, 4.0, stretch);
}
void start() {
	uint seed = hash_value(NUMBER + trial_seed * 1013u);
	TRANSFORM = mat4(1.0);
	TRANSFORM[3].xyz = random_position(seed);
	CUSTOM.xyz = random_direction(seed + 3u);
	CUSTOM.w = random_value(seed + 5u); // stagger the first lifetime across the cloud
	USERDATA1.x = 0.0;
	USERDATA1.y = random_value(seed + 6u); // how deep into the shell this dot starts to fade
	USERDATA1.z = 0.0; // the flight hasn't captured this dot's position and opacity yet
	COLOR = vec4(1.0);
}
void process() {
	vec3 target = safe_direction(flow_direction);
	if (flight_progress >= 0.0) {
		if (USERDATA1.z < 0.5) {
			USERDATA2 = vec4(TRANSFORM[3].xyz, COLOR.a);
			USERDATA1.z = 1.0;
		}
		float t = flight_progress;
		// The curve starts along the sweep and bends into the fixed impact point.
		vec3 bend = target * 0.65;
		vec3 centre = mix(bend * t, mix(bend, flight_target, t), t);
		// Flatten the cloud into the opening's footprint while keeping dots across its whole face.
		vec2 square = USERDATA2.xy / outer_bounds().xy;
		vec2 disk = square * sqrt(1.0 - 0.5 * square.yx * square.yx);
		vec3 arrival = flight_across * disk.x + flight_up * disk.y;
		vec3 offset = mix(USERDATA2.xyz, arrival, smoothstep(0.0, 1.0, t));
		TRANSFORM[3].xyz = centre + offset;
		COLOR.a = mix(USERDATA2.w, 0.85, smoothstep(0.0, 0.25, t)) * (1.0 - smoothstep(0.88, 1.0, t));
		vec3 velocity = 2.0 * mix(bend, flight_target - bend, t) + (arrival - USERDATA2.xyz) * (6.0 * t * (1.0 - t));
		orient_streak(TRANSFORM, safe_direction(velocity), smoothstep(0.0, 0.3, t));
	} else {
		vec3 bounds = outer_bounds();
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
			USERDATA1.y = random_value(seed + 6u);
		}
		TRANSFORM[3].xyz = mod(position + bounds, bounds * 2.0) - bounds;
		// Dim through the shell, not cut at a plane: each dot fades over its own depth.
		vec3 inside = bounds - abs(TRANSFORM[3].xyz);
		float edge = smoothstep(0.0, margin * mix(0.35, 1.0, USERDATA1.y), min(inside.x, min(inside.y, inside.z)));
		float life = CUSTOM.w * dot_lifetime;
		float blink = smoothstep(0.0, fade_seconds, life) * smoothstep(0.0, fade_seconds, dot_lifetime - life);
		COLOR.a = edge * blink;
		// Stretch the dots into short wind streaks during success feedback.
		orient_streak(TRANSFORM, target, alignment);
	}
}
