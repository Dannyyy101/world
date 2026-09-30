extends Node
## PlayerStats – Überleben, Wetter & Jahreszeiten-Druck (Besitzer: Agent 3).
##
## Autoload. Stats (je 0–100): &"health", &"hunger", &"thirst", &"warmth", &"energy".
## Hunger/Durst/Energie sinken mit der Spielzeit (schneller bei Bewegung). Wärme strebt einer Zieltemperatur zu,
## die von Jahreszeit, Tageszeit, Wetter, Feuer (Gruppe "heat_source"), Unterschlupf (Gruppe "shelter")
## und Kleidung abhängt. Leere Werte kosten Gesundheit; Gesundheit 0 -> Kollaps (kein Spielstandverlust).
## Erzeugt als Kinder: WeatherSystem (weather), DayNightCycle, WeatherEffects, WinterHints.

## Bildrand-Effekt für die UI (Agent 8): effect = &"hunger", &"thirst", &"cold", &"exhaustion", &"health";
## intensity 0..1 (0 = aus). Aktueller Stand: get_screen_effects().
signal screen_effect_changed(effect: StringName, intensity: float)
## Spieler ist nach Schlaf oder Kollaps aufgewacht (reason: &"sleep" oder der Kollaps-Grund).
signal woke_up(reason: StringName)

const MAX_VALUE: float = 100.0
const STATS: Array[StringName] = [&"health", &"hunger", &"thirst", &"warmth", &"energy"]

# --- Balancing (Werte pro SPIELSTUNDE; ein Spieltag hat 20 Wachstunden) ---
const HUNGER_PER_HOUR: float = 2.0
const THIRST_PER_HOUR: float = 3.0
const ENERGY_PER_HOUR: float = 3.5
const MOVING_HUNGER_THIRST_FACTOR: float = 1.5
const MOVING_ENERGY_FACTOR: float = 1.3
const COLD_HUNGER_FACTOR: float = 1.25    ## Frieren verbrennt Kalorien
const WARMTH_RATE: float = 0.5            ## Anteil des Abstands zur Zieltemperatur pro Stunde
const HEALTH_DRAIN_PER_HOUR: float = 3.0  ## je leerem Wert
const HEALTH_REGEN_PER_HOUR: float = 1.5

const LOW_THRESHOLD: float = 30.0         ## ab hier Warnung, Bildrand-Effekt und Verlangsamung
const MIN_SPEED_MULTIPLIER: float = 0.55
const EMIT_EPSILON: float = 0.1

# --- Temperatur (Punkte auf der Wärmeskala) ---
const SEASON_BASE_WARMTH: Dictionary = {
	Enums.Season.SPRING: 55.0, Enums.Season.SUMMER: 80.0, Enums.Season.AUTUMN: 42.0, Enums.Season.WINTER: 12.0,
}
const NIGHT_COLD: Dictionary = {
	Enums.Season.SPRING: 16.0, Enums.Season.SUMMER: 10.0, Enums.Season.AUTUMN: 16.0, Enums.Season.WINTER: 18.0,
}
## Weniger Nahrung aus der Natur (Agent 1 kann Sammelmengen damit skalieren).
const FORAGE_FACTOR: Dictionary = {
	Enums.Season.SPRING: 0.85, Enums.Season.SUMMER: 1.0, Enums.Season.AUTUMN: 0.8, Enums.Season.WINTER: 0.1,
}
const DEFAULT_HEAT_RADIUS: float = 64.0
const DEFAULT_HEAT_STRENGTH: float = 45.0
const DEFAULT_SHELTER_RADIUS: float = 40.0
const DEFAULT_SHELTER_WARMTH: float = 18.0
const MAX_HEAT_BONUS: float = 60.0
## Fallback, solange kein Item-Datensatz für getragene Kleidung existiert.
const CLOTHING_IDS: Array[StringName] = [&"fur_clothing"]
const CLOTHING_FALLBACK_WARMTH: float = 25.0

# --- Kollaps ---
const COLLAPSE_LOSS_FRACTION: float = 0.35
const COLLAPSE_LOST_HOURS: float = 10.0   ## "ein halber Tag"
const COLLAPSE_RESTORE: Dictionary = {
	&"health": 40.0, &"hunger": 35.0, &"thirst": 35.0, &"warmth": 55.0, &"energy": 70.0,
}
## Fallback für verlierbare Items, wenn ItemDB sie (noch) nicht kennt. Werkzeug/Waffen/Kleidung bleiben.
const LOSSABLE_FALLBACK: Array[StringName] = [
	&"branch", &"stone", &"flint", &"flint_flake", &"wood_log", &"clay", &"nettle", &"cordage", &"tinder",
	&"hide", &"bone", &"fat", &"feather", &"wild_grain", &"flour", &"charcoal", &"malachite", &"amber",
	&"berries", &"raw_meat", &"cooked_meat", &"smoked_meat", &"raw_fish", &"cooked_fish", &"flatbread", &"mushroom",
]

const WARNINGS: Dictionary = {
	&"hunger": "Dein Magen knurrt. Du brauchst Nahrung.",
	&"thirst": "Deine Kehle ist trocken. Du brauchst Wasser.",
	&"warmth": "Dir ist eiskalt. Such Feuer oder Schutz.",
	&"energy": "Du kannst kaum noch die Augen offen halten.",
}
const COLLAPSE_TEXT: Dictionary = {
	&"starvation": "Vor Hunger bist du zusammengebrochen.",
	&"dehydration": "Vor Durst bist du zusammengebrochen.",
	&"exposure": "Die Kälte hat dich überwältigt.",
	&"exhaustion": "Erschöpft bist du zusammengebrochen.",
}

var weather: WeatherSystem
## Debug: keine Gesundheitsverluste.
var invulnerable: bool = false

var _values: Dictionary[StringName, float] = {
	&"health": MAX_VALUE,
	&"hunger": MAX_VALUE,
	&"thirst": MAX_VALUE,
	&"warmth": 70.0,
	&"energy": MAX_VALUE,
}
var _last_emitted: Dictionary[StringName, float] = {}
var _effects: Dictionary[StringName, float] = {}
var _warned: Dictionary[StringName, bool] = {}
var _tracked_fires: Dictionary[int, Node2D] = {}
var _drain_cause: StringName = &"exhaustion"
var _speed_multiplier: float = 1.0
var _applied_multiplier: float = -1.0
var _speed_player: Node2D = null
var _base_speed: float = 0.0
var _sleeping: bool = false
var _collapsing: bool = false
var _own_collapse_emit: bool = false
var _night_pending: bool = false
var _collapsed_this_night: bool = false
var _winter_active: bool = false
var _breakdown: Dictionary = {}


func _ready() -> void:
	SaveManager.register("player_stats", self)
	weather = WeatherSystem.new()
	weather.name = "Weather"
	add_child(weather)
	var daynight: DayNightCycle = DayNightCycle.new()
	daynight.name = "DayNight"
	add_child(daynight)
	var effects: WeatherEffects = WeatherEffects.new()
	effects.name = "WeatherEffects"
	add_child(effects)
	var hints: WinterHints = WinterHints.new()
	hints.name = "WinterHints"
	add_child(hints)
	EventBus.fire_lit.connect(_on_fire_lit)
	EventBus.fire_extinguished.connect(_on_fire_extinguished)
	EventBus.player_collapsed.connect(_on_player_collapsed)
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.season_changed.connect(_on_season_changed)
	call_deferred("_emit_all")


# ==================================================================================================
# Öffentliche API
# ==================================================================================================

func get_value(stat: StringName) -> float:
	return _values.get(stat, 0.0)


## Verändert einen Wert um delta (immer sofort player_stat_changed).
func modify(stat: StringName, delta: float) -> void:
	if not _values.has(stat):
		return
	_set_stat(stat, _values[stat] + delta, true)


## Isst/trinkt ein Item aus dem Inventar. Rückgabe: true, wenn konsumiert wurde.
## Entfernt 1 Stück aus dem Inventar (die UI muss es nicht selbst entfernen).
func eat(item_id: StringName) -> bool:
	var item: ItemData = ItemDB.get_item(item_id)
	if item == null or (item.nutrition <= 0.0 and item.hydration <= 0.0):
		return false
	if not Inventory.has_item(item_id):
		return false
	var helps_hunger: bool = item.nutrition > 0.0 and _values[&"hunger"] < MAX_VALUE - 0.5
	var helps_thirst: bool = item.hydration > 0.0 and _values[&"thirst"] < MAX_VALUE - 0.5
	if not (helps_hunger or helps_thirst):
		EventBus.notification_requested.emit("Du bist satt.", null)
		return false
	if not Inventory.remove_item(item_id, 1):
		return false
	modify(&"hunger", item.nutrition)
	modify(&"thirst", item.hydration)
	if item.category == Enums.ItemCategory.FOOD and item.warmth != 0.0:
		modify(&"warmth", item.warmth)
	EventBus.item_consumed.emit(item_id)
	return true


## Darf der Spieler jetzt schlafen? (abends/nachts oder wenn müde)
func can_sleep() -> bool:
	return TimeManager.hour >= 18.0 or TimeManager.hour < TimeManager.WAKE_HOUR \
		or _values[&"energy"] < 50.0


## Schlafen an einem Schlafplatz: Energie voll, Gesundheit erholt sich, Nacht vergeht.
## quality: 0.25–1.5 (Höhle/Hütte 1.0). Emittiert action_performed(&"sleep").
func sleep(quality: float = 1.0, place: Node2D = null) -> bool:
	if _sleeping or _collapsing:
		return false
	if not can_sleep():
		EventBus.notification_requested.emit("Du bist noch nicht müde.", null)
		return false
	_sleeping = true
	# Im Schlaf verhungert und verdurstet niemand.
	_drain_in_sleep(&"hunger", 14.0, 12.0)
	_drain_in_sleep(&"thirst", 18.0, 12.0)
	var fed: bool = _values[&"hunger"] > 25.0 and _values[&"thirst"] > 25.0
	if fed:
		modify(&"health", 20.0 * quality)
	_set_stat(&"warmth", lerpf(_values[&"warmth"], _target_warmth(), 0.7), true)
	_set_stat(&"energy", MAX_VALUE, true)
	var place_name: String = String(place.name) if place != null else ""
	EventBus.action_performed.emit(&"sleep", {"quality": quality, "place": place_name})
	TimeManager.skip_to_morning()
	_sleeping = false
	woke_up.emit(&"sleep")
	return true


## Ist der Spieler gerade in einem Unterschlupf (Gruppe "shelter")?
func is_sheltered() -> bool:
	return _shelter_warmth() > 0.0


## Bewegungsfaktor 0.55–1.0 durch niedrige Werte (Player wendet ihn an, siehe README).
func get_speed_multiplier() -> float:
	return _speed_multiplier


## Aktuelle Bildrand-Intensitäten {effect: 0..1}.
func get_screen_effects() -> Dictionary:
	return _effects.duplicate()


## Faktor für Sammelmengen von Beeren/Pflanzen (Winter ~0.1) – Agent 1 kann damit skalieren.
func get_forage_factor() -> float:
	return FORAGE_FACTOR.get(TimeManager.season, 1.0)


## Aufschlüsselung der Zieltemperatur (Ambient, Nacht, Wetter, Feuer, Schutz, Kleidung, target).
func get_temperature_breakdown() -> Dictionary:
	_target_warmth()
	return _breakdown.duplicate()


# ==================================================================================================
# Debug-Befehle (Agent 9 bindet sie an die Konsole)
# ==================================================================================================

## debug_set_stat(&"hunger", 20.0)
func debug_set_stat(stat: StringName, value: float) -> void:
	if _values.has(stat):
		_set_stat(stat, value, true)


## Alle Werte auf 100.
func debug_fill_stats() -> void:
	for s in STATS:
		_set_stat(s, MAX_VALUE, true)


## Alle Werte außer Gesundheit auf 0 (testet Verlangsamung und Gesundheitsverlust).
func debug_drain_stats() -> void:
	for s in [&"hunger", &"thirst", &"warmth", &"energy"]:
		_set_stat(s, 0.0, true)


## debug_set_weather(&"storm") – &"clear", &"rain", &"storm", &"snow", &"fog"
func debug_set_weather(weather_id: StringName, duration_hours: int = 6) -> void:
	weather.force_weather(weather_id, duration_hours)


## Uhrzeit setzen (0–24).
func debug_set_hour(hour: float) -> void:
	TimeManager.hour = fposmod(hour, 24.0)


## Springt zum 1. Tag der Jahreszeit (Enums.Season) im aktuellen Jahr.
func debug_set_season(season: Enums.Season) -> void:
	var day: int = ((TimeManager.year - 1) * 4 + int(season)) * TimeManager.DAYS_PER_SEASON + 1
	TimeManager.load_save_data({"day": day, "hour": TimeManager.hour})


## Springt zu einem Tag der Jahreszeit (1–28).
func debug_set_day_of_season(season: Enums.Season, day_of_season: int) -> void:
	var day: int = ((TimeManager.year - 1) * 4 + int(season)) * TimeManager.DAYS_PER_SEASON \
		+ clampi(day_of_season, 1, TimeManager.DAYS_PER_SEASON)
	TimeManager.load_save_data({"day": day, "hour": TimeManager.hour})


## Löst einen Kollaps aus (Grund z. B. &"exhaustion").
func debug_collapse(reason: StringName = &"exhaustion") -> void:
	_collapse(reason)


func debug_toggle_invulnerable() -> bool:
	invulnerable = not invulnerable
	return invulnerable


# ==================================================================================================
# Simulation
# ==================================================================================================

func _process(delta: float) -> void:
	if TimeManager.is_paused() or _collapsing or _sleeping:
		return
	var game_hours: float = delta * TimeManager.WAKING_HOURS \
		/ (TimeManager.DAY_REAL_MINUTES * 60.0) * TimeManager.time_scale
	if game_hours <= 0.0:
		return
	_tick(game_hours)


func _tick(dh: float) -> void:
	if _values[&"health"] <= 0.0:
		_collapse(_drain_cause)
		return
	var moving: bool = _is_player_moving()
	var target: float = _target_warmth()
	# Wärme strebt der Zieltemperatur zu.
	_set_stat(&"warmth", _values[&"warmth"] + (target - _values[&"warmth"]) * minf(1.0, WARMTH_RATE * dh))
	# Hunger/Durst/Energie.
	var hunger_factor: float = MOVING_HUNGER_THIRST_FACTOR if moving else 1.0
	if _values[&"warmth"] < 40.0:
		hunger_factor *= COLD_HUNGER_FACTOR
	_set_stat(&"hunger", _values[&"hunger"] - HUNGER_PER_HOUR * hunger_factor * dh)
	_set_stat(&"thirst", _values[&"thirst"] - THIRST_PER_HOUR \
		* (MOVING_HUNGER_THIRST_FACTOR if moving else 1.0) * dh)
	_set_stat(&"energy", _values[&"energy"] - ENERGY_PER_HOUR * (MOVING_ENERGY_FACTOR if moving else 1.0) * dh)
	# Gesundheit: leere Werte kosten, gute Versorgung heilt.
	var drain: float = 0.0
	var worst: float = 0.0
	for pair in [[&"hunger", &"starvation"], [&"thirst", &"dehydration"],
			[&"warmth", &"exposure"], [&"energy", &"exhaustion"]]:
		if _values[pair[0]] <= 0.0:
			drain += HEALTH_DRAIN_PER_HOUR * (0.5 if pair[0] == &"energy" else 1.0)
			if worst < 1.0:
				_drain_cause = pair[1]
				worst = 1.0
	if drain > 0.0:
		if not invulnerable:
			_set_stat(&"health", _values[&"health"] - drain * dh)
	elif _values[&"hunger"] > 50.0 and _values[&"thirst"] > 50.0 and _values[&"warmth"] > 40.0:
		_set_stat(&"health", _values[&"health"] + HEALTH_REGEN_PER_HOUR * dh)
	_update_effects()
	_apply_speed_multiplier()
	if _values[&"health"] <= 0.0:
		_collapse(_drain_cause)


## Zieltemperatur des Körpers (Punkte 0–100, kann darunter liegen). Füllt _breakdown.
func _target_warmth() -> float:
	var season: int = int(TimeManager.season)
	var ambient: float = SEASON_BASE_WARMTH.get(season, 50.0)
	var night: float = -NIGHT_COLD.get(season, 15.0) if TimeManager.is_night() else 0.0
	var shelter: float = _shelter_warmth()
	var weather_mod: float = weather.get_temperature_modifier() if weather != null else 0.0
	if shelter > 0.0:
		weather_mod = 0.0   # geschützt vor Nässe und Wind
	var fire: float = _fire_warmth()
	var clothing: float = _clothing_warmth()
	var total: float = clampf(ambient + night + weather_mod + shelter + fire + clothing, -10.0, MAX_VALUE)
	_breakdown = {
		"ambient": ambient, "night": night, "weather": weather_mod, "shelter": shelter,
		"fire": fire, "clothing": clothing, "target": total,
	}
	return total


func _fire_warmth() -> float:
	var player: Node2D = GameState.player
	if player == null or not is_instance_valid(player):
		return 0.0
	var sources: Dictionary[int, Node2D] = {}
	for n in get_tree().get_nodes_in_group("heat_source"):
		if n is Node2D:
			sources[n.get_instance_id()] = n
	for id in _tracked_fires:
		if is_instance_valid(_tracked_fires[id]):
			sources[id] = _tracked_fires[id]
	var total: float = 0.0
	for n in sources.values():
		if n.has_method("is_lit") and not n.call("is_lit"):
			continue
		var radius: float = _prop(n, "heat_radius", DEFAULT_HEAT_RADIUS)
		var strength: float = _prop(n, "heat_strength", DEFAULT_HEAT_STRENGTH)
		var d: float = player.global_position.distance_to(n.global_position)
		if d < radius:
			total += strength * (1.0 - 0.5 * d / radius)
	return minf(total, MAX_HEAT_BONUS)


func _shelter_warmth() -> float:
	var player: Node2D = GameState.player
	if player == null or not is_instance_valid(player):
		return 0.0
	var best: float = 0.0
	for n in get_tree().get_nodes_in_group("shelter"):
		if not (n is Node2D):
			continue
		var radius: float = _prop(n, "shelter_radius", DEFAULT_SHELTER_RADIUS)
		if player.global_position.distance_to((n as Node2D).global_position) <= radius:
			best = maxf(best, _prop(n, "shelter_warmth", DEFAULT_SHELTER_WARMTH))
	return best


## Getragene Kleidung. Wenn das Inventar get_worn_clothing() -> Array[ItemData] anbietet, wird das genutzt;
## sonst zählt Kleidung im Inventar (siehe interface_requests.md).
func _clothing_warmth() -> float:
	if Inventory.has_method("get_worn_clothing"):
		var total: float = 0.0
		for it in Inventory.call("get_worn_clothing"):
			total += (it as ItemData).warmth
		return total
	var best: float = 0.0
	for id in CLOTHING_IDS:
		if Inventory.has_item(id):
			var item: ItemData = ItemDB.get_item(id)
			best = maxf(best, item.warmth if item != null and item.warmth > 0.0 else CLOTHING_FALLBACK_WARMTH)
	return best


func _prop(n: Object, prop: String, fallback: float) -> float:
	var v: Variant = n.get(prop)
	return float(v) if v != null else fallback


func _is_player_moving() -> bool:
	var p: Node2D = GameState.player
	if p == null or not is_instance_valid(p):
		return false
	var v: Variant = p.get("velocity")
	return v is Vector2 and (v as Vector2).length() > 1.0


# ==================================================================================================
# Werte, Effekte, Geschwindigkeit
# ==================================================================================================

func _set_stat(stat: StringName, value: float, force_emit: bool = false) -> void:
	var v: float = clampf(value, 0.0, MAX_VALUE)
	_values[stat] = v
	var last: float = _last_emitted.get(stat, -1000.0)
	var edge: bool = (v <= 0.0 or v >= MAX_VALUE) and v != last
	if force_emit or edge or absf(v - last) >= EMIT_EPSILON:
		_last_emitted[stat] = v
		EventBus.player_stat_changed.emit(stat, v, MAX_VALUE)
	if stat != &"health" and WARNINGS.has(stat):
		_check_warning(stat, v)
	elif stat == &"health" and v <= 0.0 and not _collapsing and not invulnerable:
		call_deferred("_collapse_if_dead")   # z. B. modify(&"health", -999) von außen


func _emit_all() -> void:
	for s in STATS:
		_last_emitted[s] = _values[s]
		EventBus.player_stat_changed.emit(s, _values[s], MAX_VALUE)


func _drain_in_sleep(stat: StringName, amount: float, floor_value: float) -> void:
	var cur: float = _values[stat]
	_set_stat(stat, maxf(cur - amount, minf(cur, floor_value)), true)


func _check_warning(stat: StringName, value: float) -> void:
	var warned: bool = _warned.get(stat, false)
	if value < LOW_THRESHOLD and not warned:
		_warned[stat] = true
		EventBus.notification_requested.emit(WARNINGS[stat], null)
	elif value > LOW_THRESHOLD + 15.0 and warned:
		_warned[stat] = false


func _low_intensity(value: float) -> float:
	return clampf((LOW_THRESHOLD - value) / LOW_THRESHOLD, 0.0, 1.0)


func _update_effects() -> void:
	_set_effect(&"hunger", _low_intensity(_values[&"hunger"]))
	_set_effect(&"thirst", _low_intensity(_values[&"thirst"]))
	_set_effect(&"cold", _low_intensity(_values[&"warmth"]))
	_set_effect(&"exhaustion", _low_intensity(_values[&"energy"]))
	_set_effect(&"health", clampf((35.0 - _values[&"health"]) / 35.0, 0.0, 1.0))
	var worst: float = 0.0
	for e in [&"hunger", &"thirst", &"cold", &"exhaustion"]:
		worst = maxf(worst, _effects.get(e, 0.0))
	_speed_multiplier = lerpf(1.0, MIN_SPEED_MULTIPLIER, worst)


func _set_effect(effect: StringName, intensity: float) -> void:
	var last: float = _effects.get(effect, 0.0)
	if absf(intensity - last) >= 0.02 or (intensity == 0.0 and last != 0.0):
		_effects[effect] = intensity
		screen_effect_changed.emit(effect, intensity)


func _apply_speed_multiplier() -> void:
	var p: Node2D = GameState.player
	if p == null or not is_instance_valid(p):
		return
	if "speed_multiplier" in p:
		p.set("speed_multiplier", _speed_multiplier)
		return
	if p != _speed_player:
		# Fallback, bis Player ein speed_multiplier anbietet: Basis-Speed merken und skalieren.
		if p.get("speed") == null:
			return
		_speed_player = p
		_base_speed = float(p.get("speed"))
		_applied_multiplier = -1.0
	if not is_equal_approx(_applied_multiplier, _speed_multiplier):
		_applied_multiplier = _speed_multiplier
		p.set("speed", _base_speed * _speed_multiplier)


# ==================================================================================================
# Kollaps
# ==================================================================================================

func _collapse_if_dead() -> void:
	if _values[&"health"] <= 0.0:
		_collapse(_drain_cause)


func _collapse(reason: StringName) -> void:
	if _collapsing or _sleeping:
		return
	_collapsing = true
	_own_collapse_emit = true
	EventBus.player_collapsed.emit(reason)
	_own_collapse_emit = false
	_collapsed_this_night = true
	var lost: Dictionary = _lose_items()
	_advance_time_after_collapse()
	var pos: Variant = _wake_position()
	var p: Node2D = GameState.player
	if pos != null and p != null and is_instance_valid(p):
		p.global_position = pos
	for s in STATS:
		_set_stat(s, maxf(_values[s] if s != &"health" else 0.0, COLLAPSE_RESTORE[s]), true)
	_warned.clear()
	_update_effects()
	_apply_speed_multiplier()
	var text: String = COLLAPSE_TEXT.get(reason, "Du bist zusammengebrochen.") + " Du erwachst am Lager."
	if not lost.is_empty():
		text += " Ein Teil deiner Vorräte ging verloren."
	EventBus.notification_requested.emit(text, null)
	_collapsing = false
	woke_up.emit(reason)


## Entfernt einen Teil der Material-/Nahrungsvorräte (nie Werkzeug, Waffen, Kleidung). Rückgabe {id: menge}.
func _lose_items() -> Dictionary:
	var lost: Dictionary = {}
	var ids: Array[StringName] = []
	for item in ItemDB.all_items():
		if _is_lossable(item.id):
			ids.append(item.id)
	for id in LOSSABLE_FALLBACK:
		if not ids.has(id) and _is_lossable(id):
			ids.append(id)
	for id in ids:
		var c: int = Inventory.count(id)
		if c <= 0:
			continue
		var n: int = maxi(1, ceili(float(c) * COLLAPSE_LOSS_FRACTION))
		if Inventory.remove_item(id, n):
			lost[id] = n
	return lost


func _is_lossable(id: StringName) -> bool:
	var item: ItemData = ItemDB.get_item(id)
	if item == null:
		return LOSSABLE_FALLBACK.has(id)
	return item.category == Enums.ItemCategory.MATERIAL or item.category == Enums.ItemCategory.FOOD


func _advance_time_after_collapse() -> void:
	if TimeManager.has_method("advance_hours"):
		TimeManager.call("advance_hours", COLLAPSE_LOST_HOURS)
	else:
		TimeManager.skip_to_morning()   # Fallback (siehe interface_requests.md)


func _wake_position() -> Variant:
	if GameState.has_camp:
		return GameState.camp_position
	var places: Array[Node] = get_tree().get_nodes_in_group("sleeping_place")
	if not places.is_empty() and places[0] is Node2D:
		return (places[0] as Node2D).global_position
	return null


# ==================================================================================================
# Ereignisse
# ==================================================================================================

func _on_fire_lit(fire: Node2D) -> void:
	if fire != null:
		_tracked_fires[fire.get_instance_id()] = fire


func _on_fire_extinguished(fire: Node2D) -> void:
	if fire != null:
		_tracked_fires.erase(fire.get_instance_id())


func _on_player_collapsed(reason: StringName) -> void:
	if _own_collapse_emit or reason != &"forced_sleep":
		return
	# Nicht rechtzeitig schlafen gegangen: unruhiger Schlaf unter freiem Himmel.
	_drain_in_sleep(&"hunger", 14.0, 12.0)
	_drain_in_sleep(&"thirst", 18.0, 12.0)
	_set_stat(&"energy", maxf(_values[&"energy"], 60.0), true)
	EventBus.notification_requested.emit("Vor Müdigkeit eingeschlafen – der Schlaf war unruhig.", null)


func _on_hour_changed(hour: int) -> void:
	if hour == int(TimeManager.NIGHT_START_HOUR):
		_night_pending = true
		_collapsed_this_night = false


func _on_day_ended(_day: int) -> void:
	_night_pending = true


func _on_day_started(_day: int) -> void:
	if _night_pending and not _collapsed_this_night:
		EventBus.action_performed.emit(&"survive_night", {"day": _day})
	_night_pending = false
	_collapsed_this_night = false


func _on_season_changed(season: int) -> void:
	if season == int(Enums.Season.WINTER):
		_winter_active = true
	elif season == int(Enums.Season.SPRING) and _winter_active:
		_winter_active = false
		EventBus.action_performed.emit(&"survive_winter", {"year": TimeManager.year - 1})


# ==================================================================================================
# Speichern
# ==================================================================================================

func get_save_data() -> Dictionary:
	var values: Dictionary = {}
	for s in STATS:
		values[s] = _values[s]
	return {
		"values": values,
		"winter_active": _winter_active,
		"night_pending": _night_pending,
	}


func load_save_data(data: Dictionary) -> void:
	var values: Dictionary = data.get("values", {})
	for s in STATS:
		if values.has(s):
			_values[s] = clampf(float(values[s]), 0.0, MAX_VALUE)
		elif values.has(String(s)):
			_values[s] = clampf(float(values[String(s)]), 0.0, MAX_VALUE)
	_winter_active = bool(data.get("winter_active", false))
	_night_pending = bool(data.get("night_pending", false))
	_collapsed_this_night = false
	_collapsing = false
	_sleeping = false
	_warned.clear()
	_update_effects()
	_emit_all()
