## Data resource describing everything about one sol (Martian day).
## Equivalent of Unity ScriptableObject for sols.
class_name SolData
extends Resource

@export var sol_number: int = 1
@export var title: String = ""
@export var objective_text: String = ""
@export_multiline var task_description: String = ""

@export_group("Event")
@export var event: EventData

@export_group("Night Summary")
@export_multiline var night_fact: String = ""
@export var night_fact_source: String = ""

@export_group("Real NASA Data")
@export var earth_date: String = ""
@export var temp_min_c: float = -80.0
@export var temp_max_c: float = -20.0
@export var radiation_note: String = ""
