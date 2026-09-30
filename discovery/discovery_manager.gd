extends Node
## Discoveries – STUB – Agent 6 implementiert.

var _unlocked: Dictionary[StringName, bool] = {}


func is_unlocked(id: StringName) -> bool:
	return _unlocked.has(id)


func unlock(id: StringName) -> void:
	if _unlocked.has(id):
		return
	_unlocked[id] = true
	EventBus.discovery_unlocked.emit(id)


## Fortschritt 0..1 (Stub: 1 wenn freigeschaltet, sonst 0).
func get_progress(id: StringName) -> float:
	return 1.0 if _unlocked.has(id) else 0.0
