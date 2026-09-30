extends Node
## Test der Kern-Autoloads: EventBus, GameState, TimeManager, ItemDB, SaveManager, Stubs.
## Starten: Szene öffnen und F6 drücken, oder headless:
##   godot --headless --path . res://core/tests/test_core.tscn
## Ergebnis steht im Output/Label; im Headless-Modus endet der Prozess mit Exit-Code 0 (ok) / 1 (Fehler).

var _failures: int = 0
var _log: Array[String] = []
var _events: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	_test_stubs()
	_test_game_state_and_save()
	_test_time()
	_test_item_db()
	_test_save_encoding()
	var summary: String = "ALLE TESTS BESTANDEN" if _failures == 0 else "%d FEHLER" % _failures
	_log.append("== " + summary)
	print("\n".join(_log))
	($Label as Label).text = "\n".join(_log)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures == 0 else 1)


func _check(cond: bool, what: String) -> void:
	if cond:
		_log.append("ok   " + what)
	else:
		_failures += 1
		_log.append("FAIL " + what)


func _test_stubs() -> void:
	_check(Inventory.add_item(&"branch", 3) == 0, "Inventory.add_item liefert Rest 0")
	_check(Inventory.count(&"branch") == 3 and Inventory.has_item(&"branch", 3), "Inventory.count/has_item")
	_check(Inventory.remove_item(&"branch", 2) and not Inventory.remove_item(&"branch", 5), "Inventory.remove_item")
	_check(Inventory.get_equipped() == null, "Inventory.get_equipped() == null")
	Inventory.damage_equipped(1)
	PlayerStats.modify(&"hunger", -30.0)
	_check(is_equal_approx(PlayerStats.get_value(&"hunger"), 70.0), "PlayerStats.modify/get_value")
	_check(not PlayerStats.eat(&"berries"), "PlayerStats.eat (Stub)")
	_check(not Discoveries.is_unlocked(&"fire"), "Discoveries.is_unlocked false")
	Discoveries.unlock(&"fire")
	_check(Discoveries.is_unlocked(&"fire") and Discoveries.get_progress(&"fire") == 1.0, "Discoveries.unlock")
	_check(Tribe.get_size() == 0 and Tribe.get_members().is_empty(), "Tribe-Stub")


class Dummy extends Node:
	var value: Dictionary = {}
	func get_save_data() -> Dictionary:
		return value.duplicate(true)
	func load_save_data(data: Dictionary) -> void:
		value = data


func _test_game_state_and_save() -> void:
	GameState.set_phase(Enums.Phase.MITTELSTEINZEIT)
	GameState.set_camp(Vector2(12.5, -40))
	GameState.set_flag("first_fire", true)
	GameState.set_flag("spot", Vector2i(3, 4))
	var dummy: Dummy = Dummy.new()
	add_child(dummy)
	dummy.value = {"n": 7, "pos": Vector2(1.5, 2.5), "id": &"deer", "list": [1, 2, 3], "f": 0.25}
	SaveManager.register("test_dummy", dummy)
	_check(SaveManager.save_game(99), "SaveManager.save_game(99)")
	# Zustand zerstören
	GameState.set_phase(Enums.Phase.ALTSTEINZEIT)
	GameState.camp_position = Vector2.ZERO
	GameState.has_camp = false
	GameState.flags = {}
	dummy.value = {}
	_check(SaveManager.load_game(99), "SaveManager.load_game(99)")
	_check(GameState.phase == Enums.Phase.MITTELSTEINZEIT, "GameState.phase wiederhergestellt")
	_check(GameState.camp_position == Vector2(12.5, -40) and GameState.has_camp, "camp_position wiederhergestellt")
	_check(GameState.get_flag("first_fire") == true and GameState.get_flag("spot") == Vector2i(3, 4), "flags wiederhergestellt")
	_check(GameState.get_flag("missing", 5) == 5, "get_flag default")
	_check(dummy.value.get("n") is int and dummy.value["n"] == 7, "int bleibt int")
	_check(dummy.value.get("pos") == Vector2(1.5, 2.5), "Vector2 Roundtrip")
	_check(dummy.value.get("f") == 0.25 and dummy.value.get("list") == [1, 2, 3], "float/Array Roundtrip")
	SaveManager.unregister("test_dummy")
	dummy.queue_free()
	SaveManager.delete_save(99)
	_check(not SaveManager.load_game(99), "load_game ohne Datei -> false")
	GameState.flags = {}
	GameState.set_phase(Enums.Phase.ALTSTEINZEIT)
	GameState.has_camp = false
	GameState.camp_position = Vector2.ZERO


func _on_day_started(d: int) -> void:
	_events.append("day_started:%d" % d)


func _on_day_ended(d: int) -> void:
	_events.append("day_ended:%d" % d)


func _on_hour(h: int) -> void:
	_events.append("hour:%d" % h)


func _on_season(s: int) -> void:
	_events.append("season:%d" % s)


func _on_collapsed(reason: StringName) -> void:
	_events.append("collapsed:%s" % reason)


func _test_time() -> void:
	TimeManager.pause()
	var saved: Dictionary = TimeManager.get_save_data()
	TimeManager.load_save_data({"day": 1, "hour": 6.0})
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.hour_changed.connect(_on_hour)
	EventBus.season_changed.connect(_on_season)
	EventBus.player_collapsed.connect(_on_collapsed)
	_events.clear()
	TimeManager.resume()
	TimeManager.time_scale = 1.0
	TimeManager.pause()
	# Eine Stunde vorspulen
	TimeManager._advance_hours(1.0)
	_check(TimeManager.get_hour_int() == 7 and _events.has("hour:7"), "hour_changed bei 7 Uhr")
	_check(not TimeManager.is_night(), "7 Uhr ist nicht Nacht")
	# Bis 20 Uhr -> Nacht
	TimeManager._advance_hours(13.0)
	_check(TimeManager.is_night(), "20 Uhr ist Nacht")
	# Bis Zwangsschlaf (2 Uhr = 20h nach Aufwachen)
	TimeManager._advance_hours(6.5)
	_check(_events.has("collapsed:forced_sleep"), "Zwangsschlaf um 2 Uhr")
	_check(_events.has("day_ended:1") and _events.has("day_started:2"), "day_ended/day_started beim Übergang")
	_check(TimeManager.day == 2 and is_equal_approx(TimeManager.hour, 6.0), "Tag 2, 6:00")
	# Jahreszeit
	_events.clear()
	TimeManager.load_save_data({"day": TimeManager.DAYS_PER_SEASON, "hour": 10.0})
	TimeManager.skip_to_morning()
	_check(TimeManager.season == Enums.Season.SUMMER and _events.has("season:1"), "Sommer nach 28 Tagen")
	TimeManager.load_save_data({"day": TimeManager.DAYS_PER_SEASON * 4, "hour": 10.0})
	TimeManager.skip_to_morning()
	_check(TimeManager.year == 2 and TimeManager.season == Enums.Season.SPRING, "Jahr 2, Frühling")
	EventBus.day_started.disconnect(_on_day_started)
	EventBus.day_ended.disconnect(_on_day_ended)
	EventBus.hour_changed.disconnect(_on_hour)
	EventBus.season_changed.disconnect(_on_season)
	EventBus.player_collapsed.disconnect(_on_collapsed)
	TimeManager.load_save_data(saved)
	TimeManager.resume()


func _test_item_db() -> void:
	# Ohne .tres-Dateien (Agent 2 liefert die Daten) muss ItemDB trotzdem sauber laufen.
	ItemDB.reload()
	_check(ItemDB.get_item(&"__does_not_exist__") == null, "ItemDB.get_item unbekannt -> null")
	_check(ItemDB.get_recipe(&"__does_not_exist__") == null, "ItemDB.get_recipe unbekannt -> null")
	_check(ItemDB.all_recipes() is Array, "ItemDB.all_recipes() liefert Array")
	var item: ItemData = ItemData.new()
	item.id = &"test"
	_check(item.category == Enums.ItemCategory.MATERIAL and item.max_stack == 99, "ItemData-Defaults")
	var recipe: RecipeData = RecipeData.new()
	recipe.inputs = {&"branch": 2}
	_check(recipe.inputs[&"branch"] == 2 and recipe.station == Enums.Station.HAND, "RecipeData-Defaults")
	var disc: DiscoveryData = DiscoveryData.new()
	_check(disc.trigger_type == DiscoveryData.TriggerType.ACTION_COUNT, "DiscoveryData-Defaults")


func _test_save_encoding() -> void:
	var enc: Variant = SaveManager.encode_value({"a": Vector2(1, 2), "b": [Color.RED, &"x"]})
	var json: String = JSON.stringify(enc)
	var dec: Variant = SaveManager.decode_value(JSON.parse_string(json))
	_check(dec["a"] == Vector2(1, 2) and dec["b"][0] == Color.RED and dec["b"][1] == "x", "encode/decode Roundtrip via JSON")
