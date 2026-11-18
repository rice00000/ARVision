shader_type spatial;
render_mode unshaded, cull_disabled;
// Turn to fit's shadow window (Megan, Nov 18, beat 1: a smooth shadow edge). The CV's 64 × 48 shapes come in
// as a small texture: R = the cup's live shadow, G = the card's shape (filled). On the GPU (nearly free):
// a small Gaussian blur rounds off the blocky pixels and drops stray specks, the 0.5 contour of the blur is
// the smooth edge, and the card's outline is a band of `line_width` texels around its contour. Edges are
// anti-aliased to one screen pixel, so they stay crisp at any distance.

uniform sampler2D mask : filter_linear, repeat_disable;
uniform vec3 background = vec3(0.10, 0.10, 0.12);
uniform vec3 shadow = vec3(0.80, 0.80, 0.80);
uniform vec3 line = vec3(0.95, 0.75, 0.20);
uniform float line_width = 1.0;   // half-width of the card outline, in shape pixels (texels)
uniform float blur = 1.0;         // spacing of the 5 × 5 blur taps, in texels (sigma ≈ this)

vec2 blurred(vec2 uv, vec2 texel) {
	const float w[5] = float[](1.0, 4.0, 6.0, 4.0, 1.0);
	vec2 sum = vec2(0.0);
	for (int i = 0; i < 5; i++) {
		for (int j = 0; j < 5; j++) {
			sum += texture(mask, uv + vec2(float(i - 2), float(j - 2)) * texel * blur).rg * w[i] * w[j];
		}
	}
	return sum / 256.0;
}

void fragment() {
	vec2 size = vec2(textureSize(mask, 0));
	vec2 m = blurred(UV, 1.0 / size);
	vec2 change = max(fwidth(m), vec2(1e-4));                    // per screen pixel
	vec2 dist = (m - 0.5) / change;                              // signed distance to each contour, screen px
	float px_per_texel = 1.0 / max(length(fwidth(UV) * size) * 0.7071, 1e-5);
	float fill = clamp(dist.x + 0.5, 0.0, 1.0);
	float outline = clamp(line_width * px_per_texel - abs(dist.y) + 0.5, 0.0, 1.0);
	vec3 colour = mix(background, shadow, fill);
	ALBEDO = mix(colour, line, outline);
}
