shader_type spatial;
render_mode unshaded, cull_back;
// A level's square card, cut to the circle inside its border (LevelPiece.drawn).
uniform sampler2D picture : source_color, filter_linear_mipmap;

void fragment() {
	vec2 from_middle = UV - 0.5;
	if (length(from_middle) > 0.5) {
		discard;
	}
	ALBEDO = texture(picture, 0.5 + from_middle * 0.93).rgb;
}
