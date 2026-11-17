class_name HelloFx
extends RefCounted
## Scene 01 (Hello) effects, for the Hub chat to call (Effects chat, Nov 17; Megan approved "Playful Pop
## + subtle clockwork magic"). Effects does not call these itself: entry.gd is the Hub chat's.
## * [method pop]: from [code]Entry._pop()[/code], right after [code]_sounds.play_pop(...)[/code]:
##   [code]HelloFx.pop(self, _mouth, _mouth_radius).add_to_group(&"entry_transient")[/code]
## * [method rattle]: from [code]_hello()[/code], right after the pre-rattle sound:
##   [code]HelloFx.rattle(_cog)[/code] (the cog beside the empty socket; with the cauldron at its side
##   spot the Hub may prefer another bit of clockwork: any Node3D that turns about its Y works).


## A few bubbles of the brew lift off [param mouth] (Kenney Particle Pack circles, CC0) and fade, under 1 s.
static func pop(parent: Node, mouth: Vector3, radius := 0.04) -> PopBurst:
	return PopBurst.play(parent, mouth, radius)


## [param cog] ticks round [param steps] times (1/16 turn each, a small settle), like an escapement.
static func rattle(cog: Node3D, steps := 2) -> void:
	await ClockworkTick.tick(cog, steps)
