class_name OutpostAssembly
extends Node3D
## Assembles the Blender outpost kit into the Sol Survivor map (GDD section 8).
##
## Put the .glb files in res://assets/models/outpost/ and add this script to a
## Node3D in main.tscn. All coordinates are Godot coords: +Z is toward the
## player spawn (0, 1, 7.2), so every model's front (door, windows) already
## faces +Z. No 180 degree fix needed.
##
## Layout (top view, player at the bottom looking up):
##
##   greenhouse ==corridor== HAB ==corridor== workshop        z = -8
##                       steps/camp   tanks      shelter
##   solar rows                                    dish        z = 0..5
##                  crash pod (behind spawn)  >  lander (hidden)

const DIR := "res://assets/models/outpost/"
const GROUND_Y := -0.05            # terrain is flat (y = 0) under the base

const HAB_POS := Vector3(0, 0, -8)
const WORKSHOP_POS := Vector3(10.7, 0, -8)
const GREENHOUSE_POS := Vector3(-11.85, 0, -8)
const SHELTER_POS := Vector3(14.5, 0, -0.5)
const TANKS_POS := Vector3(6, 0, -4.2)
const DISH_POS := Vector3(9, 0, 4.5)
const CRASH_POS := Vector3(-5, 0, 10)
const LANDER_POS := Vector3(3, 0, 22)

## Walk-in hab exported from tools/blender/build_hab_enterable.py. When this file is
## imported it replaces hab.glb; the kit furniture moves inside to its MARKER_* empties.
const HAB_ENTERABLE := "hab_enterable"
const HAB_FURNITURE := {   # marker name in the GLB -> kit model to place there
	"MARKER_bed": "bed",
	"MARKER_terminal": "terminal",
	"MARKER_power_switch": "power_switch",
	"MARKER_heater": "heater",
}
## Interactable marker for each piece of furniture: local offset from the model origin
## (centre of the interaction box, in the model's own axes; the model faces +Z).
const HAB_FURNITURE_MARKER := {
	"bed": Vector3(0, 0.7, 0),
	"terminal": Vector3(0, 1.0, -0.3),
	"power_switch": Vector3(0, 1.5, -0.3),
	"heater": Vector3(0, 0.8, -0.3),
}
const HAB_INNER_RADIUS := 3.08   ## furniture corners must stay inside this (lining is at 3.14)
## Materials in the GLB can carry stale values if the .blend came from an older script
## version, so the game's real values are re-applied by material name.
const HAB_MATERIAL_TUNING := {   # name: [metallic, roughness, emission energy (0 = off)]
	"HabMat_amber": [0.10, 0.55, 0.0], "HabMat_beige": [0.10, 0.70, 0.0],
	"HabMat_cream": [0.05, 0.60, 0.0], "HabMat_door": [0.10, 0.55, 0.0],
	"HabMat_glass": [0.20, 0.12, 0.0], "HabMat_grey": [0.45, 0.45, 0.0],
	"HabMat_mauve": [0.40, 0.50, 0.0], "HabMat_orange": [0.10, 0.50, 0.0],
	"HabMat_pale": [0.05, 0.55, 0.0], "HabMat_silver": [0.85, 0.30, 0.0],
	"HabMat_slate": [0.55, 0.45, 0.0], "HabMat_fab_lav": [0.0, 0.90, 0.0],
	"HabMat_fab_teal": [0.0, 0.90, 0.0],
	"HabMat_teal": [0.0, 0.50, 1.0], "HabMat_teal_hot": [0.0, 0.50, 1.9],
	"HabMat_red_on": [0.0, 0.50, 4.0],
}
var _hab_enterable := false

## x, z, radius. Rocks never spawn inside these circles.
const EXCLUDE := [
	Vector3(0, -8, 6.0), Vector3(-11.85, -8, 5.5), Vector3(10.7, -8, 4.5),
	Vector3(14.5, -0.5, 6.0), Vector3(6, -4.2, 3.2), Vector3(-9.5, -0.5, 5.0),
	Vector3(-9.5, 2.0, 5.0), Vector3(9, 4.5, 3.5), Vector3(-5, 10, 4.0),
	Vector3(-5, 13.5, 4.5), Vector3(3, 22, 4.5), Vector3(15.2, -8.6, 2.5),
]

var _nodes: Dictionary = {}      # tag -> Node3D
var _markers: Dictionary = {}    # name -> Marker3D


func _ready() -> void:
	_build_world()


# ---------------------------------------------------------------- public API
## Marker3D for gameplay hooks (put your Interactable on / at these).
## Names: power_switch, heater, bed, terminal, o2_tank_1..3, greenhouse_crack,
## shelter_wall, solar_panels, dish_antenna, dish_cable, dish_powerbox
func marker(marker_name: String) -> Marker3D:
	return _markers.get(marker_name)


func set_panels_clean(clean: bool) -> void:
	for row in ["solar_a", "solar_b"]:
		_vis(row + "_dusty", not clean)
		_vis(row + "_clean", clean)


func set_dish_fixed(fixed: bool) -> void:
	_vis("dish_broken", not fixed)
	_vis("dish_fixed", fixed)


func set_greenhouse_patched(patched: bool) -> void:
	_vis("gh_crack", not patched)
	_vis("gh_patch", patched)


func set_shelter_repaired(repaired: bool) -> void:
	_vis("shelter_crack", not repaired)
	_vis("shelter_patch", repaired)


## Hide the crew lander again (retry after a win, or a fresh run).
func reset_lander() -> void:
	var l: Node3D = _nodes.get("lander")
	if l == null:
		return
	l.visible = false
	l.position = LANDER_POS


## Ending: the crew lander comes down.
func land_lander(duration: float = 6.0) -> void:
	var l: Node3D = _nodes.get("lander")
	if l == null:
		return
	l.visible = true
	l.position = LANDER_POS + Vector3(0, 40, 0)
	var tw := create_tween()
	tw.tween_property(l, "position", LANDER_POS, duration) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------- build
func _build_world() -> void:
	# ground + big stuff
	_spawn("terrain", Vector3(0, GROUND_Y, 0), 0.0, true, "terrain")
	_spawn_hab()
	_spawn("greenhouse", GREENHOUSE_POS, 0.0, true, "greenhouse")
	_spawn("workshop", WORKSHOP_POS, 0.0, true, "workshop")
	_spawn("shelter", SHELTER_POS, 0.0, true, "shelter")
	_spawn("corridor", HAB_POS + Vector3(-5.8, 0, 0), 0.0, true, "corridor_l")
	_spawn("corridor", HAB_POS + Vector3(5.8, 0, 0), 0.0, true, "corridor_r")
	_spawn("tanks", TANKS_POS, 0.0, true, "tanks")

	# solar: two rows, dusty and clean variants swapped by set_panels_clean()
	for row in [["solar_a", Vector3(-9.5, 0, -0.5)], ["solar_b", Vector3(-9.5, 0, 2.0)]]:
		var tag: String = row[0]
		var pos: Vector3 = row[1]
		_spawn("solar_row_dusty", pos, 0.0, false, tag + "_dusty")
		var clean := _spawn("solar_row", pos, 0.0, false, tag + "_clean")
		if clean:
			clean.visible = false
		_add_box_body(pos + Vector3(0, 0.9, 0), Vector3(8.6, 1.8, 1.8))

	# comms dish: broken until Sol 6, plus the 3 parts lying around
	_spawn("dish_broken", DISH_POS, 0.0, false, "dish_broken")
	var fixed := _spawn("dish_fixed", DISH_POS, 0.0, false, "dish_fixed")
	if fixed:
		fixed.visible = false
	_add_box_body(DISH_POS + Vector3(0, 1.6, 0), Vector3(2.4, 3.2, 2.4))
	_spawn("part_antenna", Vector3(11.8, 0, 6.8), 35.0, false, "part_antenna")
	_spawn("part_cable", Vector3(7.2, 0, 7.4), 0.0, false, "part_cable")
	_spawn("part_powerbox", Vector3(12.4, 0, 3.2), -20.0, false, "part_powerbox")

	# damage decals + repair plates (toggled by the repair tasks)
	var gh_decal := Vector3(GREENHOUSE_POS.x, 1.6, -4.80)
	_decal("crack", gh_decal, -25.8, "gh_crack", true)
	_decal("patch_plate", gh_decal + Vector3(0, 0.02, 0.04), -25.8, "gh_patch", false)
	var sh_decal := Vector3(SHELTER_POS.x + 1.6, 2.2, SHELTER_POS.z + 1.98)
	_decal("crack", sh_decal, 0.0, "shelter_crack", true)
	_decal("patch_plate", sh_decal + Vector3(0, 0, 0.03), 0.0, "shelter_patch", false)

	# crash site behind the spawn, trail of boot prints to the hab door
	_spawn("crash_pod", CRASH_POS, 20.0, true, "crash_pod")
	# (the walk-in hab's steps start at z = -3.3, so the trail ends at the bottom step)
	var trail_end := Vector3(-0.3, 0, -3.2) if _hab_enterable else Vector3(-0.4, 0, -2.4)
	_footprints(Vector3(-3.8, 0, 8.2), trail_end)

	# crew lander for the ending (hidden until land_lander())
	var lander := _spawn("lander", LANDER_POS, 0.0, false, "lander")
	if lander:
		lander.visible = false

	# crates
	# Was wedged into the 0.7 m gap between the workshop and shelter (overlapping
	# the shelter and closing the path); now beside the workshop's far end.
	_spawn("crate_stack", Vector3(15.2, 0, -8.6), 8.0, true, "crates_a")
	_spawn("crate_large", Vector3(-6.5, 0, -4.8), -12.0, true, "crate_b")
	_spawn("crate_small", Vector3(3.4, 0, -1.2), 25.0, true, "crate_c")

	# cables from the solar field to the hab
	if _hab_enterable:
		# The power switch / heater moved inside, so the cables now run to the hab's
		# base plate (radius 3.98 round (0,-8)) instead of ending beside the old camp.
		_run_cable("cable_a", Vector3(-5.2, 0, -1.6), Vector3(-3.3, 0, -5.3))
		_run_cable("cable_b", Vector3(-5.7, 0, -1.7), Vector3(-3.75, 0, -5.45))
	else:
		_spawn("cable", Vector3(-5.6, 0, -2.4), 18.0, false, "")
		_spawn("cable", Vector3(-5.2, 0, -0.6), -8.0, false, "")

	if _hab_enterable:
		# Walk-in hab: the kit furniture lives inside it (no outdoor camp needed).
		_place_hab_furniture(_nodes["hab"])
	else:
		# Fallback when hab_enterable.glb is not imported: furniture in an outdoor
		# "camp" in front of the hab, under canopies.
		_spawn("power_switch", Vector3(-3.2, 0, -2.6), 0.0, true, "power_switch")
		_spawn("heater", Vector3(-5.2, 0, -2.6), 0.0, true, "heater")
		_spawn("terminal", Vector3(3.4, 0, -2.6), 0.0, true, "terminal")
		_spawn("bed", Vector3(5.6, 0, -1.2), 0.0, true, "bed")
		_build_camp_canopy()
		_build_west_camp()
	_build_shelter_awning()

	# two big foreground boulders + scattered rocks
	_spawn("rock_8", Vector3(-17, 0, 6), 40.0, true, "")
	_spawn("rock_8", Vector3(19, 0, 10), 200.0, true, "")
	_scatter_rocks()

	_build_markers()
	if _hab_enterable:
		_retarget_markers_to_furniture()
	_build_location_labels()


# ---------------------------------------------------------- enterable hab
func _spawn_hab() -> void:
	if ResourceLoader.exists(DIR + HAB_ENTERABLE + ".glb"):
		var hab := _spawn(HAB_ENTERABLE, HAB_POS, 0.0, false, "hab")
		if hab != null:
			_hab_enterable = true
			_tune_hab_materials(hab)
			_add_structural_collision(hab)
			# Round table in the middle: its mesh is decorative (no trimesh), so box it.
			_add_box_body(HAB_POS + Vector3(0, 0.68, -0.8), Vector3(1.1, 0.76, 1.1))
			_add_hab_lights(hab)
			return
	_spawn("hab", HAB_POS, 0.0, true, "hab")


## Re-apply the game's metallic / roughness / emission values by material name.
func _tune_hab_materials(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var mesh := (child as MeshInstance3D).mesh
			for s in mesh.get_surface_count():
				var mat := mesh.surface_get_material(s) as BaseMaterial3D
				if mat == null or not HAB_MATERIAL_TUNING.has(mat.resource_name):
					continue
				var t: Array = HAB_MATERIAL_TUNING[mat.resource_name]
				mat.metallic = t[0]
				mat.roughness = t[1]
				mat.emission_enabled = t[2] > 0.0
				if t[2] > 0.0:
					mat.emission = mat.albedo_color
					mat.emission_energy_multiplier = t[2]
		_tune_hab_materials(child)


## Collide only on the chunky parts (objects exported with bevel >= 20 mm: walls, floor,
## dome, steps, door frame, lockers). Rivets, ribs, lights and trim stay collision-free so
## the player never snags on them.
func _add_structural_collision(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D and _is_structural(String(child.name)):
			(child as MeshInstance3D).create_trimesh_collision()
		_add_structural_collision(child)


func _is_structural(node_name: String) -> bool:
	var idx := node_name.rfind("_b")
	return idx >= 0 and node_name.substr(idx + 2).to_int() >= 20


func _add_hab_lights(hab: Node3D) -> void:
	for spec in [["MARKER_light_center", 2.2, 8.0], ["MARKER_light_desk", 1.1, 5.0]]:
		var m := hab.get_node_or_null(spec[0]) as Node3D
		if m == null:
			continue
		var lamp := OmniLight3D.new()
		lamp.position = m.global_position
		lamp.light_color = Color("#FFE2C4")
		lamp.light_energy = spec[1]
		lamp.omni_range = spec[2]
		lamp.shadow_enabled = false
		add_child(lamp)


## Put the game's own bed / terminal / power switch / heater at the GLB's markers and
## nudge each inward until every corner is inside the lining.
func _place_hab_furniture(hab: Node3D) -> void:
	for marker_name in HAB_FURNITURE:
		var m := hab.get_node_or_null(marker_name) as Node3D
		if m == null:
			push_warning("OutpostAssembly: %s missing from %s.glb" % [marker_name, HAB_ENTERABLE])
			continue
		var model: String = HAB_FURNITURE[marker_name]
		var n := _spawn(model, m.global_position, rad_to_deg(m.global_rotation.y), true, model)
		if n != null:
			_fit_inside_hab(n)


func _fit_inside_hab(node: Node3D) -> void:
	var centre := Vector2(HAB_POS.x, HAB_POS.z)
	for _i in 6:
		var worst := 0.0
		for corner in _mesh_corners(node):
			worst = maxf(worst, Vector2(corner.x, corner.z).distance_to(centre))
		if worst <= HAB_INNER_RADIUS:
			return
		var flat := Vector2(node.global_position.x, node.global_position.z) - centre
		if flat.length() < 0.01:
			return
		var shift := flat.normalized() * (worst - HAB_INNER_RADIUS)
		node.global_position -= Vector3(shift.x, 0.0, shift.y)


func _mesh_corners(root: Node) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for child in root.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var box := mi.get_aabb()
			for ix in 2:
				for iy in 2:
					for iz in 2:
						out.append(mi.global_transform * (box.position + box.size * Vector3(ix, iy, iz)))
		out.append_array(_mesh_corners(child))
	return out


## A name label floating above every place (Hab, Greenhouse, ...). Billboard mode makes
## each one always face the player; the names/positions come from Locations, the same
## table the map screen uses.
func _build_location_labels() -> void:
	for loc in Locations.all():
		var label := Label3D.new()
		label.name = "Label_%s" % loc["id"]
		label.text = String(loc["name"]).to_upper()
		var pos: Vector3 = loc["pos"]
		label.position = Vector3(pos.x, loc["label_y"], pos.z)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font = UITheme.get_heavy_font()
		label.font_size = 48
		# Constant on-screen size, so a label next to the player is no bigger than a far one.
		label.fixed_size = true
		label.pixel_size = 0.0007
		label.modulate = Color("#F5EFE6")
		label.outline_size = 12
		label.outline_modulate = Color("#16141A")
		label.shaded = false
		label.double_sided = true
		add_child(label)
		_nodes["label_" + String(loc["id"])] = label


## Place names are for the title backdrop and for play; hide them behind the mission
## briefing and the debrief, where they would float through the dimmed screen.
func _process(_delta: float) -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return
	var scene := get_tree().current_scene
	var intro := scene.get_node_or_null("IntroSequence") if scene else null
	var show_labels: bool = gm.current_state != 4 and not (intro != null and intro.visible)
	for loc in Locations.all():
		var label: Node3D = _nodes.get("label_" + String(loc["id"]))
		if label and label.visible != show_labels:
			label.visible = show_labels


## Lay one 4.2 m cable model between two ground points (its length runs along local X).
func _run_cable(tag: String, from: Vector3, to: Vector3) -> void:
	var d := to - from
	_spawn("cable", (from + to) * 0.5, rad_to_deg(atan2(-d.z, d.x)), false, tag)


## Interaction markers follow the furniture (position and facing).
func _retarget_markers_to_furniture() -> void:
	for model in HAB_FURNITURE_MARKER:
		var n: Node3D = _nodes.get(model)
		var m: Marker3D = _markers.get(model)
		if n == null or m == null:
			continue
		m.global_position = n.global_transform * HAB_FURNITURE_MARKER[model]
		m.global_rotation.y = n.global_rotation.y


## Lean-to over the bed and terminal so the camp reads as a deliberate shelter
## rather than furniture left in the open. The bed/terminal models and their
## markers are unchanged.
func _build_camp_canopy() -> void:
	_build_canopy("CampCanopy", "camp", 2.2, 7.6, -3.0, 0.6, 2.9,
			"SLEEP POD", Vector3(5.6, 2.35, -1.2), 1)


## Lean-to over the power switch and heater (west of the hab steps). The solar
## rows start at z = -1.4, so the canopy stays behind z = -1.7. Open at both ends
## so the cable run to the solar field is not blocked.
func _build_west_camp() -> void:
	_build_canopy("WestCampCanopy", "west_camp", -6.5, -2.3, -3.7, -1.7, 3.2,
			"POWER & HEAT", Vector3(-4.4, 2.75, -2.0), 0)


## Shared lean-to builder: primitives in the hab's palette (slate frame, orange
## trim, cyan light). Posts are solid; the roof sits above head height and falls
## toward the front (+Z), where the player stands. windbreak_side: +1 = solid
## panel on the +X end, -1 = on the -X end, 0 = none.
func _build_canopy(node_name: String, tag: String, x0: float, x1: float, z0: float,
		z1: float, post_h: float, label_text: String, label_pos: Vector3,
		windbreak_side: int) -> void:
	const TILT_DEG := 5.0

	var canopy := Node3D.new()
	canopy.name = node_name
	add_child(canopy)
	_nodes[tag] = canopy

	var pal := _camp_palette()
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var width := x1 - x0
	var depth := z1 - z0

	# floor pad (no collision; 5 cm high)
	canopy.add_child(_camp_box(Vector3(width, 0.05, depth), Vector3(cx, 0.025, cz), pal["pad"]))

	# four posts (solid)
	for px in [x0, x1]:
		for pz in [z0, z1]:
			canopy.add_child(_camp_box(Vector3(0.2, post_h, 0.2), Vector3(px, post_h * 0.5, pz), pal["frame"]))
			_add_box_body(Vector3(px, post_h * 0.5, pz), Vector3(0.2, post_h, 0.2))

	# sloped roof with an orange trim strip along the front edge
	var roof := _camp_box(Vector3(width + 0.6, 0.15, depth + 0.6), Vector3(cx, post_h + 0.05, cz), pal["roof"])
	roof.rotation_degrees.x = TILT_DEG
	canopy.add_child(roof)
	var front_drop := sin(deg_to_rad(TILT_DEG)) * (depth + 0.6) * 0.5
	canopy.add_child(_camp_box(Vector3(width + 0.6, 0.14, 0.14),
			Vector3(cx, post_h + 0.05 - front_drop, z1 + 0.3), pal["trim"]))

	# optional windbreak against the prevailing dust
	if windbreak_side != 0:
		var wx := x1 if windbreak_side > 0 else x0
		canopy.add_child(_camp_box(Vector3(0.12, 2.1, depth), Vector3(wx, 1.05, cz), pal["roof"]))
		_add_box_body(Vector3(wx, 1.05, cz), Vector3(0.12, 2.1, depth))

	# warm light + cyan light bar so it is readable at night and in storms
	canopy.add_child(_camp_box(Vector3(width * 0.55, 0.05, 0.08), Vector3(cx, post_h - 0.12, cz), pal["glow"]))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(cx, post_h - 0.4, cz)
	lamp.light_color = Color("#FFD9A0")
	lamp.light_energy = 1.2
	lamp.omni_range = 5.5
	lamp.shadow_enabled = false
	canopy.add_child(lamp)

	# say what it is
	var label := Label3D.new()
	label.text = label_text
	label.position = label_pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 36
	label.pixel_size = 0.005
	label.modulate = Color("#7FE8E0")
	label.outline_size = 6
	label.outline_modulate = Color("#1B2030")
	canopy.add_child(label)

## Overhang over the radiation shelter's door and repair wall (Sol 5 "hide in the
## shelter"). The building itself is a closed prop, so this gives the player a
## covered place to stand that matches the sleep-pod canopy. Roof is attached to
## the front wall (z ~ 1.5) and falls toward the front posts.
func _build_shelter_awning() -> void:
	const X0 := 13.4
	const X1 := 17.4
	const Z_BACK := 1.5
	const Z_FRONT := 3.9
	const Y_BACK := 3.4
	const Y_FRONT := 2.9

	var awning := Node3D.new()
	awning.name = "ShelterAwning"
	add_child(awning)
	_nodes["shelter_awning"] = awning

	var pal := _camp_palette()
	var cx := (X0 + X1) * 0.5
	var cz := (Z_BACK + Z_FRONT) * 0.5
	var dz := Z_FRONT - Z_BACK
	var dy := Y_BACK - Y_FRONT
	var slope_len := sqrt(dz * dz + dy * dy)

	var roof := _camp_box(Vector3((X1 - X0) + 0.6, 0.15, slope_len + 0.4),
			Vector3(cx, (Y_BACK + Y_FRONT) * 0.5, cz), pal["roof"])
	roof.rotation_degrees.x = rad_to_deg(atan2(dy, dz))
	awning.add_child(roof)
	awning.add_child(_camp_box(Vector3((X1 - X0) + 0.6, 0.14, 0.14),
			Vector3(cx, Y_FRONT - 0.04, Z_FRONT + 0.2), pal["trim"]))

	# two front posts (solid) and a windbreak on the +X end
	for px in [X0, X1]:
		awning.add_child(_camp_box(Vector3(0.2, Y_FRONT + 0.1, 0.2),
				Vector3(px, (Y_FRONT + 0.1) * 0.5, Z_FRONT), pal["frame"]))
		_add_box_body(Vector3(px, (Y_FRONT + 0.1) * 0.5, Z_FRONT), Vector3(0.2, Y_FRONT + 0.1, 0.2))
	awning.add_child(_camp_box(Vector3(0.12, 2.1, dz), Vector3(X1, 1.05, cz), pal["roof"]))
	_add_box_body(Vector3(X1, 1.05, cz), Vector3(0.12, 2.1, dz))

	# light bar + lamp so the covered spot is readable in the Sol 5 storm
	awning.add_child(_camp_box(Vector3(3.0, 0.05, 0.08), Vector3(cx, Y_FRONT - 0.2, cz + 0.4), pal["glow"]))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(cx, Y_FRONT - 0.5, cz + 0.4)
	lamp.light_color = Color("#FFD9A0")
	lamp.light_energy = 1.2
	lamp.omni_range = 5.5
	lamp.shadow_enabled = false
	awning.add_child(lamp)
	# (the name label "Radiation Shelter" now comes from _build_location_labels)


## Shared materials for the camp canopy and the shelter awning.
func _camp_palette() -> Dictionary:
	var glow := _camp_material(Color("#7FE8E0"), 0.4)
	glow.emission_enabled = true
	glow.emission = Color("#7FE8E0")
	glow.emission_energy_multiplier = 2.0
	return {
		"frame": _camp_material(Color("#3d3752"), 0.6),
		"roof": _camp_material(Color("#6b5a73"), 0.8),
		"trim": _camp_material(Color("#E0723A"), 0.7),
		"pad": _camp_material(Color("#2b2733"), 0.9),
		"glow": glow,
	}


func _camp_material(colour: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = roughness
	return m


func _camp_box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	return mi


func _build_markers() -> void:
	_mark("power_switch", Vector3(-3.2, 1.5, -2.9))
	_mark("heater", Vector3(-5.2, 0.8, -2.9))
	_mark("terminal", Vector3(3.4, 1.0, -2.9))
	_mark("bed", Vector3(5.6, 0.7, -1.2))
	for i in 3:
		_mark("o2_tank_%d" % (i + 1), TANKS_POS + Vector3((i - 1) * 1.1, 1.3, 0.55))
	_mark("greenhouse_crack", Vector3(GREENHOUSE_POS.x, 1.6, -4.7))
	_mark("shelter_wall", Vector3(SHELTER_POS.x + 1.6, 2.2, SHELTER_POS.z + 2.1))
	_mark("solar_panels", Vector3(-9.5, 1.5, 0.8))
	_mark("dish_antenna", Vector3(11.8, 0.4, 6.8))
	_mark("dish_cable", Vector3(7.2, 0.4, 7.4))
	_mark("dish_powerbox", Vector3(12.4, 0.5, 3.2))


# ----------------------------------------------------------------- helpers
func _spawn(model: String, pos: Vector3, yaw_deg: float = 0.0,
		collide: bool = true, tag: String = "") -> Node3D:
	var path := DIR + model + ".glb"
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("OutpostAssembly: missing " + path)
		return null
	var n := scene.instantiate() as Node3D
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	add_child(n)
	if collide:
		_add_collision(n)
	if tag != "":
		_nodes[tag] = n
	return n


func _decal(model: String, pos: Vector3, tilt_x_deg: float, tag: String, shown: bool) -> void:
	var n := _spawn(model, pos, 0.0, false, tag)
	if n:
		n.rotation_degrees.x = tilt_x_deg
		n.visible = shown


func _add_collision(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).create_trimesh_collision()
		_add_collision(child)


func _add_box_body(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	add_child(body)


func _mark(marker_name: String, pos: Vector3) -> void:
	var m := Marker3D.new()
	m.name = marker_name
	m.position = pos
	add_child(m)
	_markers[marker_name] = m


func _vis(tag: String, on: bool) -> void:
	var n: Node3D = _nodes.get(tag)
	if n:
		n.visible = on


func _footprints(from: Vector3, to: Vector3, step: float = 0.75) -> void:
	var dir := to - from
	var length := dir.length()
	dir = dir.normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	var yaw := rad_to_deg(atan2(-dir.x, -dir.z))   # toe points along -Z
	var d := 0.0
	var i := 0
	while d < length:
		var off := side * (0.16 if i % 2 == 0 else -0.16)
		_spawn("footprint", from + dir * d + off, yaw, false, "")
		d += step
		i += 1


func _is_clear(p: Vector3) -> bool:
	if absf(p.x) < 4.0 and p.z > -4.0 and p.z < 26.0:
		return false                         # keep the spawn -> hab path open
	var p2 := Vector2(p.x, p.z)
	for e in EXCLUDE:
		var c := e as Vector3
		if p2.distance_to(Vector2(c.x, c.y)) < c.z:
			return false
	return true


func _scatter_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var placed := 0
	var tries := 0
	while placed < 46 and tries < 3000:
		tries += 1
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(13.0, 75.0)
		var p := Vector3(cos(ang) * dist, 0, sin(ang) * dist)
		if not _is_clear(p):
			continue
		var idx := 1 + int(pow(rng.randf(), 1.8) * 7.99)    # small rocks more common
		_spawn("rock_%d" % idx, p, rng.randf() * 360.0, idx >= 5, "")
		placed += 1
