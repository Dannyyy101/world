extends Node
## GameState – globaler Spielzustand (Besitzer: Agent 0).
## Phase, Lagerplatz, Referenz auf den Spieler und ein freies Flag-Dictionary.

var phase: Enums.Phase = Enums.Phase.ALTSTEINZEIT
var camp_position: Vector2 = Vector2.ZERO
var has_camp: bool = false
## Wird vom Player in _ready gesetzt (Node2D, in der Praxis player/player.gd).
var player: Node2D = null
## Freie Flags (JSON-tauglich: bool/int/float/String/Vector2/Arrays/Dictionaries).
var flags: Dictionary = {}


func _ready() -> void:
	SaveManager.register("game_state", self)


func set_phase(p: Enums.Phase) -> void:
	if p == phase:
		return
	phase = p
	EventBus.phase_changed.emit(int(p))


func set_flag(key: String, value: Variant) -> void:
	flags[key] = value


func get_flag(key: String, default: Variant = null) -> Variant:
	return flags.get(key, default)


func set_camp(pos: Vector2) -> void:
	camp_position = pos
	has_camp = true


func get_save_data() -> Dictionary:
	return {
		"phase": int(phase),
		"camp_position": camp_position,
		"has_camp": has_camp,
		"flags": flags.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	var new_phase: Enums.Phase = int(data.get("phase", 0)) as Enums.Phase
	camp_position = data.get("camp_position", Vector2.ZERO)
	has_camp = data.get("has_camp", false)
	flags = data.get("flags", {})
	phase = new_phase
	EventBus.phase_changed.emit(int(phase))
