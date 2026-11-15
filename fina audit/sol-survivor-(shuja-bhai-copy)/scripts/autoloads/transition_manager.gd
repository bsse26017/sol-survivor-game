## Full-screen fade transition (black overlay that fades in/out).
## Autoload singleton so any system can trigger a fade.
extends CanvasLayer

signal fade_finished

var _overlay: ColorRect
var _tween: Tween

func _ready() -> void:
	layer = 100  # On top of everything
	process_mode = Node.PROCESS_MODE_ALWAYS

	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

## Fade to black over `duration` seconds.
func fade_out(duration: float = 0.4) -> void:
	_kill_tween()
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_tween = create_tween()
	_tween.tween_property(_overlay, "color:a", 1.0, duration)
	await _tween.finished
	fade_finished.emit()

## Fade from black to clear over `duration` seconds.
func fade_in(duration: float = 0.4) -> void:
	_kill_tween()
	_overlay.color.a = 1.0
	_tween = create_tween()
	_tween.tween_property(_overlay, "color:a", 0.0, duration)
	await _tween.finished
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_finished.emit()

## Fade out, call `callable`, then fade in.
func transition(callable: Callable, out_dur: float = 0.6, hold: float = 0.4, in_dur: float = 0.6) -> void:
	await fade_out(out_dur)
	await get_tree().create_timer(hold).timeout
	callable.call()
	await fade_in(in_dur)

func _kill_tween() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
