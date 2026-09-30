class_name WeatherSystem
extends Node
## Wettersystem (Besitzer: Agent 3). Wird von PlayerStats als Kind erzeugt (PlayerStats.weather).
## Wetter dauert einige Spielstunden und wird je Jahreszeit gewichtet gewürfelt.
## Wechsel -> EventBus.weather_changed (Agent 4 löscht daraufhin ungeschützte Feuer bei &"rain"/&"storm").

const CLEAR: StringName = &"clear"
const RAIN: StringName = &"rain"
const STORM: StringName = &"storm"
const SNOW: StringName = &"snow"
const FOG: StringName = &"fog"

## Gewichte je Jahreszeit (Enums.Season -> Wetter -> Gewicht). Gewicht 0 = in dieser Jahreszeit unmöglich.
const WEIGHTS: Dictionary = {
	Enums.Season.SPRING: {CLEAR: 40, RAIN: 45, FOG: 10, STORM: 5},
	Enums.Season.SUMMER: {CLEAR: 75, RAIN: 12, FOG: 5, STORM: 8},
	Enums.Season.AUTUMN: {CLEAR: 25, RAIN: 20, FOG: 30, STORM: 25},
	Enums.Season.WINTER: {CLEAR: 25, SNOW: 60, FOG: 15},
}
## Zusätzliche Kälte (Punkte auf die Umgebungswärme, negativ = kälter).
const TEMPERATURE_MOD: Dictionary = {CLEAR: 0.0, RAIN: -12.0, STORM: -20.0, SNOW: -10.0, FOG: -4.0}
const MIN_HOURS: int = 3
const MAX_HOURS: int = 8

var current: StringName = CLEAR
var _hours_left: int = 6
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	SaveManager.register("weather", self)
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.season_changed.connect(_on_season_changed)
	EventBus.day_started.connect(_on_day_started)
	call_deferred("_emit_current")


func _emit_current() -> void:
	EventBus.weather_changed.emit(current)


## Regen, Sturm oder Schnee.
func is_precipitation() -> bool:
	return current == RAIN or current == STORM or current == SNOW


func is_wet() -> bool:
	return current == RAIN or current == STORM


func get_temperature_modifier() -> float:
	return TEMPERATURE_MOD.get(current, 0.0)


## Setzt das Wetter sofort (Debug / Skripte). duration_hours <= 0 = zufällige Dauer.
func force_weather(weather: StringName, duration_hours: int = 0) -> void:
	_hours_left = duration_hours if duration_hours > 0 else _rng.randi_range(MIN_HOURS, MAX_HOURS)
	_set_weather(weather)


func roll_new_weather() -> void:
	_hours_left = _rng.randi_range(MIN_HOURS, MAX_HOURS)
	_set_weather(_pick_for_season(TimeManager.season))


func _pick_for_season(season: int) -> StringName:
	var table: Dictionary = WEIGHTS.get(season, WEIGHTS[Enums.Season.SPRING])
	var total: float = 0.0
	for w in table:
		total += float(table[w])
	var roll: float = _rng.randf() * total
	for w in table:
		roll -= float(table[w])
		if roll <= 0.0:
			return w
	return CLEAR


func _set_weather(weather: StringName) -> void:
	if weather == current:
		return
	current = weather
	EventBus.weather_changed.emit(current)


func _on_hour_changed(_hour: int) -> void:
	_hours_left -= 1
	if _hours_left <= 0:
		roll_new_weather()


func _on_day_started(_day: int) -> void:
	# Die Nacht ist vergangen (Schlaf überspringt Stunden): Wetter nach ~6 Stunden ggf. neu würfeln.
	_hours_left -= 6
	if _hours_left <= 0:
		roll_new_weather()


func _on_season_changed(season: int) -> void:
	# Unmögliches Wetter (Schnee im Sommer) sofort ersetzen.
	var table: Dictionary = WEIGHTS.get(season, {})
	if int(table.get(current, 0)) <= 0:
		roll_new_weather()


func get_save_data() -> Dictionary:
	return {"weather": current, "hours_left": _hours_left}


func load_save_data(data: Dictionary) -> void:
	_hours_left = int(data.get("hours_left", 6))
	current = StringName(data.get("weather", CLEAR))
	EventBus.weather_changed.emit(current)
