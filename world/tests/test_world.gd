extends Node2D
## Isolierter Test der Welt (Agent 1).
## Interaktiv (F6): WASD laufen, E interagieren, Linksklick Werkzeug (ohne Axt: nur Wackler).
##   T = nächste Jahreszeit · N = neue Welt (neuer Seed) · F5 speichern · F9 laden · X = hand_axe + Entdeckungen geben
## Headless: godot --headless --path . res://world/tests/test_world.tscn   (Exit 0 = ok)

const WORLD_SCENE: PackedScene = preload("res://world/scenes/world.tscn")
const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const FIELD_SCENE: PackedScene = preload("res://world/scenes/field_plot.tscn")
const SLOT: int = 9

var _failures: int = 0
var _log: Array[String] = []
var _world: WorldGenerator
var _player: Player
var _actions: Array[StringName] = []
var _weather_events: Array[StringName] = []
var _generated_signals: int = 0

@onready var _label: Label = $CanvasLayer/Label


func _ready() -> void:
	EventBus.action_performed.connect(func(a: StringName, _c: Dictionary) -> void: _actions.append(a))
	EventBus.weather_changed.connect(func(w: StringName) -> void: _weather_events.append(w))
	EventBus.world_generated.connect(func() -> void: _generated_signals += 1)
	_world = WORLD_SCENE.instantiate()
	_world.auto_generate = false
	add_child(_world)
	_player = PLAYER_SCENE.instantiate()
	(get_tree().get_first_node_in_group("entity_layer") as Node).add_child(_player)
	if DisplayServer.get_name() == "headless":
		await _run_checks()
	else:
		_world.generate(_world.world_seed)
		_player.position = _world.get_start_position()
		var cam: Camera2D = Camera2D.new()
		_player.add_child(cam)
		_label.text = "WASD laufen · E interagieren · T Jahreszeit · N neue Welt · F5/F9 speichern/laden · X Werkzeug+Entdeckungen"


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_T:
			var next_day: int = (TimeManager.get_day_of_season() * 0 + (int(TimeManager.season) + 1) * TimeManager.DAYS_PER_SEASON + 1)
			_jump_to_day(next_day % (TimeManager.DAYS_PER_SEASON * 4) + 0)
		KEY_N:
			_world.generate(randi() % 100000)
		KEY_F5:
			SaveManager.save_game(SLOT)
		KEY_F9:
			SaveManager.load_game(SLOT)
		KEY_X:
			Inventory.add_item(&"hand_axe", 1)
			Inventory.add_item(&"fired_pottery", 1)
			Inventory.add_item(&"wild_grain", 5)
			Discoveries.unlock(&"agriculture")
			Discoveries.unlock(&"kiln")


func _jump_to_day(day: int) -> void:
	TimeManager.load_save_data({"day": maxi(1, day), "hour": 8.0})


func _check(cond: bool, what: String) -> void:
	_log.append(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_failures += 1


func _ids_with_prefix(prefix: String) -> Array[String]:
	var out: Array[String] = []
	for n in _world.get_resource_nodes():
		if n.node_id.begins_with(prefix + "@"):
			out.append(n.node_id)
	return out


func _first_node(prefix: String) -> ResourceNode:
	var ids: Array[String] = _ids_with_prefix(prefix)
	return _world.get_node_by_id(ids[0]) as ResourceNode if not ids.is_empty() else null


func _run_checks() -> void:
	_jump_to_day(1)
	var t0: int = Time.get_ticks_msec()
	_world.generate(4242)
	var gen_ms: int = Time.get_ticks_msec() - t0
	_log.append("Generierung: %d ms" % gen_ms)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_test_biomes()
	await _test_navigation()
	_test_cave()
	_test_determinism()
	_test_resources_and_seasons()
	_test_drink()
	_test_farming_seeds()
	_test_field_plot()
	_test_visuals_and_rare()
	_test_save_load()
	_test_weather()
	var summary: String = "ALLE TESTS BESTANDEN" if _failures == 0 else "%d FEHLER" % _failures
	_log.append("== " + summary)
	print("\n".join(_log))
	_label.text = "\n".join(_log)
	get_tree().quit(0 if _failures == 0 else 1)


# --- Biome, Fluss, Furten ---------------------------------------------------------------------
func _test_biomes() -> void:
	var counts: Dictionary = _world.count_terrain()
	for t in Biome.Terrain.values():
		_check(int(counts.get(t, 0)) > 0, "Terrain '%s' kommt vor (%d Zellen)" % [Biome.NAMES[t], int(counts.get(t, 0))])
	_check(_world._ford_columns.size() == 3, "3 Furten angelegt")
	_check(_world.get_terrain_at(Vector2(0, 0)) == Biome.Terrain.CAVE_FLOOR, "Startpunkt liegt in der Höhle")
	_check(_world._ground.tile_set.get_physics_layers_count() == 1, "TileSet hat Physik-Layer (Wasser/Wand blockieren)")
	# Erreichbarkeit: vom Start (0,0) über begehbare Zellen bis südlich des Flusses
	var reach: Dictionary = _flood_fill(Vector2i(0, 0))
	var south_reached: bool = false
	var ford_ok: bool = false
	for cell in reach:
		var c: Vector2i = cell
		if c.y > _world.river_base_y + 20:
			south_reached = true
		if _world.get_terrain_cell(c) == Biome.Terrain.FORD:
			ford_ok = true
	_check(ford_ok, "Furt ist vom Start aus erreichbar")
	_check(south_reached, "Land südlich des Flusses ist über Furt erreichbar")
	# Wasser blockiert: Fluss ohne Furt wäre unpassierbar -> Fill darf Wasser nie betreten
	var water_in_reach: bool = false
	for cell in reach:
		if _world.get_terrain_cell(cell) == Biome.Terrain.WATER:
			water_in_reach = true
	_check(not water_in_reach, "begehbare Fläche enthält kein Wasser")


func _flood_fill(start: Vector2i) -> Dictionary:
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + off
			if _world.map_rect.has_point(nb) and not seen.has(nb) and not Biome.is_blocking(_world.get_terrain_cell(nb)):
				seen[nb] = true
				queue.append(nb)
	return seen


func _test_navigation() -> void:
	# Der NavigationServer synchronisiert asynchron (Thread) – auf die erste Iteration warten.
	var waited: int = 0
	while NavigationServer2D.map_get_iteration_id(_world.get_navigation_map()) == 0 and waited < 600:
		waited += 1
		await get_tree().physics_frame
		await get_tree().create_timer(0.01).timeout
	var polys: int = 0
	for region in _world._nav_regions:
		polys += region.navigation_polygon.get_polygon_count()
	_check(polys > 0, "Navigationsmesh gebacken (%d Regionen, %d Polygone)" % [_world._nav_regions.size(), polys])
	var map: RID = _world.get_navigation_map()
	var from: Vector2 = Vector2(8, 40)
	# Ziel: Landzelle südlich des Flusses in der Nähe von x=0
	var target: Vector2 = Vector2.INF
	for cy in range(_world.river_base_y + 22, _world.map_rect.end.y - 2):
		var cell: Vector2i = Vector2i(0, cy)
		if _world.get_terrain_cell(cell) != Biome.Terrain.WATER:
			target = _world.cell_center(cell)
			break
	var path: PackedVector2Array = NavigationServer2D.map_get_path(map, from, target, true)
	_check(path.size() >= 2, "Wegfindung über den Fluss liefert einen Pfad (%d Punkte)" % path.size())
	var crosses_water: bool = false
	for i in range(path.size() - 1):
		var steps: int = 8
		for s in steps + 1:
			var p: Vector2 = path[i].lerp(path[i + 1], float(s) / steps)
			if _world.get_terrain_at(p) == Biome.Terrain.WATER:
				crosses_water = true
	_check(not crosses_water, "Pfad führt nicht durch Wasser (nutzt die Furt)")


# --- Höhle ------------------------------------------------------------------------------------
func _test_cave() -> void:
	_check(_world.is_sheltered(Vector2(8, -20)), "Höhlen-Innenraum bietet Schutz")
	_check(not _world.is_sheltered(Vector2(8, 60)), "Außerhalb kein Schutz")
	var anchor: Marker2D = _world.get_cave_painting_anchor()
	_check(anchor != null and anchor.name == &"CavePaintingAnchor", "CavePaintingAnchor vorhanden")
	_check(_world.get_terrain_at(anchor.global_position + Vector2(0, -8)) == Biome.Terrain.CAVE_WALL, "Anker liegt an der Höhlenwand")
	_check(GameState.has_camp, "Start-Lager gesetzt (GameState.camp_position)")
	_check(_world.is_sheltered(GameState.camp_position), "Lager liegt in der Höhle")


# --- Determinismus ----------------------------------------------------------------------------
func _test_determinism() -> void:
	var h1: int = hash(_world._terrain)
	var ids1: Array = _world._nodes_by_id.keys()
	ids1.sort()
	_world.generate(4242)
	var ids2: Array = _world._nodes_by_id.keys()
	ids2.sort()
	_check(h1 == hash(_world._terrain), "gleicher Seed -> gleiches Terrain")
	_check(ids1 == ids2, "gleicher Seed -> gleiche Ressourcen (%d Nodes)" % ids1.size())
	_world.generate(777)
	_check(h1 != hash(_world._terrain), "anderer Seed -> anderes Terrain")
	_world.generate(4242)
	_check(_generated_signals >= 1, "world_generated wurde emittiert")


# --- Ressourcen, Nachwachsen, Jahreszeiten ----------------------------------------------------
func _test_resources_and_seasons() -> void:
	for p in ["tree", "branch_bush", "stone", "flint", "clay", "nettle", "berry_bush", "mushroom", "wild_grain", "malachite", "amber"]:
		_check(not _ids_with_prefix(p).is_empty(), "Ressource '%s' platziert (%d)" % [p, _ids_with_prefix(p).size()])
	var types: Dictionary = {}
	for n in _world.get_resource_nodes():
		if n.node_id.begins_with("tree@"):
			types[n.foliage] = true
	_check(types.has(ResourceNode.Foliage.DECIDUOUS) and types.has(ResourceNode.Foliage.CONIFER), "Laub- und Nadelbäume")

	# Baum: nur mit Axt
	_jump_to_day(1)
	var tree: ResourceNode = _first_node("tree")
	var wood_before: int = Inventory.count(&"wood_log")
	tree._hurtbox.receive_hit(1.0, int(Enums.ToolType.NONE), null)
	tree._hurtbox.receive_hit(1.0, int(Enums.ToolType.NONE), null)
	_check(Inventory.count(&"wood_log") == wood_before and tree.is_available(), "Baum reagiert nicht auf bloße Hände")
	_actions.clear()
	for i in 4:
		tree._hurtbox.receive_hit(1.0, int(Enums.ToolType.AXE), null)
	_check(tree.is_depleted() and Inventory.count(&"wood_log") >= wood_before + 2, "Baum fällt nach 4 Axt-Treffern und droppt wood_log")
	_check(Inventory.count(&"branch") >= 1, "Baum droppt auch branch")
	_check(_actions.has(&"chop_tree"), "action_performed(chop_tree)")
	_jump_to_day(1 + tree.regrow_days)
	_check(not tree.is_depleted(), "Baum wächst nach %d Tagen nach" % tree.regrow_days)

	# Handernte einfacher Nodes
	for p in ["branch_bush", "stone", "flint", "clay"]:
		var n: ResourceNode = _first_node(p)
		_actions.clear()
		var before: int = Inventory.count(n.item_id)
		n._interactable.interact(_player)
		_check(Inventory.count(n.item_id) > before and n.is_depleted(), "'%s' abbaubar -> %s" % [p, n.item_id])
		_check(_actions.has(&"gather"), "action_performed(gather) bei '%s'" % p)
	var bush: ResourceNode = _first_node("branch_bush")
	_jump_to_day(TimeManager.day + bush.regrow_days)
	_check(not bush.is_depleted(), "Ast-Busch wächst nach")

	# Jahreszeitliche Verfügbarkeit
	var berries: ResourceNode = _first_node("berry_bush")
	var mush: ResourceNode = _first_node("mushroom")
	var grain: ResourceNode = _first_node("wild_grain")
	var nettle: ResourceNode = _first_node("nettle")
	_jump_to_day(1)  # Frühling
	_check(not berries.is_available() and berries._sprite.texture == berries.texture_off_season, "Beeren im Frühling nicht verfügbar (kahler Busch)")
	_check(nettle.is_available(), "Brennnesseln im Frühling verfügbar")
	_jump_to_day(29)  # Sommer, Tag 1
	_check(berries.is_available(), "Beeren im Sommer verfügbar")
	_check(not grain.is_available(), "Wildgetreide Frühsommer noch nicht reif")
	_jump_to_day(29 + 20)  # Spätsommer
	_check(grain.is_available(), "Wildgetreide im Spätsommer reif")
	_check(not mush.is_available(), "Pilze im Sommer nicht verfügbar")
	_jump_to_day(57 + 3)  # Herbst
	_check(mush.is_available() and berries.is_available(), "Pilze und Beeren im Herbst verfügbar")
	var before_m: int = Inventory.count(&"mushroom")
	mush._interactable.interact(_player)
	_check(Inventory.count(&"mushroom") > before_m, "Pilze sammelbar (Herbst)")
	_jump_to_day(85 + 3)  # Winter
	_check(not berries.is_available() and not mush.is_available() and not grain.is_available(), "Winter: keine Beeren/Pilze/Getreide")
	_check(not nettle.is_available(), "Winter: keine Brennnesseln")

	# Malachit erst nach Entdeckung sichtbar
	_jump_to_day(1)
	var mal: ResourceNode = _first_node("malachite")
	_check(not mal.visible and not mal.is_available(), "Malachit unsichtbar ohne Entdeckung 'kiln'")
	Discoveries.unlock(&"kiln")
	_check(mal.visible and mal.is_available(), "Malachit sichtbar nach 'kiln'")
	var before_mal: int = Inventory.count(&"malachite")
	mal._interactable.interact(_player)
	_check(Inventory.count(&"malachite") == before_mal + 1, "Malachit abbaubar")
	_jump_to_day(1000)
	_check(mal.is_depleted(), "Malachit wächst nie nach")

	# Bernstein am Ufer
	var amber: ResourceNode = _first_node("amber")
	_check(_world.get_terrain_at(amber.position) == Biome.Terrain.BANK, "Bernstein liegt am Ufer")
	var rare_seen: Array[StringName] = []
	EventBus.rare_find.connect(func(i: StringName, _p: Vector2) -> void: rare_seen.append(i))
	_jump_to_day(1)
	amber._interactable.interact(_player)
	_check(rare_seen.has(&"amber") and Inventory.count(&"amber") >= 1, "Bernstein: rare_find + Item")
	# Ton nur an der Flussaue, Feuerstein/Malachit im Fels
	var clay: ResourceNode = _first_node("clay")
	_check(_world._water_dist[_world._index(_world.world_to_cell(clay.position))] <= 4, "Tonstelle nahe am Wasser")
	_check(_world.get_biome_at(_first_node("flint").position) == Biome.Terrain.ROCK, "Feuerstein im Felsgebiet")


func _test_drink() -> void:
	var spots: Array = _world._nodes_by_id.keys().filter(func(k: String) -> bool: return k.begins_with("drink@"))
	_check(spots.size() >= 3, "Trinkstellen am Ufer (%d)" % spots.size())
	var spot: DrinkSpot = _world.get_node_by_id(spots[0]) as DrinkSpot
	PlayerStats.modify(&"thirst", -60.0)
	var before: float = PlayerStats.get_value(&"thirst")
	spot._interactable.interact(_player)
	_check(PlayerStats.get_value(&"thirst") > before, "Trinken erhöht Durst-Wert")
	_check(_world.get_terrain_at(spot.position) == Biome.Terrain.BANK, "Trinkstelle liegt am Ufer")


# --- Wildgetreide keimt am Lager ---------------------------------------------------------------
func _test_farming_seeds() -> void:
	_jump_to_day(60)
	GameState.set_camp(Vector2(8, -40))
	GameState.player = _player
	_player.global_position = Vector2(8, 20)   # vor der Höhle, < 6 Tiles vom Lager
	var tries: int = 0
	while _world.get_pending_seed_count() == 0 and tries < 300:
		tries += 1
		EventBus.item_consumed.emit(&"wild_grain")
	_check(_world.get_pending_seed_count() >= 1, "Wildgetreide essen am Lager streut Samen (nach %d Versuchen)" % tries)
	var far: int = _world.get_pending_seed_count()
	_player.global_position = Vector2(600, 300)
	for i in 100:
		EventBus.item_consumed.emit(&"wild_grain")
	_check(_world.get_pending_seed_count() == far, "weit vom Lager: keine Samen")
	_player.global_position = Vector2(8, 20)
	_world.notify_item_on_ground(&"wild_grain", Vector2(8, 24))
	_check(_world.get_pending_seed_count() == far + 1, "Getreide am Boden nahe dem Lager wird vorgemerkt")
	# Im selben Frühling keimen frische Samen nicht ...
	_actions.clear()
	_jump_to_day(113)   # Jahr 2, Frühling Tag 1; Samen sind aus Jahr 1
	# ... die aus dem Vorjahr schon
	_check(_actions.has(&"seed_sprouted_at_camp"), "Samen keimen im nächsten Frühling (seed_sprouted_at_camp)")
	_check(_world.get_pending_seed_count() == 0, "gekeimte Samen sind verbraucht")
	var sprouts: int = _world._dynamic.get_children().filter(func(n: Node) -> bool: return n is ResourceNode).size()
	_check(sprouts >= 1, "Wildgetreide-Busch am Lager gewachsen (%d)" % sprouts)
	# frischer Same im Frühling darf nicht sofort keimen
	_world.scatter_grain_seed(Vector2(8, 24))
	_jump_to_day(113)
	_check(_world.get_pending_seed_count() == 1, "Same aus laufendem Frühling keimt erst im nächsten")
	_world._grain_seeds.clear()


func _test_field_plot() -> void:
	_jump_to_day(140)
	_world._weather.current = &"clear"
	var plot: FieldPlot = FIELD_SCENE.instantiate()
	plot.position = Vector2(8, 100)
	_world._dynamic.add_child(plot)
	plot._interactable.interact(_player)
	_check(plot.state == FieldPlot.State.UNTILLED, "Acker ohne Entdeckung 'agriculture' inaktiv")
	Discoveries.unlock(&"agriculture")
	plot._on_interacted(_player)
	_check(plot.state == FieldPlot.State.UNTILLED or Inventory.has_item(&"hand_axe"), "ohne Werkzeug kein Hacken")
	Inventory.add_item(&"hand_axe", 1)
	plot._on_interacted(_player)
	_check(plot.state == FieldPlot.State.TILLED, "Hacken -> gehackter Boden")
	Inventory.add_item(&"wild_grain", 1)
	_actions.clear()
	plot._on_interacted(_player)
	_check(plot.state == FieldPlot.State.GROWING and _actions.has(&"plant_seed"), "Säen -> plant_seed")
	# trockene Tage: kein Wachstum
	EventBus.day_ended.emit(1)
	_check(plot.growth == 0, "ohne Wasser kein Wachstum (aber keine Verluste)")
	Inventory.add_item(&"fired_pottery", 1)
	plot._on_interacted(_player)   # gießen
	_check(plot.watered, "Gießen mit Gefäß")
	EventBus.day_ended.emit(2)
	_check(plot.growth == 1 and not plot.watered, "Wachstum nach bewässertem Tag")
	_world._weather.current = &"rain"
	for d in FieldPlot.GROW_DAYS:
		EventBus.day_ended.emit(3 + d)
	_check(plot.state == FieldPlot.State.RIPE, "Regen bewässert; Pflanze reif nach %d Tagen" % FieldPlot.GROW_DAYS)
	_world._weather.current = &"clear"
	var before: int = Inventory.count(&"wild_grain")
	plot._on_interacted(_player)
	_check(Inventory.count(&"wild_grain") >= before + 4 and plot.state == FieldPlot.State.TILLED, "Ernte liefert Wildgetreide, Parzelle bleibt gehackt")
	# Speichern erhält Feld
	plot.state = FieldPlot.State.GROWING
	plot.growth = 3
	var data: Dictionary = _world.get_save_data()
	_check((data["fields"] as Array).size() == 1, "Acker im Speicherstand")
	plot.queue_free()


func _test_visuals_and_rare() -> void:
	var tints: Array[Color] = []
	var snow: Array[float] = []
	for s in 4:
		_world._apply_season(s, false)
		tints.append(_world._ground.modulate)
		snow.append(_world._snow.modulate.a)
	_check(tints[0] != tints[1] and tints[1] != tints[2] and tints[2] != tints[3], "Bodenfarbe unterscheidet sich je Jahreszeit")
	_check(snow[0] == 0.0 and snow[3] == 1.0, "Schnee nur im Winter")
	# Laubbaum-Färbung
	var dec: ResourceNode = null
	for n in _world.get_resource_nodes():
		if n.foliage == ResourceNode.Foliage.DECIDUOUS and n.node_id.begins_with("tree@"):
			dec = n
			break
	_jump_to_day(57 + 3)
	var autumn: Color = dec._sprite.modulate
	_jump_to_day(29 + 3)
	_check(autumn != dec._sprite.modulate, "Laubbäume ändern die Farbe (Herbst vs. Sommer)")
	# rare_find -> Glitzern
	var before: int = _world._dynamic.get_child_count()
	EventBus.rare_find.emit(&"amber", Vector2(100, 100))
	_check(_world._dynamic.get_child_count() == before + 1, "rare_find löst Glitzer-Effekt aus")


func _test_save_load() -> void:
	_jump_to_day(1)
	_world.generate(31337)
	var hash_a: int = hash(_world._terrain)
	var ids: Array[String] = _ids_with_prefix("stone")
	var n1: ResourceNode = _world.get_node_by_id(ids[0]) as ResourceNode
	var n2: ResourceNode = _world.get_node_by_id(ids[1]) as ResourceNode
	n1._interactable.interact(_player)
	n2._interactable.interact(_player)
	var id1: String = n1.node_id
	var id2: String = n2.node_id
	var regrow1: int = n1.get_regrow_day()
	var sprout_pos: Vector2 = Vector2(8, 30)
	_world._sprouts.append(sprout_pos)
	_world._create_sprout_node(sprout_pos)
	_check(SaveManager.save_game(SLOT), "SaveManager.save_game()")
	_world.generate(1)
	_check(hash(_world._terrain) != hash_a, "andere Welt vor dem Laden")
	_check(SaveManager.load_game(SLOT), "SaveManager.load_game()")
	_check(_world.world_seed == 31337, "Seed nach dem Laden erhalten")
	_check(hash(_world._terrain) == hash_a, "Terrain nach dem Laden identisch")
	var m1: ResourceNode = _world.get_node_by_id(id1) as ResourceNode
	var m2: ResourceNode = _world.get_node_by_id(id2) as ResourceNode
	_check(m1.is_depleted() and m2.is_depleted() and m1.get_regrow_day() == regrow1, "abgebaute Nodes bleiben abgebaut (inkl. Nachwachs-Tag)")
	var untouched: ResourceNode = _world.get_node_by_id(_ids_with_prefix("stone")[2]) as ResourceNode
	_check(not untouched.is_depleted(), "unberührte Nodes bleiben voll")
	_check(_world.get_node_by_id("sprout@8,30") != null, "Keimling nach dem Laden vorhanden")
	SaveManager.delete_save(SLOT)


func _test_weather() -> void:
	_weather_events.clear()
	_jump_to_day(85 + 10)  # Winter
	var seen_snow: bool = false
	for d in range(85, 85 + 28):
		_jump_to_day(d)
		if _world.get_weather() == &"snow":
			seen_snow = true
	_check(seen_snow, "Im Winter schneit es an einigen Tagen")
	_check(not _weather_events.is_empty(), "weather_changed wird emittiert")
	_jump_to_day(30)
	var same: StringName = _world.get_weather()
	_jump_to_day(30)
	_check(same == _world.get_weather(), "Wetter ist pro Tag deterministisch")
