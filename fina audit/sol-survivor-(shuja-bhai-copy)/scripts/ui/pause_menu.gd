## Esc pauses the game (the "How to play" page promises it). Resume with Esc or the button;
## the map and the how-to-play page can be opened from here.
extends CanvasLayer

var _root: Control


func _ready() -> void:
	layer = 14
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _process(_delta: float) -> void:
	if visible and Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if visible:
		if not _overlay_open():
			resume()
			get_viewport().set_input_as_handled()
	elif _can_pause():
		pause()
		get_viewport().set_input_as_handled()


func pause() -> void:
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func resume() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## Only while actually playing: not on the title, event card, night summary or debrief,
## and not while the map or the how-to-play page is already on screen.
func _can_pause() -> bool:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null or gm.current_state != gm.GameState.PLAYING:
		return false
	return not get_tree().paused and not _overlay_open()


func _overlay_open() -> bool:
	var map := get_node_or_null("/root/MapScreen")
	var how := get_node_or_null("/root/HowToPlay")
	return (map != null and map.visible) or (how != null and how.visible)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.086, 0.078, 0.102, 0.66)
	_root.add_child(dim)

	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -190
	frame.offset_right = 190
	frame.offset_top = -190
	frame.offset_bottom = 190
	frame.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.SLATE_PANEL, UITheme.CREAM_SHEET, 2, 0, 28, 24, 22))
	_root.add_child(frame)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	frame.add_child(box)

	var title := UITheme.style_label(Label.new(), 38, UITheme.SAND_GOLD, true)
	title.text = "Paused"
	box.add_child(title)

	var sub := UITheme.style_label(Label.new(), 13, UITheme.TEXT_MUTED_LIGHT, true)
	sub.text = "// Mission on hold"
	box.add_child(sub)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(1, 1, 1, 0.16)
	box.add_child(sep)

	box.add_child(_button("RESUME", UITheme.TERRACOTTA, UITheme.TERRACOTTA_HOVER, UITheme.BASALT_DARK, resume))
	box.add_child(_button("MAP", UITheme.SLATE_TRACK, UITheme.SLATE_PANEL, UITheme.CREAM_SHEET, _open_map))
	box.add_child(_button("HOW TO PLAY", UITheme.SLATE_TRACK, UITheme.SLATE_PANEL, UITheme.CREAM_SHEET, _open_how_to_play))

	var hint := UITheme.style_label(Label.new(), 12, UITheme.TEXT_MUTED_LIGHT, true)
	hint.text = "[ESC] resume    [M] map"
	box.add_child(hint)


func _button(text: String, bg: Color, hover: Color, fg: Color, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 46)
	btn.text = text
	UITheme.style_button(btn, 18, bg, hover, fg, UITheme.CREAM_SHEET if bg == UITheme.SLATE_TRACK else Color.TRANSPARENT,
			1 if bg == UITheme.SLATE_TRACK else 0, 3, 16, 8)
	btn.pressed.connect(on_press)
	return btn


func _open_map() -> void:
	var map := get_node_or_null("/root/MapScreen")
	if map:
		map.open()


func _open_how_to_play() -> void:
	var how := get_node_or_null("/root/HowToPlay")
	if how:
		how.open()
