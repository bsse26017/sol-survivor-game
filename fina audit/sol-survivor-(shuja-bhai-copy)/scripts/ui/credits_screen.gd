class_name CreditsScreen
extends CanvasLayer

signal closed

var _root: Control

const NASA_SOURCES := [
	{"title": "CURIOSITY ROVER REMS", "desc": "Gale crater weather telemetry and temperature mapping"},
	{"title": "CURIOSITY RAD DETECTOR", "desc": "Surface radiation dosage & galactic cosmic ray mapping"},
	{"title": "NASA DONKI SPACE WEATHER", "desc": "CME Tracking and space weather database"},
	{"title": "CIP MARS CROP RESEARCH", "desc": "Potato crop growth simulations in Martian regolith"},
]

const DEV_CREDITS := [
	{"title": "ENGINE: GODOT 4.7", "desc": "Developed using the open-source Godot engine"},
	{"title": "3D ART: BLENDER LOW-POLY KIT", "desc": "Built with 3D low-poly models, inspired by Astroneer and Firewatch"},
	{"title": "SOL SURVIVOR TEAM", "desc": "A submission for the NASA Space Apps Challenge 2026"},
]

func _ready() -> void:
	layer = 15
	visible = false
	_build_ui()

func _process(_delta: float) -> void:
	if visible and Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Full-screen warm dark dim overlay matching concept render
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.086, 0.078, 0.102, 0.62)
	_root.add_child(dim)

	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -435
	frame.offset_right = 435
	frame.offset_top = -245
	frame.offset_bottom = 245
	frame.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.SLATE_PANEL, UITheme.CREAM_SHEET, 2, 0, 0, 0, 22))
	_root.add_child(frame)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 0)
	frame.add_child(outer_vbox)

	# Top Solar-Array Schematic Strip with SOL Badges
	var strip_wrap := Control.new()
	strip_wrap.custom_minimum_size = Vector2(0, 26)
	outer_vbox.add_child(strip_wrap)

	var solar_grid := UITheme.make_vector_icon("solar_strip", Vector2.ZERO, Color.WHITE)
	solar_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	strip_wrap.add_child(solar_grid)

	for is_right in [false, true]:
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.BASALT_DARK, UITheme.CREAM_SHEET, 1, 0, 8, 2))
		if is_right:
			badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			badge.offset_left = -46
			badge.offset_bottom = 26
		else:
			badge.offset_right = 46
			badge.offset_bottom = 26
		strip_wrap.add_child(badge)

		var b_lbl := UITheme.style_label(Label.new(), 11, UITheme.CREAM_SHEET, true)
		b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b_lbl.text = "SOL"
		badge.add_child(b_lbl)

	# Cream Banner Header
	var header_panel := PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.CREAM_SHEET, Color.TRANSPARENT, 0, 0, 28, 14))
	outer_vbox.add_child(header_panel)

	var header_lbl := UITheme.style_label(Label.new(), 26, UITheme.BASALT_DARK, true)
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.text = "NASA DATA SOURCES & MISSION CREDITS"
	header_panel.add_child(header_lbl)

	# Two-Column Dark Slate Body
	var body_margin := MarginContainer.new()
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_margin.add_theme_constant_override("margin_left", 28)
	body_margin.add_theme_constant_override("margin_right", 28)
	body_margin.add_theme_constant_override("margin_top", 20)
	body_margin.add_theme_constant_override("margin_bottom", 20)
	outer_vbox.add_child(body_margin)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	body_margin.add_child(cols)

	# Column 01: NASA Data
	var col_left := VBoxContainer.new()
	col_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_left.add_theme_constant_override("separation", 11)
	cols.add_child(col_left)

	var hdr_l := UITheme.style_label(Label.new(), 18, UITheme.CREAM_SHEET, true)
	hdr_l.text = "01 // NASA DATA"
	col_left.add_child(hdr_l)

	for item in NASA_SOURCES:
		col_left.add_child(_make_entry(item["title"], item["desc"]))

	# Vertical Divider
	var v_div := ColorRect.new()
	v_div.custom_minimum_size = Vector2(1, 0)
	v_div.color = Color(1, 1, 1, 0.18)
	cols.add_child(v_div)

	# Column 02: Development
	var col_right := VBoxContainer.new()
	col_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_right.add_theme_constant_override("separation", 11)
	cols.add_child(col_right)

	var hdr_r := UITheme.style_label(Label.new(), 18, UITheme.CREAM_SHEET, true)
	hdr_r.text = "02 // DEVELOPMENT"
	col_right.add_child(hdr_r)

	for item in DEV_CREDITS:
		col_right.add_child(_make_entry(item["title"], item["desc"]))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_right.add_child(spacer)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	col_right.add_child(btn_row)

	var close_btn := Button.new()
	close_btn.custom_minimum_size = Vector2(114, 42)
	close_btn.text = "CLOSE"
	UITheme.style_button(
		close_btn, 18,
		UITheme.TERRACOTTA, UITheme.TERRACOTTA_HOVER,
		UITheme.BASALT_DARK,
		Color.TRANSPARENT, 0, 2, 18, 8
	)
	close_btn.pressed.connect(_close)
	btn_row.add_child(close_btn)

func _make_entry(title_text: String, desc_text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var t := UITheme.style_label(Label.new(), 15, UITheme.CREAM_SHEET, true)
	t.text = title_text
	box.add_child(t)

	var d := UITheme.style_label(Label.new(), 13, UITheme.TEXT_MUTED_LIGHT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.text = desc_text
	box.add_child(d)

	return box

func _close() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
