extends Node
## Inventory – STUB – Agent 2 implementiert.
## Dieser Stub speichert nur Zähler in einem Dictionary (unbegrenzte Kapazität,
## kein Ausrüsten, keine Haltbarkeit), damit andere Systeme schon gegen die API
## entwickeln können. Agent 2 ersetzt den Inhalt und behält die Signaturen.

var _counts: Dictionary[StringName, int] = {}


## Fügt Items hinzu. Rückgabe: Rest, der nicht gepasst hat (Stub: immer 0).
func add_item(id: StringName, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	_counts[id] = count(id) + amount
	EventBus.item_collected.emit(id, amount)
	return 0


func remove_item(id: StringName, amount: int = 1) -> bool:
	if not has_item(id, amount):
		return false
	_counts[id] = count(id) - amount
	if _counts[id] <= 0:
		_counts.erase(id)
	EventBus.item_removed.emit(id, amount)
	return true


func has_item(id: StringName, amount: int = 1) -> bool:
	return count(id) >= amount


func count(id: StringName) -> int:
	return _counts.get(id, 0)


## Aktuell ausgerüstetes Item (Stub: nichts ausgerüstet -> null = bloße Hände).
func get_equipped() -> ItemData:
	return null


## Verringert die Haltbarkeit des ausgerüsteten Items (Stub: no-op).
func damage_equipped(_amount: int) -> void:
	pass
