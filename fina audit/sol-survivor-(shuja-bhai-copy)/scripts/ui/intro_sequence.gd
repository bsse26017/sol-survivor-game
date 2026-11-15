class_name IntroSequence
extends CanvasLayer

signal intro_finished

var _root: Control
var _text_container: VBoxContainer
var _skip_btn: Button
var _is_playing: bool = false

const BRIEFING_LINES: Array[String] = [
	"ARES-IV EMERGENCY TELEMETRY // GALE CRATER SECTOR",
	"A severe dust squall has coated the primary solar arrays and compromised habitat reserve seals.",
	"Emergency extraction lander is 6 Sols out. Stabilize base systems, run field scans, and ration O₂, Power, Food, and Shielding until rescue arrives."
]

func _ready() -> void:
	layer = 20
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _process(_delta: float) -> void:
	if visible and Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func play() -> void:
	visible = true
	_is_playing = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	for child in _text_container.get_children():
		child.queue_free()
	_play_sequence()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.086, 0.078, 0.102, 0.94)
	_root.add_child(bg)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -410
	card.offset_right = 410
	card.offset_top = -185
	card.offset_bottom = 185
	card.add_theme_stylebox_override("panel", UITheme.make_flat_box(UITheme.SLATE_PANEL, UITheme.CREAM_SHEET, 2, 2, 34, 28, 20))
	_root.add_child(card)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 16)
	card.add_child(outer_vbox)

	var header := UITheme.style_label(Label.new(), 24, UITheme.SAND_GOLD, true)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.text = "MISSION BRIEFING // BEFORE SOL 01"
	outer_vbox.add_child(header)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(0.96, 0.94, 0.90, 0.24)
	outer_vbox.add_child(sep)

	_text_container = VBoxContainer.new()
	_text_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_text_container.add_theme_constant_override("separation", 16)
	outer_vbox.add_child(_text_container)

	_skip_btn = Button.new()
	_skip_btn.text = "DEPLOY TO OUTPOST"
	_skip_btn.custom_minimum_size = Vector2(210, 46)
	UITheme.style_button(_skip_btn, 17, UITheme.TERRACOTTA, UITheme.TERRACOTTA_HOVER, UITheme.BASALT_DARK)
	_skip_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_btn.offset_left = -242
	_skip_btn.offset_top = -72
	_skip_btn.offset_right = -32
	_skip_btn.offset_bottom = -26
	_skip_btn.pressed.connect(_finish_intro)
	_root.add_child(_skip_btn)

func _play_sequence() -> void:
	for line_text in BRIEFING_LINES:
		if not is_inside_tree() or not _is_playing:
			return
		var lbl := UITheme.style_label(Label.new(), 16, UITheme.CREAM_SHEET)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.text = line_text
		lbl.modulate.a = 0.0
		_text_container.add_child(lbl)

		var tween := create_tween()
		tween.tween_property(lbl, "modulate:a", 1.0, 0.4)
		await get_tree().create_timer(1.5).timeout

func _finish_intro() -> void:
	if not _is_playing:
		return
	_is_playing = false
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	intro_finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
			_finish_intro()
