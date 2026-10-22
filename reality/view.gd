class_name View
extends Resource
## How the real world is shown during a block: a passthrough filter plus
## dimming. Neutral by default. Every round logs it, so a result always says
## what the child saw. Presets live in content/views/.
##
## On a Quest the filter is Meta's passthrough filter, so the units are Meta's;
## the simulated room imitates it.

@export var title := "Normal"

@export_group("Filter")
## Added light, -100..100.
@export_range(-100.0, 100.0) var brightness := 0.0
## 1 = unchanged, above 1 = stronger.
@export_range(0.0, 4.0) var contrast := 1.0
## 1 = unchanged, 0 = greyscale.
@export_range(0.0, 4.0) var saturation := 1.0
## Only light and dark, nothing between. Overrides the three above.
@export var black_and_white := false
## Real edges drawn in this colour; alpha 0 = off.
@export var edges := Color(0, 0, 0, 0)

@export_group("Less information")
## How much the real world is darkened, 0..1.
@export_range(0.0, 1.0) var dim := 0.0
## A circle of this radius (metres) around the trial's focus point is spared
## from dimming: a spotlight. 0 = dim evenly.
@export var focus_radius := 0.0


## Changes brightness, contrast or saturation.
func is_graded() -> bool:
	return brightness != 0.0 or contrast != 1.0 or saturation != 1.0


func to_log() -> Dictionary:
	return {title = title, brightness = brightness, contrast = contrast, saturation = saturation,
		black_and_white = black_and_white, edges = edges, dim = dim, focus_radius = focus_radius}
