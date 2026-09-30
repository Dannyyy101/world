extends Node2D
## Werkplatz: Herstellungsstation (Enums.Station.WORKSPOT). E öffnet das Herstellen-Menü.
## Liegt in der Gruppe "crafting_station"; CraftingSystem erkennt ihn über die Property `station`.

@export var station: Enums.Station = Enums.Station.WORKSPOT

@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	add_to_group(CraftingSystem.STATION_GROUP)
	_interactable.interacted.connect(_on_interacted)


func _on_interacted(_by: Node2D) -> void:
	if Inventory.ui != null:
		Inventory.ui.open_crafting()
