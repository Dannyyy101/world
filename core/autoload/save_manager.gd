extends Node
## SaveManager – Speichern/Laden als JSON (Besitzer: Agent 0).
##
## Systeme registrieren sich mit register("key", self) und implementieren
##   get_save_data() -> Dictionary
##   load_save_data(data: Dictionary) -> void
## Vector2/Vector2i/Color/StringName/Vector3 in den Daten werden automatisch
## (de)kodiert. Ganzzahlen bleiben Ganzzahlen (JSON-Zahlen ohne Nachkommaanteil
## werden beim Laden zu int).

const SAVE_VERSION: int = 1
const SAVE_DIR: String = "user://saves"

signal saved(slot: int)
signal loaded(slot: int)

var _systems: Dictionary[String, WeakRef] = {}
var _order: Array[String] = []


func register(key: String, node: Object) -> void:
	if not (node.has_method("get_save_data") and node.has_method("load_save_data")):
		push_error("SaveManager.register('%s'): Objekt braucht get_save_data() und load_save_data()." % key)
		return
	if not _systems.has(key):
		_order.append(key)
	_systems[key] = weakref(node)


func unregister(key: String) -> void:
	_systems.erase(key)
	_order.erase(key)


func get_slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(get_slot_path(slot))


func save_game(slot: int) -> bool:
	var systems_data: Dictionary = {}
	for key in _order:
		var obj: Object = _resolve(key)
		if obj == null:
			continue
		systems_data[key] = encode_value(obj.call("get_save_data"))
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"systems": systems_data,
	}
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file: FileAccess = FileAccess.open(get_slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: kann Slot %d nicht schreiben (Fehler %d)" % [slot, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	saved.emit(slot)
	return true


func load_game(slot: int) -> bool:
	if not has_save(slot):
		return false
	var text: String = FileAccess.get_file_as_string(get_slot_path(slot))
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("SaveManager: Slot %d ist beschädigt." % slot)
		return false
	var payload: Dictionary = parsed
	var version: int = int(payload.get("version", 0))
	if version > SAVE_VERSION:
		push_error("SaveManager: Slot %d stammt aus neuerer Version (%d)." % [slot, version])
		return false
	var systems_data: Dictionary = payload.get("systems", {})
	for key in _order:
		if not systems_data.has(key):
			continue
		var obj: Object = _resolve(key)
		if obj == null:
			continue
		var data: Variant = decode_value(systems_data[key])
		if data is Dictionary:
			obj.call("load_save_data", data)
	loaded.emit(slot)
	return true


func delete_save(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(get_slot_path(slot))


func _resolve(key: String) -> Object:
	var ref: WeakRef = _systems.get(key)
	if ref == null:
		return null
	return ref.get_ref()


# --- (De)Kodierung JSON-untauglicher Typen -------------------------------------------

static func encode_value(v: Variant) -> Variant:
	match typeof(v):
		TYPE_VECTOR2:
			var v2: Vector2 = v
			return {"__t": "v2", "x": v2.x, "y": v2.y}
		TYPE_VECTOR2I:
			var v2i: Vector2i = v
			return {"__t": "v2i", "x": v2i.x, "y": v2i.y}
		TYPE_VECTOR3:
			var v3: Vector3 = v
			return {"__t": "v3", "x": v3.x, "y": v3.y, "z": v3.z}
		TYPE_COLOR:
			var c: Color = v
			return {"__t": "color", "r": c.r, "g": c.g, "b": c.b, "a": c.a}
		TYPE_STRING_NAME:
			return String(v)
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			var d: Dictionary = v
			for k in d:
				out[String(k) if typeof(k) == TYPE_STRING_NAME else k] = encode_value(d[k])
			return out
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			var arr: Array = []
			for e in v:
				arr.append(encode_value(e))
			return arr
		_:
			return v


static func decode_value(v: Variant) -> Variant:
	if v is Dictionary:
		var d: Dictionary = v
		if d.has("__t"):
			match d["__t"]:
				"v2":
					return Vector2(d["x"], d["y"])
				"v2i":
					return Vector2i(int(d["x"]), int(d["y"]))
				"v3":
					return Vector3(d["x"], d["y"], d["z"])
				"color":
					return Color(d["r"], d["g"], d["b"], d["a"])
		var out: Dictionary = {}
		for k in d:
			out[k] = decode_value(d[k])
		return out
	if v is Array:
		var arr: Array = []
		for e in v:
			arr.append(decode_value(e))
		return arr
	if v is float:
		var f: float = v
		if is_finite(f) and f == floorf(f) and absf(f) < 9007199254740992.0:
			return int(f)
	return v
