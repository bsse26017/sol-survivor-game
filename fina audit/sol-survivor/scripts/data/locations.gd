## Single source of truth for the named places on the outpost.
## The 3D name labels, the map screen and the field-task placement all read this, so
## the same names and positions are used everywhere ("Same names are used on the map").
class_name Locations
extends RefCounted

## Which location each sol's main repair happens at (drives the map's objective star).
const SOL_OBJECTIVE := {
	1: "hab",         # flip the main power breaker (inside the hab)
	2: "hab",         # repair the thermal heater (inside the hab)
	3: "tanks",       # reboot the O2 scrubber
	4: "greenhouse",  # patch the dome breach (far west)
	5: "shelter",     # reinforce the radiation shield (far east)
	6: "dish",        # align the comms dish and call the crew (south-east)
}

## Older field-task data refers to places by these names.
const ALIASES := {"solar_rows": "solar"}


## All places, in the order they are listed. Positions come from the assembly's own
## constants so nothing can drift out of sync with where the buildings really are.
static func all() -> Array[Dictionary]:
	return [
		{"id": "hab", "name": "Hab", "pos": OutpostAssembly.HAB_POS, "label_y": 7.6,
			"shape": "circle", "size": Vector2(4.0, 4.0), "color": Color("#8E93B5")},
		{"id": "greenhouse", "name": "Greenhouse", "pos": OutpostAssembly.GREENHOUSE_POS, "label_y": 4.8,
			"shape": "circle", "size": Vector2(4.1, 4.1), "color": Color("#69A478")},
		{"id": "workshop", "name": "Workshop", "pos": OutpostAssembly.WORKSHOP_POS, "label_y": 5.2,
			"shape": "rect", "size": Vector2(5.9, 3.9), "color": Color("#B7A28D")},
		{"id": "shelter", "name": "Radiation Shelter", "pos": OutpostAssembly.SHELTER_POS, "label_y": 5.8,
			"shape": "rect", "size": Vector2(7.0, 7.0), "color": Color("#D95D39")},
		{"id": "tanks", "name": "O2 Tanks", "pos": OutpostAssembly.TANKS_POS, "label_y": 4.2,
			"shape": "rect", "size": Vector2(4.0, 1.8), "color": Color("#5EA394"), "label_side": "below"},
		{"id": "solar", "name": "Solar Field", "pos": Vector3(-9.5, 0.0, 0.75), "label_y": 3.4,
			"shape": "rect", "size": Vector2(8.6, 4.4), "color": Color("#6E7BB8")},
		{"id": "dish", "name": "Comms Dish", "pos": OutpostAssembly.DISH_POS, "label_y": 5.4,
			"shape": "rect", "size": Vector2(4.1, 2.4), "color": Color("#DFC896"), "label_side": "below"},
		{"id": "crash_pod", "name": "Crash Pod", "pos": OutpostAssembly.CRASH_POS, "label_y": 3.9,
			"shape": "circle", "size": Vector2(3.2, 3.2), "color": Color("#C4CCD8"), "label_side": "below"},
	]


static func find(id: String) -> Dictionary:
	var key: String = ALIASES.get(id, id)
	for loc in all():
		if loc["id"] == key:
			return loc
	return {}


## World position (y = 0) of a place by id or old alias; the origin if unknown.
static func position_of(id: String) -> Vector3:
	var loc := find(id)
	return loc["pos"] if not loc.is_empty() else Vector3.ZERO


static func objective_for_sol(sol: int) -> String:
	return SOL_OBJECTIVE.get(sol, "")
