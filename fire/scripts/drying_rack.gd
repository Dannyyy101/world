class_name DryingRack
extends FireStation
## Trocken-/Räuchergestell (Besitzer: Agent 4). Fleisch hängt über Tage -> smoked_meat (verdirbt nicht).
## Steht ein brennendes Feuer in der Nähe (SMOKE_RADIUS), geht es SMOKE_SPEEDUP-mal schneller.

const MAX_SLOTS: int = 4
const SMOKE_RADIUS: float = 64.0
const SMOKE_SPEEDUP: float = 2.5

var _slots: Array[Dictionary] = []      # {p: FireProcess, t: float, done: bool}


func _get_texture() -> Texture2D:
	return FireArt.drying_rack()


func is_smoking() -> bool:
	for n: Node in get_tree().get_nodes_in_group("heat_source"):
		var n2: Node2D = n as Node2D
		if n2 != self and n2 != null and n2.has_method("is_burning") and n2.call("is_burning") \
				and n2.global_position.distance_to(global_position) <= SMOKE_RADIUS:
			return true
	return false


func load_item(p: FireProcess) -> bool:
	if _slots.size() >= MAX_SLOTS or not Inventory.remove_item(p.input_id, 1):
		return false
	_slots.append({"p": p, "t": 0.0, "done": false})
	return true


func collect() -> int:
	var total: int = 0
	for i in range(_slots.size() - 1, -1, -1):
		if bool(_slots[i]["done"]):
			var p: FireProcess = _slots[i]["p"]
			if _give(p.output_id, p.output_amount) == 0:
				_slots.remove_at(i)
				total += p.output_amount
	return total


func has_ready() -> bool:
	for s in _slots:
		if bool(s["done"]):
			return true
	return false


func slot_count() -> int:
	return _slots.size()


func _next_action() -> Dictionary:
	if has_ready():
		return {"kind": &"collect", "text": "Geräuchertes nehmen"}
	if _slots.size() < MAX_SLOTS:
		for p in FireProcess.for_station(Enums.Station.DRYING_RACK):
			if Inventory.has_item(p.input_id):
				return {"kind": &"load", "text": "%s aufhängen" % _item_name(p.input_id), "p": p}
	return {"kind": &"none", "text": "Trockengestell"}


func _get_prompt() -> String:
	return str(_next_action()["text"])


func _on_interacted(_by: Node2D) -> void:
	var act: Dictionary = _next_action()
	if act["kind"] == &"collect":
		collect()
	elif act["kind"] == &"load":
		load_item(act["p"])


func _advance(dh: float) -> void:
	if _slots.is_empty():
		return
	var rate: float = SMOKE_SPEEDUP if is_smoking() else 1.0
	for slot in _slots:
		if bool(slot["done"]):
			continue
		var p: FireProcess = slot["p"]
		slot["t"] = float(slot["t"]) + dh * rate
		if float(slot["t"]) >= p.duration_hours:
			slot["done"] = true
			EventBus.action_performed.emit(p.action_id, {"item_id": p.output_id, "position": global_position})


func _draw() -> void:
	var y: float = -11.0
	for slot in _slots:
		var p: FireProcess = slot["p"]
		_draw_bar(0.0, y, 12.0, float(slot["t"]) / p.duration_hours, Color(0.75, 0.5, 0.3))
		y -= 4.0


func get_state() -> Dictionary:
	var slots: Array = []
	for s in _slots:
		slots.append({"p": (s["p"] as FireProcess).id, "t": s["t"], "done": s["done"]})
	return {"slots": slots}


func set_state(data: Dictionary) -> void:
	_slots.clear()
	for s: Dictionary in data.get("slots", []):
		var p: FireProcess = FireProcess.find_by_id(StringName(str(s.get("p", ""))))
		if p != null:
			_slots.append({"p": p, "t": float(s.get("t", 0.0)), "done": bool(s.get("done", false))})
