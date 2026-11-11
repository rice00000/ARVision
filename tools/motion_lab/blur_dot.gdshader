shader_type spatial;
// One dot of the motion lab's trial block (Nov 10). A flat disc on a quad facing the viewer.
// Stimulus-only blur: the disc edge follows a Gaussian profile, alpha = Phi((r - d) / sigma),
// using the logistic approximation Phi(x) ~ 1 / (1 + exp(-1.702 x)). Exact for sigma much
// smaller than the dot radius; it underestimates the spread as sigma approaches the radius.
// sigma = 0 draws a sharp, antialiased disc. This blurs the dots only, never the UI.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 dot_color : source_color = vec3(0.75, 0.95, 1.0);
uniform float radius_m = 0.02;
uniform float sigma_m = 0.0;
uniform float half_extent_m = 0.02;

void fragment() {
	float d = length((UV - 0.5) * 2.0 * half_extent_m);
	float a;
	if (sigma_m <= 0.000001) {
		float aa = max(fwidth(d), 0.0001);
		a = 1.0 - smoothstep(radius_m - aa, radius_m + aa, d);
	} else {
		a = 1.0 / (1.0 + exp(1.702 * (d - radius_m) / sigma_m));
	}
	ALBEDO = dot_color;
	ALPHA = a;
}
