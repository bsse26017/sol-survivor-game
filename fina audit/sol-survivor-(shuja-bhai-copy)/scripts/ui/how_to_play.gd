## "How to play" page: goal, controls, the four meters, the flow of one sol and how
## to earn coins. Opened from the title screen (and the pause menu); Back / Esc closes.
class_name HowToPlayScreen
extends CanvasLayer

signal closed

const CONTROLS := [
	["W A S D", "Move"],
	["MOUSE", "Look around"],
	["SPACE", "Jump"],
	["SHIFT", "Sprint"],
	["HOLD E", "Repair / interact"],
	["ESC", "Pause"],
	["M", "Open the map"],
]

const METERS := [
	["lungs", "LIFE SUPPORT", "Air for the crew"],
	["lightning", "POWER", "Runs heat, air and the dish"],
	["apple", "FOOD", "The greenhouse keeps you fed"],
	["shield", "SHIELD", "Protection from radiation"],
]

const SOL_FLOW := [
	["1", "REPAIR", "Fix that sol's system (hold E)"],
	["2", "EVENT CARD", "Choose how to handle the event"],
	["3", "BED", "Hold E on the bed to sleep"],
	["4", "NIGHT SUMMARY", "See what the night cost you"],
]

const COIN_RULES := [
	["+20", "Main repair completed"],
	["+10", "Optional field task (2 each sol, in different places)"],
	["+25", "Survive the night"],
	["+50", "Win the game"],
]

var _root: Control


func _ready() -> void:
	layer = 15
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func open() -> void:
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _process(_delta: float) -> void:
	if visible and Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.086, 0.078, 0.102, 0.72)
	_root.add_child(dim)

	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -520
	frame.offset_right = 520
	frame.offset_top = -330
	frame.offset_bottom = 330
	frame.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.SLATE_PANEL, UITheme.CREAM_SHEET, 2, 0, 0, 0, 22))
	_root.add_child(frame)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	frame.add_child(outer)

	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.CREAM_SHEET, Color.TRANSPARENT, 0, 0, 28, 14))
	outer.add_child(header)
	var header_lbl := UITheme.style_label(Label.new(), 26, UITheme.BASALT_DARK, true)
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.text = "How to play"
	header.add_child(header_lbl)

	var body := MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("margin_left", 30)
	body.add_theme_constant_override("margin_right", 30)
	body.add_theme_constant_override("margin_top", 20)
	body.add_theme_constant_override("margin_bottom", 18)
	outer.add_child(body)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	body.add_child(cols)

	# ---- left column: goal + controls ----
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	cols.add_child(left)

	left.add_child(_section("01 // Goal"))
	left.add_child(_text("Survive 6 sols. Fix the comms dish and call the crew down to rescue you.", 16, UITheme.CREAM_SHEET))

	left.add_child(_section("02 // Controls"))
	for entry in CONTROLS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		left.add_child(row)
		row.add_child(_key_chip(entry[0]))
		var action := _text(entry[1], 16, UITheme.CREAM_SHEET)
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(action)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(1, 0)
	divider.color = Color(1, 1, 1, 0.18)
	cols.add_child(divider)

	# ---- right column: meters, flow of a sol, coins ----
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	cols.add_child(right)

	right.add_child(_section("03 // The 4 meters"))
	for m in METERS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		right.add_child(row)
		row.add_child(UITheme.make_vector_icon(m[0], Vector2(16, 16), UITheme.TEAL_CHIP))
		var name_lbl := UITheme.style_label(Label.new(), 14, UITheme.CREAM_SHEET, true)
		name_lbl.custom_minimum_size = Vector2(128, 0)
		name_lbl.text = m[1]
		row.add_child(name_lbl)
		var desc := _text(m[2], 14, UITheme.TEXT_MUTED_LIGHT)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc)
	right.add_child(_text("If any meter hits 0, the mission fails.", 14, UITheme.TERRACOTTA_HOVER))

	right.add_child(_section("04 // Flow of one sol"))
	for step in SOL_FLOW:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		right.add_child(row)
		row.add_child(_number_chip(step[0]))
		var name_lbl := UITheme.style_label(Label.new(), 14, UITheme.CREAM_SHEET, true)
		name_lbl.custom_minimum_size = Vector2(128, 0)
		name_lbl.text = step[1]
		row.add_child(name_lbl)
		var desc := _text(step[2], 14, UITheme.TEXT_MUTED_LIGHT)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc)

	right.add_child(_section("05 // How to earn coins"))
	for rule in COIN_RULES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		right.add_child(row)
		var amount := PanelContainer.new()
		amount.custom_minimum_size = Vector2(54, 0)
		amount.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.SAND_GOLD, Color.TRANSPARENT, 0, 3, 6, 2))
		row.add_child(amount)
		var amount_lbl := UITheme.style_label(Label.new(), 14, UITheme.BASALT_DARK)
		amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amount_lbl.text = rule[0]
		amount.add_child(amount_lbl)
		var desc := _text(rule[1], 14, UITheme.CREAM_SHEET)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(btn_row)
	var back := Button.new()
	back.custom_minimum_size = Vector2(130, 42)
	back.text = "BACK"
	UITheme.style_button(back, 18, UITheme.TERRACOTTA, UITheme.TERRACOTTA_HOVER,
			UITheme.BASALT_DARK, Color.TRANSPARENT, 0, 2, 18, 8)
	back.pressed.connect(close)
	btn_row.add_child(back)


func _section(title: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var lbl := UITheme.style_label(Label.new(), 18, UITheme.CREAM_SHEET, true)
	lbl.text = title
	box.add_child(lbl)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.color = Color(1, 1, 1, 0.22)
	box.add_child(line)
	return box


func _text(text: String, size: int, colour: Color) -> Label:
	var lbl := UITheme.style_label(Label.new(), size, colour)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.text = text
	return lbl


func _key_chip(text: String) -> Control:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(112, 0)
	chip.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.SLATE_TRACK, UITheme.CREAM_SHEET, 1, 3, 8, 4))
	var lbl := UITheme.style_label(Label.new(), 14, UITheme.CREAM_SHEET, true)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.text = text
	chip.add_child(lbl)
	return chip


func _number_chip(text: String) -> Control:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(24, 24)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.TERRACOTTA, Color.TRANSPARENT, 0, 12, 0, 0))
	var lbl := UITheme.style_label(Label.new(), 13, UITheme.BASALT_DARK)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.text = text
	chip.add_child(lbl)
	return chip
