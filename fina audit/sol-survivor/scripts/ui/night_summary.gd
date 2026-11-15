class_name NightSummaryUI
extends CanvasLayer

signal continue_pressed

var _root: Control
var _header_label: Label
var _rows_box: VBoxContainer
var _nasa_header: Label
var _nasa_body: Label
var _continue_btn: Button
var _day_snapshot: Dictionary = {}

const METER_CONFIG := [
	{"key": "life_support", "label": "OXYGEN", "glyph": "lungs"},
	{"key": "power", "label": "POWER", "glyph": "lightning"},
	{"key": "food", "label": "FOOD", "glyph": "apple"},
	{"key": "shield", "label": "SHIELD", "glyph": "shield"},
]

func _ready() -> void:
	layer = 13
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.sol_started.connect(func(_s: int) -> void: _capture_snapshot())
		gm.show_night_summary.connect(_on_show_night_summary)
		gm.state_changed.connect(func(st: int) -> void:
			if st == 1:
				_capture_snapshot()
			elif st != 3:
				visible = false
		)

func _process(_delta: float) -> void:
	if visible and Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _capture_snapshot() -> void:
	var ms := get_node_or_null("/root/MeterSystem")
	if ms and ms.has_method("get_snapshot"):
		_day_snapshot = ms.get_snapshot()

func _on_show_night_summary(sol_number: int, fact: String, source: String) -> void:
	var ms := get_node_or_null("/root/MeterSystem")
	var after: Dictionary = ms.get_snapshot() if (ms and ms.has_method("get_snapshot")) else {}
	var before := _day_snapshot if not _day_snapshot.is_empty() else after
	var loc := source if source != "" else "GALE CRATER"
	var body := fact if fact != "" else "MARS GETS ONLY 43% OF THE SUNLIGHT EARTH DOES. SOLAR PANELS ON MARS NEED TO BE MUCH LARGER, AND DUST STORMS CAN BLOCK EVEN MORE LIGHT!"
	populate(sol_number, before, after, loc, body)
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_continue() -> void:
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	continue_pressed.emit()
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.on_night_dismissed()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -480
	frame.offset_right = 480
	frame.offset_top = -245
	frame.offset_bottom = 245
	frame.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.CREAM_SHEET, UITheme.BASALT_DARK, 3, 0, 18, 18, 20))
	_root.add_child(frame)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 18)
	frame.add_child(main_vbox)

	var top_bar := PanelContainer.new()
	top_bar.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.SLATE_PANEL, Color.TRANSPARENT, 0, 0, 20, 14))
	main_vbox.add_child(top_bar)

	_header_label = UITheme.style_label(Label.new(), 28, UITheme.CREAM_SHEET, true)
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.text = "SOL 01 COMPLETE // NIGHT TELEMETRY LOG"
	top_bar.add_child(_header_label)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	main_vbox.add_child(columns)

	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.size_flags_stretch_ratio = 1.48
	_rows_box.add_theme_constant_override("separation", 8)
	columns.add_child(_rows_box)

	var v_div := ColorRect.new()
	v_div.custom_minimum_size = Vector2(1, 0)
	v_div.color = Color(0.086, 0.078, 0.102, 0.32)
	columns.add_child(v_div)

	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 1.0
	right_col.add_theme_constant_override("separation", 10)
	columns.add_child(right_col)

	_nasa_header = UITheme.style_label(Label.new(), 14, UITheme.BASALT_DARK, true)
	_nasa_header.text = "NASA FIELD DATA // GALE CRATER"
	# Long source names must wrap inside the card instead of overflowing its edge.
	_nasa_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nasa_header.custom_minimum_size.x = 1.0
	_nasa_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_child(_nasa_header)

	var note_wrap := Control.new()
	note_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(note_wrap)

	var note_bg := UITheme.make_vector_icon("chamfer_note", Vector2.ZERO, UITheme.CREAM_NOTE, false)
	note_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	note_wrap.add_child(note_bg)

	var note_margin := MarginContainer.new()
	note_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	note_margin.add_theme_constant_override("margin_left", 16)
	note_margin.add_theme_constant_override("margin_right", 18)
	note_margin.add_theme_constant_override("margin_top", 14)
	note_margin.add_theme_constant_override("margin_bottom", 16)
	note_wrap.add_child(note_margin)

	_nasa_body = UITheme.style_label(Label.new(), 15, UITheme.BASALT_DARK, true)
	_nasa_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_margin.add_child(_nasa_body)

	var cta_wrap := Control.new()
	cta_wrap.custom_minimum_size = Vector2(0, 62)
	right_col.add_child(cta_wrap)

	var bracket_tl := UITheme.make_vector_icon("bracket_tl", Vector2(12, 12), UITheme.BASALT_DARK, false)
	bracket_tl.position = Vector2(0, 0)
	cta_wrap.add_child(bracket_tl)

	var bracket_tr := UITheme.make_vector_icon("bracket_tr", Vector2(12, 12), UITheme.BASALT_DARK, false)
	bracket_tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bracket_tr.offset_left = -12
	bracket_tr.offset_bottom = 12
	cta_wrap.add_child(bracket_tr)

	var bracket_bl := UITheme.make_vector_icon("bracket_bl", Vector2(12, 12), UITheme.BASALT_DARK, false)
	bracket_bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bracket_bl.offset_right = 12
	bracket_bl.offset_top = -12
	cta_wrap.add_child(bracket_bl)

	var bracket_br := UITheme.make_vector_icon("bracket_br", Vector2(12, 12), UITheme.BASALT_DARK, false)
	bracket_br.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bracket_br.offset_left = -12
	bracket_br.offset_top = -12
	cta_wrap.add_child(bracket_br)

	_continue_btn = Button.new()
	_continue_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_continue_btn.offset_left = 8
	_continue_btn.offset_right = -8
	_continue_btn.offset_top = 8
	_continue_btn.offset_bottom = -8
	_continue_btn.text = "CONTINUE TO SOL 02"
	UITheme.style_button(
		_continue_btn, 18,
		UITheme.TERRACOTTA, UITheme.TERRACOTTA_HOVER,
		UITheme.BASALT_DARK,
		Color.TRANSPARENT, 0, 2, 14, 8
	)
	_continue_btn.pressed.connect(_on_continue)
	cta_wrap.add_child(_continue_btn)

func populate(sol_num: int, before: Dictionary, after: Dictionary, location_tag: String, nasa_fact: String) -> void:
	_header_label.text = "SOL %02d COMPLETE // NIGHT TELEMETRY LOG" % sol_num
	_nasa_header.text = "NASA FIELD DATA // %s" % location_tag
	_nasa_body.text = nasa_fact
	_continue_btn.text = "FINAL MISSION DEBRIEF" if sol_num >= 6 else "CONTINUE TO SOL %02d" % (sol_num + 1)

	for child in _rows_box.get_children():
		child.queue_free()

	for i in range(METER_CONFIG.size()):
		var cfg: Dictionary = METER_CONFIG[i]
		var key: String = cfg["key"]
		var prev_val := int(round(before.get(key, before.get(StringName(key), 50))))
		var next_val := int(round(after.get(key, after.get(StringName(key), 50))))
		var diff := next_val - prev_val

		var row := HBoxContainer.new()
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 14)
		_rows_box.add_child(row)

		var icon := UITheme.make_vector_icon(cfg["glyph"], Vector2(32, 32), UITheme.SLATE_PANEL, true)
		row.add_child(icon)

		var name_lbl := UITheme.style_label(Label.new(), 22, UITheme.BASALT_DARK, true)
		name_lbl.custom_minimum_size = Vector2(124, 0)
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.text = cfg["label"]
		row.add_child(name_lbl)

		var trans_box := HBoxContainer.new()
		trans_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		trans_box.add_theme_constant_override("separation", 10)
		row.add_child(trans_box)

		var prev_lbl := UITheme.style_label(Label.new(), 22, UITheme.BASALT_DARK)
		prev_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		prev_lbl.text = "%d%%" % prev_val
		trans_box.add_child(prev_lbl)

		var arrow := UITheme.make_vector_icon("arrow_right", Vector2(22, 16), UITheme.BASALT_DARK, true)
		trans_box.add_child(arrow)

		var next_lbl := UITheme.style_label(Label.new(), 22, UITheme.BASALT_DARK)
		next_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		next_lbl.text = "%d%%" % next_val
		trans_box.add_child(next_lbl)

		var badge_color := UITheme.SAND_NEUTRAL
		var diff_str := "0%"
		if diff > 0:
			badge_color = UITheme.SAGE_POSITIVE
			diff_str = "+%d%%" % diff
		elif diff < 0:
			badge_color = UITheme.TERRACOTTA
			diff_str = "%d%%" % diff

		var delta_box := PanelContainer.new()
		delta_box.custom_minimum_size = Vector2(86, 42)
		delta_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		delta_box.add_theme_stylebox_override("panel", UITheme.make_flat_box(badge_color, Color.TRANSPARENT, 0, 2, 8, 4))
		row.add_child(delta_box)

		var delta_lbl := UITheme.style_label(Label.new(), 20, UITheme.BASALT_DARK)
		delta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		delta_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		delta_lbl.text = diff_str
		delta_box.add_child(delta_lbl)

		if i < METER_CONFIG.size() - 1:
			var h_div := ColorRect.new()
			h_div.custom_minimum_size = Vector2(0, 1)
			h_div.color = Color(0.086, 0.078, 0.102, 0.30)
			_rows_box.add_child(h_div)

	_add_coin_row()


## Coins earned this sol and the running total, under the four meter rows.
func _add_coin_row() -> void:
	var coins := get_node_or_null("/root/CoinSystem")
	if coins == null:
		return

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color(0.086, 0.078, 0.102, 0.30)
	_rows_box.add_child(divider)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	_rows_box.add_child(row)

	var icon_wrap := CenterContainer.new()
	icon_wrap.custom_minimum_size = Vector2(32, 0)
	row.add_child(icon_wrap)
	icon_wrap.add_child(UITheme.make_coin_icon(26.0))

	var name_lbl := UITheme.style_label(Label.new(), 22, UITheme.BASALT_DARK, true)
	name_lbl.custom_minimum_size = Vector2(124, 0)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.text = "COINS"
	row.add_child(name_lbl)

	var earned_lbl := UITheme.style_label(Label.new(), 22, UITheme.BASALT_DARK)
	earned_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	earned_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	earned_lbl.text = "+%d THIS SOL" % coins.earned_this_sol
	row.add_child(earned_lbl)

	var total_box := PanelContainer.new()
	total_box.custom_minimum_size = Vector2(86, 42)
	total_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	total_box.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.SAND_GOLD, Color.TRANSPARENT, 0, 2, 8, 4))
	row.add_child(total_box)

	var total_lbl := UITheme.style_label(Label.new(), 20, UITheme.BASALT_DARK)
	total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	total_lbl.text = str(coins.total)
	total_box.add_child(total_lbl)
