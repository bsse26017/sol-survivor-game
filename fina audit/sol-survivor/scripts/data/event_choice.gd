## One of three choices on an event card.
## Stores the display text, icon, and the meter effects.
class_name EventChoice
extends Resource

@export var text: String = ""
@export var icon: String = ""  # Emoji or icon reference

@export_group("Meter Effects")
@export var life_support_change: float = 0.0
@export var power_change: float = 0.0
@export var food_change: float = 0.0
@export var shield_change: float = 0.0

func get_effects_summary() -> String:
	var parts: PackedStringArray = []
	if life_support_change != 0.0:
		parts.append("🫁 %+.0f" % life_support_change)
	if power_change != 0.0:
		parts.append("⚡ %+.0f" % power_change)
	if food_change != 0.0:
		parts.append("🥔 %+.0f" % food_change)
	if shield_change != 0.0:
		parts.append("🛡️ %+.0f" % shield_change)
	return "  ".join(parts)
