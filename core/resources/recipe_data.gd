class_name RecipeData
extends Resource
## Ein Rezept. Als .tres unter res://items/recipes/ ablegen; ItemDB lädt es automatisch.

@export var id: StringName = &""
## Item-ID -> Menge
@export var inputs: Dictionary[StringName, int] = {}
@export var output_id: StringName = &""
@export var output_amount: int = 1
@export var station: Enums.Station = Enums.Station.HAND
@export var craft_seconds: float = 1.0
## Leer = immer verfügbar
@export var required_discovery: StringName = &""
