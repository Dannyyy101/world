extends Node2D
## Test des Überlebenssystems: Stats, Wetter, Tag/Nacht, Kollaps & Aufwachen, Schlaf, Speichern.
## Interaktiv (F6): 1–5 Wetter (klar/Regen/Sturm/Schnee/Nebel) · F Lagerfeuer an/aus · H Hunger/Durst/Wärme leeren
##   R alles füllen · K Kollaps · T +3 Stunden · Y nächste Jahreszeit · E am braunen Feld schlafen · WASD laufen
## Headless: godot --headless --path . res://survival/tests/test_survival.tscn  (Exit 0 = ok)

var _failures: int = 0
var _weather_events: Array[StringName] = []
var _actions: Array[StringName] = []
var _collapses: Array[StringName] = []
var _stat_events: int = 0
var _hints: int = 0
var _fire_on: bool = false

@onready var _player: Player = $Player
@onready var _fire: Node2D = $Fire
@onready var _label: Label = $CanvasLayer/Label


func _ready() -> void:
	EventBus.weather_changed.connect(func(w: StringName) -> void: _weather_events.append(w))
	EventBus.action_performed.connect(func(a: StringName, _c: Dictionary) -> void: _actions.append(a))
	EventBus.player_collapsed.connect(func(r: StringName) -> void: _collapses.append(r))
	EventBus.player_stat_changed.connect(func(_s: StringName, _v: float, _m: float) -> void: _stat_events += 1)
	EventBus.hint_requested.connect(func(_d: StringName, _s: StringName) -> void: _hints += 1)
	_fire.remove_from_group("heat_source")
	if DisplayServer.get_name() == "headless":
		_run_checks()


func _process(_delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var t: Dictionary = PlayerStats.get_temperature_breakdown()
	_label.text = "Tag %d (%s) %s · Wetter: %s\nHP %d  Hunger %d  Durst %d  Wärme %d  Energie %d\nZiel-Wärme %d (Feuer %d, Schutz %d)  Tempo x%.2f\n1-5 Wetter · F Feuer · H leeren · R füllen · K Kollaps · T +3h · Y Jahreszeit · E schlafen" % [
		TimeManager.day, ["Frühling", "Sommer", "Herbst", "Winter"][int(TimeManager.season)],
		TimeManager.get_time_string(), PlayerStats.weather.current,
		PlayerStats.get_value(&"health"), PlayerStats.get_value(&"hunger"), PlayerStats.get_value(&"thirst"),
		PlayerStats.get_value(&"warmth"), PlayerStats.get_value(&"energy"),
		t.get("target", 0.0), t.get("fire", 0.0), t.get("shelter", 0.0), PlayerStats.get_speed_multiplier()]


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_1: PlayerStats.debug_set_weather(&"clear")
		KEY_2: PlayerStats.debug_set_weather(&"rain")
		KEY_3: PlayerStats.debug_set_weather(&"storm")
		KEY_4: PlayerStats.debug_set_weather(&"snow")
		KEY_5: PlayerStats.debug_set_weather(&"fog")
		KEY_F: _toggle_fire()
		KEY_H: PlayerStats.debug_drain_stats()
		KEY_R: PlayerStats.debug_fill_stats()
		KEY_K: PlayerStats.debug_collapse(&"exhaustion")
		KEY_T: PlayerStats.debug_set_hour(TimeManager.hour + 3.0)
		KEY_Y: PlayerStats.debug_set_season(((int(TimeManager.season) + 1) % 4) as Enums.Season)


func _toggle_fire() -> void:
	_fire_on = not _fire_on
	if _fire_on:
		_fire.add_to_group("heat_source")
		EventBus.fire_lit.emit(_fire)
	else:
		_fire.remove_from_group("heat_source")
		EventBus.fire_extinguished.emit(_fire)
	$Fire/Glow.visible = _fire_on


func _check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_failures += 1


func _tick(hours: float) -> void:
	PlayerStats.call("_tick", hours)


func _run_checks() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	PlayerStats.debug_fill_stats()
	TimeManager.pause()   # Tests treiben die Simulation selbst voran
	_check(GameState.player == _player, "Player registriert")
	_check(_stat_events >= 5, "player_stat_changed wird emittiert")

	# --- Hunger/Durst sinken, Bewegung beschleunigt ---
	_tick(5.0)
	_check(PlayerStats.get_value(&"hunger") < 100.0 and PlayerStats.get_value(&"thirst") < 100.0, "Hunger/Durst sinken")
	_check(PlayerStats.get_value(&"thirst") < PlayerStats.get_value(&"hunger"), "Durst sinkt schneller als Hunger")

	# --- Wetter ---
	PlayerStats.debug_set_season(Enums.Season.WINTER)
	PlayerStats.debug_set_weather(&"clear")
	PlayerStats.debug_set_hour(12.0)
	var clear_target: float = float(PlayerStats.get_temperature_breakdown()["target"])
	PlayerStats.debug_set_weather(&"snow")
	_check(_weather_events.has(&"snow"), "weather_changed(snow) emittiert")
	var snow_target: float = float(PlayerStats.get_temperature_breakdown()["target"])
	_check(snow_target < clear_target, "Schnee ist kälter als klares Wetter")
	PlayerStats.debug_set_hour(23.0)
	var night_target: float = float(PlayerStats.get_temperature_breakdown()["target"])
	_check(night_target < snow_target, "Nachts ist es kälter")
	# Feuer wärmt
	_player.global_position = _fire.global_position + Vector2(8, 0)
	_toggle_fire()
	var fire_target: float = float(PlayerStats.get_temperature_breakdown()["target"])
	_check(fire_target > night_target + 20.0, "Nähe zu Feuer wärmt")
	_toggle_fire()
	# Unterschlupf schützt vor Wetter
	var shelter_place: SleepingPlace = $SleepingPlace
	_player.global_position = shelter_place.global_position
	_check(PlayerStats.is_sheltered(), "Schlafplatz zählt als Unterschlupf")
	_check(float(PlayerStats.get_temperature_breakdown()["weather"]) == 0.0, "Unterschlupf negiert Wettermalus")
	_player.global_position = Vector2(300, 300)
	# Kälte kostet Gesundheit
	PlayerStats.debug_fill_stats()
	PlayerStats.debug_set_stat(&"warmth", 0.0)
	var hp: float = PlayerStats.get_value(&"health")
	_tick(0.5)
	_check(PlayerStats.get_value(&"health") < hp, "Wärme 0 kostet Gesundheit")
	_check(PlayerStats.get_speed_multiplier() < 1.0, "niedrige Wärme verlangsamt")
	_check(float(PlayerStats.get_screen_effects().get(&"cold", 0.0)) > 0.5, "Bildrand-Effekt 'cold' aktiv")

	# --- Wetter-Wahrscheinlichkeiten je Jahreszeit ---
	var snow_in_summer: bool = false
	var rain_in_winter: bool = false
	for i in 200:
		PlayerStats.debug_set_season(Enums.Season.SUMMER)
		PlayerStats.weather.roll_new_weather()
		if PlayerStats.weather.current == &"snow":
			snow_in_summer = true
		PlayerStats.debug_set_season(Enums.Season.WINTER)
		PlayerStats.weather.roll_new_weather()
		if PlayerStats.weather.current == &"rain":
			rain_in_winter = true
	_check(not snow_in_summer, "Sommer: nie Schnee")
	_check(not rain_in_winter, "Winter: nie Regen")

	# --- Tag/Nacht ---
	var noon: Color = DayNightCycle.color_for_hour(12.0)
	var midnight: Color = DayNightCycle.color_for_hour(23.5)
	_check(noon.get_luminance() > midnight.get_luminance() * 2.5, "Mittag deutlich heller als Nacht")

	# --- Kollaps & Aufwachen ---
	TimeManager.load_save_data({"day": 5, "hour": 12.0})
	PlayerStats.debug_fill_stats()
	Inventory.add_item(&"stone", 10)
	Inventory.add_item(&"berries", 4)
	var day_before: int = TimeManager.day
	_collapses.clear()
	_player.global_position = Vector2(200, 200)
	GameState.set_camp(Vector2(-40, -40))
	PlayerStats.debug_set_stat(&"health", 0.0)
	_tick(0.01)
	_check(_collapses.has(&"starvation") or _collapses.has(&"exposure") or _collapses.has(&"dehydration") or _collapses.has(&"exhaustion"),
		"player_collapsed bei Gesundheit 0")
	_check(PlayerStats.get_value(&"health") > 0.0, "Aufwachen: Gesundheit wiederhergestellt")
	_check(Inventory.count(&"stone") < 10 and Inventory.count(&"stone") > 0, "Kollaps kostet einen Teil des Inventars")
	_check(TimeManager.day >= day_before, "Kollaps verliert Zeit (Tag >= vorher)")
	_check(_player.global_position.distance_to(Vector2(-40, -40)) < 1.0, "Aufwachen am Lager")
	GameState.has_camp = false

	# --- Schlaf ---
	PlayerStats.debug_set_season(Enums.Season.SPRING)
	PlayerStats.debug_set_hour(21.0)
	PlayerStats.debug_set_stat(&"energy", 10.0)
	_actions.clear()
	var day_pre: int = TimeManager.day
	_check(PlayerStats.sleep(1.0, shelter_place), "Schlafen am Schlafplatz")
	_check(PlayerStats.get_value(&"energy") >= 99.9, "Schlaf füllt Energie")
	_check(TimeManager.day == day_pre + 1 and is_equal_approx(TimeManager.hour, 6.0), "Schlaf springt zum Morgen")
	_check(_actions.has(&"sleep"), "action_performed(sleep)")
	_check(_actions.has(&"survive_night"), "action_performed(survive_night)")
	PlayerStats.debug_set_hour(10.0)
	PlayerStats.debug_set_stat(&"energy", 90.0)
	_check(not PlayerStats.sleep(1.0), "Tagsüber ausgeruht: kein Schlaf")

	# --- Winter überlebt ---
	_actions.clear()
	PlayerStats.debug_set_season(Enums.Season.WINTER)
	PlayerStats.debug_set_season(Enums.Season.SPRING)
	_check(_actions.has(&"survive_winter"), "action_performed(survive_winter) beim Frühlingsanfang")

	# --- Winter-Hinweise ---
	_hints = 0
	PlayerStats.debug_set_day_of_season(Enums.Season.AUTUMN, 14)
	_check(_hints >= 1, "Herbstmitte: Traum-Hinweis auf den Winter (hint_requested)")
	_check(is_equal_approx(PlayerStats.get_forage_factor(), 0.8), "Herbst: reduzierte Sammelmenge")
	PlayerStats.debug_set_season(Enums.Season.WINTER)
	_check(PlayerStats.get_forage_factor() < 0.2, "Winter: kaum Beeren/Pflanzen")

	# --- Speichern ---
	PlayerStats.debug_set_stat(&"hunger", 42.0)
	var saved: Dictionary = SaveManager.decode_value(SaveManager.encode_value(PlayerStats.get_save_data()))
	PlayerStats.debug_set_stat(&"hunger", 99.0)
	PlayerStats.load_save_data(saved)
	_check(is_equal_approx(PlayerStats.get_value(&"hunger"), 42.0), "Stats werden gespeichert/geladen")
	var wsave: Dictionary = PlayerStats.weather.get_save_data()
	PlayerStats.weather.load_save_data(wsave)
	_check(PlayerStats.weather.current == wsave["weather"], "Wetter wird gespeichert/geladen")

	print("== ", "ALLE TESTS BESTANDEN" if _failures == 0 else "%d FEHLER" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
