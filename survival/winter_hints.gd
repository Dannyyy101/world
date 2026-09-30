class_name WinterHints
extends Node
## Winter-Vorbereitung als Spielgefühl (Besitzer: Agent 3). Ab Herbstmitte häufen sich Hinweise auf den
## nahenden Winter: erst ein Traum, dann Stamm/Beobachtung, dann der erste Frost.
## Emittiert hint_requested (Agent 6 zeigt die Höhlenmalerei) und notification_requested (Agent 8).
## Jede Stufe feuert höchstens einmal pro Jahr.

## Tag der Jahreszeit -> {key, source, discovery, text}
const STAGES: Array = [
	{"day": 14, "key": "dream", "source": &"dream", "discovery": &"smoking",
		"text": "Im Traum: verschneite Hügel und ein leerer Magen. Der Winter wird kommen."},
	{"day": 20, "key": "tribe", "source": &"tribe", "discovery": &"fur_clothing",
		"text": "Die Vögel ziehen fort, die Nächte werden bitterkalt. Wärmende Felle wären gut."},
	{"day": 26, "key": "frost", "source": &"observation", "discovery": &"smoking",
		"text": "Der erste Frost liegt auf dem Gras. Bald gibt es kaum noch Beeren."},
]

var _done: Dictionary = {}   ## "<jahr>_<key>" -> true


func _ready() -> void:
	SaveManager.register("winter_hints", self)
	EventBus.day_started.connect(_on_day_started)


func _on_day_started(_day: int) -> void:
	if TimeManager.season != Enums.Season.AUTUMN:
		return
	var dos: int = TimeManager.get_day_of_season()
	for stage in STAGES:
		var key: String = "%d_%s" % [TimeManager.year, stage["key"]]
		if dos >= int(stage["day"]) and not _done.has(key):
			_done[key] = true
			_fire(stage)
			return   # höchstens eine Stufe pro Tag


func _fire(stage: Dictionary) -> void:
	var source: StringName = stage["source"]
	# Ohne Stamm kann niemand warnen -> Beobachtung.
	if source == &"tribe" and Tribe.get_size() <= 0:
		source = &"observation"
	var discovery: StringName = stage["discovery"]
	if not Discoveries.is_unlocked(discovery):
		EventBus.hint_requested.emit(discovery, source)
	EventBus.notification_requested.emit(stage["text"], null)


func get_save_data() -> Dictionary:
	return {"done": _done.keys()}


func load_save_data(data: Dictionary) -> void:
	_done.clear()
	for k in data.get("done", []):
		_done[str(k)] = true
