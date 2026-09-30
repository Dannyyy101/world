class_name WorldGenerator
extends Node2D
## Prozedurale Steinzeit-Welt (Besitzer: Agent 1).
##
## - Biome per FastNoiseLite (Seed speicherbar): Laubwald, Nadelwald, Wiese, Flussaue, Felsgebiet
## - Ein Fluss West->Ost mit 3 Furten, begehbaren Ufern und Trinkstellen
## - Höhle am Ursprung (Zelle 0,0 = Startpunkt): Start-Lager, Regen-/Kälteschutz, Wand für Höhlenmalereien
## - Ressourcen-Nodes per SpawnRule-Resources, Nachwachsen nach Kalender, Jahreszeiten-Optik
## - NavigationRegion2D (zur Laufzeit gebacken), Wildgetreide-Keimung am Lager
##
## Speichern: registriert sich als "world" beim SaveManager (Seed + Abbau-Zustand + Keimlinge + Felder).
## Andere Systeme finden die Welt über die Gruppe "world_generator" (kein Node-Pfad nötig).

const CELL: int = 16
const CAVE_WALLS: Rect2i = Rect2i(-5, -7, 11, 9)       ## Zellen x -5..5, y -7..1
const CAVE_INTERIOR: Rect2i = Rect2i(-4, -5, 9, 6)     ## Zellen x -4..4, y -5..0
const CAVE_ENTRANCE: Rect2i = Rect2i(-1, 1, 3, 1)      ## Öffnung in der Südwand
const CAMP_SEED_RADIUS: float = 6.0 * CELL             ## 6 Tiles um das Lager
const NAV_CHUNK: int = 16                          ## Zellen pro Navigations-Chunk
const NAV_MARGIN: float = 4.0                      ## Sicherheitsabstand um Hindernisse (px)
const SEED_CHANCE: float = 0.2
const RULE_DIR: String = "res://world/data/spawn_rules"
const FIELD_PLOT_SCENE: PackedScene = preload("res://world/scenes/field_plot.tscn")
const DRINK_SPOT_SCENE: PackedScene = preload("res://world/scenes/drink_spot.tscn")
const SPROUT_SCENE: PackedScene = preload("res://world/scenes/wild_grain.tscn")

## Wird nach jeder (Neu-)Generierung ausgelöst (zusätzlich zu EventBus.world_generated).
signal generated()

@export var world_seed: int = 20260930
## Kartenausschnitt in Zellen. Der Ursprung (Höhle) liegt im nördlichen Drittel.
@export var map_rect: Rect2i = Rect2i(-64, -40, 128, 96)
@export var auto_generate: bool = true
@export_group("Fluss")
@export var river_base_y: int = 20
@export var river_amplitude: float = 14.0
@export var ford_count: int = 3
@export_group("Biome-Anteile")
@export_range(0.0, 0.5) var rock_share: float = 0.13
@export_range(0.0, 1.0) var forest_share: float = 0.45

var _w: int = 0
var _h: int = 0
var _terrain: PackedByteArray = PackedByteArray()
var _water_dist: PackedInt32Array = PackedInt32Array()
var _occupied: Dictionary = {}                 ## Vector2i -> true
var _nodes_by_id: Dictionary = {}              ## String -> Node (ResourceNode/DrinkSpot)
var _shore_cells: Array[Vector2i] = []         ## Ufer-Zellen direkt am Wasser
var _ford_columns: Array[int] = []
var _rules: Array[SpawnRule] = []
var _grain_seeds: Array[Dictionary] = []       ## {"pos": Vector2, "day": int}
var _sprouts: Array[Vector2] = []
var _nav_regions: Array[NavigationRegion2D] = []
var _generated: bool = false
var _season_tween: Tween = null

@onready var _ground: TileMapLayer = $Ground
@onready var _snow: TileMapLayer = $Snow
@onready var _objects: Node2D = $Objects
@onready var _trees: TreeSpawner = $Objects/Trees
@onready var _resources: Node2D = $Objects/Resources
@onready var _dynamic: Node2D = $Objects/Dynamic
@onready var _nav: Node2D = $Navigation
@onready var _boundary: Node2D = $Boundary
@onready var _weather: WorldWeather = $Weather
@onready var _cave: Node2D = $Cave
@onready var _shelter: Area2D = $Cave/CaveShelter
@onready var _painting_anchor: Marker2D = $Cave/CavePaintingAnchor
@onready var _camp_spot: Marker2D = $Cave/CampSpot
@onready var _player_start: Marker2D = $Cave/PlayerStart


func _ready() -> void:
	add_to_group("world_generator")
	SaveManager.register("world", self)
	_load_rules()
	EventBus.season_changed.connect(_on_season_changed)
	EventBus.day_started.connect(_on_day_started)
	EventBus.discovery_unlocked.connect(_on_discovery_unlocked)
	EventBus.item_consumed.connect(_on_item_consumed)
	EventBus.rare_find.connect(_on_rare_find)
	_setup_cave_nodes()
	if auto_generate:
		generate(world_seed)


# =============================================================================================
# Öffentliche API
# =============================================================================================

## Erzeugt die Welt neu. seed_value < 0 = aktuellen `world_seed` behalten.
func generate(seed_value: int = -1) -> void:
	if seed_value >= 0:
		world_seed = seed_value
	_clear_world()
	_build_terrain()
	_paint_tiles()
	_reserve_areas()
	_trees.spawn(self)
	_spawn_resources()
	_spawn_drink_spots()
	_build_boundary()
	_bake_navigation()
	_weather.world_seed = world_seed
	_apply_season(int(TimeManager.season), false)
	if not GameState.has_camp:
		GameState.set_camp(_camp_spot.global_position)
	_generated = true
	generated.emit()
	# Deferred: Player und andere Systeme sind dann sicher im Baum.
	EventBus.world_generated.emit.call_deferred()


func get_terrain_cell(cell: Vector2i) -> int:
	if not map_rect.has_point(cell):
		return Biome.Terrain.CAVE_WALL  # außerhalb der Karte: undurchdringlich
	return _terrain[_index(cell)]


## Terrain (Biome.Terrain) an einer Weltposition.
func get_terrain_at(pos: Vector2) -> int:
	return get_terrain_cell(world_to_cell(pos))


## Landschafts-Biom (MEADOW, DECIDUOUS, CONIFER, FLOODPLAIN, ROCK) an einer Weltposition.
func get_biome_at(pos: Vector2) -> int:
	return Biome.to_biome(get_terrain_at(pos))


func is_walkable(pos: Vector2) -> bool:
	return not Biome.is_blocking(get_terrain_at(pos))


## Steht die Position in der Höhle (Schutz vor Regen/Schnee/Kälte)?
func is_sheltered(pos: Vector2) -> bool:
	return _shelter_rect().has_point(pos)


func is_raining() -> bool:
	return _weather.is_raining()


func get_weather() -> StringName:
	return _weather.current


## Marker für die Höhlenmalereien (Agent 6): unterer Mittelpunkt der Nordwand, Malfläche bis 32 px darüber.
func get_cave_painting_anchor() -> Marker2D:
	return _painting_anchor


func get_start_position() -> Vector2:
	return _player_start.global_position


func get_camp_position() -> Vector2:
	return _camp_spot.global_position


## Nächstes Ufer am Wasser (begehbar) – z. B. für Tiere, die trinken wollen. Vector2.INF, wenn keins.
func get_nearest_shore_position(from: Vector2) -> Vector2:
	var best: Vector2 = Vector2.INF
	var best_d: float = INF
	for cell in _shore_cells:
		var p: Vector2 = cell_center(cell)
		var d: float = from.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = p
	return best


## Wegfindung: NavigationServer2D.map_get_path(world.get_navigation_map(), von, nach, true)
## oder einen NavigationAgent2D nutzen (er verwendet die Standard-Karte der Welt automatisch).
func get_navigation_map() -> RID:
	return _nav_regions[0].get_navigation_map() if not _nav_regions.is_empty() else RID()


func get_map_rect_px() -> Rect2:
	return Rect2(Vector2(map_rect.position) * CELL, Vector2(map_rect.size) * CELL)


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL), floori(pos.y / CELL))


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL + CELL / 2.0, cell.y * CELL + CELL / 2.0)


## Zählt Zellen je Terrain (Debug/Test).
func count_terrain() -> Dictionary:
	var out: Dictionary = {}
	for v in _terrain:
		out[int(v)] = int(out.get(int(v), 0)) + 1
	return out


func is_occupied(cell: Vector2i) -> bool:
	return _occupied.has(cell)


func mark_occupied(cell: Vector2i) -> void:
	_occupied[cell] = true


func register_node(node: Node) -> void:
	var id: Variant = node.get("node_id")
	if id is String and id != "":
		_nodes_by_id[id] = node


func get_node_by_id(id: String) -> Node:
	return _nodes_by_id.get(id)


func get_resource_nodes() -> Array[ResourceNode]:
	var out: Array[ResourceNode] = []
	for n in _nodes_by_id.values():
		if n is ResourceNode:
			out.append(n)
	return out


## Ein Getreidekorn liegt auf dem Boden (z. B. von Agent 2 beim Fallenlassen aufgerufen).
## Nur im Umkreis von 6 Tiles um das Lager keimt es im nächsten Frühling.
func notify_item_on_ground(item_id: StringName, pos: Vector2) -> void:
	if item_id == &"wild_grain":
		scatter_grain_seed(pos)


## Legt ein Samenkorn ab (nur nahe dem Lager wirksam). Rückgabe: true, wenn es gemerkt wurde.
func scatter_grain_seed(pos: Vector2) -> bool:
	if not GameState.has_camp or pos.distance_to(GameState.camp_position) > CAMP_SEED_RADIUS:
		return false
	if not is_walkable(pos):
		return false
	_grain_seeds.append({"pos": pos, "day": TimeManager.day})
	return true


func get_pending_seed_count() -> int:
	return _grain_seeds.size()


# =============================================================================================
# Terrain-Generierung
# =============================================================================================

func _index(cell: Vector2i) -> int:
	return (cell.x - map_rect.position.x) + (cell.y - map_rect.position.y) * _w


func _clear_world() -> void:
	_nodes_by_id.clear()
	_occupied.clear()
	_shore_cells.clear()
	_ford_columns.clear()
	_grain_seeds.clear()
	_sprouts.clear()
	_trees.clear()
	for container in [_resources, _dynamic, _boundary]:
		for child in (container as Node).get_children():
			container.remove_child(child)
			child.queue_free()
	for plot in get_tree().get_nodes_in_group("field_plots"):
		if is_ancestor_of(plot):
			plot.queue_free()
	_ground.clear()
	_snow.clear()


func _build_terrain() -> void:
	_w = map_rect.size.x
	_h = map_rect.size.y
	var total: int = _w * _h
	_terrain = PackedByteArray()
	_terrain.resize(total)
	_terrain.fill(255)  # 255 = noch nicht festgelegt (Land)
	_water_dist = PackedInt32Array()
	_water_dist.resize(total)
	_water_dist.fill(999)

	_carve_river()
	_compute_water_distance()

	# --- Rauschfelder -------------------------------------------------------------------
	var elev: FastNoiseLite = _make_noise(1, 0.022)
	var forest: FastNoiseLite = _make_noise(2, 0.032)
	var temp: FastNoiseLite = _make_noise(3, 0.018)
	var elev_v: PackedFloat32Array = PackedFloat32Array()
	var forest_v: PackedFloat32Array = PackedFloat32Array()
	var temp_v: PackedFloat32Array = PackedFloat32Array()
	elev_v.resize(total)
	forest_v.resize(total)
	temp_v.resize(total)
	var land_elev: Array[float] = []
	for cy in range(map_rect.position.y, map_rect.end.y):
		for cx in range(map_rect.position.x, map_rect.end.x):
			var i: int = _index(Vector2i(cx, cy))
			elev_v[i] = elev.get_noise_2d(cx, cy)
			forest_v[i] = forest.get_noise_2d(cx, cy)
			temp_v[i] = temp.get_noise_2d(cx, cy)
			if _terrain[i] == 255:
				land_elev.append(elev_v[i])
	# Schwellen per Quantil -> jedes Biom kommt bei jedem Seed vor.
	land_elev.sort()
	var rock_cut: float = land_elev[int((1.0 - rock_share) * (land_elev.size() - 1))]
	var forest_vals: Array[float] = []
	for i in total:
		if _terrain[i] == 255 and elev_v[i] < rock_cut:
			forest_vals.append(forest_v[i])
	forest_vals.sort()
	var forest_cut: float = forest_vals[int((1.0 - forest_share) * (forest_vals.size() - 1))]
	var temp_vals: Array[float] = []
	for i in total:
		if _terrain[i] == 255 and elev_v[i] < rock_cut and forest_v[i] >= forest_cut:
			temp_vals.append(temp_v[i])
	temp_vals.sort()
	var temp_cut: float = temp_vals[temp_vals.size() / 2] if not temp_vals.is_empty() else 0.0

	for cy in range(map_rect.position.y, map_rect.end.y):
		for cx in range(map_rect.position.x, map_rect.end.x):
			var cell: Vector2i = Vector2i(cx, cy)
			var i: int = _index(cell)
			if _terrain[i] != 255:
				continue
			var e: float = elev_v[i]
			# Felsmassiv um die Höhle erzwingen
			var d: Vector2 = Vector2(cx - 0.0, (cy + 4.0) * 1.25)
			if d.length() < 13.0:
				e += 5.0
			var dist: int = _water_dist[i]
			var t: int
			if dist == 1:
				t = Biome.Terrain.BANK
			elif e >= rock_cut:
				t = Biome.Terrain.ROCK
			elif dist <= 5:
				t = Biome.Terrain.FLOODPLAIN
			elif forest_v[i] >= forest_cut:
				t = Biome.Terrain.DECIDUOUS if temp_v[i] >= temp_cut else Biome.Terrain.CONIFER
			else:
				t = Biome.Terrain.MEADOW
			_terrain[i] = t
	_carve_cave()
	_collect_shore_cells()


func _make_noise(offset: int, freq: float) -> FastNoiseLite:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = world_seed + offset * 101
	n.frequency = freq
	return n


func _carve_river() -> void:
	var rn: FastNoiseLite = FastNoiseLite.new()
	rn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	rn.seed = world_seed + 11
	rn.frequency = 0.02
	var wn: FastNoiseLite = FastNoiseLite.new()
	wn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wn.seed = world_seed + 12
	wn.frequency = 0.05
	var prev_c: float = river_base_y + rn.get_noise_1d(map_rect.position.x) * river_amplitude
	for cx in range(map_rect.position.x, map_rect.end.x):
		var c: float = river_base_y + rn.get_noise_1d(cx) * river_amplitude
		var half: float = (3.0 + roundf(absf(wn.get_noise_1d(cx)) * 4.0)) / 2.0
		var lo: int = floori(minf(c, prev_c) - half)
		var hi: int = ceili(maxf(c, prev_c) + half)
		prev_c = c
		for cy in range(lo, hi + 1):
			var cell: Vector2i = Vector2i(cx, cy)
			if map_rect.has_point(cell):
				_terrain[_index(cell)] = Biome.Terrain.WATER
	# Furten
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0xF0D
	for k in ford_count:
		var frac: float = (k + 1.0) / (ford_count + 1.0)
		var fx: int = map_rect.position.x + int(_w * frac) + rng.randi_range(-4, 4)
		_ford_columns.append(fx)
		for cx in range(fx - 1, fx + 2):
			for cy in range(map_rect.position.y, map_rect.end.y):
				var cell: Vector2i = Vector2i(cx, cy)
				if map_rect.has_point(cell) and _terrain[_index(cell)] == Biome.Terrain.WATER:
					_terrain[_index(cell)] = Biome.Terrain.FORD


func _compute_water_distance() -> void:
	var queue: Array[Vector2i] = []
	for cy in range(map_rect.position.y, map_rect.end.y):
		for cx in range(map_rect.position.x, map_rect.end.x):
			var cell: Vector2i = Vector2i(cx, cy)
			if Biome.is_water(_terrain[_index(cell)]):
				_water_dist[_index(cell)] = 0
				queue.append(cell)
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		var d: int = _water_dist[_index(cur)]
		if d >= 8:
			continue
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + off
			if map_rect.has_point(nb) and _water_dist[_index(nb)] > d + 1:
				_water_dist[_index(nb)] = d + 1
				queue.append(nb)


func _carve_cave() -> void:
	for cy in range(CAVE_WALLS.position.y, CAVE_WALLS.end.y):
		for cx in range(CAVE_WALLS.position.x, CAVE_WALLS.end.x):
			var cell: Vector2i = Vector2i(cx, cy)
			var t: int = Biome.Terrain.CAVE_WALL
			if CAVE_INTERIOR.has_point(cell) or CAVE_ENTRANCE.has_point(cell):
				t = Biome.Terrain.CAVE_FLOOR
			_terrain[_index(cell)] = t


func _collect_shore_cells() -> void:
	_shore_cells.clear()
	for cy in range(map_rect.position.y, map_rect.end.y):
		for cx in range(map_rect.position.x, map_rect.end.x):
			var cell: Vector2i = Vector2i(cx, cy)
			if _terrain[_index(cell)] != Biome.Terrain.BANK:
				continue
			for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nb: Vector2i = cell + off
				if map_rect.has_point(nb) and _terrain[_index(nb)] == Biome.Terrain.WATER:
					_shore_cells.append(cell)
					break


func _paint_tiles() -> void:
	var ts: TileSet = WorldArt.get_tileset()
	_ground.tile_set = ts
	_snow.tile_set = ts
	for cy in range(map_rect.position.y, map_rect.end.y):
		for cx in range(map_rect.position.x, map_rect.end.x):
			var cell: Vector2i = Vector2i(cx, cy)
			var t: int = _terrain[_index(cell)]
			var variant: int = (cx * 73856093 ^ cy * 19349663 ^ world_seed) & 3
			_ground.set_cell(cell, 0, Vector2i(variant, t))
			if t != Biome.Terrain.WATER and t != Biome.Terrain.FORD \
					and t != Biome.Terrain.CAVE_FLOOR and t != Biome.Terrain.CAVE_WALL:
				_snow.set_cell(cell, 0, Vector2i(variant, Biome.SNOW_ROW))


## Zellen, die von Bäumen/Ressourcen frei bleiben (Höhle, Lagerplatz davor).
func _reserve_areas() -> void:
	var keep: Rect2i = Rect2i(-8, -9, 17, 20)   # Höhle + Vorplatz bis y=10
	for cy in range(keep.position.y, keep.end.y):
		for cx in range(keep.position.x, keep.end.x):
			_occupied[Vector2i(cx, cy)] = true


# =============================================================================================
# Ressourcen
# =============================================================================================

func _load_rules() -> void:
	_rules.clear()
	var dir: DirAccess = DirAccess.open(RULE_DIR)
	if dir == null:
		push_warning("WorldGenerator: keine Spawn-Regeln unter %s" % RULE_DIR)
		return
	var files: Array[String] = []
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var name: String = entry.trim_suffix(".remap")
		if not dir.current_is_dir() and name.ends_with(".tres"):
			files.append(name)
		entry = dir.get_next()
	dir.list_dir_end()
	files.sort()
	for f in files:
		var res: Resource = load(RULE_DIR.path_join(f))
		if res is SpawnRule:
			_rules.append(res)


func _spawn_resources() -> void:
	var rule_index: int = 0
	for rule in _rules:
		rule_index += 1
		if rule.scene == null:
			continue
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = world_seed ^ (rule_index * 7919)
		var candidates: Array[Vector2i] = []
		for cy in range(map_rect.position.y, map_rect.end.y):
			for cx in range(map_rect.position.x, map_rect.end.x):
				var cell: Vector2i = Vector2i(cx, cy)
				if _cell_allowed(rule, cell):
					candidates.append(cell)
		_shuffle(candidates, rng)
		var centers: Array[Vector2i] = []
		var placed: int = 0
		var spacing_sq: float = rule.min_spacing * rule.min_spacing
		for cell in candidates:
			if placed >= rule.count:
				break
			if _occupied.has(cell):
				continue
			var too_close: bool = false
			for c in centers:
				if Vector2(cell - c).length_squared() < spacing_sq:
					too_close = true
					break
			if too_close:
				continue
			centers.append(cell)
			placed += _spawn_resource(rule, cell, rng)
			if rule.cluster_size > 1:
				var extra: int = rule.cluster_size - 1
				var tries: int = 0
				while extra > 0 and tries < 24 and placed < rule.count:
					tries += 1
					var ang: float = rng.randf() * TAU
					var r: float = rng.randf_range(1.0, rule.cluster_radius)
					var nb: Vector2i = cell + Vector2i(roundi(cos(ang) * r), roundi(sin(ang) * r))
					if map_rect.has_point(nb) and _cell_allowed(rule, nb) and not _occupied.has(nb):
						placed += _spawn_resource(rule, nb, rng)
						extra -= 1


func _cell_allowed(rule: SpawnRule, cell: Vector2i) -> bool:
	if _occupied.has(cell):
		return false
	var i: int = _index(cell)
	if not rule.terrains.has(int(_terrain[i])):
		return false
	var wd: int = _water_dist[i]
	if rule.max_water_dist >= 0 and wd > rule.max_water_dist:
		return false
	return wd >= rule.min_water_dist


func _spawn_resource(rule: SpawnRule, cell: Vector2i, rng: RandomNumberGenerator) -> int:
	var node: Node2D = rule.scene.instantiate()
	node.set("node_id", "%s@%d,%d" % [rule.id, cell.x, cell.y])
	node.position = (cell_center(cell) + Vector2(rng.randi_range(-3, 3), 4 + rng.randi_range(-2, 2))).floor()
	_resources.add_child(node)
	register_node(node)
	mark_occupied(cell)
	return 1


func _spawn_drink_spots() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0xD121
	var cells: Array[Vector2i] = _shore_cells.duplicate()
	_shuffle(cells, rng)
	var chosen: Array[Vector2i] = []
	for cell in cells:
		if chosen.size() >= 16:
			break
		var ok: bool = true
		for c in chosen:
			if Vector2(cell - c).length_squared() < 64.0:
				ok = false
				break
		if ok and not _occupied.has(cell):
			chosen.append(cell)
	for cell in chosen:
		var spot: DrinkSpot = DRINK_SPOT_SCENE.instantiate()
		spot.node_id = "drink@%d,%d" % [cell.x, cell.y]
		spot.position = cell_center(cell)
		_resources.add_child(spot)
		register_node(spot)
		mark_occupied(cell)


func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


# =============================================================================================
# Begrenzung & Navigation
# =============================================================================================

func _build_boundary() -> void:
	var r: Rect2 = get_map_rect_px()
	var t: float = 32.0
	var rects: Array[Rect2] = [
		Rect2(r.position.x - t, r.position.y - t, r.size.x + 2 * t, t),
		Rect2(r.position.x - t, r.end.y, r.size.x + 2 * t, t),
		Rect2(r.position.x - t, r.position.y, t, r.size.y),
		Rect2(r.end.x, r.position.y, t, r.size.y),
	]
	for rc in rects:
		var body: StaticBody2D = StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rs: RectangleShape2D = RectangleShape2D.new()
		rs.size = rc.size
		shape.shape = rs
		body.position = rc.get_center()
		body.add_child(shape)
		_boundary.add_child(body)


func _bake_navigation() -> void:
	# Die Karte wird in Chunks gebacken (je eine NavigationRegion2D): ein einziges Mesh mit ~1000
	# Baum-Löchern braucht >10 s, 48 Chunks brauchen zusammen unter einer Sekunde. Die Chunk-Ränder
	# liegen exakt aufeinander und werden vom NavigationServer automatisch verbunden.
	for region in _nav_regions:
		_nav.remove_child(region)
		region.queue_free()
	_nav_regions.clear()
	var blockers: Dictionary = {}   # Vector2i(Chunk) -> Array[Rect2]
	var margin: float = NAV_MARGIN
	for cy in range(map_rect.position.y, map_rect.end.y):
		var run_start: int = 0
		var in_run: bool = false
		for cx in range(map_rect.position.x, map_rect.end.x + 1):
			var blocked: bool = cx < map_rect.end.x and Biome.is_blocking(_terrain[_index(Vector2i(cx, cy))])
			if blocked and not in_run:
				in_run = true
				run_start = cx
			elif not blocked and in_run:
				in_run = false
				_add_blocker(blockers, Rect2(run_start * CELL, cy * CELL, (cx - run_start) * CELL, CELL).grow(margin))
	for node in _nodes_by_id.values():
		if node is ResourceNode and (node as ResourceNode).blocks_movement:
			var rn: ResourceNode = node
			var sz: Vector2 = rn.body_size
			_add_blocker(blockers, Rect2(rn.position.x - sz.x / 2.0, rn.position.y - sz.y, sz.x, sz.y).grow(margin))
	var chunk_px: float = NAV_CHUNK * CELL
	var origin: Vector2 = Vector2(map_rect.position) * CELL
	for ky in range(ceili(float(map_rect.size.y) / NAV_CHUNK)):
		for kx in range(ceili(float(map_rect.size.x) / NAV_CHUNK)):
			var rc: Rect2 = Rect2(origin + Vector2(kx, ky) * chunk_px, Vector2(chunk_px, chunk_px)).intersection(get_map_rect_px())
			var np: NavigationPolygon = NavigationPolygon.new()
			var src: NavigationMeshSourceGeometryData2D = NavigationMeshSourceGeometryData2D.new()
			src.add_traversable_outline(_rect_outline(rc))
			for b in blockers.get(Vector2i(kx, ky), []):
				src.add_obstruction_outline(_rect_outline(b))
			NavigationServer2D.bake_from_source_geometry_data(np, src)
			var region: NavigationRegion2D = NavigationRegion2D.new()
			region.navigation_polygon = np
			_nav.add_child(region)
			_nav_regions.append(region)


## Trägt ein Hindernis in alle Chunks ein, die es berührt.
func _add_blocker(blockers: Dictionary, rc: Rect2) -> void:
	var chunk_px: float = NAV_CHUNK * CELL
	var origin: Vector2 = Vector2(map_rect.position) * CELL
	var k0: Vector2i = Vector2i(floori((rc.position.x - origin.x) / chunk_px), floori((rc.position.y - origin.y) / chunk_px))
	var k1: Vector2i = Vector2i(floori((rc.end.x - origin.x) / chunk_px), floori((rc.end.y - origin.y) / chunk_px))
	for ky in range(k0.y, k1.y + 1):
		for kx in range(k0.x, k1.x + 1):
			var key: Vector2i = Vector2i(kx, ky)
			if not blockers.has(key):
				blockers[key] = []
			(blockers[key] as Array).append(rc)


func _rect_outline(rc: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rc.position, Vector2(rc.end.x, rc.position.y), rc.end, Vector2(rc.position.x, rc.end.y)])


# =============================================================================================
# Höhle
# =============================================================================================

func _shelter_rect() -> Rect2:
	return Rect2(Vector2(CAVE_INTERIOR.position) * CELL, Vector2(CAVE_INTERIOR.size) * CELL)


func _setup_cave_nodes() -> void:
	var rc: Rect2 = _shelter_rect()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rc.size
	($Cave/CaveShelter/CollisionShape2D as CollisionShape2D).shape = shape
	_shelter.position = rc.get_center()
	# Nordwand: unterer Rand der Wand über dem Innenraum, mittig
	_painting_anchor.position = Vector2(rc.get_center().x, rc.position.y)
	_camp_spot.position = Vector2(rc.get_center().x, rc.position.y + 3.0 * CELL)
	_player_start.position = Vector2(0, 0)


# =============================================================================================
# Jahreszeiten
# =============================================================================================

func _on_season_changed(season: int) -> void:
	if not _generated:
		return
	_apply_season(season, true)
	if season == Enums.Season.SPRING:
		_sprout_seeds()


func _on_day_started(_day: int) -> void:
	if _generated:
		get_tree().call_group("world_resources", "refresh_state")


func _on_discovery_unlocked(_id: StringName) -> void:
	if _generated:
		get_tree().call_group("world_resources", "refresh_state")


func _apply_season(season: int, animate: bool) -> void:
	var tint: Color = WorldArt.ground_tint(season)
	var snow_alpha: float = 1.0 if season == Enums.Season.WINTER else 0.0
	if _season_tween != null:
		_season_tween.kill()
		_season_tween = null
	if animate and is_inside_tree():
		_season_tween = create_tween().set_parallel(true)
		_season_tween.tween_property(_ground, "modulate", tint, 1.5)
		_season_tween.tween_property(_snow, "modulate:a", snow_alpha, 2.0)
	else:
		_ground.modulate = tint
		_snow.modulate.a = snow_alpha
	_snow.visible = true
	get_tree().call_group("world_resources", "refresh_state")


# =============================================================================================
# Wildgetreide am Lager -> Ackerbau-Vorstufe
# =============================================================================================

func _on_item_consumed(item_id: StringName) -> void:
	if item_id != &"wild_grain" or GameState.player == null or not _generated:
		return
	if randf() < SEED_CHANCE:
		scatter_grain_seed(GameState.player.global_position + Vector2(randi_range(-10, 10), randi_range(-4, 10)))


func _sprout_seeds() -> void:
	# Beginn des aktuellen Frühlings; nur Samen, die davor fielen, keimen jetzt.
	var spring_start_day: int = (TimeManager.year - 1) * TimeManager.DAYS_PER_SEASON * 4 + 1
	var remaining: Array[Dictionary] = []
	for s in _grain_seeds:
		if int(s["day"]) < spring_start_day:
			_spawn_sprout(s["pos"])
		else:
			remaining.append(s)
	_grain_seeds = remaining


func _spawn_sprout(pos: Vector2) -> void:
	_sprouts.append(pos)
	_create_sprout_node(pos)
	EventBus.action_performed.emit(&"seed_sprouted_at_camp", {"position": pos})


func _create_sprout_node(pos: Vector2) -> void:
	var node: ResourceNode = SPROUT_SCENE.instantiate()
	node.node_id = "sprout@%d,%d" % [roundi(pos.x), roundi(pos.y)]
	node.position = pos.floor()
	_dynamic.add_child(node)
	register_node(node)


func _on_rare_find(item_id: StringName, pos: Vector2) -> void:
	if not _generated:
		return
	var fx: CPUParticles2D = CPUParticles2D.new()
	fx.texture = WorldArt.tex("glitter")
	fx.emitting = false
	fx.one_shot = true
	fx.amount = 12
	fx.lifetime = 1.1
	fx.explosiveness = 0.9
	fx.direction = Vector2(0, -1)
	fx.spread = 120.0
	fx.gravity = Vector2(0, -8)
	fx.initial_velocity_min = 8.0
	fx.initial_velocity_max = 22.0
	fx.color = Color(1.0, 0.85, 0.4) if item_id == &"amber" else Color(0.9, 1.0, 0.95)
	fx.position = pos + Vector2(0, -6)
	_dynamic.add_child(fx)
	fx.restart()
	fx.emitting = true
	get_tree().create_timer(fx.lifetime + 0.5).timeout.connect(fx.queue_free)


# =============================================================================================
# Speichern / Laden
# =============================================================================================

func get_save_data() -> Dictionary:
	var depleted: Dictionary = {}
	for id in _nodes_by_id:
		var n: Variant = _nodes_by_id[id]
		if n is ResourceNode and (n as ResourceNode).is_depleted():
			depleted[id] = (n as ResourceNode).get_regrow_day()
	var seeds: Array = []
	for s in _grain_seeds:
		seeds.append({"pos": s["pos"], "day": s["day"]})
	var fields: Array = []
	for plot in get_tree().get_nodes_in_group("field_plots"):
		if plot is FieldPlot:
			fields.append((plot as FieldPlot).get_save_data())
	return {
		"seed": world_seed,
		"depleted": depleted,
		"seeds": seeds,
		"sprouts": _sprouts.duplicate(),
		"fields": fields,
	}


func load_save_data(data: Dictionary) -> void:
	var saved_seed: int = int(data.get("seed", world_seed))
	# Immer neu generieren: setzt Abbau-Zustand, Keimlinge und Felder sauber zurück.
	generate(saved_seed)
	_grain_seeds.clear()
	for s in data.get("seeds", []):
		_grain_seeds.append({"pos": s["pos"], "day": int(s["day"])})
	_sprouts.clear()
	for p in data.get("sprouts", []):
		var pos: Vector2 = p
		_sprouts.append(pos)
		_create_sprout_node(pos)
	var depleted: Dictionary = data.get("depleted", {})
	for id in depleted:
		var n: Node = get_node_by_id(String(id))
		if n is ResourceNode:
			(n as ResourceNode).set_depleted(true, int(depleted[id]))
	for plot in get_tree().get_nodes_in_group("field_plots"):
		plot.queue_free()
	for f in data.get("fields", []):
		var plot: FieldPlot = FIELD_PLOT_SCENE.instantiate()
		plot.position = f["position"]
		_dynamic.add_child(plot)
		plot.apply_save_data(f)
