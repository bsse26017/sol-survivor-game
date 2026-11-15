## The outpost map. Opened from the title screen's MAP button and in-game with M.
## Every location is named (same names as the 3D labels: both read Locations), the
## player is marked "YOU ARE HERE", the current sol's objective is highlighted and the
## optional field tasks still to scan show as small teal rings.
extends CanvasLayer

signal closed

var _root: Control
var _canvas: MapCanvas
var _sol_label: Label
var _paused_by_map := false


func _ready() -> void:
	layer = 16
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func open() -> void:
	if visible:
		return
	visible = true
	_paused_by_map = false
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.current_state == gm.GameState.PLAYING and not get_tree().paused:
		get_tree().paused = true    # the world holds still while you read the map
		_paused_by_map = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_header()
	_canvas.queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	if _paused_by_map:
		get_tree().paused = false
		_paused_by_map = false
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.current_state == gm.GameState.PLAYING and not get_tree().paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	closed.emit()


func _process(_delta: float) -> void:
	if visible and Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		if visible:
			close()
			get_viewport().set_input_as_handled()
		elif _can_open():
			open()
			get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


## Allowed on the title screen and while playing (also from the pause menu).
func _can_open() -> bool:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return true
	return gm.current_state == gm.GameState.TITLE or gm.current_state == gm.GameState.PLAYING


func _refresh_header() -> void:
	var gm := get_node_or_null("/root/GameManager")
	var sol: int = maxi(1, gm.current_sol) if gm else 1
	_sol_label.text = "SOL %d OBJECTIVE: %s" % [sol, String(Locations.find(Locations.objective_for_sol(sol)).get("name", "")).to_upper()]


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.086, 0.078, 0.102, 0.78)
	_root.add_child(dim)

	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -560
	frame.offset_right = 560
	frame.offset_top = -345
	frame.offset_bottom = 345
	frame.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.SLATE_PANEL, UITheme.CREAM_SHEET, 2, 0, 0, 0, 22))
	_root.add_child(frame)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	frame.add_child(outer)

	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.CREAM_SHEET, Color.TRANSPARENT, 0, 0, 28, 12))
	outer.add_child(header)
	var header_row := HBoxContainer.new()
	header.add_child(header_row)
	var title := UITheme.style_label(Label.new(), 26, UITheme.BASALT_DARK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text = "Outpost map"
	header_row.add_child(title)
	_sol_label = UITheme.style_label(Label.new(), 16, UITheme.TERRACOTTA, true)
	_sol_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_row.add_child(_sol_label)

	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	outer.add_child(margin)

	_canvas = MapCanvas.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_canvas)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 22)
	var footer_margin := MarginContainer.new()
	footer_margin.add_theme_constant_override("margin_left", 22)
	footer_margin.add_theme_constant_override("margin_right", 22)
	footer_margin.add_theme_constant_override("margin_bottom", 14)
	footer_margin.add_child(footer)
	outer.add_child(footer_margin)

	for item in [["BUILDING", Color("#8E93B5")], ["SOL OBJECTIVE", UITheme.TERRACOTTA],
			["FIELD TASK  +10", UITheme.TEAL_CHIP], ["YOU ARE HERE", UITheme.SAND_GOLD]]:
		var chip_row := HBoxContainer.new()
		chip_row.add_theme_constant_override("separation", 8)
		footer.add_child(chip_row)
		var swatch := PanelContainer.new()
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.add_theme_stylebox_override("panel", UITheme.make_flat_box(item[1], Color.TRANSPARENT, 0, 3, 0, 0))
		chip_row.add_child(swatch)
		var lbl := UITheme.style_label(Label.new(), 13, UITheme.TEXT_MUTED_LIGHT, true)
		lbl.text = item[0]
		chip_row.add_child(lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	var hint := UITheme.style_label(Label.new(), 13, UITheme.TEXT_MUTED_LIGHT, true)
	hint.text = "[M] or [ESC] to close"
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(hint)

	var close_btn := Button.new()
	close_btn.custom_minimum_size = Vector2(120, 38)
	close_btn.text = "CLOSE"
	UITheme.style_button(close_btn, 18, UITheme.TERRACOTTA, UITheme.TERRACOTTA_HOVER,
			UITheme.BASALT_DARK, Color.TRANSPARENT, 0, 2, 18, 6)
	close_btn.pressed.connect(close)
	footer.add_child(close_btn)


## Draws the plan view: +X to the right, -Z up (the hab is "north" of the spawn).
class MapCanvas extends Control:
	const WORLD_MIN := Vector2(-16.0, -12.0)
	const WORLD_MAX := Vector2(20.0, 14.0)
	const SPAWN_TRAIL_FROM := Vector3(-3.8, 0.0, 8.2)
	const SPAWN_TRAIL_TO := Vector3(-0.3, 0.0, -3.2)

	var _time := 0.0

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_time += delta
			queue_redraw()

	func _scale() -> float:
		return minf(size.x / (WORLD_MAX.x - WORLD_MIN.x), size.y / (WORLD_MAX.y - WORLD_MIN.y))

	func to_map(world: Vector3) -> Vector2:
		var s := _scale()
		var used := Vector2((WORLD_MAX.x - WORLD_MIN.x) * s, (WORLD_MAX.y - WORLD_MIN.y) * s)
		var origin := (size - used) * 0.5
		return origin + Vector2((world.x - WORLD_MIN.x) * s, (world.z - WORLD_MIN.y) * s)

	func _draw() -> void:
		var s := _scale()
		var font := UITheme.get_heavy_font()
		draw_rect(Rect2(Vector2.ZERO, size), Color("#10131C"))

		# 5 m grid
		for gx in range(-15, 21, 5):
			draw_line(to_map(Vector3(gx, 0, WORLD_MIN.y)), to_map(Vector3(gx, 0, WORLD_MAX.y)), Color(1, 1, 1, 0.05), 1.0)
		for gz in range(-10, 15, 5):
			draw_line(to_map(Vector3(WORLD_MIN.x, 0, gz)), to_map(Vector3(WORLD_MAX.x, 0, gz)), Color(1, 1, 1, 0.05), 1.0)

		# corridors (greenhouse - hab - workshop) and the boot-print trail to the hab door
		var hab := Locations.position_of("hab")
		draw_line(to_map(Locations.position_of("greenhouse")), to_map(hab), UITheme.SLATE_TRACK, 6.0)
		draw_line(to_map(hab), to_map(Locations.position_of("workshop")), UITheme.SLATE_TRACK, 6.0)
		draw_dashed_line(to_map(SPAWN_TRAIL_FROM), to_map(SPAWN_TRAIL_TO), Color(1, 1, 1, 0.28), 2.0, 7.0)

		var objective_id := _current_objective_id()
		for loc in Locations.all():
			_draw_location(loc, s, font, loc["id"] == objective_id)

		_draw_field_tasks()
		_draw_player(font)
		_draw_scale_bar(s, font)

	func _current_objective_id() -> String:
		var gm := get_node_or_null("/root/GameManager")
		var sol: int = maxi(1, gm.current_sol) if gm else 1
		return Locations.objective_for_sol(sol)

	func _draw_location(loc: Dictionary, s: float, font: Font, is_objective: bool) -> void:
		var centre := to_map(loc["pos"])
		var extent: Vector2 = loc["size"] * s
		var fill: Color = loc["color"]
		var half_h := extent.y * 0.5
		if loc["shape"] == "circle":
			var r := extent.x * 0.5
			half_h = r
			draw_circle(centre, r, Color(fill.r, fill.g, fill.b, 0.78))
			draw_arc(centre, r, 0.0, TAU, 48, UITheme.CREAM_SHEET, 2.0)
			if is_objective:
				_draw_objective_ring(centre, r + 8.0)
		else:
			var rect := Rect2(centre - extent * 0.5, extent)
			draw_rect(rect, Color(fill.r, fill.g, fill.b, 0.78))
			draw_rect(rect, UITheme.CREAM_SHEET, false, 2.0)
			if is_objective:
				_draw_objective_ring(centre, maxf(extent.x, extent.y) * 0.5 + 8.0)

		var text := String(loc["name"]).to_upper()
		var size_px := 15
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		var below: bool = loc.get("label_side", "above") == "below"
		var y := centre.y + half_h + 18.0 if below else centre.y - half_h - 9.0
		var pos := Vector2(centre.x - width * 0.5, y)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 5, Color("#10131C"))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, UITheme.CREAM_SHEET)
		if is_objective:
			var tag := "SOL OBJECTIVE"
			var tag_w := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var tag_pos := Vector2(centre.x - tag_w * 0.5, y + (15.0 if below else -15.0))
			draw_string_outline(font, tag_pos, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color("#10131C"))
			draw_string(font, tag_pos, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.TERRACOTTA_HOVER)

	func _draw_objective_ring(centre: Vector2, radius: float) -> void:
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		draw_arc(centre, radius + pulse * 3.0, 0.0, TAU, 48, Color(UITheme.TERRACOTTA, 0.55 + 0.45 * pulse), 3.0)

	func _draw_field_tasks() -> void:
		var gm := get_node_or_null("/root/GameManager")
		if gm == null:
			return
		for node in gm._bonus_nodes:
			if not is_instance_valid(node) or node.get_meta("completed", false):
				continue
			var p := to_map(node.global_position)
			draw_circle(p, 5.0, UITheme.TEAL_CHIP)
			draw_arc(p, 9.0 + sin(_time * 3.0) * 1.5, 0.0, TAU, 24, Color(UITheme.TEAL_CHIP, 0.7), 2.0)

	func _draw_player(font: Font) -> void:
		var scene := get_tree().current_scene
		if scene == null:
			return
		var player := scene.find_child("Player", true, false) as Node3D
		if player == null:
			return
		var p := to_map(player.global_position)
		var fwd := -player.global_transform.basis.z
		var dir := Vector2(fwd.x, fwd.z)
		dir = dir.normalized() if dir.length() > 0.001 else Vector2(0, -1)
		var pulse := 0.5 + 0.5 * sin(_time * 5.0)
		draw_arc(p, 14.0 + pulse * 4.0, 0.0, TAU, 32, Color(UITheme.SAND_GOLD, 0.6 - pulse * 0.3), 2.0)
		var tip := p + dir * 13.0
		var left := p + dir.rotated(2.5) * 9.0
		var right := p + dir.rotated(-2.5) * 9.0
		draw_colored_polygon(PackedVector2Array([tip, left, p - dir * 3.0, right]), UITheme.SAND_GOLD)
		draw_polyline(PackedVector2Array([tip, left, p - dir * 3.0, right, tip]), Color("#10131C"), 2.0)

		var text := "YOU ARE HERE"
		var size_px := 14
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		var box := Rect2(p + Vector2(-20.0 - (w + 18.0), -12.0), Vector2(w + 18.0, 24.0))
		if box.position.x < 0.0:
			box.position.x = p.x + 20.0
		draw_rect(box, UITheme.SAND_GOLD)
		draw_string(font, box.position + Vector2(9.0, 17.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, UITheme.BASALT_DARK)

	func _draw_scale_bar(s: float, font: Font) -> void:
		var start := Vector2(16.0, size.y - 18.0)
		draw_line(start, start + Vector2(5.0 * s, 0.0), UITheme.CREAM_SHEET, 2.0)
		draw_line(start + Vector2(0, -4), start + Vector2(0, 4), UITheme.CREAM_SHEET, 2.0)
		draw_line(start + Vector2(5.0 * s, -4), start + Vector2(5.0 * s, 4), UITheme.CREAM_SHEET, 2.0)
		draw_string(font, start + Vector2(5.0 * s + 8.0, 5.0), "5 M", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.TEXT_MUTED_LIGHT)
