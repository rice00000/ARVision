class_name HelloFx
extends Node3D
## Scene 1, Hello (Megan's scene review, Nov 17; built by the build chat because fx-2 had no HelloFx):
## * [method bubbles]: a few soft bubbles drift up out of the cauldron and fade when Onion pops up.
##   The look follows the Kenney Particle Pack's bubble (CC0: a thin bright rim, a clear middle and one
##   small highlight), drawn here by a tiny shader because the pack could not be downloaded from the
##   build machine. To use Kenney's own picture, set [member texture] to it: the shader then samples it.
## * [method nudge]: one subtle turn of the panel's little cog during the rattle, as if something in
##   there moved it, then it rests. Once only, no sound of its own.
## Onion's own bounce is unchanged. Slow and soft, no flash; ~5 unshaded quads, freed after ~2 s.

## Kenney's bubble picture, if one is put in the project (null = the drawn bubble).
static var texture: Texture2D = null

const RISE := Vector2(0.08, 0.14)        # metres each bubble rises (min, max)
const SIZE := Vector2(0.012, 0.024)      # bubble diameter, metres
const LIFE := Vector2(1.3, 1.8)          # seconds each lives
const STAGGER := 0.35                    # the last one starts this long after the first
const DRIFT := 0.012                     # sideways sway, metres
const PEAK := 0.75                       # brightest alpha (soft, never a flash)

const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform float alpha = 0.0;
uniform vec3 tint = vec3(0.97, 0.95, 0.88);
uniform bool use_texture = false;
uniform sampler2D picture : source_color, filter_linear;
void vertex() {
	// face the eye (billboard), keep the node's own scale
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a;
	if (use_texture) {
		vec4 t = texture(picture, UV);
		ALBEDO = t.rgb * tint;
		a = t.a;
	} else {
		float rim = smoothstep(0.62, 0.86, r) * (1.0 - smoothstep(0.9, 1.0, r));
		float inner = 0.12 * (1.0 - smoothstep(0.0, 0.9, r));
		float shine = 1.0 - smoothstep(0.0, 0.17, length(p - vec2(-0.36, 0.38)));
		a = max(max(rim * 0.85, inner), shine);
		ALBEDO = tint + vec3(shine * 0.1);
	}
	ALPHA = a * alpha;
}
"""

static var _shader: Shader

var _bubbles: Array[Dictionary] = []   # {node, material, from, rise, life, start, phase}
var _clock := 0.0


## A few bubbles from the cauldron's opening ([param mouth], [param radius] metres across half);
## [param parent] holds them. Seeded, so pictures and tests see the same bubbles.
static func bubbles(parent: Node, mouth: Vector3, radius: float, count := 5, seed_value := 7) -> HelloFx:
	var fx := HelloFx.new()
	fx.name = "hello_bubbles"
	fx.add_to_group(&"entry_transient")   # a jump clears it like the other leftovers
	parent.add_child(fx)
	fx._make(mouth, radius, count, seed_value)
	return fx


## One small turn of [param cog] about its own up axis, then a slight settle back. [param degrees]
## is the turn; it takes about 0.8 s. Returns the tween (tests and pictures may wait for it).
static func nudge(cog: Node3D, degrees := 14.0) -> Tween:
	var start := cog.rotation.y
	var tween := cog.create_tween()
	tween.tween_property(cog, "rotation:y", start + deg_to_rad(degrees), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(cog, "rotation:y", start + deg_to_rad(degrees * 0.75), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


## How many bubbles are showing now (tests).
func showing() -> int:
	return _bubbles.filter(func(b: Dictionary) -> bool: return (b.node as Node3D).visible).size()


func _make(mouth: Vector3, radius: float, count: int, seed_value: int) -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	for i in count:
		var material := ShaderMaterial.new()
		material.shader = _shader
		material.set_shader_parameter(&"use_texture", texture != null)
		if texture != null:
			material.set_shader_parameter(&"picture", texture)
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		var node := MeshInstance3D.new()
		node.mesh = quad
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.scale = Vector3.ONE * random.randf_range(SIZE.x, SIZE.y)
		node.visible = false
		add_child(node)
		var angle := random.randf() * TAU
		var from := mouth + Vector3(cos(angle), 0.0, sin(angle)) * radius * random.randf_range(0.1, 0.7)
		node.global_position = from
		_bubbles.append({node = node, material = material, from = from, rise = random.randf_range(RISE.x, RISE.y),
				life = random.randf_range(LIFE.x, LIFE.y), start = STAGGER * i / maxf(1.0, count - 1.0), phase = random.randf() * TAU})


func _process(delta: float) -> void:
	_clock += delta
	var alive := false
	for b in _bubbles:
		var t: float = (_clock - b.start) / b.life
		var node: Node3D = b.node
		if t < 0.0:
			alive = true
			continue
		if t >= 1.0:
			node.visible = false
			continue
		alive = true
		node.visible = true
		var up := 1.0 - pow(1.0 - t, 2.0)   # quick out of the brew, slowing as it rises
		var sway := sin(t * 5.0 + b.phase) * DRIFT * t
		node.global_position = b.from + Vector3(sway, up * b.rise, sway * 0.6)
		var fade := minf(t / 0.12, 1.0) * (1.0 - smoothstep(0.6, 1.0, t))
		(b.material as ShaderMaterial).set_shader_parameter(&"alpha", fade * PEAK)
	if not alive:
		queue_free()
