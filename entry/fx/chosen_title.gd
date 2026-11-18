class_name ChosenTitle
extends Node3D
## The chosen game's name over its bubble (Megan, Nov 18): chunky retro letters (Luckiest Guy), cream with a
## thick dark outline and a hard drop shadow, flared a little (wider at the top, ~15 %, like a retro title).
## It pops in (~0.2 s) with a short chime, holds still to be read (~1.3 s), then fades (~0.4 s). Nothing in it
## moves while it is up. Big and high-contrast for low vision; the name is also spoken (the sound label).

const FONT := preload("res://entry/assets/fonts/luckiest_guy.woff2")
const CREAM := Color(0.97, 0.93, 0.82)
const INK := Color(0.10, 0.09, 0.09)
const FLARE := 0.15
const HEIGHT := 0.065            # metres: the letters' height in the world (about 3x the subtitles)
const MAX_WIDTH := 0.26         # metres: about the menu's arc
const FONT_SIZE := 96
const IN_SECONDS := 0.2
const HOLD_SECONDS := 1.3
const OUT_SECONDS := 0.4

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled;
uniform sampler2D text_texture : source_color, filter_linear_mipmap;
uniform float flare = 0.15;
uniform float fade = 1.0;
void fragment() {
	// Each row is drawn narrower toward the bottom: the widest (top) row fills the quad.
	float k = 1.0 - flare * UV.y;
	vec2 at = vec2((UV.x - 0.5) / k + 0.5, UV.y);
	vec4 c = texture(text_texture, at);
	float inside = step(0.0, at.x) * step(at.x, 1.0);
	ALBEDO = c.rgb;
	ALPHA = c.a * inside * fade;
}
"""

static var _shader: Shader

var text := ""
var _material: ShaderMaterial
var _sounds: Sounds


## Shows [param name] over [param at] (the top of the chosen bubble), facing [param eye], under [param parent].
## Frees itself when done.
static func show_over(parent: Node, name: String, at: Vector3, eye: Vector3) -> ChosenTitle:
	var title := ChosenTitle.new()
	title.name = "chosen_title"
	title.text = name
	parent.add_child(title)
	title.global_position = at
	title.look_at(eye, Vector3.UP, true)   # square to the child's eyes (from above it would read squashed)
	title._build()
	title._play()
	return title


func _build() -> void:
	var outline := FONT_SIZE / 5
	var shadow := FONT_SIZE / 14
	var size := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var pad := outline + shadow + 8
	var view := SubViewport.new()
	view.name = "letters"
	view.transparent_bg = true
	view.disable_3d = true
	view.size = Vector2i(ceili(size.x) + pad * 2, ceili(size.y) + pad * 2)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var label := Label.new()
	label.text = text
	label.add_theme_font_override(&"font", FONT)
	label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	label.add_theme_color_override(&"font_color", CREAM)
	label.add_theme_color_override(&"font_outline_color", INK)
	label.add_theme_constant_override(&"outline_size", outline)
	label.add_theme_color_override(&"font_shadow_color", INK)
	label.add_theme_constant_override(&"shadow_offset_x", shadow)
	label.add_theme_constant_override(&"shadow_offset_y", shadow)
	label.add_theme_constant_override(&"shadow_outline_size", outline)
	label.position = Vector2(pad, pad)
	view.add_child(label)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = _shader
	_material.set_shader_parameter(&"text_texture", view.get_texture())
	_material.set_shader_parameter(&"flare", FLARE)
	_material.set_shader_parameter(&"fade", 0.0)
	var quad := QuadMesh.new()
	var aspect := float(view.size.x) / float(view.size.y)
	var tall := minf(HEIGHT, MAX_WIDTH / aspect)   # a long name gets smaller letters, never wider than MAX_WIDTH
	quad.size = Vector2(tall * aspect, tall)
	quad.center_offset = Vector3(0.0, tall * 0.5, 0.0)   # standing on [param at]
	var card := MeshInstance3D.new()
	card.name = "card"
	card.mesh = quad
	card.material_override = _material
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(card)


func _play() -> void:
	_sounds = Sounds.new()
	add_child(_sounds)
	_sounds.play(&"chosen_chime", global_position)
	scale = Vector3.ONE * 0.6
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(self, "scale", Vector3.ONE, IN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)   # no overshoot
	tween.tween_method(_fade, 0.0, 1.0, IN_SECONDS)
	tween.chain().tween_interval(HOLD_SECONDS)
	tween.chain().tween_method(_fade, 1.0, 0.0, OUT_SECONDS)
	tween.chain().tween_callback(queue_free)


func _fade(amount: float) -> void:
	_material.set_shader_parameter(&"fade", amount)
