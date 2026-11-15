## Autoload singleton that manages the 4 survival meters.
## Emits signals when values change so the HUD and other systems can react.
extends Node

signal meter_changed(meter_name: StringName, old_value: float, new_value: float)
signal meter_depleted(meter_name: StringName)

# ---------- constants ----------
const METER_NAMES: Array[StringName] = [
	&"life_support", &"power", &"food", &"shield"
]

const STARTING_VALUES: Dictionary = {
	&"life_support": 60.0,
	&"power": 40.0,
	&"food": 50.0,
	&"shield": 40.0,
}

const DISPLAY_NAMES: Dictionary = {
	&"life_support": "Life Support",
	&"power": "Power",
	&"food": "Food",
	&"shield": "Shield",
}

const ICONS: Dictionary = {
	&"life_support": "🫁",
	&"power": "⚡",
	&"food": "🥔",
	&"shield": "🛡️",
}

const METER_COLORS: Dictionary = {
	&"life_support": Color("5b9bd5"),
	&"power": Color("f5a623"),
	&"food": Color("7ec850"),
	&"shield": Color("9c88b8"),
}

# ---------- state ----------
var _values: Dictionary = {}

func _ready() -> void:
	reset()

# ---------- public API ----------
func reset() -> void:
	for m in METER_NAMES:
		_values[m] = STARTING_VALUES[m]
	# Notify everyone of the fresh values
	for m in METER_NAMES:
		meter_changed.emit(m, 0.0, _values[m])

func get_value(meter_name: StringName) -> float:
	return _values.get(meter_name, 0.0)

func set_value(meter_name: StringName, value: float) -> void:
	var old := _values.get(meter_name, 0.0) as float
	var clamped := clampf(value, 0.0, 100.0)
	_values[meter_name] = clamped
	meter_changed.emit(meter_name, old, clamped)
	if clamped <= 0.0:
		meter_depleted.emit(meter_name)

func change_value(meter_name: StringName, delta: float) -> void:
	set_value(meter_name, get_value(meter_name) + delta)

func apply_changes(life: float, power: float, food: float, shield: float) -> void:
	change_value(&"life_support", life)
	change_value(&"power", power)
	change_value(&"food", food)
	change_value(&"shield", shield)

func all_above_zero() -> bool:
	for m in METER_NAMES:
		if _values[m] <= 0.0:
			return false
	return true

func get_all_values() -> Dictionary:
	return _values.duplicate()

func get_snapshot() -> Dictionary:
	return _values.duplicate()

func restore_snapshot(snapshot: Dictionary) -> void:
	for m in METER_NAMES:
		if snapshot.has(m):
			set_value(m, snapshot[m])
