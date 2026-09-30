class_name Campfire
extends FireStation
## Lagerfeuer (Besitzer: Agent 4).
## - Brennstoff branch/wood_log, brennt ab, Regen löscht es ohne Unterschlupf (Gruppe "shelter" in der Nähe
##   oder `sheltered = true`).
## - Gruppe "heat_source": Properties heat_radius (px), get_heat_strength() 0..1, is_burning().
## - Entzünden per Feuerbohrer-Minispiel, Kochen/Härten/Zeitbalken, Ton härtet über Nacht.
## - Das erste platzierte Feuer setzt das Lager (GameState.set_camp).
##
## E-Belegung (eine Taste, Priorität): Fertiges nehmen > Brennstoff bei niedriger Glut > Garen/Härten >
## Ton ans Feuer legen > Brennstoff nachlegen.

signal ignited
signal extinguished(reason: StringName)
signal clay_hardened(item_id: StringName)

const MAX_FUEL_HOURS: float = 12.0
const LOW_FUEL_HOURS: float = 2.0
const MAX_SLOTS: int = 3
const MAX_CLAY: int = 3
## Wie lange Ton am brennenden Feuer liegen muss (Spielstunden, ~ eine Nacht).
const CLAY_HARDEN_HOURS: float = 6.0
const SHELTER_RADIUS: float = 64.0
const FUEL_HOURS: Dictionary = {&"branch": 1.5, &"wood_log": 4.0}
const CLAY_ITEMS: Array[StringName] = [&"clay_pot_unfired", &"clay"]

@export var base_heat_radius: float = 72.0
@export var sheltered: bool = false

var fuel_hours: float = 0.0
var burning: bool = false
## Aktueller Wärmeradius in Pixeln (0 = aus). Für Agent 3 auslesbar.
var heat_radius: float = 0.0

var _slots: Array[Dictionary] = []      # {p: FireProcess, t: float, done: bool}
var _clay: Array[Dictionary] = []       # {id: StringName, h: float}
var _ready_items: Array[Dictionary] = []  # {id: StringName, n: int}
var _weather: StringName = &"clear"
var _minigame_active: bool = false
var _light: PointLight2D
var _sparks: CPUParticles2D
var _flicker: float = 0.0


func _station_ready() -> void:
	add_to_group("heat_source")
	_build_light()
	_build_sparks()
	EventBus.weather_changed.connect(_on_weather)
	if not GameState.has_camp:
		GameState.set_camp(global_position)
	_refresh_effects()


func _get_texture() -> Texture2D:
	return FireArt.campfire(burning)


func is_burning() -> bool:
	return burning


func get_heat_strength() -> float:
	if not burning:
		return 0.0
	return clampf(0.35 + fuel_hours / 4.0, 0.35, 1.0)


func is_sheltered() -> bool:
	if sheltered:
		return true
	for n: Node in get_tree().get_nodes_in_group("shelter"):
		var n2: Node2D = n as Node2D
		if n2 != null and n2.global_position.distance_to(global_position) <= SHELTER_RADIUS:
			return true
	return false


# --- Öffentliche Aktionen (auch von Tests nutzbar) --------------------------------

func add_fuel(id: StringName) -> bool:
	if not FUEL_HOURS.has(id) or fuel_hours >= MAX_FUEL_HOURS - 0.01:
		return false
	if not Inventory.remove_item(id, 1):
		return false
	fuel_hours = minf(MAX_FUEL_HOURS, fuel_hours + float(FUEL_HOURS[id]))
	return true


func can_light() -> bool:
	return not burning and fuel_hours > 0.0 and not _is_raining_on_us()


## Entzündet das Feuer sofort (nach erfolgreichem Minispiel).
func ignite() -> bool:
	if not can_light():
		return false
	burning = true
	GameState.set_flag("first_fire", true)
	_refresh_effects()
	ignited.emit()
	EventBus.fire_lit.emit(self)
	EventBus.action_performed.emit(&"light_fire", {"position": global_position})
	return true


func start_process(p: FireProcess) -> bool:
	if not burning or _slots.size() >= MAX_SLOTS:
		return false
	if not Inventory.remove_item(p.input_id, 1):
		return false
	_slots.append({"p": p, "t": 0.0, "done": false})
	return true


func place_clay(id: StringName) -> bool:
	if _clay.size() >= MAX_CLAY or not Inventory.remove_item(id, 1):
		return false
	_clay.append({"id": id, "h": 0.0})
	return true


## Nimmt alles Fertige mit. Rückgabe: Anzahl Items.
func collect() -> int:
	var total: int = 0
	for i in range(_slots.size() - 1, -1, -1):
		if bool(_slots[i]["done"]):
			var p: FireProcess = _slots[i]["p"]
			_slots.remove_at(i)
			_ready_items.append({"id": p.output_id, "n": p.output_amount})
	var leftover: Array[Dictionary] = []
	for entry in _ready_items:
		var id: StringName = entry["id"]
		var n: int = int(entry["n"])
		var rest: int = _give(id, n)
		total += n - rest
		if rest > 0:
			leftover.append({"id": id, "n": rest})
	_ready_items = leftover
	return total


func has_ready() -> bool:
	if not _ready_items.is_empty():
		return true
	for s in _slots:
		if bool(s["done"]):
			return true
	return false


func slot_count() -> int:
	return _slots.size()


func clay_count() -> int:
	return _clay.size()


# --- Interaktion ------------------------------------------------------------------

func _next_action() -> Dictionary:
	if has_ready():
		return {"kind": &"collect", "text": "Fertiges nehmen"}
	var fuel_id: StringName = _best_fuel_in_inventory()
	if not burning:
		if fuel_hours <= 0.0:
			if fuel_id != &"":
				return {"kind": &"fuel", "text": "%s nachlegen" % _item_name(fuel_id), "id": fuel_id}
			return {"kind": &"none", "text": "Kein Brennstoff"}
		if _is_raining_on_us():
			return {"kind": &"none", "text": "Zu nass zum Entzünden"}
		if Inventory.has_item(&"fire_drill"):
			return {"kind": &"light", "text": "Feuer entzünden"}
		return {"kind": &"none", "text": "Feuerbohrer fehlt"}
	if fuel_hours < LOW_FUEL_HOURS and fuel_id != &"":
		return {"kind": &"fuel", "text": "%s nachlegen" % _item_name(fuel_id), "id": fuel_id}
	if _slots.size() < MAX_SLOTS:
		for p in FireProcess.for_station(Enums.Station.CAMPFIRE):
			if Inventory.has_item(p.input_id):
				return {"kind": &"process", "text": "%s ans Feuer" % _item_name(p.input_id), "p": p}
	if _clay.size() < MAX_CLAY:
		for id in CLAY_ITEMS:
			if Inventory.has_item(id):
				return {"kind": &"clay", "text": "%s ans Feuer legen" % _item_name(id), "id": id}
	if fuel_id != &"" and fuel_hours < MAX_FUEL_HOURS - 0.5:
		return {"kind": &"fuel", "text": "%s nachlegen" % _item_name(fuel_id), "id": fuel_id}
	return {"kind": &"none", "text": "Lagerfeuer"}


func _get_prompt() -> String:
	return str(_next_action()["text"])


func _on_interacted(_by: Node2D) -> void:
	if _minigame_active:
		return
	var act: Dictionary = _next_action()
	match act["kind"]:
		&"collect":
			collect()
		&"fuel":
			add_fuel(act["id"])
		&"light":
			_start_drill()
		&"process":
			start_process(act["p"])
		&"clay":
			place_clay(act["id"])
		_:
			if act["text"] == "Feuerbohrer fehlt":
				_notify("Ohne Feuerbohrer bekommst du kein Feuer an.")


func _best_fuel_in_inventory() -> StringName:
	for id: StringName in [&"branch", &"wood_log"]:
		if Inventory.has_item(id):
			return id
	return &""


func _start_drill() -> void:
	var mg: FireDrillMinigame = FireDrillMinigame.new()
	if Inventory.has_item(&"tinder"):
		Inventory.remove_item(&"tinder", 1)
		mg.use_tinder = true
	_minigame_active = true
	mg.finished.connect(_on_drill_finished)
	get_tree().root.add_child(mg)


func _on_drill_finished(success: bool) -> void:
	_minigame_active = false
	if success:
		ignite()
	else:
		_notify("Der Funke will nicht überspringen. Versuch es noch einmal.")


# --- Simulation -------------------------------------------------------------------

func _advance(dh: float) -> void:
	if not burning:
		return
	if _is_raining_on_us():
		extinguish(&"rain")
		return
	fuel_hours -= dh
	for i in range(_slots.size() - 1, -1, -1):
		var slot: Dictionary = _slots[i]
		var p: FireProcess = slot["p"]
		slot["t"] = float(slot["t"]) + dh
		var t: float = float(slot["t"])
		if not bool(slot["done"]) and t >= p.duration_hours:
			slot["done"] = true
			EventBus.action_performed.emit(p.action_id, {"item_id": p.output_id, "position": global_position})
		if bool(slot["done"]) and p.burn_after_hours > 0.0 and t >= p.duration_hours + p.burn_after_hours:
			_slots.remove_at(i)
			_notify("%s ist verbrannt!" % _item_name(p.output_id))
	for i in range(_clay.size() - 1, -1, -1):
		_clay[i]["h"] = float(_clay[i]["h"]) + dh
		if float(_clay[i]["h"]) >= CLAY_HARDEN_HOURS:
			var was: StringName = _clay[i]["id"]
			_clay.remove_at(i)
			_ready_items.append({"id": &"fired_pottery", "n": 1})
			clay_hardened.emit(was)
			EventBus.action_performed.emit(&"clay_hardened", {"item_id": was, "position": global_position})
			_notify("Der Ton neben dem Feuer ist über Nacht hart wie Stein geworden!")
	if fuel_hours <= 0.0:
		fuel_hours = 0.0
		extinguish(&"burned_out")
	else:
		heat_radius = base_heat_radius * lerpf(0.6, 1.0, clampf(fuel_hours / 3.0, 0.0, 1.0))


func extinguish(reason: StringName = &"manual") -> void:
	if not burning:
		return
	burning = false
	if reason == &"rain":
		fuel_hours *= 0.5
		_notify("Der Regen hat das Feuer gelöscht.")
	_refresh_effects()
	extinguished.emit(reason)
	EventBus.fire_extinguished.emit(self)


func _is_raining_on_us() -> bool:
	return (_weather == &"rain" or _weather == &"storm") and not is_sheltered()


func _on_weather(weather: StringName) -> void:
	_weather = weather
	if burning and _is_raining_on_us():
		extinguish(&"rain")


# --- Visuals ----------------------------------------------------------------------

func _build_light() -> void:
	_light = PointLight2D.new()
	var grad: Gradient = Gradient.new()
	grad.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	_light.texture = tex
	_light.color = Color(1.0, 0.7, 0.35)
	_light.enabled = false
	add_child(_light)


func _build_sparks() -> void:
	_sparks = CPUParticles2D.new()
	_sparks.position = Vector2(0, -4)
	_sparks.amount = 10
	_sparks.lifetime = 0.9
	_sparks.direction = Vector2(0, -1)
	_sparks.spread = 25.0
	_sparks.gravity = Vector2(0, -12)
	_sparks.initial_velocity_min = 12.0
	_sparks.initial_velocity_max = 28.0
	_sparks.color = Color(1.0, 0.65, 0.2)
	_sparks.emitting = false
	add_child(_sparks)


func _refresh_effects() -> void:
	if burning:
		heat_radius = base_heat_radius * lerpf(0.6, 1.0, clampf(fuel_hours / 3.0, 0.0, 1.0))
	else:
		heat_radius = 0.0
	_light.enabled = burning
	_sparks.emitting = burning


func _process(delta: float) -> void:
	super._process(delta)
	if burning:
		_flicker += delta * 12.0
		_light.energy = 0.95 + 0.15 * sin(_flicker) + randf_range(-0.05, 0.05)
		_light.texture_scale = maxf(0.1, heat_radius / 64.0)


func _draw() -> void:
	if burning or fuel_hours > 0.0:
		_draw_bar(0.0, -13.0, 12.0, fuel_hours / MAX_FUEL_HOURS, Color(1.0, 0.6, 0.15))
	var y: float = -17.0
	for slot in _slots:
		var p: FireProcess = slot["p"]
		var t: float = float(slot["t"])
		var color: Color = Color(0.4, 0.85, 0.4)
		var ratio: float = t / p.duration_hours
		if t >= p.duration_hours:
			ratio = 1.0
			if p.burn_after_hours > 0.0:
				color = Color(0.95, 0.85, 0.2).lerp(Color(0.9, 0.15, 0.1), clampf((t - p.duration_hours) / p.burn_after_hours, 0.0, 1.0))
		_draw_bar(0.0, y, 12.0, ratio, color)
		y -= 4.0
	for i in _clay.size():
		draw_rect(Rect2(-7.0 + float(i) * 5.0, 6.0, 4, 3), Color(0.62, 0.42, 0.3))


# --- Speichern --------------------------------------------------------------------

func get_state() -> Dictionary:
	var slots: Array = []
	for s in _slots:
		slots.append({"p": (s["p"] as FireProcess).id, "t": s["t"], "done": s["done"]})
	var clay: Array = []
	for c in _clay:
		clay.append({"id": c["id"], "h": c["h"]})
	return {"fuel": fuel_hours, "burning": burning, "slots": slots, "clay": clay, "ready": _ready_items.duplicate(true)}


func set_state(data: Dictionary) -> void:
	fuel_hours = float(data.get("fuel", 0.0))
	burning = bool(data.get("burning", false))
	_slots.clear()
	for s: Dictionary in data.get("slots", []):
		var p: FireProcess = FireProcess.find_by_id(StringName(str(s.get("p", ""))))
		if p != null:
			_slots.append({"p": p, "t": float(s.get("t", 0.0)), "done": bool(s.get("done", false))})
	_clay.clear()
	for c: Dictionary in data.get("clay", []):
		_clay.append({"id": StringName(str(c.get("id", ""))), "h": float(c.get("h", 0.0))})
	_ready_items.clear()
	for r: Dictionary in data.get("ready", []):
		_ready_items.append({"id": StringName(str(r.get("id", ""))), "n": int(r.get("n", 1))})
	if is_inside_tree():
		_refresh_effects()
