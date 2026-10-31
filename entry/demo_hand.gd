class_name DemoHand
extends Node3D
## STUB: the interaction chat replaces the body and keeps this API. A softly translucent
## teaching hand that shows ONE gesture at a time and loops it until [method stop]: a tap on
## the cauldron, a pinch that lifts the gear, a lowering and opening over the socket.
## First a stand-in made of primitives; later the MRTK Hand Coach rigs (see the assets
## folder's hand-coach/README.md).

## Taps at [param at] (the cauldron's rim), looping until [method stop].
func tap(_at: Vector3) -> void:
	await get_tree().create_timer(0.5).timeout


## Pinches [param gear] and lifts it a little, looping until [method stop]. It only shows the
## gesture: the real gear stays where it is.
func pinch_lift(_gear: Node3D) -> void:
	await get_tree().create_timer(0.5).timeout


## Lowers over [param socket_at] and opens its fingers, looping until [method stop].
func lower_release(_socket_at: Vector3) -> void:
	await get_tree().create_timer(0.5).timeout


## Takes the hand away (soon, softly).
func stop() -> void:
	pass
