## Data resource describing one event card (shown after a repair task).
## Equivalent of Unity ScriptableObject for events.
class_name EventData
extends Resource

@export var title: String = ""
@export_multiline var description: String = ""
@export var choices: Array[EventChoice] = []
