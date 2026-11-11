extends RefCounted
## Stimulus and timing settings for the motion lab's trial block (Nov 9 build plan).
##
## EVERY VALUE HERE IS A PROVISIONAL DEVELOPER DEFAULT. None is a research-approved
## difficulty level, a clinical dose or a replication of a published task. Change them here;
## each block copies the values it ran with into the developer record.

const BASELINE := preload("res://trials/motion/motion_demo.tres")

## Stimulus-only blur (Nov 10): each dot's edge is softened with a Gaussian profile; panels,
## text and buttons are never blurred. It is a display manipulation for exploration, NOT a
## simulation of any diagnosis and NOT a prescribed treatment.
const BLUR_IMPL := "per-dot Gaussian edge v1: alpha = Phi((r - d) / sigma) (logistic approximation of the normal CDF); exact for sigma << dot radius, underestimates spread when sigma approaches the radius"
const DOT_RENDER := "flat quad disc shader v1 (block mode)"

## Bounded customization ranges: chosen to keep the field visible and the dots moving on a
## desktop. They are developer bounds, not clinically suitable ranges.
const RANGES := {
	coherence = {min = 0.05, max = 1.0, step = 0.05},
	speed_m_s = {min = 0.1, max = 0.6, step = 0.05},
	blur_sigma_deg = {min = 0.0, max = 0.5, step = 0.05},
	expose_s = {min = 0.5, max = 2.0, step = 0.25},
	dot_radius_m = {min = 0.01, max = 0.04, step = 0.005},
	dots = {min = 15, max = 300, step = 5},
}

## Everything that must match for two blocks to share an accuracy-versus-coherence series:
## all of the condition except coherence, seeds and signal direction.
const CONDITION_FIELDS := ["name", "aperture", "dots", "dot_radius_m", "distance_m", "half_width_m",
	"half_height_m", "aperture_radius_m", "speed_m_s", "dot_lifetime_s", "noise", "contrast",
	"blur_sigma_deg", "blur_impl", "dot_render", "input"]

## Gaps that stop either configuration from claiming benchmark equivalence.
const UNRESOLVED := [
	"dot speed / displacement per frame: Rajendran 2020 reports 0.15 deg steps but no time base; the lab moves dots at the motion_demo.tres speed",
	"dot lifetime and the noise algorithm (here: unit-length random 2D directions, lifetime respawn)",
	"dot size and contrast in degrees on the headset (the 15 px reference dots have no stated pitch)",
	"display calibration and the actually displayed duration on Quest (desktop timing is not headset timing)",
]


## Timing and block shape. 1 s preparation and 1 s exposure follow the reference task as a
## starting point for development; six trials is a usability-review placeholder.
static func timing() -> Dictionary:
	return {
		prepare_s = 1.0,
		expose_s = 1.0,
		demo_expose_s = 2.0,
		teach_coherence = 1.0,
		trials = 6,
		provisional = true,
		note = "1 s preparation / 1 s exposure are reference-informed starting values; 6 trials is a usability placeholder, not a dose or a threshold sample.",
	}


## The existing preview geometry: motion_demo.tres baseline, flat centres in a rectangle.
static func preview(coherence := 0.9) -> Dictionary:
	var c := BASELINE.condition(0.0, 0, false)
	var distance: float = c.value(&"distance")
	var half_w: float = c.value(&"half_width")
	var half_h: float = c.value(&"half_height")
	return {
		name = "preview_rectangle",
		label = "Preview default: rectangle, motion_demo.tres baseline (developer default)",
		aperture = "rectangle",
		dots = int(c.value(&"dots")),
		dot_radius_m = 0.02,
		distance_m = distance,
		half_width_m = half_w,
		half_height_m = half_h,
		aperture_radius_m = 0.0,
		extent_deg = [snappedf(rad_to_deg(2.0 * atan(half_w / distance)), 0.1),
			snappedf(rad_to_deg(2.0 * atan(half_h / distance)), 0.1)],
		speed_m_s = float(c.value(&"speed")),
		dot_lifetime_s = float(c.value(&"dot_lifetime")),
		coherence = coherence,
		blur_sigma_deg = 0.0,
		blur_impl = BLUR_IMPL,
		dot_render = DOT_RENDER,
		input = "desktop_fallback",
		noise = "2D unit-length random directions, lifetime respawn, rectangular wrap",
		contrast = "light dots (0.75, 0.95, 1.0) on a near-black panel; not calibrated",
		provisional = true,
		unresolved = UNRESOLVED,
	}


## A circle sized like the reference display (10 deg field, 15 dots; Rajendran et al. 2020).
## Only size and count follow the reference: speed, lifetime, dot size, contrast and the noise
## algorithm are the lab's own. NOT a replication.
static func reference_circle(coherence := 0.9) -> Dictionary:
	var c := BASELINE.condition(0.0, 0, false)
	var distance: float = c.value(&"distance")
	var radius := distance * tan(deg_to_rad(5.0))
	return {
		name = "reference_circle_10deg",
		label = "Reference-sized circle: 10 deg field, 15 dots (after Rajendran 2020). Not a replication.",
		aperture = "circle",
		dots = 15,
		dot_radius_m = 0.02,
		distance_m = distance,
		half_width_m = radius,
		half_height_m = radius,
		aperture_radius_m = radius,
		extent_deg = [10.0, 10.0],
		speed_m_s = float(c.value(&"speed")),
		dot_lifetime_s = float(c.value(&"dot_lifetime")),
		coherence = coherence,
		blur_sigma_deg = 0.0,
		blur_impl = BLUR_IMPL,
		dot_render = DOT_RENDER,
		input = "desktop_fallback",
		noise = "2D unit-length random directions, lifetime respawn, antipodal re-entry at the circle edge",
		contrast = "light dots (0.75, 0.95, 1.0) on a near-black panel; not calibrated",
		provisional = true,
		unresolved = UNRESOLVED,
	}


static func by_name(config_name: String, coherence := 0.9) -> Dictionary:
	return reference_circle(coherence) if config_name == "reference_circle_10deg" else preview(coherence)


## [param base] with [param changes] applied, each clamped and snapped to its range.
static func customized(base: Dictionary, changes: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for key: String in changes:
		var value: Variant = changes[key]
		if RANGES.has(key):
			var r: Dictionary = RANGES[key]
			value = clampf(snappedf(float(value), float(r.step)), float(r.min), float(r.max))
			if key == "dots":
				value = int(value)
		out[key] = value
	if out.aperture == "circle":
		out.half_width_m = out.aperture_radius_m
		out.half_height_m = out.aperture_radius_m
	return out


static func customized_timing(base: Dictionary, expose_s: float) -> Dictionary:
	var out := base.duplicate(true)
	var r: Dictionary = RANGES.expose_s
	out.expose_s = clampf(snappedf(expose_s, float(r.step)), float(r.min), float(r.max))
	return out


## A stable text key for "same condition except coherence". Includes timing and the display.
static func condition_key(stimulus: Dictionary, block_timing: Dictionary, display := {}) -> String:
	var parts: Array = []
	for field: String in CONDITION_FIELDS:
		parts.append("%s=%s" % [field, str(stimulus.get(field, ""))])
	parts.append("prepare_s=%s" % str(block_timing.get("prepare_s", "")))
	parts.append("expose_s=%s" % str(block_timing.get("expose_s", "")))
	parts.append("renderer=%s" % str(display.get("renderer", "")))
	parts.append("xr=%s" % str(display.get("xr", "")))
	return "|".join(parts)


## Short human label for a condition (graph legends).
static func condition_label(stimulus: Dictionary, block_timing: Dictionary) -> String:
	return "%s · %d dots · %.2f m/s · blur %.2f° · %.2f s · %s" % [
		stimulus.get("name", "?"), int(stimulus.get("dots", 0)), float(stimulus.get("speed_m_s", 0.0)),
		float(stimulus.get("blur_sigma_deg", 0.0)), float(block_timing.get("expose_s", 0.0)),
		stimulus.get("input", "?")]
