class_name WorldWeather
extends Node
## Einfaches, deterministisches Tageswetter (Seed + Tag). Emittiert EventBus.weather_changed.
## Schnee im Winter, sonst klar/Regen/Nebel/Sturm. Die Welt ist Emittent laut ARCHITECTURE §10.

var world_seed: int = 0
var current: StringName = &"clear"


func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)


func _on_day_started(day: int) -> void:
	set_day(day)


func set_day(day: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([world_seed, day])
	var roll: float = rng.randf()
	var w: StringName = _pick(int(TimeManager.season), roll)
	if w != current:
		current = w
		EventBus.weather_changed.emit(current)


func is_raining() -> bool:
	return current == &"rain" or current == &"storm"


static func _pick(season: int, roll: float) -> StringName:
	# [Schwellen für Regen, Sturm, Nebel, Schnee] – kumulativ
	var rain: float = 0.0
	var storm: float = 0.0
	var fog: float = 0.0
	var snow: float = 0.0
	match season:
		Enums.Season.SPRING:
			rain = 0.30; storm = 0.03; fog = 0.10
		Enums.Season.SUMMER:
			rain = 0.14; storm = 0.06; fog = 0.04
		Enums.Season.AUTUMN:
			rain = 0.30; storm = 0.06; fog = 0.20
		_:
			snow = 0.35; fog = 0.10
	if roll < rain:
		return &"rain"
	if roll < rain + storm:
		return &"storm"
	if roll < rain + storm + fog:
		return &"fog"
	if roll < rain + storm + fog + snow:
		return &"snow"
	return &"clear"
