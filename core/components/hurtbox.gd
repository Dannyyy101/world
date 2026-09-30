class_name Hurtbox
extends Area2D
## Verwundbarer Bereich (Ebene 6). Reagiert auf Hitboxen (Ebene 5) und meldet `hit`.
## Bäume, Tiere usw. hängen eine Hurtbox an und verbinden `hit`.

signal hit(damage: float, tool_type: int, source: Node)

const LAYER_HURTBOX: int = 1 << 5


func _init() -> void:
	collision_layer = LAYER_HURTBOX
	collision_mask = 0
	monitoring = false


func receive_hit(damage: float, tool_type: int, source: Node) -> void:
	hit.emit(damage, tool_type, source)
