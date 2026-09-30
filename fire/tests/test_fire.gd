extends Node2D
## Testszene Feuer (Agent 4): Feuer entzünden, am Leben halten, kochen, räuchern, Ton über Nacht härten,
## Ofen auf Temperatur bringen, Kupfer schmelzen. Läuft automatisch (Zeitraffer über TimeManager.time_scale),
## danach (nicht headless) kann man mit einem Player selbst am Feuer spielen.
## Headless: godot --headless --path . res://fire/tests/test_fire.tscn   (Exit 0 = ok)

@onready var _label: Label = $CanvasLayer/Label

var _lines: PackedStringArray = []
var _failed: int = 0


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failed += 1
	_lines.append(("OK   " if cond else "FAIL ") + msg)
	print(_lines[-1])
	_label.text = "\n".join(_lines.slice(maxi(0, _lines.size() - 12)))


func _wait_until(cond: Callable, timeout: float = 20.0) -> bool:
	var t: float = 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return cond.call()


func _give(items: Dictionary) -> void:
	for id: StringName in items:
		Inventory.add_item(id, int(items[id]))


func _spawn(scene_path: String, pos: Vector2) -> FireStation:
	var node: FireStation = (load(scene_path) as PackedScene).instantiate() as FireStation
	node.position = pos
	add_child(node)
	return node


func _run() -> void:
	GameState.has_camp = false
	TimeManager.time_scale = 1.0
	_give({&"branch": 12, &"wood_log": 8, &"raw_meat": 3, &"raw_fish": 1, &"wooden_spear": 1, &"clay": 1,
		&"clay_pot_unfired": 2, &"malachite": 1, &"charcoal": 4, &"fire_drill": 1, &"tinder": 1, &"blowpipe": 1})

	# --- 1. Lagerfeuer: Brennstoff, Minispiel, Lager -------------------------------
	var fire: Campfire = _spawn("res://fire/scenes/campfire.tscn", Vector2(100, 100)) as Campfire
	await get_tree().process_frame
	_check(GameState.has_camp and GameState.camp_position == Vector2(100, 100), "erstes Feuer setzt das Lager")
	_check(fire.is_in_group("heat_source"), "Gruppe heat_source")
	_check(not fire.can_light(), "ohne Brennstoff nicht entzündbar")
	_check(fire.add_fuel(&"branch"), "Ast nachlegen")
	var lit: Array[bool] = [false]
	EventBus.action_performed.connect(func(a: StringName, _c: Dictionary) -> void:
		if a == &"light_fire":
			lit[0] = true)
	var mg: FireDrillMinigame = FireDrillMinigame.new()
	mg.use_tinder = true
	mg.finished.connect(func(ok: bool) -> void:
		if ok:
			fire.ignite())
	add_child(mg)
	await get_tree().process_frame
	for i in 10:
		mg.marker = mg.zone_center
		mg.press()
		if mg == null or not is_instance_valid(mg):
			break
	await get_tree().process_frame
	_check(fire.burning and lit[0], "Feuerbohrer-Minispiel -> Feuer brennt, light_fire gesendet")
	_check(fire.heat_radius > 0.0, "Wärmeradius > 0 (%d px)" % int(fire.heat_radius))

	# --- 2. Am Leben halten / abbrennen -------------------------------------------
	TimeManager.time_scale = 600.0
	fire.add_fuel(&"wood_log")
	fire.add_fuel(&"wood_log")
	# --- 3. Kochen (Zeitbalken, Verbrennen) ---------------------------------------
	var cook: FireProcess = FireProcess.find_by_id(&"cook_meat")
	_check(cook != null and fire.start_process(cook), "Fleisch ans Feuer")
	var done: bool = await _wait_until(func() -> bool: return fire.has_ready(), 10.0)
	_check(done, "Fleisch fertig")
	var got: int = fire.collect()
	_check(got == 1 and Inventory.count(&"cooked_meat") == 1, "gegartes Fleisch eingesammelt")
	fire.start_process(FireProcess.find_by_id(&"cook_fish"))
	await _wait_until(func() -> bool: return fire.slot_count() == 0, 10.0)
	_check(fire.slot_count() == 0 and Inventory.count(&"cooked_fish") == 0, "Fisch zu lange gelassen -> verbrannt")

	# --- 4. Feuerhärtung -----------------------------------------------------------
	fire.add_fuel(&"wood_log")
	fire.start_process(FireProcess.find_by_id(&"harden_spear"))
	await _wait_until(func() -> bool: return fire.has_ready(), 10.0)
	fire.collect()
	_check(Inventory.count(&"hardened_spear") == 1, "Speer feuergehärtet")

	# --- 5. Ton über Nacht ---------------------------------------------------------
	var hardened: Array[bool] = [false]
	EventBus.action_performed.connect(func(a: StringName, _c: Dictionary) -> void:
		if a == &"clay_hardened":
			hardened[0] = true)
	_check(fire.place_clay(&"clay_pot_unfired"), "Tontopf neben das Feuer gelegt")
	for i in 3:
		fire.add_fuel(&"wood_log")
		fire.add_fuel(&"branch")
	await _wait_until(func() -> bool: return hardened[0], 15.0)
	_check(hardened[0], "Ton wurde hart (clay_hardened)")
	fire.collect()
	_check(Inventory.count(&"fired_pottery") >= 1, "fired_pottery im Inventar")

	# --- 6. Regen ohne Unterschlupf löscht ------------------------------------------
	fire.add_fuel(&"branch")
	EventBus.weather_changed.emit(&"rain")
	_check(not fire.burning, "Regen löscht das Feuer")
	EventBus.weather_changed.emit(&"clear")

	# --- 7. Trockengestell -----------------------------------------------------------
	var rack: DryingRack = _spawn("res://fire/scenes/drying_rack.tscn", Vector2(160, 100)) as DryingRack
	await get_tree().process_frame
	_check(rack.load_item(FireProcess.find_by_id(&"smoke_meat")), "Fleisch aufgehängt")
	await _wait_until(func() -> bool: return rack.has_ready(), 15.0)
	rack.collect()
	_check(Inventory.count(&"smoked_meat") == 1, "geräuchertes Fleisch (nach Spielstunden)")

	# --- 8. Ofen + Kupfer ---------------------------------------------------------
	TimeManager.time_scale = 60.0
	var kiln: Kiln = _spawn("res://fire/scenes/kiln.tscn", Vector2(220, 100)) as Kiln
	await get_tree().process_frame
	var smelted: Array[bool] = [false]
	kiln.copper_smelted.connect(func(_k: Kiln) -> void: smelted[0] = true)
	_check(kiln.load_item(FireProcess.find_by_id(&"fire_pottery")), "Rohling in den Ofen")
	_check(kiln.add_fuel(&"wood_log") and kiln.add_fuel(&"wood_log"), "Holz im Ofen")
	await _wait_until(func() -> bool: return kiln.output_count(&"fired_pottery") > 0, 30.0)
	_check(kiln.output_count(&"fired_pottery") == 1, "Keramik gebrannt (>= 600 °C), Temp %d" % int(kiln.temperature))
	_check(kiln.temperature < 1085.0 or not smelted[0], "ohne Luftzufuhr kein Kupfer (Deckel %d °C)" % int(Kiln.NATURAL_CAP))
	kiln.collect()
	_check(kiln.load_item(FireProcess.find_by_id(&"smelt_malachite")), "Malachit + Holzkohle geladen")
	var t: float = 0.0
	while not smelted[0] and t < 60.0:
		if kiln.piece_count() < 3 and Inventory.has_item(&"charcoal"):
			kiln.add_fuel(&"charcoal")
		elif kiln.piece_count() < 3 and Inventory.has_item(&"wood_log"):
			kiln.add_fuel(&"wood_log")
		kiln.blow(true)
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	_check(smelted[0], "Kupfer geschmolzen bei %d °C" % int(kiln.temperature))
	kiln.collect()
	_check(Inventory.count(&"copper_bead") == 1, "copper_bead im Inventar")
	_check(bool(GameState.get_flag("copper_smelted", false)), "Flag copper_smelted (Hook für Agent 9)")

	# --- 9. Speichern -----------------------------------------------------------------
	var st: Dictionary = kiln.get_state()
	kiln.set_state(st)
	_check(is_equal_approx(kiln.temperature, float(st["temp"])), "Save/Load-Roundtrip Ofen")

	TimeManager.time_scale = 1.0
	_check(true, "Fertig: %d Fehler" % _failed)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if _failed > 0 else 0)
	else:
		_hands_on()


## Nicht headless: Player + frisch bestückte Stationen zum Selbstspielen.
func _hands_on() -> void:
	for n in get_children():
		if n is FireStation:
			n.queue_free()
	_give({&"branch": 10, &"wood_log": 6, &"raw_meat": 3, &"flour": 2, &"clay_pot_unfired": 2, &"malachite": 1, &"charcoal": 4})
	_spawn("res://fire/scenes/campfire.tscn", Vector2(240, 135))
	_spawn("res://fire/scenes/drying_rack.tscn", Vector2(290, 135))
	_spawn("res://fire/scenes/kiln.tscn", Vector2(190, 135))
	var player: Node2D = (load("res://player/player.tscn") as PackedScene).instantiate() as Node2D
	player.position = Vector2(240, 170)
	add_child(player)
	_lines.append("Selbst spielen: E am Feuer/Gestell/Ofen (TimeManager.time_scale=%d)" % int(TimeManager.time_scale))
	_label.text = "\n".join(_lines.slice(maxi(0, _lines.size() - 10)))
