## Autoload singleton that drives the sol loop, bonus field tasks, dynamic weather, and state machine.
extends Node

# ---------- signals ----------
signal state_changed(new_state: int)
signal sol_started(sol_number: int)
signal objective_updated(text: String)
signal show_event(event: Resource)
signal show_night_summary(sol_number: int, fact: String, source: String)
signal show_debrief(won: bool)
signal interact_prompt_visible(visible: bool, text: String)
signal repair_progress_updated(progress: float)

# ---------- enums ----------
enum GameState {
	TITLE,
	PLAYING,
	EVENT_CARD,
	NIGHT_SUMMARY,
	DEBRIEF,
}

# ---------- state ----------
var current_state: int = GameState.TITLE
var current_sol: int = 0
var repair_completed: bool = false
var event_completed: bool = false
var choices_made: Array[Dictionary] = []

# Night-rule flags
var panels_clean: bool = false
var greenhouse_working: bool = true
var greenhouse_seed_bonus: bool = false
var sol3_delayed_harvest: bool = false
var sol5_dish_head_start: bool = false

# Snapshots for retry
var _sol_start_snapshot: Dictionary = {}
## Full game-state snapshot taken at the start of every sol, keyed by sol number.
## Retry rewinds to the start of the PREVIOUS sol (see retry_sol) so that a bad
## earlier choice that left the player in an unwinnable state can be undone.
var _sol_snapshots: Dictionary = {}

# Sol data – loaded at _ready
var sol_data_list: Array[Resource] = []

# Bonus field tasks & weather state
var _bonus_nodes: Array[Node3D] = []
var _active_bonus_task: Node3D = null
var _bonus_hold_time: float = 0.0
var _toast_layer: CanvasLayer = null
var _toast_label: Label = null
var _toast_panel: PanelContainer = null
var _toast_timer: float = 0.0

const BONUS_SCAN_DURATION := 1.25

const SOL_FIELD_TASKS := {
	1: [
		{"title": "CRASH POD BLACKBOX", "marker": "crash_pod", "offset": Vector3(2.2, 0.6, 1.8), "meter": &"shield", "delta": 10.0, "note": "RECOVERED ENTRY TELEMETRY (+10% SHIELD)"},
		{"title": "O2 SCRUBBER VALVE", "marker": "tanks", "offset": Vector3(1.6, 0.8, 1.6), "meter": &"life_support", "delta": 8.0, "note": "PURGED REGOLITH FROM O2 INTAKE (+8% O2)"},
	],
	2: [
		{"title": "ALGAE BIOREACTOR", "marker": "greenhouse", "offset": Vector3(-2.4, 0.8, 2.2), "meter": &"food", "delta": 10.0, "note": "HARVESTED SPIRULINA CULTURE (+10% FOOD)"},
		{"title": "AUXILIARY BATTERY BUS", "marker": "solar_rows", "offset": Vector3(0.0, 0.7, 3.8), "meter": &"power", "delta": 10.0, "note": "BALANCED CELL VOLTAGE (+10% POWER)"},
	],
	3: [
		{"title": "SOIL NITRATE PROBE", "marker": "greenhouse", "offset": Vector3(2.5, 0.7, 2.0), "meter": &"food", "delta": 10.0, "note": "CALIBRATED PERCHLORATE FILTER (+10% FOOD)"},
		{"title": "HABITAT SEAL PATCH", "marker": "hab", "offset": Vector3(-3.2, 0.8, 1.5), "meter": &"life_support", "delta": 8.0, "note": "SEALED AIRLOCK MICRO-LEAK (+8% O2)"},
	],
	4: [
		{"title": "CONDENSATE PUMP", "marker": "tanks", "offset": Vector3(-1.8, 0.8, 1.8), "meter": &"life_support", "delta": 10.0, "note": "RECLAIMED GRAYWATER VAPOR (+10% O2)"},
		{"title": "WORKSHOP CAPACITOR", "marker": "workshop", "offset": Vector3(0.0, 0.8, 3.4), "meter": &"power", "delta": 10.0, "note": "SALVAGED SPARE INVERTER (+10% POWER)"},
	],
	5: [
		{"title": "RADIATION DOSIMETER", "marker": "shelter", "offset": Vector3(-5.0, 0.8, -2.0), "meter": &"shield", "delta": 12.0, "note": "MAPPED SOLAR PROTON FLUX (+12% SHIELD)"},
		{"title": "EMERGENCY RATION CRATE", "marker": "crash_pod", "offset": Vector3(-2.0, 0.6, 1.5), "meter": &"food", "delta": 10.0, "note": "UNPACKED FREEZE-DRIED RATIONS (+10% FOOD)"},
	],
	6: [
		{"title": "LANDING BEACON TRANSPONDER", "marker": "dish", "offset": Vector3(2.0, 0.8, 1.8), "meter": &"power", "delta": 12.0, "note": "BOOSTED UHF CARRIER GAIN (+12% POWER)"},
		{"title": "FINAL CABIN PRESSURIZATION", "marker": "hab", "offset": Vector3(3.0, 0.8, 2.2), "meter": &"life_support", "delta": 10.0, "note": "VERIFIED ASCENT SUIT SEALS (+10% O2)"},
	],
}

func _ready() -> void:
	MeterSystem.meter_depleted.connect(_on_meter_depleted)
	_load_sol_data()
	_build_toast_overlay()

func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0 and _toast_layer:
			_toast_layer.visible = false

	if current_state != GameState.PLAYING:
		if _active_bonus_task != null:
			_active_bonus_task = null
			_bonus_hold_time = 0.0
		return

	_update_bonus_tasks(delta)

# ---------- sol data loading ----------
func _load_sol_data() -> void:
	for i in range(1, 7):
		var path := "res://resources/sols/sol_%d.tres" % i
		if ResourceLoader.exists(path):
			sol_data_list.append(load(path))
		else:
			sol_data_list.append(null)

func get_current_sol_data() -> Resource:
	if current_sol >= 1 and current_sol <= sol_data_list.size():
		return sol_data_list[current_sol - 1]
	return null

# ---------- game flow ----------
func start_game() -> void:
	current_sol = 0
	CoinSystem.reset()
	_sol_snapshots.clear()
	choices_made.clear()
	panels_clean = false
	greenhouse_working = true
	greenhouse_seed_bonus = false
	sol3_delayed_harvest = false
	sol5_dish_head_start = false


	var assembly := _get_assembly()
	if assembly:
		assembly.set_panels_clean(false)
		assembly.set_dish_fixed(false)
		assembly.set_greenhouse_patched(false)
		assembly.set_shelter_repaired(false)
		assembly.reset_lander()

	MeterSystem.reset()

	var scene := get_tree().current_scene
	var intro := scene.find_child("IntroSequence", true, false) if scene else null
	if intro and intro.has_method("play"):
		if not intro.intro_finished.is_connected(_on_intro_finished):
			intro.intro_finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)
		intro.play()
	else:
		advance_to_next_sol()

func _on_intro_finished() -> void:
	advance_to_next_sol()

func advance_to_next_sol() -> void:
	current_sol += 1
	repair_completed = false
	event_completed = false
	_sol_start_snapshot = MeterSystem.get_snapshot()
	CoinSystem.begin_sol()
	_record_sol_snapshot()
	_set_state(GameState.PLAYING)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	sol_started.emit(current_sol)

	_apply_sol_weather(current_sol, false)
	_spawn_bonus_tasks_for_sol(current_sol)

	var sd := get_current_sol_data()
	if sd and "objective_text" in sd:
		objective_updated.emit(sd.objective_text)
	else:
		objective_updated.emit("Sol %d" % current_sol)

func on_repair_completed() -> void:
	repair_completed = true
	CoinSystem.award(CoinSystem.REWARD_REPAIR, "repair")
	_show_toast("REPAIR COMPLETE  |  +%d COINS" % CoinSystem.REWARD_REPAIR)
	_apply_sol_weather(current_sol, true)

	var sd := get_current_sol_data()
	if sd and "event" in sd and sd.event:
		show_event.emit(sd.event)
		_set_state(GameState.EVENT_CARD)
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		event_completed = true
		objective_updated.emit("Go to bed (find the bed and hold E)")

func on_event_choice_made(choice_index: int) -> void:
	var sd := get_current_sol_data()
	if sd and "event" in sd and sd.event:
		var choice: Resource = sd.event.choices[choice_index]
		MeterSystem.apply_changes(
			choice.life_support_change,
			choice.power_change,
			choice.food_change,
			choice.shield_change,
		)
		choices_made.append({
			"sol": current_sol,
			"choice_text": choice.text,
			"choice_index": choice_index,
		})
		_apply_special_choice_effects(current_sol, choice_index)

	event_completed = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_set_state(GameState.PLAYING)
	objective_updated.emit("Go to bed")

func can_sleep() -> bool:
	return event_completed

func on_bed_interacted() -> void:
	if not can_sleep():
		_show_toast("COMPLETE PRIMARY OUTPOST REPAIR BEFORE SLEEPING")
		return
	start_night()

func start_night() -> void:
	_clear_bonus_tasks()
	_apply_night_rules()
	if MeterSystem.all_above_zero():
		CoinSystem.award(CoinSystem.REWARD_NIGHT, "night")   # survived the night
	var sd := get_current_sol_data()
	var fact := ""
	var source := ""
	if sd:
		if "night_fact" in sd:
			fact = sd.night_fact
		if "night_fact_source" in sd:
			source = sd.night_fact_source
	show_night_summary.emit(current_sol, fact, source)
	_set_state(GameState.NIGHT_SUMMARY)

func on_night_dismissed() -> void:
	if current_sol >= 6:
		var won := MeterSystem.all_above_zero()
		if won:
			CoinSystem.award(CoinSystem.REWARD_WIN, "win")
			var assembly := _get_assembly()
			if assembly:
				assembly.land_lander()
		show_debrief.emit(won)
		_set_state(GameState.DEBRIEF)
	else:
		if not MeterSystem.all_above_zero():
			show_debrief.emit(false)
			_set_state(GameState.DEBRIEF)
		else:
			advance_to_next_sol()

func _record_sol_snapshot() -> void:
	_sol_snapshots[current_sol] = {
		"meters": MeterSystem.get_snapshot(),
		"panels_clean": panels_clean,
		"greenhouse_working": greenhouse_working,
		"greenhouse_seed_bonus": greenhouse_seed_bonus,
		"sol3_delayed_harvest": sol3_delayed_harvest,
		"sol5_dish_head_start": sol5_dish_head_start,
		"choices": choices_made.duplicate(true),
		"coins": CoinSystem.total,
	}

## The sol a retry returns to: the start of the previous sol (never before Sol 1).
## Rewinding one sol lets the player undo the earlier choice that caused the failure.
func get_retry_target_sol() -> int:
	var target := maxi(1, current_sol - 1)
	if not _sol_snapshots.has(target):
		return current_sol
	return target

func retry_sol() -> void:
	var target := get_retry_target_sol()
	var snap: Dictionary = _sol_snapshots.get(target, {})
	if snap.is_empty():
		# No snapshot (should not happen): fall back to restarting the current sol.
		MeterSystem.restore_snapshot(_sol_start_snapshot)
	else:
		MeterSystem.restore_snapshot(snap["meters"])
		panels_clean = snap["panels_clean"]
		greenhouse_working = snap["greenhouse_working"]
		greenhouse_seed_bonus = snap["greenhouse_seed_bonus"]
		sol3_delayed_harvest = snap["sol3_delayed_harvest"]
		sol5_dish_head_start = snap["sol5_dish_head_start"]
		choices_made.clear()
		for entry in snap["choices"]:
			choices_made.append(entry)
		CoinSystem.restore(snap.get("coins", 0))

	current_sol = target
	CoinSystem.begin_sol()
	repair_completed = false
	event_completed = false
	get_tree().paused = false
	_sol_start_snapshot = MeterSystem.get_snapshot()
	_record_sol_snapshot()

	# Undo world changes made at or after the sol we are returning to.
	var assembly := _get_assembly()
	if assembly:
		assembly.set_panels_clean(panels_clean)
		assembly.set_greenhouse_patched(target > 4)
		assembly.set_shelter_repaired(target > 5)
		assembly.set_dish_fixed(false)
		assembly.reset_lander()
	for node in get_tree().get_nodes_in_group("interactables"):
		if node.has_method("reset") and node.get("interaction_type") == 0 \
				and int(node.get("sol_number")) >= target:
			node.reset()

	_set_state(GameState.PLAYING)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	sol_started.emit(current_sol)
	_apply_sol_weather(current_sol, false)
	_spawn_bonus_tasks_for_sol(current_sol)
	var sd := get_current_sol_data()
	if sd and "objective_text" in sd:
		objective_updated.emit(sd.objective_text)

# ---------- bonus field tasks ----------
func _clear_bonus_tasks() -> void:
	for node in _bonus_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_bonus_nodes.clear()
	_active_bonus_task = null
	_bonus_hold_time = 0.0

func _spawn_bonus_tasks_for_sol(sol_num: int) -> void:
	_clear_bonus_tasks()
	var scene := get_tree().current_scene
	if scene == null:
		return

	var tasks: Array = SOL_FIELD_TASKS.get(sol_num, [])

	for i in range(tasks.size()):
		var cfg: Dictionary = tasks[i]
		# Each task sits beside the named building. (Looking the name up as an assembly
		# marker never matched, so every task used to land in one spot by the spawn.)
		var base_pos := Locations.position_of(String(cfg.get("marker", "hab")))

		var beacon := Node3D.new()
		beacon.name = "BonusFieldTask_%d" % i
		beacon.set_meta("task_data", cfg)
		beacon.set_meta("completed", false)
		scene.add_child(beacon)
		beacon.global_position = base_pos + cfg.get("offset", Vector3.ZERO)

		var base_mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.14
		cyl.bottom_radius = 0.22
		cyl.height = 0.95
		base_mesh.mesh = cyl
		var base_mat := StandardMaterial3D.new()
		base_mat.albedo_color = Color("#1B2030")
		base_mesh.material_override = base_mat
		beacon.add_child(base_mesh)

		var orb := MeshInstance3D.new()
		orb.name = "BeaconOrb"
		var sphere := SphereMesh.new()
		sphere.radius = 0.16
		sphere.height = 0.32
		orb.mesh = sphere
		orb.position = Vector3(0.0, 0.68, 0.0)
		var orb_mat := StandardMaterial3D.new()
		orb_mat.albedo_color = Color("#4FD1C5")
		orb_mat.emission_enabled = true
		orb_mat.emission = Color("#4FD1C5")
		orb_mat.emission_energy_multiplier = 2.2
		orb.material_override = orb_mat
		beacon.add_child(orb)

		_bonus_nodes.append(beacon)

func _update_bonus_tasks(delta: float) -> void:
	if _bonus_nodes.is_empty():
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := scene.find_child("Player", true, false) as Node3D
	if player == null:
		return

	var t := Time.get_ticks_msec() * 0.004
	var nearest: Node3D = null
	var nearest_dist := 2.8

	for node in _bonus_nodes:
		if not is_instance_valid(node) or node.get_meta("completed", false):
			continue
		var orb := node.get_node_or_null("BeaconOrb") as Node3D
		if orb:
			orb.position.y = 0.68 + sin(t) * 0.07
		var d := player.global_position.distance_to(node.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = node

	if nearest != _active_bonus_task:
		if _active_bonus_task != null:
			interact_prompt_visible.emit(false, "")
		_active_bonus_task = nearest
		_bonus_hold_time = 0.0
		if _active_bonus_task != null:
			var data: Dictionary = _active_bonus_task.get_meta("task_data", {})
			interact_prompt_visible.emit(true, "[HOLD E] SCAN %s" % data.get("title", "FIELD DATA"))

	if _active_bonus_task != null:
		var holding_e := Input.is_key_pressed(KEY_E) or (InputMap.has_action("interact") and Input.is_action_pressed("interact"))
		if holding_e:
			_bonus_hold_time += delta
			var ratio := clampf(_bonus_hold_time / BONUS_SCAN_DURATION, 0.0, 1.0)
			repair_progress_updated.emit(ratio)
			if _bonus_hold_time >= BONUS_SCAN_DURATION:
				_complete_bonus_task(_active_bonus_task)
		elif _bonus_hold_time > 0.0:
			_bonus_hold_time = maxf(0.0, _bonus_hold_time - delta * 2.0)
			repair_progress_updated.emit(_bonus_hold_time / BONUS_SCAN_DURATION)

func _complete_bonus_task(node: Node3D) -> void:
	node.set_meta("completed", true)
	var data: Dictionary = node.get_meta("task_data", {})
	var meter_name: StringName = data.get("meter", &"power")
	var amount: float = data.get("delta", 8.0)
	MeterSystem.change_value(meter_name, amount)
	CoinSystem.award(CoinSystem.REWARD_FIELD_TASK, "field_task")

	var orb := node.get_node_or_null("BeaconOrb") as MeshInstance3D
	if orb and orb.material_override is StandardMaterial3D:
		var mat := orb.material_override as StandardMaterial3D
		mat.albedo_color = Color("#69A478")
		mat.emission = Color("#69A478")
		mat.emission_energy_multiplier = 0.6

	_active_bonus_task = null
	_bonus_hold_time = 0.0
	interact_prompt_visible.emit(false, "")
	_show_toast("%s  |  +%d COINS" % [data.get("note", "FIELD TELEMETRY LOGGED"), CoinSystem.REWARD_FIELD_TASK])

# ---------- dynamic weather ----------
func _apply_sol_weather(sol_num: int, stabilized: bool) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var is_storm := (sol_num == 1 or sol_num == 5) and not stabilized

	var world_env := scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_env and world_env.environment:
		world_env.environment.fog_density = 0.020 if is_storm else 0.006

	var sun := scene.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if sun:
		sun.light_energy = 1.25 if is_storm else 1.85
		sun.light_color = Color("#E88D5A") if is_storm else Color("#FFE2C4")

# ---------- toast notification ----------
func _build_toast_overlay() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 16
	_toast_layer.visible = false
	add_child(_toast_layer)

	# Compact pill under the HUD objective banner (and its sol-1 controls strip).
	_toast_panel = PanelContainer.new()
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_panel.offset_top = 140
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UITheme.make_flat_box(UITheme.SLATE_HUD, Color(1, 1, 1, 0.08), 1, 6, 18, 8, 6)
	box.border_color = UITheme.TEAL_CHIP
	box.border_width_left = 3
	_toast_panel.add_theme_stylebox_override("panel", box)
	_toast_layer.add_child(_toast_panel)

	_toast_label = UITheme.style_label(Label.new(), 15, UITheme.CREAM_SHEET, true)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_panel.add_child(_toast_label)

func _show_toast(msg: String) -> void:
	if _toast_label == null or _toast_layer == null:
		return
	_toast_label.text = msg.replace("  |  ", "   ·   ")
	_toast_layer.visible = true
	_toast_timer = 3.2
	_toast_panel.modulate.a = 0.0
	_toast_panel.offset_top = 128
	# Runs while the tree is paused too: the repair toast appears as the event card pauses the game.
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.tween_property(_toast_panel, "modulate:a", 1.0, 0.25)
	tw.tween_property(_toast_panel, "offset_top", 140.0, 0.25).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(_toast_panel, "modulate:a", 0.0, 0.4).set_delay(2.5)

# ---------- night rules ----------
func _apply_night_rules() -> void:
	MeterSystem.change_value(&"life_support", -8.0)
	MeterSystem.change_value(&"food", -8.0)

	if panels_clean:
		MeterSystem.change_value(&"power", 15.0)
	else:
		MeterSystem.change_value(&"power", 5.0)

	if greenhouse_working and MeterSystem.get_value(&"power") > 10.0:
		MeterSystem.change_value(&"food", 5.0)

	if greenhouse_seed_bonus:
		MeterSystem.change_value(&"food", 5.0)

	if sol3_delayed_harvest and current_sol >= 5:
		MeterSystem.change_value(&"food", 35.0)
		sol3_delayed_harvest = false

# ---------- special choice effects ----------
func _apply_special_choice_effects(sol: int, choice_idx: int) -> void:
	match sol:
		1:
			if choice_idx == 0 or choice_idx == 1:
				panels_clean = true
				var assembly := _get_assembly()
				if assembly:
					assembly.set_panels_clean(true)
		3:
			if choice_idx == 1:
				greenhouse_seed_bonus = true
			elif choice_idx == 2:
				sol3_delayed_harvest = true
		5:
			if choice_idx == 2:
				sol5_dish_head_start = true

# ---------- internals ----------
func _get_assembly() -> OutpostAssembly:
	var scene := get_tree().current_scene
	if scene:
		return scene.get_node_or_null("OutpostAssembly") as OutpostAssembly
	return null

func _set_state(new_state: int) -> void:
	current_state = new_state
	state_changed.emit(new_state)

func _on_meter_depleted(_meter_name: StringName) -> void:
	if current_state == GameState.PLAYING:
		show_debrief.emit(false)
		_set_state(GameState.DEBRIEF)
