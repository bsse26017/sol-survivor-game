## First-person player controller tuned for Martian gravity.
## Features: WASD movement, Sprint (Shift), floaty Mars Jump (Space),
## subtle head bob and FOV dynamic adjustment.
extends CharacterBody3D

@export var walk_speed: float = 4.2
@export var sprint_speed: float = 7.2
@export var jump_velocity: float = 4.5
@export var mars_gravity: float = 3.72
@export var mouse_sensitivity: float = 0.002

@export var bob_frequency: float = 2.4
@export var bob_amplitude: float = 0.05
@export var base_fov: float = 75.0
@export var sprint_fov: float = 83.0

@onready var camera: Camera3D = $Camera3D
@onready var interact_ray: RayCast3D = $Camera3D/InteractRay

## Physics layer bits. Layer 1 = world/solid geometry, layer 2 = interactables.
## The interact ray only sees layer 2, so decorative model colliders (layer 1)
## can't sit in front of an interactable and swallow the ray.
const WORLD_LAYER_MASK: int = 1
const INTERACT_LAYER_MASK: int = 2
## How far in front of the targeted surface a solid object may be before it counts
## as blocking line of sight. The ray hits the interactable's box surface, and a
## model collider that overlaps the box is only centimetres in front of it.
const LINE_OF_SIGHT_TOLERANCE: float = 0.5

## Horizontal distance from the map centre the player may walk to, and the height
## below which they count as having fallen out of the world.
const PLAY_AREA_RADIUS: float = 80.0
const FALL_RESET_Y: float = -30.0

# Internal state
var _camera_base_pos: Vector3
var _bob_timer: float = 0.0
var _current_interactable: Node = null
var _interact_held_time: float = 0.0
var _is_interacting: bool = false
var _spawn_position: Vector3

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera_base_pos = camera.position
	_spawn_position = global_position
	interact_ray.collision_mask = INTERACT_LAYER_MASK
	_setup_drifting_dust()

func _setup_drifting_dust() -> void:
	var dust := GPUParticles3D.new()
	dust.name = "PlayerDriftingDust"
	dust.amount = 140
	dust.lifetime = 4.5
	dust.preprocess = 2.0
	dust.visibility_aabb = AABB(Vector3(-15, -4, -15), Vector3(30, 8, 30))
	
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(12, 2.5, 12)
	pmat.direction = Vector3(1.0, -0.1, 0.35).normalized()
	pmat.spread = 20.0
	pmat.initial_velocity_min = 2.5
	pmat.initial_velocity_max = 5.5
	pmat.gravity = Vector3(0, -0.15, 0)
	pmat.color = Color(0.957, 0.663, 0.533, 0.45) # Semi-transparent peach
	
	dust.process_material = pmat
	
	var quad := QuadMesh.new()
	quad.size = Vector2(0.045, 0.045)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.957, 0.663, 0.533, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.roughness = 0.9
	quad.material = mat
	
	dust.draw_pass_1 = quad
	add_child(dust)

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -deg_to_rad(89), deg_to_rad(89))

	# Esc is handled by the PauseMenu autoload (it pauses the game and frees the mouse).

## The terrain is a 240 m bowl whose rim is walkable and ends in empty space, and
## nothing else stops the player leaving it. Keep them inside the dunes, and put
## them back at the spawn point if they ever fall out of the world.
func _keep_in_play_area() -> void:
	if global_position.y < FALL_RESET_Y:
		global_position = _spawn_position
		velocity = Vector3.ZERO
		return
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() > PLAY_AREA_RADIUS:
		flat = flat.normalized() * PLAY_AREA_RADIUS
		global_position.x = flat.x
		global_position.z = flat.y
		velocity.x = 0.0
		velocity.z = 0.0

func _physics_process(delta: float) -> void:
	# Subtle 3D camera pan behind the title screen
	if GameManager.current_state == GameManager.GameState.TITLE:
		rotate_y(delta * 0.04)
		return

	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	_keep_in_play_area()

	# ----- gravity -----
	if not is_on_floor():
		velocity.y -= mars_gravity * delta

	# ----- jump (Mars floaty jump) -----
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# ----- movement speed & sprint -----
	var is_sprinting: bool = Input.is_action_pressed("sprint") and is_on_floor()
	var target_speed := sprint_speed if is_sprinting else walk_speed

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if direction:
		velocity.x = move_toward(velocity.x, direction.x * target_speed, 20.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, 20.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)

	move_and_slide()

	# ----- camera juice: head bob & sprint FOV -----
	_process_camera_bob(delta, is_sprinting)

	# ----- interaction -----
	_process_interaction(delta)

func _process_camera_bob(delta: float, is_sprinting: bool) -> void:
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horiz_speed > 0.5:
		var speed_mult := 1.4 if is_sprinting else 1.0
		_bob_timer += delta * bob_frequency * speed_mult
		var bob_y := sin(_bob_timer * 2.0) * bob_amplitude
		var bob_x := cos(_bob_timer) * (bob_amplitude * 0.5)
		camera.position.y = lerpf(camera.position.y, _camera_base_pos.y + bob_y, 10.0 * delta)
		camera.position.x = lerpf(camera.position.x, _camera_base_pos.x + bob_x, 10.0 * delta)
	else:
		_bob_timer = 0.0
		camera.position.y = lerpf(camera.position.y, _camera_base_pos.y, 8.0 * delta)
		camera.position.x = lerpf(camera.position.x, _camera_base_pos.x, 8.0 * delta)

	# Smooth FOV transition
	var target_fov := sprint_fov if (is_sprinting and horiz_speed > 1.0) else base_fov
	camera.fov = lerpf(camera.fov, target_fov, 8.0 * delta)

## True unless solid world geometry sits clearly between the camera and the target
## point (e.g. a hab wall). Stops interacting through walls now that the interact
## ray ignores world colliders.
func _has_line_of_sight(target_point: Vector3) -> bool:
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, target_point, WORLD_LAYER_MASK)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return from.distance_to(hit.position) >= from.distance_to(target_point) - LINE_OF_SIGHT_TOLERANCE

func _process_interaction(delta: float) -> void:
	# Check what the raycast is looking at
	var new_target: Node = null
	var hit_point: Vector3 = Vector3.ZERO
	if interact_ray.is_colliding():
		var collider := interact_ray.get_collider()
		hit_point = interact_ray.get_collision_point()
		if collider is Node and collider.has_method("is_interactable") and collider.is_interactable() \
				and _has_line_of_sight(hit_point):
			new_target = collider

	# Target changed
	if new_target != _current_interactable:
		_current_interactable = new_target
		_interact_held_time = 0.0
		_is_interacting = false
		if _current_interactable:
			GameManager.interact_prompt_visible.emit(true, _current_interactable.prompt_text)
			GameManager.repair_progress_updated.emit(0.0)
		else:
			GameManager.interact_prompt_visible.emit(false, "")
			GameManager.repair_progress_updated.emit(0.0)

	# Hold E to interact
	if _current_interactable and Input.is_action_pressed("interact"):
		_is_interacting = true
		_interact_held_time += delta
		var progress: float = _interact_held_time / _current_interactable.hold_duration
		GameManager.repair_progress_updated.emit(clampf(progress, 0.0, 1.0))

		if _interact_held_time >= _current_interactable.hold_duration:
			_current_interactable.complete_interaction()
			_interact_held_time = 0.0
			_is_interacting = false
			GameManager.interact_prompt_visible.emit(false, "")
			GameManager.repair_progress_updated.emit(0.0)
			_current_interactable = null
	elif _is_interacting:
		_interact_held_time = 0.0
		_is_interacting = false
		GameManager.repair_progress_updated.emit(0.0)
