class_name Carry
extends Node
## STUB: the interaction chat replaces the body and keeps this API (the story chat codes
## against it). Lets the child pick up the gear with a pinch, carry it, and set it into the
## socket: a generous acceptance volume, auto-align and a click on release near the socket,
## a gentle fall to the table if released elsewhere, recovery within reach on tracking loss.
## No scoring, no failure.

## The child picked the gear up.
signal picked_up
## The child let go (docked: it went into the socket).
signal released(docked: bool)
## The gear is in the socket (after the auto-align and the click).
signal docked

## The child may pick it up now (the story turns this on after asking).
var enabled := false
## A hand is holding it.
var held := false

var _gear: Node3D
var _socket_at := Vector3.ZERO


## Starts watching for [param gear] to be picked up and set into the socket at [param socket_at].
func begin(gear: Node3D, socket_at: Vector3) -> void:
	_gear = gear
	_socket_at = socket_at
	enabled = true


func stop() -> void:
	enabled = false
	held = false


## STUB, kept for the story chat's tests: pretends the child picked it up and set it in.
func simulate(after := 1.0) -> void:
	await get_tree().create_timer(after).timeout
	picked_up.emit()
	await get_tree().create_timer(after).timeout
	released.emit(true)
	docked.emit()
