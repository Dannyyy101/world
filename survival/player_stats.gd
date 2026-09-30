extends Node
## PlayerStats – STUB – Agent 3 implementiert.
## Stats: &"health", &"hunger", &"thirst", &"warmth", &"energy" (Stub: alle voll, max 100).

const MAX_VALUE: float = 100.0

var _values: Dictionary[StringName, float] = {
	&"health": MAX_VALUE,
	&"hunger": MAX_VALUE,
	&"thirst": MAX_VALUE,
	&"warmth": MAX_VALUE,
	&"energy": MAX_VALUE,
}


func get_value(stat: StringName) -> float:
	return _values.get(stat, 0.0)


func modify(stat: StringName, delta: float) -> void:
	if not _values.has(stat):
		return
	_values[stat] = clampf(_values[stat] + delta, 0.0, MAX_VALUE)
	EventBus.player_stat_changed.emit(stat, _values[stat], MAX_VALUE)


## Isst ein Item. Rückgabe: true, wenn gegessen wurde (Stub: immer false).
func eat(_item_id: StringName) -> bool:
	return false
