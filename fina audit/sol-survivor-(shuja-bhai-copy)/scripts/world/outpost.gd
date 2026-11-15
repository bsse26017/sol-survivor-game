## Hooks Hold-E interactables onto OutpostAssembly Marker3Ds and triggers visual repair swaps.
extends Node3D

const InteractableScript = preload("res://scripts/gameplay/interactable.gd")

const COL_LAVENDER := Color("9C88B8")
const COL_TEAL := Color("4FD1C5")
const COL_AMBER := Color("F5A623")

var _assembly: OutpostAssembly = null

func _ready() -> void:
	var ground_mesh := get_node_or_null("Ground/MeshInstance3D")
	if ground_mesh:
		ground_mesh.visible = false

	call_deferred("_wire_outpost_interactables")

func _wire_outpost_interactables() -> void:
	_assembly = get_node_or_null("../OutpostAssembly") as OutpostAssembly
	if _assembly == null:
		push_warning("Outpost: Could not find sibling OutpostAssembly node!")
		return

	# Sol 1: Power switch
	_create_marker_interactable("PowerSwitch", "power_switch",
		"Hold E to flip the main power breaker", 3.0, 1, 0, COL_TEAL, Vector3(1.2, 1.8, 1.2))

	# Sol 2: Heater
	_create_marker_interactable("HeaterUnit", "heater",
		"Hold E to repair habitat thermal heater", 3.0, 2, 0, COL_AMBER, Vector3(1.4, 1.6, 1.4))

	# Sol 3: Oxygen tanks (centered on middle tank)
	_create_marker_interactable("O2Console", "o2_tank_2",
		"Hold E to reboot atmospheric O2 scrubber", 3.5, 3, 0, COL_TEAL, Vector3(3.2, 2.4, 1.6))

	# Sol 4: Greenhouse crack -> swaps crack decal for patch plate
	var gh_node := _create_marker_interactable("DomePatch", "greenhouse_crack",
		"Hold E to patch greenhouse dome breach", 3.0, 4, 0, COL_TEAL, Vector3(2.2, 2.2, 2.2))
	if gh_node:
		gh_node.interaction_completed.connect(func(): _assembly.set_greenhouse_patched(true))

	# Sol 5: Shelter wall -> swaps wall crack for patch plate
	var sh_node := _create_marker_interactable("ShelterWall", "shelter_wall",
		"Hold E to reinforce radiation shield plating", 3.5, 5, 0, COL_AMBER, Vector3(2.4, 2.4, 2.0),
		0.0, 0.0, 0.0, 20.0)
	if sh_node:
		sh_node.interaction_completed.connect(func(): _assembly.set_shelter_repaired(true))

	# Sol 6: Dish antenna -> swaps broken dish for fixed dish
	var dish_node := _create_marker_interactable("DishConsole", "dish_antenna",
		"Hold E to align high-gain transmitter dish", 4.0, 6, 0, COL_TEAL, Vector3(2.2, 2.0, 2.2))
	if dish_node:
		dish_node.interaction_completed.connect(func(): _assembly.set_dish_fixed(true))

	# Sleep Pod / Bed
	_create_marker_interactable("Bed", "bed",
		"Hold E to enter sleep pod", 1.5, 0, 1, COL_LAVENDER, Vector3(2.6, 1.4, 1.4))   # bed model is 2.5 m long along its own X

func _create_marker_interactable(obj_name: String, marker_name: String,
		prompt: String, duration: float, sol: int, type: int,
		accent_color: Color, box_size: Vector3,
		life: float = 0.0, power: float = 0.0, food: float = 0.0, shield: float = 0.0) -> StaticBody3D:
	var m := _assembly.marker(marker_name)
	if m == null:
		push_warning("Outpost: Missing marker '%s' in OutpostAssembly" % marker_name)
		return null

	var node := StaticBody3D.new()
	node.name = obj_name
	# Layer 1 keeps the box solid for walking; layer 2 is what the player's interact ray sees.
	node.collision_layer = 1 | 2
	node.set_script(InteractableScript)
	node.set("prompt_text", prompt)
	node.set("hold_duration", duration)
	node.set("is_active", sol == 1 or type == 1)
	node.set("sol_number", sol)
	node.set("interaction_type", type)
	node.set("life_support_change", life)
	node.set("power_change", power)
	node.set("food_change", food)
	node.set("shield_change", shield)
	node.set("active_color", accent_color)

	# Small glowing beacon orb so Interactable._update_visual() highlights the active target
	var beacon := MeshInstance3D.new()
	beacon.name = "MeshInstance3D"
	var sphere := SphereMesh.new()
	sphere.radius = 0.14
	sphere.height = 0.28
	beacon.mesh = sphere
	beacon.position = Vector3(0, 0.35, 0)
	node.add_child(beacon)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	col.shape = box
	node.add_child(col)

	add_child(node)
	# Must be set after add_child(): global_position needs the node inside the tree.
	node.global_position = m.global_position
	node.global_rotation.y = m.global_rotation.y   # box follows the furniture's facing
	return node
