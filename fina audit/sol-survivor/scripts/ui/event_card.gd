class_name EventCardUI
extends CanvasLayer

signal choice_selected(choice_index: int)

var _root: Control
var _tag_label: Label
var _title_label: Label
var _desc_label: Label
var _choices_box: VBoxContainer

const SOL_CATEGORIES := {
	1: "POWER ANOMALY",
	2: "THERMAL REGULATION",
	3: "BOTANICAL CRISIS",
	4: "WATER RECYCLER",
	5: "RADIATION ALERT",
	6: "COMMS UPLINK",
}

func _ready() -> void:
	layer = 12
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.show_event.connect(_on_show_event)
		gm.state_changed.connect(func(st: int) -> void:
			if st != 2:
				visible = false
		)

func _process(_delta: float) -> void:
	if visible and Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_show_event(event_res: Resource) -> void:
	var gm := get_node_or_null("/root/GameManager")
	var sol_num: int = gm.current_sol if gm else 1
	var default_cat: String = SOL_CATEGORIES.get(sol_num, "SYSTEM ANOMALY")
	var raw_cat = event_res.get("category")
	var category: String = raw_cat if (raw_cat != null and str(raw_cat) != "") else default_cat
	var headline: String = event_res.get("title") if event_res.get("title") != null else "CRITICAL DECISION"
	var desc: String = event_res.get("description") if event_res.get("description") != null else ""

	var formatted_choices: Array[Dictionary] = []
	var raw_choices: Array = event_res.get("choices") if event_res.get("choices") != null else []
	for ch in raw_choices:
		var deltas: Array[Dictionary] = []
		var o2 := int(round(ch.get("life_support_change") if ch.get("life_support_change") != null else 0))
		var pwr := int(round(ch.get("power_change") if ch.get("power_change") != null else 0))
		var food := int(round(ch.get("food_change") if ch.get("food_change") != null else 0))
		var shd := int(round(ch.get("shield_change") if ch.get("shield_change") != null else 0))

		if o2 != 0:
			deltas.append({"tag": "%+d O2" % o2, "positive": o2 > 0})
		if pwr != 0:
			deltas.append({"tag": "%+d PWR" % pwr, "positive": pwr > 0})
		if food != 0:
			deltas.append({"tag": "%+d FOOD" % food, "positive": food > 0})
		if shd != 0:
			deltas.append({"tag": "%+d SHD" % shd, "positive": shd > 0})

		formatted_choices.append({
			"label": ch.get("text") if ch.get("text") != null else "SELECT",
			"deltas": deltas,
		})

	populate(sol_num, category, headline, desc, formatted_choices)
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _select_choice(idx: int) -> void:
	visible = false
	choice_selected.emit(idx)
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.on_event_choice_made(idx)

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var sheet := PanelContainer.new()
	# Right side, vertically centred, as tall as its content (it used to stretch the full
	# screen height and leave half the sheet empty).
	sheet.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	sheet.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	sheet.grow_vertical = Control.GROW_DIRECTION_BOTH
	sheet.offset_left = -540
	sheet.offset_right = -32
	sheet.offset_top = 0
	sheet.offset_bottom = 0
	sheet.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.CREAM_SHEET, Color.TRANSPARENT, 0, 4, 28, 28, 18))
	_root.add_child(sheet)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	sheet.add_child(vbox)

	var badge_wrap := HBoxContainer.new()
	vbox.add_child(badge_wrap)

	var badge_panel := PanelContainer.new()
	badge_panel.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.TERRACOTTA, Color.TRANSPARENT, 0, 4, 12, 5))
	badge_wrap.add_child(badge_panel)

	_tag_label = UITheme.style_label(Label.new(), 14, UITheme.CREAM_SHEET, true)
	_tag_label.text = "SOL 01 // POWER ANOMALY"
	badge_panel.add_child(_tag_label)

	_title_label = UITheme.style_label(Label.new(), 36, UITheme.BASALT_DARK, true)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.text = "DUST ON SOLAR ARRAYS"
	vbox.add_child(_title_label)

	_desc_label = UITheme.style_label(Label.new(), 16, UITheme.TEXT_MUTED_DARK)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.text = ""
	vbox.add_child(_desc_label)

	var spacer_top := Control.new()
	spacer_top.custom_minimum_size = Vector2(0, 14)
	vbox.add_child(spacer_top)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 14)
	vbox.add_child(_choices_box)

	var spacer_bot := Control.new()
	spacer_bot.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer_bot)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(footer)

	footer.add_child(UITheme.make_vector_icon("bracket_bl", Vector2(12, 12), UITheme.BASALT_DARK))

	var foot_lbl := UITheme.style_label(Label.new(), 13, UITheme.TEXT_MUTED_DARK, true)
	foot_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot_lbl.text = "SELECT OPTION TO CONTINUE"
	footer.add_child(foot_lbl)

	footer.add_child(UITheme.make_vector_icon("bracket_br", Vector2(12, 12), UITheme.BASALT_DARK))

func populate(sol_num: int, category: String, headline: String, description: String, choices: Array[Dictionary]) -> void:
	_tag_label.text = "SOL %02d // %s" % [sol_num, category]
	_title_label.text = headline
	_desc_label.text = description

	for child in _choices_box.get_children():
		child.queue_free()

	for i in range(choices.size()):
		var c: Dictionary = choices[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 64)
		UITheme.style_button(
			btn, 14,
			UITheme.CREAM_SHEET, UITheme.CREAM_HOVER,
			UITheme.BASALT_DARK,
			UITheme.BASALT_DARK, 2, 4, 0, 0
		)
		btn.text = ""

		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)
		btn.add_child(margin)

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		margin.add_child(row)

		var lbl := UITheme.style_label(Label.new(), 14, UITheme.BASALT_DARK, true)
		lbl.text = "[%d] %s" % [i + 1, c.get("label", "OPTION")]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lbl)

		var chips_row := HBoxContainer.new()
		chips_row.size_flags_horizontal = Control.SIZE_SHRINK_END
		chips_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chips_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chips_row.add_theme_constant_override("separation", 6)
		row.add_child(chips_row)

		var deltas: Array = c.get("deltas", [])
		if deltas.is_empty():
			# Choices with only delayed/story consequences still get a visible chip.
			var none_chip := PanelContainer.new()
			none_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			none_chip.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.BASALT_DARK, Color.TRANSPARENT, 0, 4, 7, 4))
			chips_row.add_child(none_chip)
			var none_lbl := UITheme.style_label(Label.new(), 13, UITheme.CREAM_SHEET, true)
			none_lbl.text = "NO IMMEDIATE EFFECT"
			none_chip.add_child(none_lbl)
		for d in deltas:
			var chip := PanelContainer.new()
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var is_pos: bool = d.get("positive", false)
			var chip_bg := UITheme.TEAL_CHIP if is_pos else UITheme.TERRACOTTA
			chip.add_theme_stylebox_override("panel", UITheme.make_flat_box(chip_bg, Color.TRANSPARENT, 0, 4, 7, 4))
			chips_row.add_child(chip)

			var chip_lbl := UITheme.style_label(Label.new(), 13, UITheme.CREAM_SHEET, true)
			chip_lbl.text = d.get("tag", "")
			chip.add_child(chip_lbl)

		var idx := i
		btn.pressed.connect(func() -> void: _select_choice(idx))
		_choices_box.add_child(btn)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var count := _choices_box.get_child_count()
		if event.keycode == KEY_1 and count >= 1:
			_select_choice(0)
		elif event.keycode == KEY_2 and count >= 2:
			_select_choice(1)
		elif event.keycode == KEY_3 and count >= 3:
			_select_choice(2)
