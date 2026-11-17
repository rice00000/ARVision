class_name SummonFx
extends RefCounted
## Summon and fold (Effects chat, Nov 17): how an activity comes out of its impression and goes back.
## * [method grow]: the impression lifts a little, glides to the workspace, and the activity rises out
##   of the table there at full width with a line of light on its top (the reveal's "drawn up" look);
##   the impression is hidden meanwhile.
## * [method fold]: the reverse: the activity sinks into its base, and the impression comes back at its
##   own spot, settling with a soft pulse.
## Never from a point (nothing inflates), no flashing, nothing moves near the eyes.

const LIFT := 0.04


## Grows [param activity] out of [param impression] at [param workspace]; returns when it has arrived.
static func grow(impression: Impression, activity: Node3D, workspace: Transform3D, seconds := 1.2) -> void:
	if not activity.has_meta(&"fx_size"):
		activity.set_meta(&"fx_size", activity.scale)
	var size: Vector3 = activity.get_meta(&"fx_size")
	var home := impression.global_position
	impression.set_meta(&"fx_home", home)
	var glide := impression.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glide.tween_property(impression, "global_position", home + Vector3.UP * LIFT, seconds * 0.25)
	glide.tween_property(impression, "global_position", workspace.origin + Vector3.UP * LIFT, seconds * 0.35)
	glide.parallel().tween_property(impression, "scale", Vector3.ONE * 0.6, seconds * 0.35)
	await glide.finished
	impression.visible = false
	activity.global_transform = Transform3D(workspace.basis, workspace.origin)
	activity.scale = size
	var rise := _riser(activity)
	rise.arrive(activity, size, seconds * 0.6)
	await activity.get_tree().create_timer(seconds * 0.6 + 0.45).timeout
	if is_instance_valid(rise):   # a scene change mid-rise may have freed it already
		rise.queue_free()


## Folds [param activity] back into [param impression] (which reappears at its own spot).
static func fold(activity: Node3D, impression: Impression, seconds := 1.0) -> void:
	var size: Vector3 = activity.get_meta(&"fx_size", activity.scale)
	var held := RevealFx.hold_physics(activity)   # Jolt can't take a height-only scale on its shapes
	var sink := activity.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	sink.tween_property(activity, "scale", Vector3(size.x, size.y * 0.02, size.z), seconds * 0.5)
	await sink.finished
	activity.visible = false
	activity.scale = size   # ready to grow again
	RevealFx.release_physics(held)
	var home: Vector3 = impression.get_meta(&"fx_home", impression.global_position)
	impression.global_position = home + Vector3.UP * LIFT
	impression.scale = Vector3.ONE * 0.6
	impression.visible = true
	var settle := impression.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	settle.tween_property(impression, "global_position", home, seconds * 0.5)
	settle.tween_property(impression, "scale", Vector3.ONE, seconds * 0.5)
	await settle.finished
	PlaceSignal.play(impression, home, Vector3.UP, 0.1, false)


static func _riser(activity: Node3D) -> RevealFx:
	var rise := RevealFx.new()
	rise.name = "summon_rise"
	activity.get_parent().add_child(rise)
	return rise
