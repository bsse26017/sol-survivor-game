class_name DebriefUI
extends CanvasLayer

signal retry_sol_pressed
signal play_again_pressed

var _root: Control
var _outcome_title: Label
var _outcome_sub: Label
var _status_grid: GridContainer
var _log_list: VBoxContainer
var _retry_btn: Button
var _coin_label: Label

func _ready() -> void:
	layer = 14
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.show_debrief.connect(_on_show_debrief)
		gm.state_changed.connect(func(st: int) -> void:
			if st != 4:
				visible = false
		)

func _process(_delta: float) -> void:
	if visible and Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_show_debrief(won: bool) -> void:
	var gm := get_node_or_null("/root/GameManager")
	var ms := get_node_or_null("/root/MeterSystem")
	var sols_survived: int = gm.current_sol if gm else 6
	var meters: Dictionary = ms.get_snapshot() if (ms and ms.has_method("get_snapshot")) else {}

	var log_entries: Array[Dictionary] = []
	if gm:
		for ch in gm.choices_made:
			log_entries.append({
				"sol": ch.get("sol", 1),
				"optimal": ch.get("choice_index", 0) != 2,
				"summary": ch.get("choice_text", "Decision logged"),
			})

	populate(won, sols_survived, meters, log_entries)
	if gm and _retry_btn and gm.has_method("get_retry_target_sol"):
		_retry_btn.text = "RETRY FROM SOL %02d" % gm.get_retry_target_sol()
	# Retrying a sol only makes sense after failing; a rescued crew just gets "Play again".
	if _retry_btn:
		_retry_btn.visible = not won
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var root_hbox := HBoxContainer.new()
	root_hbox.set_anchors_preset(Control.PRESET_CENTER)
	root_hbox.offset_left = -480
	root_hbox.offset_right = 480
	root_hbox.offset_top = -255
	root_hbox.offset_bottom = 255
	root_hbox.add_theme_constant_override("separation", 18)
	_root.add_child(root_hbox)

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(365, 0)
	left_panel.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.SLATE_PANEL, Color(0.96, 0.94, 0.90, 0.35), 1, 4, 24, 24, 18))
	root_hbox.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 14)
	left_panel.add_child(left_vbox)

	_outcome_title = UITheme.style_label(Label.new(), 36, UITheme.SAND_GOLD, true)
	_outcome_title.text = "MISSION\nACCOMPLISHED"
	left_vbox.add_child(_outcome_title)

	_outcome_sub = UITheme.style_label(Label.new(), 13, UITheme.CREAM_SHEET, true)
	_outcome_sub.text = "// 6 SOLS SURVIVED // CREW RESCUED"
	left_vbox.add_child(_outcome_sub)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(1, 1, 1, 0.16)
	left_vbox.add_child(sep)

	var status_hdr := UITheme.style_label(Label.new(), 15, UITheme.CREAM_SHEET, true)
	status_hdr.text = "FINAL STATUS"
	left_vbox.add_child(status_hdr)

	_status_grid = GridContainer.new()
	_status_grid.columns = 2
	_status_grid.add_theme_constant_override("h_separation", 20)
	_status_grid.add_theme_constant_override("v_separation", 16)
	left_vbox.add_child(_status_grid)

	var coin_row := HBoxContainer.new()
	coin_row.add_theme_constant_override("separation", 8)
	left_vbox.add_child(coin_row)
	coin_row.add_child(UITheme.make_coin_icon(16.0))
	_coin_label = UITheme.style_label(Label.new(), 15, UITheme.SAND_GOLD, true)
	_coin_label.text = "COINS: 0"
	coin_row.add_child(_coin_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(spacer)

	var retry_btn := Button.new()
	_retry_btn = retry_btn
	retry_btn.custom_minimum_size = Vector2(0, 46)
	retry_btn.text = "RETRY SOL"
	UITheme.style_button(
		retry_btn, 17,
		UITheme.SLATE_PANEL, UITheme.SLATE_TRACK,
		UITheme.CREAM_SHEET,
		UITheme.CREAM_SHEET, 2, 4, 16, 10
	)
	retry_btn.pressed.connect(func() -> void:
		visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		retry_sol_pressed.emit()
		var gm := get_node_or_null("/root/GameManager")
		if gm:
			gm.retry_sol()
	)
	left_vbox.add_child(retry_btn)

	var again_btn := Button.new()
	again_btn.custom_minimum_size = Vector2(0, 48)
	again_btn.text = "PLAY AGAIN"
	UITheme.style_button(
		again_btn, 17,
		UITheme.TERRACOTTA, UITheme.TERRACOTTA_HOVER,
		UITheme.BASALT_DARK,
		Color.TRANSPARENT, 0, 4, 16, 10
	)
	again_btn.pressed.connect(func() -> void:
		visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		play_again_pressed.emit()
		var gm := get_node_or_null("/root/GameManager")
		if gm:
			gm.start_game()
	)
	left_vbox.add_child(again_btn)

	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.CREAM_SHEET, UITheme.CREAM_SHEET, 2, 4, 12, 12, 18))
	root_hbox.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_vbox)

	var log_hdr_box := PanelContainer.new()
	log_hdr_box.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.SLATE_PANEL, Color.TRANSPARENT, 0, 2, 16, 12))
	right_vbox.add_child(log_hdr_box)

	var log_hdr := UITheme.style_label(Label.new(), 20, UITheme.CREAM_SHEET, true)
	log_hdr.text = "DECISION & NASA LESSON LOG"
	log_hdr_box.add_child(log_hdr)

	_log_list = VBoxContainer.new()
	_log_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_list.add_theme_constant_override("separation", 6)
	right_vbox.add_child(_log_list)

func populate(victory: bool, sols_survived: int, meters: Dictionary, decision_log: Array[Dictionary]) -> void:
	if victory:
		_outcome_title.text = "MISSION\nACCOMPLISHED"
		_outcome_title.add_theme_color_override("font_color", UITheme.SAND_GOLD)
		_outcome_sub.text = "// %d SOLS SURVIVED // CREW RESCUED" % sols_survived
	else:
		_outcome_title.text = "MISSION\nABORTED"
		_outcome_title.add_theme_color_override("font_color", UITheme.TERRACOTTA)
		_outcome_sub.text = "// CRITICAL SYSTEM FAILURE ON SOL %02d" % sols_survived

	var coins := get_node_or_null("/root/CoinSystem")
	if coins:
		_coin_label.text = "COINS: %d" % coins.total + ("  (INCL. +%d WIN BONUS)" % coins.REWARD_WIN if victory else "")

	for child in _status_grid.get_children():
		child.queue_free()

	var stat_items := [
		{"key": "life_support", "label": "O2:", "glyph": ""},
		{"key": "power", "label": "POWER:", "glyph": "lightning"},
		{"key": "food", "label": "FOOD:", "glyph": "utensils"},
		{"key": "shield", "label": "SHIELD:", "glyph": "shield"},
	]

	for s in stat_items:
		var val := int(round(meters.get(s["key"], meters.get(StringName(s["key"]), 0))))
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 6)
		_status_grid.add_child(cell)

		var top_line := HBoxContainer.new()
		top_line.add_theme_constant_override("separation", 6)
		cell.add_child(top_line)

		if s["glyph"] != "":
			top_line.add_child(UITheme.make_vector_icon(s["glyph"], Vector2(15, 15), UITheme.CREAM_SHEET))

		var lbl := UITheme.style_label(Label.new(), 13, UITheme.CREAM_SHEET, true)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.text = s["label"]
		top_line.add_child(lbl)

		var pct := UITheme.style_label(Label.new(), 13, UITheme.CREAM_SHEET)
		pct.text = "%d%%" % val
		top_line.add_child(pct)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 8)
		bar.show_percentage = false
		bar.value = val
		bar.add_theme_stylebox_override("background", UITheme.make_flat_box(UITheme.SLATE_TRACK, Color.TRANSPARENT, 0, 1, 0, 0))
		bar.add_theme_stylebox_override("fill", UITheme.make_flat_box(UITheme.CREAM_SHEET, Color.TRANSPARENT, 0, 1, 0, 0))
		cell.add_child(bar)

	for child in _log_list.get_children():
		child.queue_free()

	for i in range(decision_log.size()):
		var entry: Dictionary = decision_log[i]
		var row_margin := MarginContainer.new()
		row_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row_margin.add_theme_constant_override("margin_left", 10)
		row_margin.add_theme_constant_override("margin_right", 10)
		_log_list.add_child(row_margin)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row_margin.add_child(row)

		var sol_lbl := UITheme.style_label(Label.new(), 14, UITheme.BASALT_DARK, true)
		sol_lbl.custom_minimum_size = Vector2(42, 0)
		sol_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sol_lbl.text = "SOL\n%02d" % entry.get("sol", i + 1)
		row.add_child(sol_lbl)

		var badge := PanelContainer.new()
		badge.custom_minimum_size = Vector2(22, 22)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var optimal: bool = entry.get("optimal", true)
		badge.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.SAGE_CHECK if optimal else UITheme.TERRACOTTA, Color.TRANSPARENT, 0, 3, 4, 2))
		row.add_child(badge)

		var check := UITheme.style_label(Label.new(), 12, UITheme.CREAM_SHEET)
		check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		check.text = "✓"
		badge.add_child(check)

		var summary := UITheme.style_label(Label.new(), 14, UITheme.BASALT_DARK)
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.text = entry.get("summary", "")
		row.add_child(summary)

		if i < decision_log.size() - 1:
			var div := ColorRect.new()
			div.custom_minimum_size = Vector2(0, 1)
			div.color = Color(0.086, 0.078, 0.102, 0.16)
			_log_list.add_child(div)
