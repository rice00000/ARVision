class_name DotsEntrance
extends RefCounted
## The dots' entrance (Oct 31 decision, never built until now): the cloud rises as one group from
## below, behind the table's far edge (the cloud stands beyond the table), straight up to where it will
## be shown, easing to a stop. Straight up only: no sideways or toward/away travel, which could hint at
## the round's answer (the task's directions are left, right, toward and away, never up). It has
## stopped before the round starts. On the Quest it also fades in.

const BELOW := 0.3    # metres below its spot


## Where the cloud starts: [constant BELOW] straight below [param to].
static func start_of(to: Transform3D) -> Transform3D:
	return Transform3D(to.basis, to.origin + Vector3.DOWN * BELOW)


## Moves [param cloud] from [param from] to [param to]; returns when it has stopped.
static func rise(cloud: Node3D, from: Transform3D, to: Transform3D, seconds := 1.4) -> void:
	cloud.global_transform = from
	cloud.visible = true
	var geometry := cloud as GeometryInstance3D
	if geometry:
		geometry.transparency = 1.0
	var tween := cloud.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(cloud, "global_position", to.origin, seconds)
	if geometry:
		tween.tween_property(geometry, "transparency", 0.0, seconds * 0.7)
	await tween.finished
	cloud.global_transform = to
