class_name FireProcess
extends Resource
## Ein Feuer-Prozess (Kochen, Härten, Räuchern, Brennen, Schmelzen) als Daten.
## Liegt unter res://fire/data/processes/*.tres. Alle Zeiten in SPIELSTUNDEN
## (1 Spielstunde = DAY_REAL_MINUTES*60/20 Echtsekunden, aktuell 42 s).

const DIR: String = "res://fire/data/processes"

@export var id: StringName = &""
@export var station: Enums.Station = Enums.Station.CAMPFIRE
@export var input_id: StringName = &""
## Zusätzliche Zutaten (Item-ID -> Menge), z. B. charcoal beim Schmelzen.
@export var extra_inputs: Dictionary = {}
@export var output_id: StringName = &""
@export var output_amount: int = 1
@export var duration_hours: float = 0.3
## > 0: Nach Fertigstellung verbrennt das Gut nach dieser Zeit (Kochen). 0 = bleibt ewig fertig.
@export var burn_after_hours: float = 0.0
## Nur Ofen: Fortschritt läuft nur bei mindestens dieser Temperatur (°C).
@export var min_temperature: float = 0.0
## action_performed-ID bei Fertigstellung
@export var action_id: StringName = &""

static var _cache: Array[FireProcess] = []
static var _loaded: bool = false


static func all() -> Array[FireProcess]:
	if not _loaded:
		_loaded = true
		var dir: DirAccess = DirAccess.open(DIR)
		if dir == null:
			push_warning("FireProcess: %s nicht lesbar" % DIR)
		else:
			for file in dir.get_files():
				var f: String = file.trim_suffix(".remap")
				if not f.ends_with(".tres"):
					continue
				var res: Resource = load("%s/%s" % [DIR, f])
				if res is FireProcess:
					_cache.append(res as FireProcess)
	return _cache


static func for_station(s: Enums.Station) -> Array[FireProcess]:
	var out: Array[FireProcess] = []
	for p in all():
		if p.station == s:
			out.append(p)
	return out


static func find_by_id(process_id: StringName) -> FireProcess:
	for p in all():
		if p.id == process_id:
			return p
	return null
