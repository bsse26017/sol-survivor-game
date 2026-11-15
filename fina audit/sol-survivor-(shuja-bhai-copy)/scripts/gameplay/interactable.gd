## Base class for all interactable objects in the world.
## Attach to a StaticBody3D with a CollisionShape3D and MeshInstance3D.
## The player's raycast detects this and allows hold-E interaction.
class_name Interactable
extends StaticBody3D

signal interaction_completed

@export var prompt_text: String = "Hold E to repair"
@export var hold_duration: float = 3.0
@export var is_active: bool = false
@export var sol_number: int = 1

## What type of interaction this is
enum InteractionType { REPAIR, BED }
@export var interaction_type: InteractionType = InteractionType.REPAIR

@export_group("Repair Effects (if type is REPAIR)")
@export var life_support_change: float = 0.0
@export var power_change: float = 0.0
@export var food_change: float = 0.0
@export var shield_change: float = 0.0

@export_group("Visuals")
@export var active_color: Color = Color("4fd1c5")    # Teal glow
@export var inactive_color: Color = Color("555555")   # Grey
@export var completed_color: Color = Color("7ec850")  # Green

var _completed: bool = false
var _mesh: MeshInstance3D = null

func _ready() -> void:
	add_to_group("interactables")
	_mesh = _find_mesh()
	_update_visual()

	# Listen for sol changes to activate/deactivate
	GameManager.sol_started.connect(_on_sol_started)

func is_interactable() -> bool:
	return is_active and not _completed

func complete_interaction() -> void:
	# Sleeping before the day's repair/event is done must NOT consume the bed:
	# otherwise it stays "completed" and can never be used once the player is ready,
	# which soft-locks the sol. Show the "finish your repair first" toast and bail.
	if interaction_type == InteractionType.BED and not GameManager.can_sleep():
		GameManager.on_bed_interacted()
		return

	_completed = true
	_update_visual()
	interaction_completed.emit()

	# Apply meter changes for repairs
	if interaction_type == InteractionType.REPAIR:
		MeterSystem.apply_changes(
			life_support_change, power_change, food_change, shield_change
		)
		GameManager.on_repair_completed()
	elif interaction_type == InteractionType.BED:
		GameManager.on_bed_interacted()

func reset() -> void:
	_completed = false
	_update_visual()

func _on_sol_started(sol: int) -> void:
	if interaction_type == InteractionType.BED:
		# Bed is always active and reusable
		is_active = true
		_completed = false
		_update_visual()
		return

	if sol == sol_number:
		is_active = true
		_completed = false
		_update_visual()
	else:
		is_active = false
		_update_visual()

func _update_visual() -> void:
	if not _mesh:
		return
	var mat := _mesh.get_surface_override_material(0)
	if not mat or not mat is StandardMaterial3D:
		mat = StandardMaterial3D.new()
		_mesh.set_surface_override_material(0, mat)
	if _completed:
		mat.albedo_color = completed_color
		mat.emission_enabled = false
	elif is_active:
		mat.albedo_color = active_color
		mat.emission_enabled = true
		mat.emission = active_color * 0.5
		mat.emission_energy_multiplier = 0.8
	else:
		mat.albedo_color = inactive_color
		mat.emission_enabled = false

func _find_mesh() -> MeshInstance3D:
	if has_node("MeshInstance3D") and get_node("MeshInstance3D") is MeshInstance3D:
		return get_node("MeshInstance3D") as MeshInstance3D
	for child in get_children():
		if child is MeshInstance3D:
			return child
	return null
