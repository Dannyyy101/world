extends Node
## TimeManager – Tageszyklus, Kalender (Besitzer: Agent 0).
##
## Ein Spieltag = die Wachzeit von 6:00 bis 2:00 Uhr (20 Spielstunden) und dauert
## DAY_REAL_MINUTES Echtminuten. Um 2:00 Uhr Zwangsschlaf -> skip_to_morning().
## Kalender: Tag 1 = Frühling, DAYS_PER_SEASON Tage je Jahreszeit, 4 Jahreszeiten = 1 Jahr.

const DAY_REAL_MINUTES: float = 14.0   ## <- hier Tageslänge ändern
const DAYS_PER_SEASON: int = 28
const WAKE_HOUR: float = 6.0
const FORCED_SLEEP_HOUR: float = 2.0
const NIGHT_START_HOUR: float = 20.0
const WAKING_HOURS: float = 20.0       ## 6:00 -> 2:00

## Tageszeit 0..24
var hour: float = WAKE_HOUR
var day: int = 1
var season: Enums.Season = Enums.Season.SPRING
var year: int = 1
## Debug-Multiplikator (z. B. 60.0 für Zeitraffer)
var time_scale: float = 1.0

var _paused: bool = false
var _last_hour_int: int = int(WAKE_HOUR)


func _ready() -> void:
	SaveManager.register("time", self)
	_update_calendar(false)
	call_deferred("_emit_initial")


func _emit_initial() -> void:
	EventBus.season_changed.emit(int(season))
	EventBus.hour_changed.emit(_last_hour_int)
	EventBus.day_started.emit(day)


func _process(delta: float) -> void:
	if _paused:
		return
	var hours_per_second: float = WAKING_HOURS / (DAY_REAL_MINUTES * 60.0)
	_advance_hours(delta * hours_per_second * time_scale)


func _advance_hours(hours: float) -> void:
	var awake: float = _hours_awake()
	var new_awake: float = awake + hours
	if new_awake >= WAKING_HOURS:
		hour = FORCED_SLEEP_HOUR
		EventBus.player_collapsed.emit(&"forced_sleep")
		skip_to_morning()
		return
	hour = fposmod(WAKE_HOUR + new_awake, 24.0)
	var h: int = int(hour)
	if h != _last_hour_int:
		_last_hour_int = h
		EventBus.hour_changed.emit(h)


## Stunden seit dem Aufwachen (0 .. WAKING_HOURS).
func _hours_awake() -> float:
	return clampf(fposmod(hour - WAKE_HOUR, 24.0), 0.0, WAKING_HOURS)


func is_night() -> bool:
	return hour >= NIGHT_START_HOUR or hour < WAKE_HOUR


func get_hour_int() -> int:
	return int(hour)


## "HH:MM"
func get_time_string() -> String:
	var h: int = int(hour)
	var m: int = int((hour - float(h)) * 60.0)
	return "%02d:%02d" % [h, m]


func pause() -> void:
	_paused = true


func resume() -> void:
	_paused = false


func is_paused() -> bool:
	return _paused


## Beendet den aktuellen Tag und startet den nächsten um 6:00 (Schlafen / Zwangsschlaf).
func skip_to_morning() -> void:
	EventBus.day_ended.emit(day)
	day += 1
	hour = WAKE_HOUR
	_last_hour_int = int(WAKE_HOUR)
	_update_calendar(true)
	EventBus.hour_changed.emit(_last_hour_int)
	EventBus.day_started.emit(day)


func _update_calendar(emit_changes: bool) -> void:
	var idx: int = day - 1
	var new_season: Enums.Season = ((idx / DAYS_PER_SEASON) % 4) as Enums.Season
	year = 1 + idx / (DAYS_PER_SEASON * 4)
	if new_season != season:
		season = new_season
		if emit_changes:
			EventBus.season_changed.emit(int(season))


func get_day_of_season() -> int:
	return ((day - 1) % DAYS_PER_SEASON) + 1


func get_save_data() -> Dictionary:
	return {"day": day, "hour": hour}


func load_save_data(data: Dictionary) -> void:
	day = maxi(1, int(data.get("day", 1)))
	hour = float(data.get("hour", WAKE_HOUR))
	_last_hour_int = int(hour)
	_update_calendar(false)
	season = (((day - 1) / DAYS_PER_SEASON) % 4) as Enums.Season
	EventBus.season_changed.emit(int(season))
	EventBus.hour_changed.emit(_last_hour_int)
	EventBus.day_started.emit(day)
