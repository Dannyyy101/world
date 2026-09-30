class_name ItemData
extends Resource
## Ein Item. Als .tres unter res://items/data/ ablegen; ItemDB lädt es automatisch.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var category: Enums.ItemCategory = Enums.ItemCategory.MATERIAL
@export var max_stack: int = 99
@export var tool_type: Enums.ToolType = Enums.ToolType.NONE
@export var tool_power: float = 0.0
## 0 = unzerstörbar
@export var max_durability: int = 0
@export var nutrition: float = 0.0
@export var hydration: float = 0.0
@export var warmth: float = 0.0
## 0 = verdirbt nicht
@export var spoil_days: int = 0
@export_file("*.tscn") var placeable_scene_path: String = ""
## Leer = immer verfügbar
@export var required_discovery: StringName = &""
