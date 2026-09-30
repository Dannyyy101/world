class_name SleepingPlace
extends Node2D
## Schlafplatz (Besitzer: Agent 3): Höhle, Hütte, Unterstand. Interagieren (E) -> schlafen.
## Gehört zu den Gruppen "shelter" (Wetter-/Kälteschutz) und "sleeping_place" (Aufwachort nach Kollaps).
## Szene: res://survival/scenes/sleeping_place.tscn (Höhle als Standard; Werte im Inspector anpassen).

## Wie gut der Platz erholt (0.5 = Unterstand, 1.0 = Höhle/Hütte). Skaliert Gesundheitsregeneration.
@export_range(0.25, 1.5, 0.05) var rest_quality: float = 1.0
## Radius (Pixel), in dem der Platz als Unterschlupf zählt.
@export var shelter_radius: float = 40.0
## Zusätzliche Wärme im Unterschlupf (Punkte auf die Zielwärme).
@export var shelter_warmth: float = 18.0
@export var prompt: String = "Schlafen"

@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	add_to_group("shelter")
	add_to_group("sleeping_place")
	_interactable.prompt_text = prompt
	_interactable.interacted.connect(_on_interacted)


func _on_interacted(_by: Node2D) -> void:
	PlayerStats.sleep(rest_quality, self)
