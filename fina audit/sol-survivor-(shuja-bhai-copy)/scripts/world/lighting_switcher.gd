## Switches between day / night / storm lighting presets.
## Aligned with the hazy pastel low-poly palette.
extends Node3D

@export var sun_light: DirectionalLight3D
@export var world_env: WorldEnvironment

enum Preset { DAY, NIGHT, STORM }

# Exact Palette:
# Peach: #F4A988, Rust: #C1502E, Lavender: #9C88B8, Deep Blue: #2B3A67, Amber: #F5A623
const COL_PEACH := Color("F4A988")
const COL_RUST := Color("C1502E")
const COL_LAVENDER := Color("9C88B8")
const COL_DEEP_BLUE := Color("2B3A67")
const COL_AMBER := Color("F5A623")
const COL_SUN_WARM := Color("FFD9B8")

var current_preset: Preset = Preset.DAY

func _ready() -> void:
	if not sun_light:
		sun_light = get_node_or_null("../DirectionalLight3D")
	if not world_env:
		world_env = get_node_or_null("../WorldEnvironment")
	GameManager.sol_started.connect(_on_sol_started)
	_apply_day()

func set_preset(preset: Preset) -> void:
	current_preset = preset
	match preset:
		Preset.DAY:
			_apply_day()
		Preset.NIGHT:
			_apply_night()
		Preset.STORM:
			_apply_storm()

func _apply_day() -> void:
	if sun_light:
		sun_light.light_color = COL_SUN_WARM
		sun_light.light_energy = 1.15
		sun_light.rotation_degrees = Vector3(-18, 150, 0) # Aligned with visible sun disc
	if world_env and world_env.environment:
		var env := world_env.environment
		env.ambient_light_color = COL_LAVENDER
		env.ambient_light_energy = 0.3
		env.fog_light_color = COL_PEACH
		env.fog_density = 0.0038
		env.glow_bloom = 0.22
		if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			var psky := env.sky.sky_material as ProceduralSkyMaterial
			psky.sky_top_color = COL_LAVENDER
			psky.sky_horizon_color = COL_PEACH
			psky.ground_bottom_color = COL_RUST
			psky.ground_horizon_color = COL_PEACH

func _apply_night() -> void:
	if sun_light:
		sun_light.light_color = Color(0.3, 0.4, 0.6)
		sun_light.light_energy = 0.18
		sun_light.rotation_degrees = Vector3(-20, 45, 0)
	if world_env and world_env.environment:
		var env := world_env.environment
		env.ambient_light_color = COL_DEEP_BLUE
		env.ambient_light_energy = 0.15
		env.fog_light_color = COL_DEEP_BLUE
		env.fog_density = 0.008
		env.glow_bloom = 0.35 # Make teal glows pop more at night
		if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			var psky := env.sky.sky_material as ProceduralSkyMaterial
			psky.sky_top_color = COL_DEEP_BLUE
			psky.sky_horizon_color = Color(0.08, 0.11, 0.2)
			psky.ground_bottom_color = Color(0.05, 0.07, 0.12)
			psky.ground_horizon_color = Color(0.08, 0.11, 0.2)

func _apply_storm() -> void:
	if sun_light:
		sun_light.light_color = COL_AMBER
		sun_light.light_energy = 0.35
		sun_light.rotation_degrees = Vector3(-25, 45, 0)
	if world_env and world_env.environment:
		var env := world_env.environment
		env.ambient_light_color = COL_RUST
		env.ambient_light_energy = 0.25
		env.fog_light_color = COL_RUST
		env.fog_density = 0.018 # Dense amber-brown fog, reduced visibility
		env.glow_bloom = 0.2
		if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			var psky := env.sky.sky_material as ProceduralSkyMaterial
			psky.sky_top_color = Color("8A4A28")
			psky.sky_horizon_color = COL_AMBER
			psky.ground_bottom_color = COL_RUST
			psky.ground_horizon_color = COL_AMBER

func _on_sol_started(sol: int) -> void:
	match sol:
		5:
			set_preset(Preset.STORM)
		6:
			set_preset(Preset.STORM)
		_:
			set_preset(Preset.DAY)
