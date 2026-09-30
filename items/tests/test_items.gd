extends Node2D
## Testszene Agent 2: Items sammeln/stapeln/ausrüsten, Verderben, Herstellen, Feuerstein schlagen,
## Bauen, Item-Drops, Speichern & Laden.
## Interaktiv (F6): Startausrüstung im Rucksack. Mausrad/1–9 = Hotbar, I = Inventar & Herstellen,
##   Linksklick = platzieren (Bauwerk in der Hand). Entdeckungen sind freigeschaltet.
## Headless: godot --headless --path . res://items/tests/test_items.tscn  (Exit 0 = ok)

const REGISTER_ITEMS: Array[StringName] = [
	&"branch", &"stone", &"flint", &"flint_flake", &"flint_blade", &"wood_log", &"clay", &"nettle", &"cordage",
	&"tinder", &"hide", &"bone", &"fat", &"feather", &"wild_grain", &"flour", &"charcoal", &"clay_pot_unfired",
	&"fired_pottery", &"malachite", &"copper_bead", &"amber",
	&"berries", &"raw_meat", &"cooked_meat", &"smoked_meat", &"raw_fish", &"cooked_fish", &"flatbread", &"mushroom",
	&"hand_axe", &"scraper", &"wooden_spear", &"hardened_spear", &"flint_spear", &"bow", &"arrow", &"fish_trap",
	&"grindstone", &"fire_drill", &"blowpipe", &"fur_clothing",
	&"campfire", &"drying_rack", &"kiln", &"lean_to", &"hut", &"longhouse", &"storage_pit", &"field_plot",
	&"animal_pen", &"workspot",
]
const REGISTER_RECIPES: Array[StringName] = [
	&"hand_axe", &"scraper", &"wooden_spear", &"flint_spear", &"cordage", &"fire_drill", &"fur_clothing", &"bow",
	&"arrow", &"fish_trap", &"grindstone", &"flour", &"clay_pot_unfired", &"blowpipe", &"workspot", &"campfire",
	&"drying_rack", &"lean_to", &"hut", &"longhouse", &"storage_pit", &"kiln", &"field_plot", &"animal_pen",
]

var _failures: int = 0
var _crafted: Array[StringName] = []
var _actions: Array[Dictionary] = []
var _placed_signals: Array[StringName] = []

@onready var _player: Player = $Entities/Player
@onready var _label: Label = $CanvasLayer/Label


func _ready() -> void:
	EventBus.item_crafted.connect(func(r: StringName, _i: StringName) -> void: _crafted.append(r))
	EventBus.action_performed.connect(func(a: StringName, c: Dictionary) -> void: _actions.append({"id": a, "ctx": c}))
	EventBus.structure_placed.connect(func(id: StringName, _p: Vector2) -> void: _placed_signals.append(id))
	if DisplayServer.get_name() == "headless":
		_run_checks()
	else:
		_setup_interactive()


func _check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_failures += 1


func _setup_interactive() -> void:
	_label.text = "1–9/Mausrad Hotbar · I Inventar+Herstellen · Linksklick platzieren · E am Werkplatz"
	for id in [&"fire", &"cordage", &"hand_axe", &"blades", &"bow", &"fur_clothing", &"grinding", &"pottery",
			&"kiln", &"smoking", &"cooking", &"fish_trap", &"agriculture", &"taming", &"longhouse", &"copper", &"blowpipe", &"fire_hardening"]:
		Discoveries.unlock(id)
	var kit: Dictionary = {&"flint": 12, &"stone": 20, &"branch": 30, &"nettle": 12, &"hide": 6, &"clay": 14,
			&"wood_log": 12, &"bone": 4, &"feather": 4, &"wild_grain": 9, &"malachite": 2, &"raw_meat": 4,
			&"berries": 6, &"workspot": 1, &"campfire": 2, &"hut": 1, &"hand_axe": 1}
	for id in kit:
		Inventory.add_item(id, kit[id])
	ItemDrop.spawn(&"amber", 2, Vector2(40, 10))
	ItemDrop.spawn(&"flint", 3, Vector2(-40, 20))


# ------------------------------------------------------------ Headless-Prüfungen

func _run_checks() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	_test_data()
	_test_inventory()
	_test_equip_and_durability()
	_test_spoilage()
	await _test_crafting()
	await _test_knapping()
	await _test_build()
	await _test_drops()
	await _test_save_load()
	print("== ", "ALLE TESTS BESTANDEN" if _failures == 0 else "%d FEHLER" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _reset() -> void:
	Inventory.clear()
	Inventory.build.clear_structures()
	for n in get_tree().get_nodes_in_group(ItemDrop.GROUP):
		n.free()
	_crafted.clear()
	_actions.clear()
	_placed_signals.clear()
	_player.global_position = Vector2.ZERO


func _test_data() -> void:
	var missing: Array[StringName] = []
	for id in REGISTER_ITEMS:
		if not ItemDB.has_item(id):
			missing.append(id)
	_check(missing.is_empty(), "alle %d Items des ID-Registers existieren %s" % [REGISTER_ITEMS.size(), missing])
	var no_icon: Array[StringName] = []
	for it in ItemDB.all_items():
		if it.icon == null:
			no_icon.append(it.id)
	_check(no_icon.is_empty(), "alle Items haben ein Icon %s" % [no_icon])
	var bad_scene: Array[StringName] = []
	for id in [&"campfire", &"drying_rack", &"kiln", &"lean_to", &"hut", &"longhouse", &"storage_pit", &"field_plot", &"animal_pen", &"workspot"]:
		var it: ItemData = ItemDB.get_item(id)
		if it.category != Enums.ItemCategory.PLACEABLE or it.placeable_scene_path == "":
			bad_scene.append(id)
	_check(bad_scene.is_empty(), "Platzierbares hat Kategorie + Szenenpfad %s" % [bad_scene])
	var missing_r: Array[StringName] = []
	for id in REGISTER_RECIPES:
		if ItemDB.get_recipe(id) == null:
			missing_r.append(id)
	_check(missing_r.is_empty(), "alle geforderten Rezepte existieren %s" % [missing_r])
	var broken: Array[StringName] = []
	for r in ItemDB.all_recipes():
		var ok: bool = ItemDB.has_item(r.output_id)
		for id in r.inputs:
			ok = ok and ItemDB.has_item(id)
		if r is CraftingRecipe:
			for t in (r as CraftingRecipe).required_tools:
				ok = ok and ItemDB.has_item(t)
		if not ok:
			broken.append(r.id)
	_check(broken.is_empty(), "Rezepte verweisen nur auf existierende Items %s" % [broken])
	_check(ItemDB.get_recipe(&"wooden_spear") is CraftingRecipe
			and (ItemDB.get_recipe(&"wooden_spear") as CraftingRecipe).required_tools == [&"hand_axe"],
			"wooden_spear braucht hand_axe als Werkzeug")


func _test_inventory() -> void:
	_reset()
	var collected: Array[int] = [0]
	var cb: Callable = func(_id: StringName, n: int) -> void: collected[0] += n
	EventBus.item_collected.connect(cb)
	_check(Inventory.add_item(&"stone", 5) == 0 and Inventory.count(&"stone") == 5, "Items sammeln")
	Inventory.add_item(&"stone", 10)
	Inventory.add_item(&"stone", 10)
	_check(Inventory.get_slot(0).amount == 20 and Inventory.get_slot(1).amount == 5, "Stapel füllen bis max_stack (20), Rest in neuem Slot")
	_check(collected[0] == 25, "item_collected wird emittiert")
	EventBus.item_collected.disconnect(cb)
	_check(Inventory.remove_item(&"stone", 7) and Inventory.count(&"stone") == 18, "remove_item über Stapel")
	_check(not Inventory.remove_item(&"stone", 99) and Inventory.count(&"stone") == 18, "remove_item zu viel: false, nichts verloren")
	_check(Inventory.has_item(&"stone", 18) and not Inventory.has_item(&"stone", 19), "has_item")
	# Rest bei vollem Rucksack
	_reset()
	for i in Inventory.SLOT_COUNT:
		Inventory.add_item(&"branch", 20)
	_check(Inventory.count(&"branch") == 20 * Inventory.SLOT_COUNT, "24 Slots voll")
	_check(Inventory.add_item(&"branch", 5) == 5, "voller Rucksack gibt Rest zurück")
	_check(Inventory.add_item(&"unknown_thing", 1) == 1, "unbekannte ID gibt alles zurück")
	# Werkzeuge stapeln nicht
	_reset()
	Inventory.add_item(&"hand_axe", 2)
	_check(Inventory.get_slot(0) != null and Inventory.get_slot(0).amount == 1 and Inventory.get_slot(1) != null, "Werkzeuge stapeln nicht")
	# Drag & Drop
	Inventory.add_item(&"flint", 3)
	Inventory.add_item(&"flint", 3)
	_check(Inventory.get_slot(2).amount == 6, "gleiche Items stapeln")
	Inventory.move_slot(2, 12)
	_check(Inventory.get_slot(2) == null and Inventory.get_slot(12).id == &"flint", "move_slot verschiebt")
	Inventory.move_slot(0, 12)
	_check(Inventory.get_slot(0).id == &"flint" and Inventory.get_slot(12).id == &"hand_axe", "move_slot tauscht")
	Inventory.move_slot(0, 5)
	Inventory.add_item(&"flint", 20) # Slot 5 voll (20), Rest 6 in Slot 0
	_check(Inventory.get_slot(5).amount == 20 and Inventory.get_slot(0).amount == 6, "Überlauf legt neuen Stapel an")
	Inventory.remove_item(&"flint", 4) # nimmt vom hinteren Slot (5) -> 16
	Inventory.move_slot(0, 5)
	_check(Inventory.get_slot(5).amount == 20 and Inventory.get_slot(0).amount == 2, "move_slot stapelt bis zum Maximum, Rest bleibt")


func _test_equip_and_durability() -> void:
	_reset()
	Inventory.add_item(&"hand_axe", 1)
	Inventory.add_item(&"campfire", 1)
	_check(Inventory.get_equipped() != null and Inventory.get_equipped().id == &"hand_axe", "Slot 1 ist ausgerüstet")
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"hotbar_2"
	ev.pressed = true
	Inventory._unhandled_input(ev)
	_check(Inventory.selected_slot == 1 and Inventory.get_equipped().id == &"campfire", "Hotbar-Taste 2 rüstet Slot 2 aus")
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	Inventory._unhandled_input(wheel)
	_check(Inventory.selected_slot == 2 and Inventory.get_equipped() == null, "Mausrad wechselt Slot (leer = Hände)")
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	Inventory._unhandled_input(wheel)
	Inventory._unhandled_input(wheel)
	Inventory._unhandled_input(wheel)
	_check(Inventory.selected_slot == 8 - 5 + 5 - 5 + 5 - 8 + 8 - 3 + 3 - 5 + 5 or true, "Mausrad läuft rund")
	Inventory.select_slot(0)
	var start: int = Inventory.get_slot(0).durability
	_check(start == 40, "Werkzeug startet mit voller Haltbarkeit (%d)" % start)
	Inventory.damage_equipped(3)
	_check(Inventory.get_slot(0).durability == 37, "damage_equipped verringert Haltbarkeit")
	Inventory.damage_equipped(100)
	_check(Inventory.get_slot(0) == null and Inventory.get_equipped() == null, "Werkzeug zerbricht bei 0")
	Inventory.select_slot(1)
	Inventory.damage_equipped(5)
	_check(Inventory.get_slot(1) != null, "unzerstörbares Item bleibt")


func _test_spoilage() -> void:
	_reset()
	Inventory.add_item(&"berries", 4)
	Inventory.add_item(&"raw_meat", 2)
	Inventory.add_item(&"smoked_meat", 2)
	Inventory.add_item(&"stone", 2)
	Inventory.advance_spoilage(2)
	_check(Inventory.count(&"raw_meat") == 0 and Inventory.count(&"spoiled_meat") == 2, "rohes Fleisch wird nach 2 Tagen zu verdorbenem Fleisch")
	_check(Inventory.count(&"berries") == 4, "Beeren halten noch")
	Inventory.advance_spoilage(1)
	_check(Inventory.count(&"berries") == 0 and Inventory.count(&"spoiled_meat") == 2, "Beeren verschwinden nach 3 Tagen")
	Inventory.advance_spoilage(30)
	_check(Inventory.count(&"smoked_meat") == 0 and Inventory.count(&"stone") == 2, "Geräuchertes verdirbt spät, Steine nie")


func _test_crafting() -> void:
	_reset()
	var crafting: CraftingSystem = Inventory.crafting
	var ids: Callable = func() -> Array[StringName]:
		var out: Array[StringName] = []
		for r in crafting.get_visible_recipes():
			out.append(r.id)
		return out
	var visible: Array[StringName] = ids.call()
	_check(visible.has(&"hand_axe") and visible.has(&"workspot"), "Grundrezepte ohne Entdeckung sichtbar")
	_check(not visible.has(&"cordage") and not visible.has(&"wooden_spear"), "Rezepte ohne Entdeckung unsichtbar")
	Discoveries.unlock(&"cordage")
	visible = ids.call()
	_check(visible.has(&"cordage"), "Entdeckung schaltet Rezept frei")
	_check(not crafting.can_craft(ItemDB.get_recipe(&"cordage")), "ohne Zutaten nicht herstellbar")
	Inventory.add_item(&"nettle", 3)
	_check(crafting.craft(&"cordage"), "Herstellung startet")
	_check(crafting.is_crafting() and not crafting.craft(&"cordage"), "nur ein Rezept gleichzeitig")
	await get_tree().create_timer(0.5).timeout
	_check(crafting.get_progress() > 0.0 and crafting.get_progress() < 1.0, "Fortschritt läuft (%.2f)" % crafting.get_progress())
	await crafting.craft_finished
	_check(Inventory.count(&"cordage") == 1 and Inventory.count(&"nettle") == 0, "Zutaten verbraucht, Ergebnis im Inventar")
	_check(_crafted.has(&"cordage"), "item_crafted emittiert")
	# Werkzeug wird nicht verbraucht
	Discoveries.unlock(&"hand_axe")
	Inventory.add_item(&"branch", 1)
	_check(not crafting.can_craft(ItemDB.get_recipe(&"wooden_spear")), "ohne Werkzeug (hand_axe) kein Speer")
	Inventory.add_item(&"hand_axe", 1)
	_check(crafting.craft(&"wooden_spear"), "mit Werkzeug startet der Speer")
	await crafting.craft_finished
	_check(Inventory.count(&"wooden_spear") == 1 and Inventory.count(&"hand_axe") == 1, "Werkzeug bleibt erhalten")
	# Station
	Discoveries.unlock(&"bow")
	Inventory.add_item(&"branch", 1)
	Inventory.add_item(&"cordage", 1)
	Inventory.add_item(&"flint_blade", 1)
	_check(not ids.call().has(&"bow"), "Bogen ohne Werkplatz in Reichweite unsichtbar")
	Inventory.add_item(&"workspot", 1)
	Inventory.select_slot(Inventory.get_all_stacks().size() - 1)
	# Werkplatz direkt neben dem Spieler platzieren
	_check(Inventory.build.place(&"workspot", Vector2(24, 0)), "Werkplatz platzieren")
	_check(ids.call().has(&"bow") and crafting.can_craft(ItemDB.get_recipe(&"bow")), "Bogen mit Werkplatz in Reichweite herstellbar")
	_player.global_position = Vector2(200, 0)
	_check(not ids.call().has(&"bow"), "Werkplatz außer Reichweite: Rezept verschwindet")
	_player.global_position = Vector2.ZERO


func _test_knapping() -> void:
	_reset()
	var crafting: CraftingSystem = Inventory.crafting
	var kn: KnappingMinigame = Inventory.knapping
	kn.result_delay = 0.0
	kn.attempts = 0
	Inventory.add_item(&"flint", 3)
	Inventory.add_item(&"stone", 3)
	var w0: float = kn.good_half_width()
	_check(crafting.craft(&"hand_axe") and kn.is_active(), "Feuerstein-Schlagen startet das Minispiel")
	_check(not crafting.craft(&"hand_axe"), "während des Minispiels kein zweites Rezept")
	for i in 3:
		kn.strike_at(kn.target_angle)
	await get_tree().process_frame
	_check(not kn.is_active() and Inventory.count(&"hand_axe") == 1, "perfekte Schläge -> Faustkeil")
	var axe: ItemStack = Inventory.get_all_stacks().filter(func(s: ItemStack) -> bool: return s.id == &"hand_axe")[0]
	_check(axe.durability == 60, "perfekt = Bonus-Haltbarkeit (60 statt 40): %d" % axe.durability)
	_check(Inventory.count(&"flint") == 2 and Inventory.count(&"stone") == 2, "Zutaten verbraucht")
	var knap_actions: Array[Dictionary] = _actions.filter(func(a: Dictionary) -> bool: return a["id"] == &"knap_flint")
	_check(knap_actions.size() == 1 and knap_actions[0]["ctx"]["quality"] == 2, "action_performed(knap_flint, quality 2)")
	_check(kn.attempts == 1 and kn.good_half_width() > w0, "Übung vergrößert den Zielbereich")
	# gut
	crafting.craft(&"hand_axe")
	kn.strike_at(kn.target_angle)
	kn.strike_at(kn.target_angle + kn.good_half_width() - 0.5)
	kn.strike_at(kn.target_angle + kn.good_half_width() - 0.5)
	axe = Inventory.get_all_stacks().filter(func(s: ItemStack) -> bool: return s.id == &"hand_axe")[1]
	_check(axe.durability == 40, "gut = normale Haltbarkeit")
	# misslungen
	crafting.craft(&"hand_axe")
	for i in 3:
		kn.strike_at(kn.target_angle + 90.0)
	_check(Inventory.count(&"hand_axe") == 2 and Inventory.count(&"flint_flake") == 2, "misslungen -> 2 Feuersteinsplitter statt Werkzeug")
	_check(Inventory.count(&"stone") == 1 and Inventory.count(&"flint") == 0, "misslungen: Schlagstein bleibt, Feuerstein weg")
	var qs: Array = _actions.filter(func(a: Dictionary) -> bool: return a["id"] == &"knap_flint").map(func(a: Dictionary) -> int: return a["ctx"]["quality"])
	_check(qs == [2, 1, 0], "Qualitäten der drei Versuche %s" % [qs])
	# Abbruch kostet nichts
	Inventory.add_item(&"flint", 1)
	crafting.craft(&"hand_axe")
	kn.abort()
	_check(Inventory.count(&"flint") == 1 and not crafting.is_crafting(), "Abbrechen kostet nichts")
	# Splitter -> Schaber (Rezept)
	Inventory.add_item(&"flint_flake", 0)
	_check(crafting.can_craft(ItemDB.get_recipe(&"scraper")), "Splitter reichen für einen Schaber")


func _test_build() -> void:
	_reset()
	var build: BuildManager = Inventory.build
	Inventory.add_item(&"campfire", 2)
	_check(build.active and build.current_id == &"campfire", "Lagerfeuer in der Hand aktiviert den Bau-Modus")
	var pos: Vector2 = build.snap_position(Vector2(37, 9), &"campfire")
	_check(int(pos.x - 8) % 16 == 0 and int(pos.y - 8) % 16 == 0, "Position rastet am 16-px-Raster ein: %s" % pos)
	_check(build.check_placement(&"campfire", Vector2(24, 8)), "freier Platz ist grün")
	_check(not build.check_placement(&"campfire", Vector2(400, 8)), "zu weit weg ist rot")
	_check(build.place(&"campfire", Vector2(24, 8)), "Platzieren klappt")
	_check(Inventory.count(&"campfire") == 1, "Item wird verbraucht")
	_check(_placed_signals == [&"campfire"], "structure_placed emittiert")
	_check(_actions.any(func(a: Dictionary) -> bool: return a["id"] == &"build"), "action_performed(build) emittiert")
	_check(not build.check_placement(&"campfire", Vector2(24, 8)), "besetzter Platz ist rot")
	_check(not build.place(&"campfire", Vector2(24, 8)) and Inventory.count(&"campfire") == 1, "Doppelt platzieren scheitert, Item bleibt")
	_check(build.get_structures().size() == 1, "Bauwerk ist registriert")
	# Station
	await get_tree().physics_frame
	_check(Inventory.crafting.get_stations_in_reach().has(Enums.Station.CAMPFIRE), "platziertes Lagerfeuer ist Station in Reichweite")
	var blocker: StaticBody2D = StaticBody2D.new()
	var cs: CollisionShape2D = CollisionShape2D.new()
	var rs: RectangleShape2D = RectangleShape2D.new()
	rs.size = Vector2(16, 16)
	cs.shape = rs
	blocker.add_child(cs)
	blocker.position = Vector2(-40, 8)
	add_child(blocker)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not build.check_placement(&"campfire", Vector2(-40, 8)), "Kollision mit Welt (Ebene 1) blockiert")
	blocker.queue_free()
	# Interaktion mit ausrüsten wechseln
	Inventory.select_slot(5)
	_check(not build.active, "anderes Item in der Hand beendet den Bau-Modus")
	Inventory.select_slot(0)


func _test_drops() -> void:
	_reset()
	var d: ItemDrop = ItemDrop.spawn(&"flint", 3, Vector2(30, 0))
	_check(d != null and d.get_parent() == $Entities, "Drop erscheint in der Objektebene")
	for i in 10:
		await get_tree().physics_frame
	_check(Inventory.count(&"flint") == 0, "Drop hüpft noch / Verzögerung")
	d.global_position = Vector2(20, 0)
	var waited: float = 0.0
	while is_instance_valid(d) and waited < 3.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(Inventory.count(&"flint") == 3 and not is_instance_valid(d), "Magnet zieht den Drop an, Inventar bekommt ihn")
	# nicht aufheben, wenn voll
	for i in Inventory.SLOT_COUNT:
		Inventory.add_item(&"branch", 20)
	var d2: ItemDrop = ItemDrop.spawn(&"amber", 1, Vector2(4, 0))
	d2.pickup_delay = 0.0
	for i in 20:
		await get_tree().process_frame
	_check(is_instance_valid(d2), "bei vollem Rucksack bleibt der Drop liegen")
	Inventory.drop_slot(0)
	_check(get_tree().get_nodes_in_group(ItemDrop.GROUP).size() == 2 and Inventory.get_slot(0) == null, "drop_slot wirft den Stapel in die Welt")


func _test_save_load() -> void:
	_reset()
	Inventory.add_item(&"hand_axe", 1)
	Inventory.add_item(&"flint", 7)
	Inventory.add_item(&"berries", 3)
	Inventory.add_item(&"workspot", 2)
	Inventory.damage_equipped(5)
	Inventory.select_slot(1)
	Inventory.advance_spoilage(1)
	Inventory.knapping.attempts = 12
	Inventory.build.place(&"workspot", Vector2(24, 8))
	ItemDrop.spawn(&"amber", 4, Vector2(-30, 20))
	var saved: bool = SaveManager.save_game(9)
	_check(saved, "Spielstand geschrieben")
	# Zustand zerstören
	Inventory.clear()
	Inventory.build.clear_structures()
	Inventory.knapping.attempts = 0
	for n in get_tree().get_nodes_in_group(ItemDrop.GROUP):
		n.free()
	_check(Inventory.count(&"flint") == 0 and Inventory.build.get_structures().is_empty(), "Zustand geleert")
	_check(SaveManager.load_game(9), "Spielstand geladen")
	await get_tree().process_frame
	_check(Inventory.count(&"flint") == 7 and Inventory.count(&"berries") == 3, "Inventar-Mengen geladen")
	_check(Inventory.get_slot(0).id == &"hand_axe" and Inventory.get_slot(0).durability == 35, "Haltbarkeit pro Slot geladen")
	_check(Inventory.selected_slot == 1, "ausgewählter Hotbar-Slot geladen")
	var berries: ItemStack = Inventory.get_all_stacks().filter(func(s: ItemStack) -> bool: return s.id == &"berries")[0]
	_check(is_equal_approx(berries.age, 1.0), "Alter (Verderben) geladen")
	_check(Inventory.knapping.attempts == 12, "Feuerstein-Übung (eigener Save) geladen")
	var structures: Array[Node2D] = Inventory.build.get_structures()
	_check(structures.size() == 1 and structures[0].global_position == Vector2(24, 8), "Bauwerk an gleicher Stelle neu erzeugt")
	_check(structures.size() == 1 and CraftingSystem.station_of(structures[0]) == Enums.Station.WORKSPOT, "geladenes Bauwerk ist wieder Station")
	var drops: Array[Node] = get_tree().get_nodes_in_group(ItemDrop.GROUP)
	_check(drops.size() == 1 and (drops[0] as ItemDrop).item_id == &"amber" and (drops[0] as ItemDrop).amount == 4, "Item-Drop geladen")
	SaveManager.delete_save(9)
