class_name VisionPreset
extends Resource
## A starting point for a child's vision profile (content/vision/): staff apply
## one on the facilitator's Vision page, then adjust. See Vision.

## Shown on the Vision page, never spoken (so not "title": content titles are baked as speech).
@export var label := ""
## Empty = normal. Its title becomes [member label].
@export var view: View
@export_range(0.75, 2.0, 0.25) var size_scale := 1.0
@export_range(0.5, 2.0, 0.25) var help_scale := 1.0
@export_range(1.0, 3.0, 0.5) var time_scale := 1.0
