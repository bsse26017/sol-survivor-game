class_name HUD
extends CanvasLayer

## In-game HUD.
##  - Top-left   VITALS card: all four meters (O2, power, food, shield) with bars and %.
##  - Top-centre OBJECTIVE banner: what to do now, where, and (sol 1) the controls.
##  - Top-right  SOL / COINS card, with a "+N" pop when coins are earned.
##  - Centre     reticle; bottom-centre hold-E prompt with a progress bar.

## A meter at or below this value turns terracotta and pulses.
const LOW_METER_THRESHOLD: float = 20.0
const TOTAL_SOLS: int = 6
const HINT_SECONDS: float = 25.0

const METERS := [
	{"id": &"life_support", "name": "OXYGEN", "icon": "lungs", "color": Color("#5EA394")},
	{"id": &"power", "name": "POWER", "icon": "lightning", "color": Color("#DFC896")},
	{"id": &"food", "name": "FOOD", "icon": "apple", "color": Color("#7DA87B")},
	{"id": &"shield", "name": "SHIELD", "icon": "shield", "color": Color("#8E9BD0")},
]

var _root_container: Control
var _crosshair: CrosshairReticle

# vitals: meter id -> {bar, fill_box, pct, row, color, value}
var _meter_rows: Dictionary = {}
var _vitals_panel: PanelContainer

# sol / coins
var _status_panel: PanelContainer
var _sol_label: Label
var _coin_label: Label
var _coin_pop: Label

# objective
var _objective_panel: PanelContainer
var _objective_caption: Label
var _objective_label: Label
var _objective_place: Label
var _place_chip: PanelContainer
var _controls_row: HBoxContainer
var _controls_panel: PanelContainer
var _hint_time: float = 0.0
var _hint_fading := false

# interaction prompt
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _prompt_bar: ProgressBar

var _pulse_time := 0.0


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_connect_signals()
	var gm := get_node_or_null("/root/GameManager")
	_apply_state(gm.current_state if gm else 0)


# ------------------------------------------------------------------ build
func _build_ui() -> void:
	_root_container = Control.new()
	_root_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root_container)

	_crosshair = CrosshairReticle.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.offset_left = -16
	_crosshair.offset_right = 16
	_crosshair.offset_top = -16
	_crosshair.offset_bottom = 16
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_container.add_child(_crosshair)

	_build_vitals()
	_build_status()
	_build_objective_banner()
	_build_prompt()
	_build_camera_hint()


func _card_style(accent: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box := UITheme.make_flat_box(UITheme.SLATE_HUD, Color(1, 1, 1, 0.08), 1, 6, 14, 10, 6)
	if accent.a > 0.0:
		box.border_color = accent
		box.border_width_left = 3
	return box


func _caption(text: String, color: Color = UITheme.SAND_GOLD) -> Label:
	var l := UITheme.style_label(Label.new(), 11, color, true)
	l.text = text
	l.add_theme_constant_override("line_spacing", 0)
	return l


## Four ring gauges (icon in the ring, value and name underneath) on a soft backing so
## they stay readable over the bright sky.
func _build_vitals() -> void:
	_vitals_panel = PanelContainer.new()
	_vitals_panel.position = Vector2(20, 18)
	_vitals_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitals_panel.add_theme_stylebox_override("panel",
			UITheme.make_flat_box(Color(0.106, 0.125, 0.188, 0.70), Color(1, 1, 1, 0.08), 1, 10, 14, 10, 6))
	_root_container.add_child(_vitals_panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	_vitals_panel.add_child(row)

	for m in METERS:
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 2)
		row.add_child(col)

		var gauge := RingGauge.new()
		gauge.custom_minimum_size = Vector2(52, 52)
		gauge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		gauge.ring_color = m["color"]
		gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(gauge)
		var icon := UITheme.make_vector_icon(m["icon"], Vector2(20, 20), m["color"], false)
		icon.set_anchors_preset(Control.PRESET_CENTER)
		icon.offset_left = -10
		icon.offset_right = 10
		icon.offset_top = -10
		icon.offset_bottom = 10
		gauge.add_child(icon)

		var pct := UITheme.style_label(Label.new(), 20, UITheme.CREAM_SHEET, true)
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pct.text = "--%"
		col.add_child(pct)

		var name_l := UITheme.style_label(Label.new(), 10, UITheme.TEXT_MUTED_LIGHT, true)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.text = m["name"]
		col.add_child(name_l)

		_meter_rows[m["id"]] = {"gauge": gauge, "icon": icon, "pct": pct, "row": col,
				"color": m["color"], "value": -1.0}


func _build_status() -> void:
	_status_panel = PanelContainer.new()
	_status_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_status_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_status_panel.offset_right = -20
	_status_panel.offset_top = 18
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_panel.add_theme_stylebox_override("panel", _card_style())
	_root_container.add_child(_status_panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	_status_panel.add_child(row)

	var sol_col := VBoxContainer.new()
	sol_col.add_theme_constant_override("separation", 0)
	sol_col.add_child(_caption("SOL"))
	_sol_label = UITheme.style_label(Label.new(), 22, UITheme.CREAM_SHEET, true)
	_sol_label.text = "1 / 6"
	sol_col.add_child(_sol_label)
	row.add_child(sol_col)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(1, 0)
	sep.color = Color(1, 1, 1, 0.14)
	row.add_child(sep)

	var coin_col := VBoxContainer.new()
	coin_col.add_theme_constant_override("separation", 0)
	coin_col.add_child(_caption("COINS"))
	var coin_row := HBoxContainer.new()
	coin_row.add_theme_constant_override("separation", 7)
	coin_row.add_child(UITheme.make_coin_icon(16.0))
	_coin_label = UITheme.style_label(Label.new(), 22, UITheme.SAND_GOLD, true)
	_coin_label.text = "0"
	coin_row.add_child(_coin_label)
	coin_col.add_child(coin_row)
	row.add_child(coin_col)

	# "+20" that floats up under the card when coins are earned.
	_coin_pop = UITheme.style_label(Label.new(), 20, UITheme.SAND_GOLD, true, true)
	_coin_pop.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_coin_pop.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_coin_pop.offset_right = -28
	_coin_pop.offset_top = 92
	_coin_pop.modulate.a = 0.0
	_coin_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_container.add_child(_coin_pop)


## Top-centre objective banner: tells the player what to do right now and where.
func _build_objective_banner() -> void:
	var holder := VBoxContainer.new()
	holder.set_anchors_preset(Control.PRESET_CENTER_TOP)
	holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
	holder.offset_top = 18
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.alignment = BoxContainer.ALIGNMENT_BEGIN
	holder.add_theme_constant_override("separation", 8)
	_root_container.add_child(holder)

	_objective_panel = PanelContainer.new()
	_objective_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_panel.add_theme_stylebox_override("panel", _card_style(UITheme.TERRACOTTA))
	holder.add_child(_objective_panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	_objective_panel.add_child(row)

	var target := ObjectiveMarker.new()
	target.custom_minimum_size = Vector2(22, 22)
	target.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(target)

	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 1)
	row.add_child(text_col)
	_objective_caption = _caption("SOL 1  //  OBJECTIVE", UITheme.TERRACOTTA_HOVER)
	text_col.add_child(_objective_caption)
	_objective_label = UITheme.style_label(Label.new(), 18, UITheme.CREAM_SHEET, true)
	_objective_label.text = ""
	text_col.add_child(_objective_label)

	_place_chip = PanelContainer.new()
	_place_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_place_chip.add_theme_stylebox_override("panel", UITheme.make_flat_box(Color(0.37, 0.64, 0.58, 0.22), UITheme.TEAL_CHIP, 1, 4, 10, 4))
	var chip_col := VBoxContainer.new()
	chip_col.add_theme_constant_override("separation", 0)
	_objective_place = UITheme.style_label(Label.new(), 13, UITheme.CREAM_SHEET, true)
	_objective_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip_col.add_child(_objective_place)
	var map_hint := UITheme.style_label(Label.new(), 10, UITheme.TEXT_MUTED_LIGHT, true)
	map_hint.text = "[M] MAP"
	map_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip_col.add_child(map_hint)
	_place_chip.add_child(chip_col)
	row.add_child(_place_chip)

	# Sol-1 controls strip: key chips under the banner, fades out after a while.
	_controls_panel = PanelContainer.new()
	_controls_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_controls_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls_panel.add_theme_stylebox_override("panel", UITheme.make_flat_box(Color(0.106, 0.125, 0.188, 0.62), Color.TRANSPARENT, 0, 6, 12, 5))
	holder.add_child(_controls_panel)
	_controls_row = HBoxContainer.new()
	_controls_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls_row.add_theme_constant_override("separation", 14)
	_controls_panel.add_child(_controls_row)
	for pair in [["WASD", "MOVE"], ["MOUSE", "LOOK"], ["SHIFT", "SPRINT"], ["SPACE", "JUMP"],
			["HOLD E", "INTERACT"], ["M", "MAP"], ["ESC", "PAUSE"]]:
		_controls_row.add_child(_key_hint(pair[0], pair[1]))


func _key_chip(key: String, size_px: int = 11) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.CREAM_SHEET, Color.TRANSPARENT, 0, 3, 6, 1))
	var l := UITheme.style_label(Label.new(), size_px, UITheme.BASALT_DARK, true)
	l.text = key
	chip.add_child(l)
	return chip


func _key_hint(key: String, action: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.add_child(_key_chip(key))
	var l := UITheme.style_label(Label.new(), 11, UITheme.CREAM_SHEET, true)
	l.text = action
	h.add_child(l)
	return h


func _build_prompt() -> void:
	_prompt_panel = PanelContainer.new()
	_prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt_panel.offset_bottom = -64
	_prompt_panel.custom_minimum_size = Vector2(360, 0)
	_prompt_panel.visible = false
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.add_theme_stylebox_override("panel", _card_style())
	_root_container.add_child(_prompt_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_prompt_panel.add_child(col)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	row.add_child(_key_chip("HOLD  E", 13))
	_prompt_label = UITheme.style_label(Label.new(), 15, UITheme.CREAM_SHEET, true)
	_prompt_label.text = "INTERACT"
	row.add_child(_prompt_label)

	_prompt_bar = ProgressBar.new()
	_prompt_bar.custom_minimum_size = Vector2(0, 6)
	_prompt_bar.show_percentage = false
	_prompt_bar.max_value = 1.0
	_prompt_bar.add_theme_stylebox_override("background", UITheme.make_flat_box(Color(1, 1, 1, 0.08), Color.TRANSPARENT, 0, 3, 0, 0))
	_prompt_bar.add_theme_stylebox_override("fill", UITheme.make_flat_box(UITheme.TERRACOTTA, Color.TRANSPARENT, 0, 3, 0, 0))
	col.add_child(_prompt_bar)


# ------------------------------------------------------------------ signals
func _connect_signals() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.objective_updated.connect(_set_objective)
		gm.state_changed.connect(_apply_state)
		gm.sol_started.connect(func(_s: int) -> void: refresh())
		gm.interact_prompt_visible.connect(_on_interact_prompt_visible)
		gm.repair_progress_updated.connect(_on_repair_progress_updated)

	var coins := get_node_or_null("/root/CoinSystem")
	if coins:
		coins.coins_changed.connect(_on_coins_changed)

	var ms := get_node_or_null("/root/MeterSystem")
	if ms:
		ms.meter_changed.connect(func(_n, _o, _v) -> void: refresh())


func _apply_state(new_state: int) -> void:
	# Hidden on the title (0) and on the debrief (4); the debrief state also persists
	# through the intro briefing after "Play Again", so the HUD stays hidden there too.
	_root_container.visible = (new_state != 0 and new_state != 4)
	var playing := new_state == 1
	# Sol / coins stay up behind the event card so the "+20" from a repair lands on the card.
	_status_panel.visible = playing or new_state == 2
	_crosshair.visible = playing
	_objective_panel.visible = playing
	if not playing:
		_prompt_panel.visible = false
		_crosshair.set_focused(false)
	_update_controls_hint(true)
	refresh()


func _set_objective(text: String) -> void:
	var gm := get_node_or_null("/root/GameManager")
	var sol: int = maxi(1, gm.current_sol) if gm else 1
	_objective_caption.text = "SOL %d  //  OBJECTIVE" % sol
	_objective_label.text = text.replace(" â€” ", " - ")
	var place := ""
	if not text.to_lower().begins_with("go to bed"):
		var loc := Locations.find(Locations.objective_for_sol(sol))
		if not loc.is_empty():
			place = String(loc["name"])
	else:
		place = "Hab"
	_objective_place.text = place
	_place_chip.visible = place != ""
	# Draw the eye when the objective changes.
	_objective_panel.pivot_offset = _objective_panel.size * 0.5
	var tw := create_tween()
	_objective_panel.modulate = Color(1.6, 1.4, 1.2, 1.0)
	_objective_panel.scale = Vector2(1.04, 1.04)
	tw.set_parallel(true)
	tw.tween_property(_objective_panel, "modulate", Color.WHITE, 0.6)
	tw.tween_property(_objective_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_coins_changed(total: int, delta: int, _reason: String) -> void:
	_coin_label.text = str(total)
	if delta <= 0 or not _status_panel.is_visible_in_tree():
		return
	_coin_pop.text = "+%d" % delta
	_coin_pop.modulate.a = 1.0
	_coin_pop.offset_top = _status_panel.get_rect().end.y + 2.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_coin_pop, "offset_top", _coin_pop.offset_top + 14.0, 1.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(_coin_pop, "modulate:a", 0.0, 0.7).set_delay(0.6)
	_coin_label.pivot_offset = _coin_label.size * 0.5
	_coin_label.scale = Vector2(1.3, 1.3)
	create_tween().tween_property(_coin_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_interact_prompt_visible(is_vis: bool, text: String) -> void:
	_prompt_panel.visible = is_vis
	_crosshair.set_focused(is_vis)
	if is_vis:
		_prompt_label.text = _clean_prompt(text)
		_prompt_bar.value = 0.0


## Prompts arrive as "Hold E to flip the breaker" or "[HOLD E] SCAN X"; the key chip
## already says HOLD E, so keep only the action.
static func _clean_prompt(text: String) -> String:
	var t := text.strip_edges()
	for prefix in ["[HOLD E] ", "Hold E to ", "HOLD E TO ", "Hold E "]:
		if t.begins_with(prefix):
			t = t.substr(prefix.length())
			break
	return t


func _on_repair_progress_updated(progress: float) -> void:
	_prompt_bar.value = clampf(progress, 0.0, 1.0)


# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	_pulse_time += delta
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and gm.current_state == 1:
		_hint_time += delta
	_update_controls_hint(false)

	# Critical meters pulse.
	var pulse := 0.55 + 0.45 * sin(_pulse_time * 6.0)
	for id in _meter_rows:
		var r: Dictionary = _meter_rows[id]
		var critical: bool = r["value"] >= 0.0 and r["value"] <= LOW_METER_THRESHOLD
		(r["row"] as Control).modulate.a = pulse if critical else 1.0


func _update_controls_hint(immediate: bool) -> void:
	if _controls_row == null:
		return
	var gm := get_node_or_null("/root/GameManager")
	var wanted: bool = gm != null and gm.current_state == 1 and gm.current_sol <= 1 and _hint_time < HINT_SECONDS
	if wanted:
		_controls_panel.visible = true
		_controls_panel.modulate.a = 1.0
		_hint_fading = false
	elif _controls_panel.visible and not _hint_fading:
		if immediate:
			_controls_panel.visible = false
		else:
			_hint_fading = true
			var tw := create_tween()
			tw.tween_property(_controls_panel, "modulate:a", 0.0, 0.8)
			tw.tween_callback(func() -> void:
				_controls_panel.visible = false
				_hint_fading = false)


func refresh() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		_sol_label.text = "%d / %d" % [clampi(gm.current_sol, 1, TOTAL_SOLS), TOTAL_SOLS]

	var ms := get_node_or_null("/root/MeterSystem")
	if ms == null:
		return
	for id in _meter_rows:
		_set_meter(id, ms.get_value(id))


func _set_meter(id: StringName, value: float) -> void:
	var r: Dictionary = _meter_rows[id]
	var gauge: RingGauge = r["gauge"]
	var pct: Label = r["pct"]
	var critical := value <= LOW_METER_THRESHOLD
	var colour: Color = UITheme.TERRACOTTA if critical else r["color"]
	gauge.ring_color = colour
	(r["icon"] as Control).set("tint", colour)
	(r["icon"] as Control).queue_redraw()
	pct.text = "%d%%" % int(round(value))
	pct.add_theme_color_override("font_color", UITheme.TERRACOTTA_HOVER if critical else UITheme.CREAM_SHEET)
	var old: float = r["value"]
	r["value"] = value
	if old < 0.0 or not gauge.is_visible_in_tree():
		gauge.value = value
	else:
		create_tween().tween_property(gauge, "value", value, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ widgets
class CrosshairReticle extends Control:
	var _focused: bool = false

	func set_focused(active: bool) -> void:
		if _focused != active:
			_focused = active
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		if _focused:
			draw_arc(c, 8.5, 0.0, TAU, 24, Color(0.086, 0.078, 0.102, 0.55), 3.0, true)
			draw_arc(c, 8.5, 0.0, TAU, 24, UITheme.TERRACOTTA, 1.8, true)
			draw_circle(c, 2.4, UITheme.CREAM_SHEET)
		else:
			draw_circle(c, 3.0, Color(0.086, 0.078, 0.102, 0.45))
			draw_circle(c, 2.0, Color(0.96, 0.94, 0.90, 0.85))


## Small target glyph with a slow pulse, used on the objective banner.
class ObjectiveMarker extends Control:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.0
		var p := 0.5 + 0.5 * sin(_t * 3.0)
		draw_arc(c, r, 0.0, TAU, 32, Color(UITheme.TERRACOTTA, 0.45 + 0.4 * p), 2.0, true)
		draw_arc(c, r * 0.55, 0.0, TAU, 24, UITheme.TERRACOTTA_HOVER, 2.0, true)
		draw_circle(c, 2.2, UITheme.CREAM_SHEET)


## Circular meter: faint full track, coloured arc from 12 o'clock clockwise to the value,
## with a soft glow pass under it.
class RingGauge extends Control:
	var ring_color: Color = Color.WHITE:
		set(c):
			ring_color = c
			queue_redraw()
	var value: float = 0.0:
		set(v):
			value = clampf(v, 0.0, 100.0)
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 4.0
		draw_circle(c, r + 3.0, Color(0.086, 0.078, 0.102, 0.55))
		draw_arc(c, r, 0.0, TAU, 64, Color(1, 1, 1, 0.10), 5.0, true)
		if value <= 0.0:
			return
		var start := -PI * 0.5
		var end := start + TAU * value / 100.0
		draw_arc(c, r, start, end, 64, Color(ring_color, 0.25), 9.0, true)
		draw_arc(c, r, start, end, 64, ring_color, 5.0, true)
		# rounded cap at the tip
		draw_circle(c + Vector2(cos(end), sin(end)) * r, 2.5, ring_color)
		draw_circle(c + Vector2(cos(start), sin(start)) * r, 2.5, ring_color)

func _build_camera_hint() -> void:
	var bot_right := PanelContainer.new()
	bot_right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bot_right.offset_left = -240
	bot_right.offset_right = -20
	bot_right.offset_top = -40
	bot_right.offset_bottom = -16
	bot_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_right.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.SLATE_HUD, Color(1, 1, 1, 0.08), 1, 4, 10, 4))
	_root_container.add_child(bot_right)

	var cam_hint := UITheme.style_label(Label.new(), 11, UITheme.TEXT_MUTED_LIGHT)
	cam_hint.text = "ARROWS: 360° CAM | C: TOGGLE"
	cam_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bot_right.add_child(cam_hint)
