class_name Interactable
extends Area2D
## Interagierbares Objekt (Taste E). Liegt auf Kollisionsebene 4 (interactables).
## Nutzung: Szene core/components/interactable.tscn instanziieren (Shape anpassen)
## oder das Skript an eigene Area2D hängen, dann `interacted` verbinden.

signal interacted(by: Node2D)

@export var prompt_text: String = "Interagieren"
## Deaktivierte Interactables werden vom Player ignoriert.
@export var enabled: bool = true

const LAYER_INTERACTABLES: int = 1 << 3


func _init() -> void:
	collision_layer = LAYER_INTERACTABLES
	collision_mask = 0
	monitoring = false


## Wird vom Player aufgerufen.
func interact(by: Node2D) -> void:
	if enabled:
		interacted.emit(by)
