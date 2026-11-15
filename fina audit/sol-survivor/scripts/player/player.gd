## Third-person player controller tuned for Martian gravity with 360 Orbit Camera.
## Features: WASD movement, Sprint (Shift), floaty Mars Jump (Space),
## subtle head bob, astronaut walk lean/bob animation, and dynamic 360 orbit camera.
extends CharacterBody3D

@export var walk_speed: float = 4.2
@export var sprint_speed: float = 7.2
@export var jump_velocity: float = 4.5
@export var mars_gravity: float = 3.72
@export var mouse_sensitivity: float = 0.002

@export var bob_frequency: float = 2.4
@export var bob_amplitude: float = 0.04
@export var base_fov: float = 68.0
@export var sprint_fov: float = 76.0
@export var orbit_speed: float = 2.4

@onready var camera: Camera3D = $Camera3D
@onready var interact_ray: RayCast3D = $Camera3D/InteractRay
@onready var astronaut_model: Node3D = get_node_or_null("Astronaut")
@onready var orbit_pivot: Node3D = get_node_or_null("OrbitPivot")
@onready var orbit_pitch: Node3D = get_node_or_null("OrbitPivot/OrbitPitch")
@onready var camera_360: Camera3D = get_node_or_null("OrbitPivot/OrbitPitch/Camera360")
@onready var interact_ray_360: RayCast3D = get_node_or_null("OrbitPivot/OrbitPitch/Camera360/InteractRay360")

## Physics layer bits. Layer 1 = world/solid geometry, layer 2 = interactables.
const WORLD_LAYER_MASK: int = 1
const INTERACT_LAYER_MASK: int = 2
const LINE_OF_SIGHT_TOLERANCE: float = 0.5

const PLAY_AREA_RADIUS: float = 80.0
const FALL_RESET_Y: float = -30.0

# Internal state
var _camera_base_pos: Vector3
var _camera_pitch: float = deg_to_rad(-12.0)
var _bob_timer: float = 0.0
var _current_interactable: Node = null
var _interact_held_time: float = 0.0
var _is_interacting: bool = false
var _spawn_position: Vector3

# 360 Camera state
var _orbit_yaw: float = 0.0
var _orbit_pitch: float = 0.0
var _using_360_camera: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera_base_pos = camera.position
	_camera_pitch = camera.rotation.x
	_spawn_position = global_position
	interact_ray.collision_mask = INTERACT_LAYER_MASK
	interact_ray.add_exception(self)
	if interact_ray_360:
		interact_ray_360.collision_mask = INTERACT_LAYER_MASK
		interact_ray_360.add_exception(self)
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
	pmat.color = Color(0.957, 0.663, 0.533, 0.45)
	
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if GameManager.current_state == GameManager.GameState.PLAYING and not get_tree().paused and not _is_overlay_open():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _is_overlay_open() -> bool:
	var map := get_node_or_null("/root/MapScreen")
	if map and map.visible:
		return true
	var how := get_node_or_null("/root/HowToPlay")
	if how and how.visible:
		return true
	var pause := get_node_or_null("/root/PauseMenu")
	if pause and pause.visible:
		return true
	return false

func _is_arrow_held() -> bool:
	return Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_RIGHT) \
		or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_DOWN) \
		or Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right") \
		or Input.is_action_pressed("ui_up") or Input.is_action_pressed("ui_down")

func _input(event: InputEvent) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if get_tree().paused:
		return

	# Click to re-capture mouse if focus was lost
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _is_overlay_open():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return

	# Toggle between Default Camera and 360 Orbit Camera with 'C'
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C or event.physical_keycode == KEY_C:
			set_360_camera_active(not _using_360_camera)

	# Mouse look:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# If user moves mouse while in 360 orbit mode and not actively pressing arrow keys,
		# smoothly switch back to main gameplay camera!
		if _using_360_camera and not _is_arrow_held():
			set_360_camera_active(false)

		rotate_y(-event.relative.x * mouse_sensitivity)
		_camera_pitch = clampf(_camera_pitch - event.relative.y * mouse_sensitivity, -deg_to_rad(80), deg_to_rad(80))
		camera.rotation.x = _camera_pitch
		camera.rotation.y = 0.0
		camera.rotation.z = 0.0

		if orbit_pitch:
			orbit_pitch.rotation.x = clampf(_camera_pitch, -deg_to_rad(65), deg_to_rad(65))

	# Esc is handled by the PauseMenu autoload (it pauses the game and frees the mouse).

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

	# When moving with WASD in 360 mode, smoothly switch back to main gameplay camera
	if _using_360_camera and direction.length_squared() > 0.01:
		set_360_camera_active(false)

	if direction:
		velocity.x = move_toward(velocity.x, direction.x * target_speed, 20.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, 20.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)

	move_and_slide()

	# ----- camera juice: head bob & sprint FOV -----
	_process_camera_bob(delta, is_sprinting)
	_process_astronaut_movement(delta, is_sprinting)
	_process_360_camera(delta)

	# ----- interaction -----
	_process_interaction(delta)

func set_360_camera_active(active: bool) -> void:
	if not camera_360:
		return
	_using_360_camera = active
	if _using_360_camera:
		camera_360.current = true
		_orbit_pitch = _camera_pitch
		if orbit_pitch:
			orbit_pitch.rotation.x = _orbit_pitch
	else:
		camera.current = true
		_orbit_yaw = 0.0
		if orbit_pivot:
			orbit_pivot.rotation.y = 0.0

func _process_360_camera(delta: float) -> void:
	if not orbit_pivot or not orbit_pitch:
		return

	var arrow_h: float = 0.0
	var arrow_v: float = 0.0

	# Left/Right arrow keys: orbit 360 degrees around the astronaut
	if Input.is_key_pressed(KEY_LEFT) or Input.is_action_pressed("ui_left"):
		arrow_h += 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_action_pressed("ui_right"):
		arrow_h -= 1.0

	# Up/Down arrow keys: tilt pitch up and down
	if Input.is_key_pressed(KEY_UP) or Input.is_action_pressed("ui_up"):
		arrow_v -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_action_pressed("ui_down"):
		arrow_v += 1.0

	if arrow_h != 0.0 or arrow_v != 0.0:
		# Auto-activate 360 camera as soon as arrow keys are pressed!
		if not _using_360_camera:
			set_360_camera_active(true)

		_orbit_yaw += arrow_h * orbit_speed * delta
		_orbit_pitch += arrow_v * orbit_speed * delta
		_orbit_pitch = clampf(_orbit_pitch, -deg_to_rad(65), deg_to_rad(65))
		_orbit_yaw = wrapf(_orbit_yaw, -PI, PI)

		orbit_pivot.rotation.y = _orbit_yaw
		orbit_pitch.rotation.x = _orbit_pitch

func _process_astronaut_movement(delta: float, is_sprinting: bool) -> void:
	if not astronaut_model:
		return
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horiz_speed > 0.5:
		var lean := deg_to_rad(-4.0) if is_sprinting else deg_to_rad(-2.0)
		astronaut_model.rotation.x = lerpf(astronaut_model.rotation.x, lean, 10.0 * delta)
		astronaut_model.rotation.z = lerpf(astronaut_model.rotation.z, sin(_bob_timer) * 0.05, 12.0 * delta)
		astronaut_model.position.y = lerpf(astronaut_model.position.y, abs(sin(_bob_timer * 2.0)) * 0.04, 12.0 * delta)
	else:
		astronaut_model.rotation.x = lerpf(astronaut_model.rotation.x, 0.0, 8.0 * delta)
		astronaut_model.rotation.z = lerpf(astronaut_model.rotation.z, 0.0, 8.0 * delta)
		astronaut_model.position.y = lerpf(astronaut_model.position.y, 0.0, 8.0 * delta)

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

func _has_line_of_sight(target_point: Vector3) -> bool:
	var active_cam: Camera3D = camera_360 if (_using_360_camera and camera_360) else camera
	var from := active_cam.global_position
	var query := PhysicsRayQueryParameters3D.create(from, target_point, WORLD_LAYER_MASK)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return from.distance_to(hit.position) >= from.distance_to(target_point) - LINE_OF_SIGHT_TOLERANCE

func _process_interaction(delta: float) -> void:
	var active_ray: RayCast3D = interact_ray_360 if (_using_360_camera and interact_ray_360) else interact_ray
	var new_target: Node = null
	var hit_point: Vector3 = Vector3.ZERO
	if active_ray and active_ray.is_colliding():
		var collider := active_ray.get_collider()
		hit_point = active_ray.get_collision_point()
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
