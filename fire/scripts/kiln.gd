class_name Kiln
extends FireStation
## Brennofen (Besitzer: Agent 4). Temperatur 0..1200 °C.
## - Brennstoff (branch/wood_log/charcoal) liefert je "power"; Temperatur strebt (20 + Σpower) an.
## - Ohne Luftzufuhr max. NATURAL_CAP (1000 °C). Mit blowpipe im Rhythmus blasen (E, wenn der Ring voll ist)
##   gibt "bellows" (0..1) -> Zielwert x(1 + 0.35*bellows), Deckel MAX_TEMP.
## - Ein verbranntes wood_log hinterlässt 1 charcoal im Ausgabefach.
## - Prozesse (data/processes, station KILN): Keramik ab 600 °C, Malachit + charcoal ab 1085 °C -> copper_bead.
## - Gruppe "kiln" + "heat_source". Signal copper_smelted -> Hook für Agent 9 (Epochen-Ende).

signal copper_smelted(kiln: Kiln)

const MAX_TEMP: float = 1200.0
const NATURAL_CAP: float = 1000.0
const AMBIENT: float = 20.0
const MAX_PIECES: int = 5
const MAX_SLOTS: int = 4
const BELLOWS_BOOST: float = 0.35
const PULSE_PERIOD: float = 1.2
const HEAT_RATE_UP: float = 1.5
const HEAT_RATE_DOWN: float = 0.6
const FUEL: Dictionary = {
	&"branch": {"hours": 0.6, "power": 250.0},
	&"wood_log": {"hours": 1.6, "power": 400.0},
	&"charcoal": {"hours": 1.4, "power": 550.0},
}

@export var base_heat_radius: float = 48.0

var temperature: float = AMBIENT
var bellows: float = 0.0
var heat_radius: float = 0.0

var _pieces: Array[Dictionary] = []     # {id, left, power}
var _slots: Array[Dictionary] = []      # {p: FireProcess, t: float}
var _output: Dictionary = {}            # StringName -> int
var _pulse_t: float = 0.0


func _station_ready() -> void:
	add_to_group("heat_source")
	add_to_group("kiln")


func _get_texture() -> Texture2D:
	return FireArt.kiln(is_burning())


func is_burning() -> bool:
	return not _pieces.is_empty()


func get_heat_strength() -> float:
	return clampf((temperature - AMBIENT) / (MAX_TEMP - AMBIENT), 0.0, 1.0)


func target_temperature() -> float:
	var power: float = 0.0
	for pc in _pieces:
		power += float(pc["power"])
	if power <= 0.0:
		return AMBIENT
	var t: float = (AMBIENT + power) * (1.0 + BELLOWS_BOOST * bellows)
	var cap: float = MAX_TEMP if bellows > 0.05 else NATURAL_CAP
	return minf(t, cap)


# --- Öffentliche Aktionen ----------------------------------------------------------

func add_fuel(id: StringName) -> bool:
	if not FUEL.has(id) or _pieces.size() >= MAX_PIECES or not Inventory.remove_item(id, 1):
		return false
	var f: Dictionary = FUEL[id]
	_pieces.append({"id": id, "left": float(f["hours"]), "power": float(f["power"])})
	return true


func load_item(p: FireProcess) -> bool:
	if _slots.size() >= MAX_SLOTS:
		return false
	if not Inventory.has_item(p.input_id):
		return false
	for id: StringName in p.extra_inputs:
		if not Inventory.has_item(id, int(p.extra_inputs[id])):
			return false
	Inventory.remove_item(p.input_id, 1)
	for id: StringName in p.extra_inputs:
		Inventory.remove_item(id, int(p.extra_inputs[id]))
	_slots.append({"p": p, "t": 0.0})
	return true


## Blasen im Rhythmus. Treffer, wenn der Ring (fast) voll ist; force_good erzwingt einen Treffer (Tests).
func blow(force_good: bool = false) -> bool:
	if not is_burning() or not Inventory.has_item(&"blowpipe"):
		return false
	if force_good or _pulse_phase() >= 0.75:
		bellows = minf(1.0, bellows + 0.35)
		return true
	bellows = maxf(0.0, bellows - 0.15)
	return false


func collect() -> int:
	var total: int = 0
	for id: StringName in _output.keys():
		var n: int = int(_output[id])
		var rest: int = _give(id, n)
		total += n - rest
		if rest > 0:
			_output[id] = rest
		else:
			_output.erase(id)
	return total


func has_ready() -> bool:
	return not _output.is_empty()


func output_count(id: StringName) -> int:
	return int(_output.get(id, 0))


func piece_count() -> int:
	return _pieces.size()


func slot_count() -> int:
	return _slots.size()


# --- Interaktion ------------------------------------------------------------------

func _pulse_phase() -> float:
	return fposmod(_pulse_t / PULSE_PERIOD, 1.0)


func _best_fuel(prefer_cheap: bool = true) -> StringName:
	var order: Array[StringName] = [&"branch", &"wood_log", &"charcoal"] if prefer_cheap else [&"charcoal", &"wood_log", &"branch"]
	for id in order:
		if Inventory.has_item(id):
			return id
	return &""


func _next_action() -> Dictionary:
	if has_ready():
		return {"kind": &"collect", "text": "Fertiges nehmen"}
	if _slots.size() < MAX_SLOTS:
		for p in FireProcess.for_station(Enums.Station.KILN):
			if Inventory.has_item(p.input_id):
				var ok: bool = true
				for id: StringName in p.extra_inputs:
					ok = ok and Inventory.has_item(id, int(p.extra_inputs[id]))
				if ok:
					return {"kind": &"load", "text": "%s in den Ofen" % _item_name(p.input_id), "p": p}
	var fuel_id: StringName = _best_fuel(false)
	if _pieces.size() < 2 and fuel_id != &"":
		return {"kind": &"fuel", "text": "%s nachlegen" % _item_name(fuel_id), "id": fuel_id}
	if is_burning() and Inventory.has_item(&"blowpipe"):
		return {"kind": &"blow", "text": "Blasen (im Rhythmus)"}
	if _pieces.size() < MAX_PIECES and fuel_id != &"":
		return {"kind": &"fuel", "text": "%s nachlegen" % _item_name(fuel_id), "id": fuel_id}
	return {"kind": &"none", "text": "Ofen (%d °C)" % int(temperature)}


func _get_prompt() -> String:
	return str(_next_action()["text"])


func _on_interacted(_by: Node2D) -> void:
	var act: Dictionary = _next_action()
	match act["kind"]:
		&"collect":
			collect()
		&"load":
			load_item(act["p"])
		&"fuel":
			add_fuel(act["id"])
		&"blow":
			blow()


# --- Simulation -------------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	_pulse_t += delta
	bellows = maxf(0.0, bellows - 0.2 * delta)


func _advance(dh: float) -> void:
	for i in range(_pieces.size() - 1, -1, -1):
		_pieces[i]["left"] = float(_pieces[i]["left"]) - dh
		if float(_pieces[i]["left"]) <= 0.0:
			if _pieces[i]["id"] == &"wood_log":
				_output[&"charcoal"] = int(_output.get(&"charcoal", 0)) + 1
				_notify("Im Ofen ist Holzkohle entstanden.")
			_pieces.remove_at(i)
	var target: float = target_temperature()
	var rate: float = HEAT_RATE_UP if target > temperature else HEAT_RATE_DOWN
	temperature = clampf(temperature + (target - temperature) * minf(1.0, rate * dh), AMBIENT, MAX_TEMP)
	heat_radius = base_heat_radius * get_heat_strength() if is_burning() else 0.0
	for i in range(_slots.size() - 1, -1, -1):
		var p: FireProcess = _slots[i]["p"]
		if temperature < p.min_temperature:
			continue
		_slots[i]["t"] = float(_slots[i]["t"]) + dh
		if float(_slots[i]["t"]) >= p.duration_hours:
			_slots.remove_at(i)
			_output[p.output_id] = int(_output.get(p.output_id, 0)) + p.output_amount
			EventBus.action_performed.emit(p.action_id, {"item_id": p.output_id, "temperature": temperature, "position": global_position})
			if p.action_id == &"smelt_malachite":
				GameState.set_flag("copper_smelted", true)
				_notify("Aus dem grünen Stein ist glänzendes Kupfer geflossen!")
				copper_smelted.emit(self)


func _draw() -> void:
	_draw_bar(0.0, -11.0, 14.0, temperature / MAX_TEMP, Color(0.3, 0.6, 1.0).lerp(Color(1.0, 0.35, 0.1), temperature / MAX_TEMP))
	# Marken: 600 °C (Keramik) und 1085 °C (Kupfer)
	for mark: float in [600.0, 1085.0]:
		draw_rect(Rect2(-7.0 + 14.0 * mark / MAX_TEMP, -13.0, 1, 6), Color(1, 1, 1, 0.8))
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(-14, -16), "%d°C" % int(temperature), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color.WHITE)
	var y: float = -22.0
	for slot in _slots:
		var p: FireProcess = slot["p"]
		_draw_bar(0.0, y, 12.0, float(slot["t"]) / p.duration_hours, Color(0.9, 0.7, 0.3))
		y -= 4.0
	if is_burning() and Inventory.has_item(&"blowpipe"):
		var phase: float = _pulse_phase()
		draw_arc(Vector2(0, 4), 12.0, 0.0, TAU, 24, Color(1, 1, 1, 0.35), 1.0)
		draw_arc(Vector2(0, 4), 3.0 + 9.0 * phase, 0.0, TAU, 24, Color(0.4, 1.0, 0.4) if phase >= 0.75 else Color(1, 0.8, 0.3), 1.0)


func get_state() -> Dictionary:
	var slots: Array = []
	for s in _slots:
		slots.append({"p": (s["p"] as FireProcess).id, "t": s["t"]})
	return {"temp": temperature, "pieces": _pieces.duplicate(true), "slots": slots, "output": _output.duplicate()}


func set_state(data: Dictionary) -> void:
	temperature = float(data.get("temp", AMBIENT))
	_pieces.clear()
	for pc: Dictionary in data.get("pieces", []):
		_pieces.append({"id": StringName(str(pc.get("id", ""))), "left": float(pc.get("left", 0.0)), "power": float(pc.get("power", 0.0))})
	_slots.clear()
	for s: Dictionary in data.get("slots", []):
		var p: FireProcess = FireProcess.find_by_id(StringName(str(s.get("p", ""))))
		if p != null:
			_slots.append({"p": p, "t": float(s.get("t", 0.0))})
	_output.clear()
	var out: Dictionary = data.get("output", {})
	for k in out:
		_output[StringName(str(k))] = int(out[k])
