class_name ClockworkTick
extends RefCounted
## Hello's "subtle clockwork magic" (Effects chat, Nov 17): while the cauldron rattles, the little cog
## beside the empty socket ticks round twice, like an escapement catching (1/16 turn each, a small
## settle). It reuses the opening's own cog, and it hints that the cauldron and the table's mechanism
## belong together. Small and slow: nothing flashes or spins.

const STEP := TAU / 16.0


## Ticks [param cog] round [param steps] times, [param gap] seconds apart; returns when done.
static func tick(cog: Node3D, steps := 2, gap := 0.45) -> void:
	if cog == null or not cog.is_inside_tree():
		return
	for i in steps:
		var to := cog.rotation.y + STEP
		var tween := cog.create_tween()
		tween.tween_property(cog, "rotation:y", to + STEP * 0.12, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(cog, "rotation:y", to, 0.18).set_trans(Tween.TRANS_SINE)
		await tween.finished
		if i < steps - 1:
			await cog.get_tree().create_timer(gap).timeout
