class_name DropManager
extends Node
## Speichert liegende Item-Drops (Gruppe "item_drops") im Spielstand und stellt sie beim Laden wieder her.

const SAVE_KEY: String = "item_drops"


func _ready() -> void:
	SaveManager.register(SAVE_KEY, self)


func get_save_data() -> Dictionary:
	var list: Array = []
	for n in get_tree().get_nodes_in_group(ItemDrop.GROUP):
		var d: ItemDrop = n as ItemDrop
		if d != null and not d.is_queued_for_deletion():
			list.append({"id": d.item_id, "amount": d.amount, "pos": d.global_position,
					"durability": d.durability, "age": d.age})
	return {"drops": list}


func load_save_data(data: Dictionary) -> void:
	for n in get_tree().get_nodes_in_group(ItemDrop.GROUP):
		n.queue_free()
	for e in data.get("drops", []):
		var id: StringName = StringName(e.get("id", ""))
		if not ItemDB.has_item(id):
			continue
		ItemDrop.spawn(id, int(e.get("amount", 1)), e.get("pos", Vector2.ZERO),
				int(e.get("durability", 0)), float(e.get("age", 0.0)), false)
