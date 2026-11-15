extends CharacterBody3D

# Helper robot that stays/follows next to the Player (astronaut)
@export var follow_offset: Vector3 = Vector3(0.85, 0.0, 0.1) # positioned next to player
@export var speed: float = 6.0

@onready var player: CharacterBody3D = get_parent() as CharacterBody3D

func _ready() -> void:
	# Make top level at runtime so it moves smoothly in global space without parent transform jitter
	set_as_top_level(true)
	if player:
		global_position = player.global_position + player.global_transform.basis * follow_offset
		rotation.y = player.global_rotation.y + PI

func _physics_process(delta: float) -> void:
	if not player:
		return

	# Desired position next to the astronaut player (maintaining offset relative to player facing)
	var target_pos: Vector3 = player.global_position + player.global_transform.basis * follow_offset
	var diff: Vector3 = target_pos - global_position
	diff.y = 0.0
	var dist: float = diff.length()

	if dist > 0.05:
		var dir: Vector3 = diff.normalized()
		var move_speed: float = speed if dist < 2.5 else speed * 1.5
		velocity.x = move_toward(velocity.x, dir.x * move_speed, 14.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * move_speed, 14.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)

	# Face the EXACT same direction the astronaut is facing (model forward is opposite in glb)
	rotation.y = lerp_angle(rotation.y, player.global_rotation.y + PI, 8.0 * delta)

	# Sync vertical motion and Martian gravity
	if not is_on_floor():
		velocity.y -= 3.72 * delta
	else:
		if player.velocity.y > 0.5:
			velocity.y = player.velocity.y
		else:
			velocity.y = 0.0

	move_and_slide()
