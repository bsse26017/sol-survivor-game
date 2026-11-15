class_name TitleScreen
extends CanvasLayer

signal start_mission_pressed
signal nasa_archive_pressed

var _root: Control
var _menu_buttons: Array[Button] = []
var _accent_bars: Array[ColorRect] = []

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_highlight_index(0)
	_activate_title_camera()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.state_changed.connect(_on_state_changed)

func _process(_delta: float) -> void:
	if visible and Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_state_changed(new_state: int) -> void:
	visible = (new_state == 0)
	if visible:
		_activate_title_camera()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		_restore_gameplay_camera()

func _activate_title_camera() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var title_cam := scene.find_child("TitleCamera", true, false) as Camera3D
	if title_cam:
		title_cam.current = true

func _restore_gameplay_camera() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	var title_cam := scene.find_child("TitleCamera", true, false) as Camera3D
	if title_cam:
		title_cam.current = false

	var player := scene.find_child("Player", true, false)
	if player:
		var cams := player.find_children("*", "Camera3D", true, false)
		if not cams.is_empty():
			(cams[0] as Camera3D).current = true
			return

	var all_cams := scene.find_children("*", "Camera3D", true, false)
	for c in all_cams:
		if c != title_cam and c is Camera3D:
			(c as Camera3D).current = true
			break

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var scrim := TextureRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(0.18, 0.09, 0.06, 0.68),
		Color(0.18, 0.09, 0.06, 0.30),
		Color(0.18, 0.09, 0.06, 0.0)
	])
	grad.offsets = PackedFloat32Array([0.0, 0.42, 0.78])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.0, 0.25)
	grad_tex.fill_to = Vector2(1.0, 0.65)
	scrim.texture = grad_tex
	_root.add_child(scrim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 74)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_bottom", 22)
	_root.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 34)
	margin.add_child(layout)

	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 2)
	layout.add_child(header_box)

	var sub := UITheme.style_label(Label.new(), 22, UITheme.CREAM_SHEET, true, true)
	sub.text = "NASA SPACE APPS // MISSION TRAINER"
	header_box.add_child(sub)

	var title := UITheme.style_label(Label.new(), 92, UITheme.CREAM_SHEET, true, true)
	title.text = "SOL SURVIVOR"
	header_box.add_child(title)

	var menu_box := VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 14)
	layout.add_child(menu_box)

	var items: Array[String] = ["START MISSION", "HOW TO PLAY", "MAP", "NASA ARCHIVE", "QUIT"]
	for i in range(items.size()):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		menu_box.add_child(row)

		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(8, 40)
		bar.color = UITheme.TERRACOTTA
		row.add_child(bar)
		_accent_bars.append(bar)

		var btn := Button.new()
		btn.text = items[i]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UITheme.style_button(
			btn, 34,
			Color.TRANSPARENT, Color.TRANSPARENT,
			UITheme.CREAM_SHEET,
			Color.TRANSPARENT, 0, 0, 0, 0
		)
		btn.add_theme_color_override("font_shadow_color", Color(0.08, 0.05, 0.04, 0.85))
		btn.add_theme_constant_override("shadow_offset_y", 3)

		var idx := i
		btn.mouse_entered.connect(func() -> void: _highlight_index(idx))
		btn.pressed.connect(func() -> void: _on_item_pressed(idx))
		row.add_child(btn)
		_menu_buttons.append(btn)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	var ver := UITheme.style_label(Label.new(), 14, Color(0.96, 0.94, 0.90, 0.8))
	ver.text = "v1.0"
	layout.add_child(ver)

func _highlight_index(active_idx: int) -> void:
	for i in range(_menu_buttons.size()):
		var is_active := (i == active_idx)
		_accent_bars[i].modulate.a = 1.0 if is_active else 0.0
		_menu_buttons[i].modulate = Color.WHITE if is_active else Color(0.96, 0.94, 0.90, 0.78)

func _on_item_pressed(idx: int) -> void:
	match _menu_buttons[idx].text:
		"START MISSION":
			visible = false
			_restore_gameplay_camera()
			start_mission_pressed.emit()
			var gm := get_node_or_null("/root/GameManager")
			if gm:
				gm.start_game()
		"HOW TO PLAY":
			var how := get_node_or_null("/root/HowToPlay")
			if how:
				how.open()
		"MAP":
			var map := get_node_or_null("/root/MapScreen")
			if map:
				map.open()
		"NASA ARCHIVE":
			nasa_archive_pressed.emit()
			var credits := get_node_or_null("../CreditsScreen")
			if credits:
				credits.visible = true
		"QUIT":
			get_tree().quit()
