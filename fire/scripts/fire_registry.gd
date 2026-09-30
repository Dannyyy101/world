class_name FireRegistry
extends Node
## Merkt sich alle platzierten Feuerstationen (Lagerfeuer, Trockengestell, Ofen) und speichert sie.
## Wird beim ersten Stationsnode lazy erzeugt. Damit auch beim Spielstart-Laden schon jemand
## zuhört, sollte Agent 0 diese Datei als Autoload "FireSaveHub" eintragen (siehe interface_requests.md).

static var _instance: FireRegistry = null

var _stations: Array[FireStation] = []


static func ensure(tree: SceneTree) -> FireRegistry:
	if _instance == null or not is_instance_valid(_instance):
		_instance = FireRegistry.new()
		_instance.name = "FireRegistry"
		tree.root.add_child.call_deferred(_instance)
	return _instance


static func track(station: FireStation) -> void:
	var reg: FireRegistry = ensure(station.get_tree())
	if not reg._stations.has(station):
		reg._stations.append(station)


static func untrack(station: FireStation) -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance._stations.erase(station)


func _ready() -> void:
	_instance = self
	SaveManager.register("fire", self)


func get_save_data() -> Dictionary:
	var list: Array = []
	for s in _stations:
		if is_instance_valid(s) and s.scene_file_path != "":
			list.append({"scene": s.scene_file_path, "pos": s.global_position, "state": s.get_state()})
	return {"stations": list}


func load_save_data(data: Dictionary) -> void:
	for s in _stations.duplicate():
		if is_instance_valid(s):
			s.queue_free()
	_stations.clear()
	var parent: Node = get_tree().get_first_node_in_group("entity_layer")
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return
	for entry: Dictionary in data.get("stations", []):
		var scene: PackedScene = load(str(entry.get("scene", ""))) as PackedScene
		if scene == null:
			continue
		var node: FireStation = scene.instantiate() as FireStation
		if node == null:
			continue
		parent.add_child(node)
		node.global_position = entry.get("pos", Vector2.ZERO)
		node.set_state(entry.get("state", {}))
