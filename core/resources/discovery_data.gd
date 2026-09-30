class_name DiscoveryData
extends Resource
## Eine Entdeckung (Fortschritt durch Handeln/Beobachten). Wird von Agent 6 ausgewertet.

enum TriggerType { ACTION_COUNT, ITEM_COUNT, CUSTOM }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var cave_painting: Texture2D
@export var phase: Enums.Phase = Enums.Phase.ALTSTEINZEIT
@export var trigger_type: TriggerType = TriggerType.ACTION_COUNT
## ACTION_COUNT: action_id aus action_performed; ITEM_COUNT: item_id; CUSTOM: frei
@export var trigger_id: StringName = &""
@export var trigger_count: int = 1
@export var prerequisites: Array[StringName] = []
@export_multiline var hint_text: String = ""
@export var unlocks_recipes: Array[StringName] = []
