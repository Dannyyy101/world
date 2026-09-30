class_name BuildManager
extends Node
## Bau-Modus für PLACEABLE-Items: Ist ein platzierbares Item ausgerüstet, folgt eine Geister-Vorschau der Maus
## am 16-px-Raster (grün = frei, rot = blockiert/zu weit weg). Linksklick (tool_used) platziert.
## Platzieren: lädt ItemData.placeable_scene_path (fehlt die Szene noch, erscheint ein Platzhalter),
## verbraucht 1 Item, emittiert structure_placed + action_performed(&"build").
## Platzierte Bauwerke werden hier gespeichert (Key "structures") und beim Laden neu erzeugt.

signal structure_added(node: Node2D, structure_id: StringName)

const SAVE_KEY: String = "structures"
const GRID: int = 16
const STRUCTURE_DIR: String = "res://items/structures"
const PLACEHOLDER_SCENE: String = "res://items/scenes/structure_placeholder.tscn"
const GROUP: StringName = &"placed_structures"
## Maximaler Abstand zwischen Spieler und Bauplatz in Pixeln.
const BUILD_REACH: float = 96.0
## Kollisionsmaske der Platzprüfung: world (1) + player (2) + animals (3).
const BLOCK_MASK: int = 0b111

var active: bool = false
var can_place: bool = false
var current_id: StringName = &""

var _infos: Dictionary[StringName, StructureInfo] = {}
var _placed: Array[Dictionary] = []  # {id, pos, node: WeakRef}
var _ghost: BuildGhost
var _ghost_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	_load_infos()
	SaveManager.register(SAVE_KEY, self)
	Inventory.equipped_changed.connect(func(_i: ItemData) -> void: _refresh_active())
	Inventory.slot_changed.connect(func(_i: int) -> void: _refresh_active())
	EventBus.tool_used.connect(_on_tool_used)
	_refresh_active.call_deferred()


func _load_infos() -> void:
	var dir: DirAccess = DirAccess.open(STRUCTURE_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		var name: String = f.trim_suffix(".remap")
		if name.ends_with(".tres"):
			var info: StructureInfo = load(STRUCTURE_DIR.path_join(name)) as StructureInfo
			if info != null:
				_infos[info.id] = info


func get_info(id: StringName) -> StructureInfo:
	if _infos.has(id):
		return _infos[id]
	var fallback: StructureInfo = StructureInfo.new()
	fallback.id = id
	return fallback


func footprint_px(id: StringName) -> Vector2:
	return Vector2(get_info(id).footprint * GRID)


# ------------------------------------------------------------ Geist

func _refresh_active() -> void:
	var item: ItemData = Inventory.get_equipped()
	var should: bool = item != null and item.category == Enums.ItemCategory.PLACEABLE
	if should:
		current_id = item.id
	set_active(should)


func set_active(on: bool) -> void:
	active = on
	if on:
		if _ghost == null:
			_ghost = BuildGhost.new()
			_ghost.z_index = 100
		var host: Node = _world_parent()
		if host != null and _ghost.get_parent() != host:
			if _ghost.get_parent() != null:
				_ghost.get_parent().remove_child(_ghost)
			host.add_child(_ghost)
		if _ghost != null:
			_ghost.setup(footprint_px(current_id), _icon_of(current_id))
			_ghost.visible = true
	elif _ghost != null:
		_ghost.visible = false
		can_place = false


func _process(_delta: float) -> void:
	if not active or _ghost == null or _ghost.get_parent() == null:
		return
	_ghost_pos = snap_position(_ghost.get_global_mouse_position(), current_id)
	_ghost.global_position = _ghost_pos
	can_place = check_placement(current_id, _ghost_pos)
	_ghost.set_valid(can_place)


## Mittelpunkt des Bauwerks, so verschoben, dass seine Ecke auf dem Raster liegt.
func snap_position(world_pos: Vector2, id: StringName) -> Vector2:
	var size: Vector2 = footprint_px(id)
	var top_left: Vector2 = ((world_pos - size * 0.5) / GRID).round() * GRID
	return top_left + size * 0.5


## Frei? (keine Körper der Ebenen world/player/animals, keine anderen Bauwerke, in Reichweite des Spielers)
func check_placement(id: StringName, center: Vector2) -> bool:
	var size: Vector2 = footprint_px(id)
	var player: Node2D = GameState.player
	if player != null and player.global_position.distance_to(center) > BUILD_REACH:
		return false
	var rect: Rect2 = Rect2(center - size * 0.5, size)
	for e in _placed:
		var n: Node2D = _node_of(e)
		if n != null and rect.grow(-1.0).intersects(Rect2(n.global_position - footprint_px(e["id"]) * 0.5, footprint_px(e["id"]))):
			return false
	var viewport: Viewport = get_viewport()
	if viewport == null or viewport.world_2d == null:
		return true
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size - Vector2(2, 2)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = BLOCK_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return viewport.world_2d.direct_space_state.intersect_shape(query, 1).is_empty()


# ------------------------------------------------------------ Platzieren

func _on_tool_used(item_id: StringName, _target: Vector2, _facing: Vector2) -> void:
	if active and item_id == current_id:
		try_place()


## Platziert das ausgerüstete Item an der Geisterposition. Rückgabe: true bei Erfolg.
func try_place() -> bool:
	if not active or not can_place:
		return false
	return place(current_id, _ghost_pos)


## Platziert `id` bei `center` (verbraucht 1 Item aus dem Inventar). Prüft die Platzierbarkeit.
func place(id: StringName, center: Vector2) -> bool:
	if not Inventory.has_item(id) or not check_placement(id, center):
		return false
	var node: Node2D = _spawn_structure(id, center)
	if node == null:
		return false
	Inventory.remove_item(id, 1)
	EventBus.structure_placed.emit(id, center)
	EventBus.action_performed.emit(&"build", {"structure_id": id, "position": center})
	structure_added.emit(node, id)
	return true


func _spawn_structure(id: StringName, center: Vector2) -> Node2D:
	var item: ItemData = ItemDB.get_item(id)
	if item == null:
		return null
	var path: String = item.placeable_scene_path
	var used_placeholder: bool = false
	if path == "" or not ResourceLoader.exists(path):
		path = PLACEHOLDER_SCENE
		used_placeholder = true
	var node: Node2D = (load(path) as PackedScene).instantiate() as Node2D
	if node == null:
		return null
	var parent: Node = _world_parent()
	if parent == null:
		node.queue_free()
		return null
	var info: StructureInfo = get_info(id)
	if used_placeholder and node.has_method("setup"):
		node.call("setup", id, Vector2(info.footprint * GRID), info.placeholder_color, _icon_of(id))
	node.set_meta("structure_id", id)
	if info.provides_station:
		node.set_meta("station", int(info.station))
		node.add_to_group(CraftingSystem.STATION_GROUP)
	node.add_to_group(GROUP)
	parent.add_child(node)
	node.global_position = center
	_placed.append({"id": id, "pos": center, "node": weakref(node)})
	return node


func _world_parent() -> Node:
	var layer: Node = get_tree().get_first_node_in_group("entity_layer")
	return layer if layer != null else get_tree().current_scene


func _icon_of(id: StringName) -> Texture2D:
	var item: ItemData = ItemDB.get_item(id)
	return null if item == null else item.icon


func _node_of(entry: Dictionary) -> Node2D:
	var n: Object = (entry["node"] as WeakRef).get_ref()
	if n == null or (n is Node and (n as Node).is_queued_for_deletion()):
		return null
	return n as Node2D


## Alle platzierten Bauwerke (gültige Nodes).
func get_structures() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for e in _placed:
		var n: Node2D = _node_of(e)
		if n != null:
			out.append(n)
	return out


func clear_structures() -> void:
	for e in _placed:
		var n: Node2D = _node_of(e)
		if n != null:
			n.queue_free()
	_placed.clear()


# ------------------------------------------------------------ Speichern

func get_save_data() -> Dictionary:
	var list: Array = []
	for e in _placed:
		var n: Node2D = _node_of(e)
		if n != null:
			list.append({"id": e["id"], "pos": n.global_position})
	return {"structures": list}


func load_save_data(data: Dictionary) -> void:
	clear_structures()
	for e in data.get("structures", []):
		var id: StringName = StringName(e.get("id", ""))
		if ItemDB.has_item(id):
			_spawn_structure(id, e.get("pos", Vector2.ZERO))
