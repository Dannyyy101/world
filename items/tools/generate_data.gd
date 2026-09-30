extends SceneTree
## Erzeugt ItemData-/Rezept-/Struktur-.tres und die 16x16-Platzhalter-Icons.
## Aufruf (Icons zuerst, dann importieren, dann Daten):
##   godot --headless --path . --script res://items/tools/generate_data.gd -- icons
##   godot --headless --path . --import
##   godot --headless --path . --script res://items/tools/generate_data.gd -- data
## Ohne Argument: beides. Änderungen an Werten bitte HIER machen und neu generieren.

const ICON_DIR: String = "res://items/art/placeholder"
const ITEM_DIR: String = "res://items/data"
const RECIPE_DIR: String = "res://items/recipes"
const STRUCT_DIR: String = "res://items/structures"

const M: Enums.ItemCategory = Enums.ItemCategory.MATERIAL
const F: Enums.ItemCategory = Enums.ItemCategory.FOOD
const T: Enums.ItemCategory = Enums.ItemCategory.TOOL
const W: Enums.ItemCategory = Enums.ItemCategory.WEAPON
const C: Enums.ItemCategory = Enums.ItemCategory.CLOTHING
const P: Enums.ItemCategory = Enums.ItemCategory.PLACEABLE
const S: Enums.ItemCategory = Enums.ItemCategory.SPECIAL

const NO: Enums.ToolType = Enums.ToolType.NONE
const AXE: Enums.ToolType = Enums.ToolType.AXE
const SPEAR: Enums.ToolType = Enums.ToolType.SPEAR
const KNIFE: Enums.ToolType = Enums.ToolType.KNIFE
const BOW: Enums.ToolType = Enums.ToolType.BOW
const FISH: Enums.ToolType = Enums.ToolType.FISHING

const HAND: Enums.Station = Enums.Station.HAND
const CAMPFIRE: Enums.Station = Enums.Station.CAMPFIRE
const WORKSPOT: Enums.Station = Enums.Station.WORKSPOT
const RACK: Enums.Station = Enums.Station.DRYING_RACK
const KILN: Enums.Station = Enums.Station.KILN

## Items: id -> {name, desc, cat, stack, tool, power, dur, nutr, hydr, warm, spoil, scene, icon:[shape, farbe1, farbe2]}
var ITEMS: Array[Dictionary] = [
	# --- Material ---
	_i(&"branch", "Ast", "Ein trockener Ast. Für fast alles brauchbar.", M, 20, {"icon": ["stick", "8a5a2b", "5c3a1a"]}),
	_i(&"stone", "Stein", "Ein handlicher Stein.", M, 20, {"icon": ["blob", "9a9a9a", "6a6a6a"]}),
	_i(&"flint", "Feuerstein", "Dunkler Knollen. Bricht scharfkantig, wenn man ihn richtig schlägt.", M, 20, {"icon": ["chunk", "5a6470", "343c46"]}),
	_i(&"flint_flake", "Feuersteinsplitter", "Ein scharfer Abschlag. Schneidet, auch wenn der Schlag misslang.", M, 30, {"icon": ["shard", "aab4be", "6a7480"]}),
	_i(&"flint_blade", "Feuersteinklinge", "Lange, dünne Klinge – sehr scharf.", M, 20, {"icon": ["blade", "c8d2dc", "6a7480"]}),
	_i(&"wood_log", "Holzstamm", "Schwer, aber solide.", M, 10, {"icon": ["log", "7a4a22", "c89a5a"]}),
	_i(&"clay", "Ton", "Feuchter, formbarer Lehm.", M, 20, {"icon": ["blob", "b8703a", "8a4e24"]}),
	_i(&"nettle", "Brennnessel", "Brennt auf der Haut, doch die Fasern sind zäh.", M, 30, {"icon": ["leaf", "4a9a3a", "2a6a22"]}),
	_i(&"cordage", "Schnur", "Aus Pflanzenfasern gedrehte Schnur.", M, 20, {"icon": ["coil", "c8a86a", "8a6a3a"]}),
	_i(&"tinder", "Zunder", "Trockenes Gras und Rinde. Fängt schnell Funken.", M, 30, {"icon": ["tuft", "d8c878", "a89848"]}),
	_i(&"hide", "Fell", "Ein rohes Tierfell.", M, 10, {"icon": ["hide", "a06a3a", "6a4222"]}),
	_i(&"bone", "Knochen", "Stabil und leicht zu bearbeiten.", M, 20, {"icon": ["bone", "e8e0c8", "a89e80"]}),
	_i(&"fat", "Fett", "Brennt lange und hält Wasser ab.", M, 20, {"icon": ["drop", "f0e0a0", "c8b070"]}),
	_i(&"feather", "Feder", "Leicht und gerade – gut für Pfeile.", M, 30, {"icon": ["feather", "e8e8e8", "8a8a9a"]}),
	_i(&"wild_grain", "Wildgetreide", "Kleine, nahrhafte Körner.", M, 40, {"icon": ["tuft", "e0b040", "a07820"]}),
	_i(&"flour", "Mehl", "Zwischen Steinen zerrieben.", M, 40, {"spoil": 30, "icon": ["sack", "f0ece0", "b8b0a0"]}),
	_i(&"charcoal", "Holzkohle", "Brennt heißer als Holz.", M, 30, {"icon": ["chunk", "2a2a30", "14141a"]}),
	_i(&"clay_pot_unfired", "Ungebrannter Tontopf", "Noch weich. Zerbricht leicht – erst brennen.", M, 5, {"icon": ["pot", "c88048", "8a5028"]}),
	_i(&"fired_pottery", "Gebrannte Keramik", "Hart und wasserdicht.", M, 5, {"icon": ["pot", "b04a2a", "6a2a14"]}),
	_i(&"malachite", "Malachit", "Grünes Gestein. Beim Erhitzen zeigt es ein rotes Metall.", M, 20, {"icon": ["chunk", "2aa070", "146a48"]}),
	_i(&"copper_bead", "Kupferperle", "Die erste Perle aus Metall. Ein neues Zeitalter beginnt.", S, 10, {"icon": ["bead", "d8823a", "8a4a1a"]}),
	_i(&"amber", "Bernstein", "Warm leuchtendes Harz von vor Urzeiten.", S, 10, {"icon": ["chunk", "e8a020", "a86a10"]}),
	# --- Nahrung ---
	_i(&"berries", "Beeren", "Süß und saftig. Halten nicht lange.", F, 20, {"nutr": 8.0, "hydr": 4.0, "spoil": 3, "icon": ["berries", "c02a4a", "6a1a3a"]}),
	_i(&"raw_meat", "Rohes Fleisch", "Roh gegessen liegt es schwer im Magen. Verdirbt schnell.", F, 10, {"nutr": 14.0, "spoil": 2, "icon": ["meat", "c8404a", "8a2a30"]}),
	_i(&"cooked_meat", "Gebratenes Fleisch", "Saftig und sättigend.", F, 10, {"nutr": 34.0, "spoil": 4, "icon": ["meat", "8a5030", "5a3018"]}),
	_i(&"smoked_meat", "Geräuchertes Fleisch", "Haltbar für lange Wintertage.", F, 10, {"nutr": 30.0, "spoil": 20, "icon": ["meat", "6a4a34", "3a2a1a"]}),
	_i(&"raw_fish", "Roher Fisch", "Frisch gefangen. Verdirbt schnell.", F, 10, {"nutr": 10.0, "hydr": 2.0, "spoil": 2, "icon": ["fish", "8aa0b8", "4a607a"]}),
	_i(&"cooked_fish", "Gebratener Fisch", "Zart und nahrhaft.", F, 10, {"nutr": 26.0, "spoil": 3, "icon": ["fish", "c89060", "8a5a34"]}),
	_i(&"flatbread", "Fladenbrot", "Aus Mehl auf heißem Stein gebacken.", F, 10, {"nutr": 28.0, "spoil": 6, "icon": ["bread", "d8a860", "9a7030"]}),
	_i(&"mushroom", "Pilz", "Nicht jeder Pilz ist essbar …", F, 20, {"nutr": 6.0, "spoil": 4, "icon": ["mushroom", "c8a070", "e8e0d0"]}),
	_i(&"spoiled_meat", "Verdorbenes Fleisch", "Es stinkt. Besser nicht essen.", F, 10, {"icon": ["meat", "6a7a3a", "3a4a1a"]}),
	# --- Werkzeug / Waffe ---
	_i(&"hand_axe", "Faustkeil", "Ein Stein mit scharfer Kante. Fällt Bäume, schneidet, schlägt.", T, 1, {"tool": AXE, "power": 2.0, "dur": 40, "icon": ["axe", "9a9a9a", "8a5a2b"]}),
	_i(&"scraper", "Schaber", "Zum Säubern von Fellen.", T, 1, {"tool": KNIFE, "power": 1.0, "dur": 30, "icon": ["scraper", "aab4be", "8a5a2b"]}),
	_i(&"wooden_spear", "Holzspeer", "Angespitzter Ast. Besser als nichts.", W, 1, {"tool": SPEAR, "power": 2.0, "dur": 20, "icon": ["spear", "8a5a2b", "c8a070"]}),
	_i(&"hardened_spear", "Gehärteter Speer", "Im Feuer gehärtete Spitze.", W, 1, {"tool": SPEAR, "power": 3.0, "dur": 35, "icon": ["spear", "6a4222", "d8c8a0"]}),
	_i(&"flint_spear", "Feuersteinspeer", "Mit scharfer Klinge. Durchdringt dickes Fell.", W, 1, {"tool": SPEAR, "power": 4.0, "dur": 45, "icon": ["spear", "8a5a2b", "c8d2dc"]}),
	_i(&"bow", "Bogen", "Trifft aus der Ferne.", W, 1, {"tool": BOW, "power": 3.0, "dur": 60, "icon": ["bow", "8a5a2b", "e8d8b0"]}),
	_i(&"arrow", "Pfeil", "Munition für den Bogen.", W, 30, {"power": 2.0, "icon": ["arrow", "8a5a2b", "c8d2dc"]}),
	_i(&"fish_trap", "Fischreuse", "Fängt Fische, während du etwas anderes tust.", T, 1, {"tool": FISH, "power": 1.0, "dur": 30, "icon": ["trap", "a08050", "6a5030"]}),
	_i(&"grindstone", "Mahlstein", "Zum Zerreiben von Körnern.", T, 1, {"icon": ["grindstone", "8a8a90", "5a5a62"]}),
	_i(&"fire_drill", "Feuerbohrer", "Reibung erzeugt Glut.", T, 1, {"dur": 25, "icon": ["drill", "8a5a2b", "e88a2a"]}),
	_i(&"blowpipe", "Blasrohr", "Knochenrohr zum Anfachen der Glut – heiß genug für Erz.", T, 1, {"dur": 40, "icon": ["pipe", "e8e0c8", "a89e80"]}),
	# --- Kleidung ---
	_i(&"fur_clothing", "Fellkleidung", "Hält auch im Winter warm.", C, 1, {"warm": 30.0, "icon": ["clothing", "a06a3a", "6a4222"]}),
	# --- Platzierbar ---
	_i(&"campfire", "Lagerfeuer", "Wärme, Licht und Schutz.", P, 5, {"scene": "res://fire/scenes/campfire.tscn", "icon": ["campfire", "e88a2a", "5a3a1a"]}),
	_i(&"drying_rack", "Trockengestell", "Zum Räuchern und Trocknen.", P, 5, {"scene": "res://fire/scenes/drying_rack.tscn", "icon": ["rack", "8a5a2b", "c8a86a"]}),
	_i(&"kiln", "Keramikofen", "Hitze für Ton und Erz.", P, 5, {"scene": "res://fire/scenes/kiln.tscn", "icon": ["kiln", "b8703a", "5a3018"]}),
	_i(&"lean_to", "Unterstand", "Schutz vor Wind und Regen.", P, 5, {"scene": "res://tribe/scenes/lean_to.tscn", "icon": ["hut", "8a5a2b", "a06a3a"]}),
	_i(&"hut", "Hütte", "Ein festes Dach über dem Kopf.", P, 5, {"scene": "res://tribe/scenes/hut.tscn", "icon": ["hut", "b8703a", "7a4a22"]}),
	_i(&"longhouse", "Langhaus", "Platz für den ganzen Stamm.", P, 5, {"scene": "res://tribe/scenes/longhouse.tscn", "icon": ["longhouse", "b8703a", "5a3018"]}),
	_i(&"storage_pit", "Vorratsgrube", "Kühl und trocken für den Winter.", P, 5, {"scene": "res://tribe/scenes/storage_pit.tscn", "icon": ["pit", "5a3a1a", "8a5a2b"]}),
	_i(&"field_plot", "Feldbeet", "Hier wächst Getreide.", P, 5, {"scene": "res://world/scenes/field_plot.tscn", "icon": ["plot", "6a4222", "4a9a3a"]}),
	_i(&"animal_pen", "Tiergehege", "Zaun für gezähmte Tiere.", P, 5, {"scene": "res://animals/scenes/animal_pen.tscn", "icon": ["pen", "8a5a2b", "4a9a3a"]}),
	_i(&"workspot", "Werkplatz", "Flache Arbeitsfläche für größere Vorhaben.", P, 5, {"scene": "res://items/scenes/workspot.tscn", "icon": ["table", "8a5a2b", "9a9a9a"]}),
]

## Rezepte: id, inputs, out, n, station, secs, discovery, tools + Knapping/Aktion
var RECIPES: Array[Dictionary] = [
	# Feuerstein schlagen (Minispiel)
	_r(&"hand_axe", {&"flint": 1, &"stone": 1}, &"hand_axe", 1, HAND, 0.0, &"", [], {"knap": true, "fail": &"flint_flake", "fail_n": 2, "keeps": [&"stone"]}),
	_r(&"flint_blade", {&"flint": 1, &"stone": 1}, &"flint_blade", 1, HAND, 0.0, &"blades", [], {"knap": true, "fail": &"flint_flake", "fail_n": 1, "keeps": [&"stone"]}),
	# Werkzeug & Waffen
	_r(&"scraper", {&"flint_flake": 2}, &"scraper", 1, HAND, 2.0, &"", [], {}),
	_r(&"wooden_spear", {&"branch": 1}, &"wooden_spear", 1, HAND, 3.0, &"hand_axe", [&"hand_axe"], {}),
	_r(&"hardened_spear", {&"wooden_spear": 1}, &"hardened_spear", 1, CAMPFIRE, 5.0, &"fire_hardening", [], {"action": &"harden_spear"}),
	_r(&"flint_spear", {&"branch": 1, &"flint_blade": 1, &"cordage": 1}, &"flint_spear", 1, WORKSPOT, 4.0, &"blades", [], {}),
	_r(&"cordage", {&"nettle": 3}, &"cordage", 1, HAND, 2.0, &"cordage", [], {}),
	_r(&"fire_drill", {&"branch": 2, &"cordage": 1}, &"fire_drill", 1, HAND, 4.0, &"fire", [], {}),
	_r(&"fur_clothing", {&"hide": 3, &"cordage": 1}, &"fur_clothing", 1, WORKSPOT, 8.0, &"fur_clothing", [&"scraper"], {}),
	_r(&"bow", {&"branch": 1, &"cordage": 1, &"flint_blade": 1}, &"bow", 1, WORKSPOT, 5.0, &"bow", [], {}),
	_r(&"arrow", {&"branch": 1, &"flint_flake": 1, &"feather": 1}, &"arrow", 3, WORKSPOT, 3.0, &"bow", [], {}),
	_r(&"fish_trap", {&"branch": 4, &"cordage": 2}, &"fish_trap", 1, WORKSPOT, 5.0, &"fish_trap", [], {}),
	_r(&"grindstone", {&"stone": 3}, &"grindstone", 1, WORKSPOT, 6.0, &"grinding", [], {}),
	_r(&"flour", {&"wild_grain": 3}, &"flour", 1, HAND, 3.0, &"grinding", [&"grindstone"], {"action": &"grind_grain"}),
	_r(&"clay_pot_unfired", {&"clay": 3}, &"clay_pot_unfired", 1, HAND, 4.0, &"pottery", [], {}),
	_r(&"blowpipe", {&"bone": 2}, &"blowpipe", 1, WORKSPOT, 4.0, &"blowpipe", [&"scraper"], {}),
	# Bauen
	_r(&"workspot", {&"branch": 4, &"stone": 2}, &"workspot", 1, HAND, 3.0, &"", [], {}),
	_r(&"campfire", {&"branch": 4, &"stone": 3}, &"campfire", 1, HAND, 3.0, &"fire", [], {}),
	_r(&"drying_rack", {&"branch": 5, &"cordage": 2}, &"drying_rack", 1, WORKSPOT, 5.0, &"smoking", [], {}),
	_r(&"lean_to", {&"branch": 8, &"hide": 2, &"cordage": 2}, &"lean_to", 1, HAND, 5.0, &"", [], {}),
	_r(&"hut", {&"wood_log": 8, &"clay": 4, &"cordage": 4}, &"hut", 1, WORKSPOT, 10.0, &"cordage", [], {}),
	_r(&"longhouse", {&"wood_log": 20, &"clay": 10, &"cordage": 8}, &"longhouse", 1, WORKSPOT, 15.0, &"longhouse", [], {}),
	_r(&"storage_pit", {&"stone": 4, &"branch": 4}, &"storage_pit", 1, HAND, 4.0, &"", [], {}),
	_r(&"kiln", {&"clay": 10, &"stone": 6, &"wood_log": 4}, &"kiln", 1, WORKSPOT, 12.0, &"kiln", [], {}),
	_r(&"field_plot", {&"branch": 2, &"stone": 2}, &"field_plot", 1, HAND, 3.0, &"agriculture", [], {}),
	_r(&"animal_pen", {&"branch": 10, &"cordage": 4}, &"animal_pen", 1, WORKSPOT, 8.0, &"taming", [], {}),
	# Stationen (Feuer & Ofen)
	_r(&"cooked_meat", {&"raw_meat": 1}, &"cooked_meat", 1, CAMPFIRE, 4.0, &"cooking", [], {"action": &"cook"}),
	_r(&"cooked_fish", {&"raw_fish": 1}, &"cooked_fish", 1, CAMPFIRE, 3.0, &"cooking", [], {"action": &"cook"}),
	_r(&"flatbread", {&"flour": 2}, &"flatbread", 1, CAMPFIRE, 4.0, &"cooking", [], {"action": &"cook"}),
	_r(&"charcoal", {&"wood_log": 2}, &"charcoal", 1, CAMPFIRE, 6.0, &"fire", [], {}),
	_r(&"smoked_meat", {&"raw_meat": 2}, &"smoked_meat", 2, RACK, 8.0, &"smoking", [], {"action": &"smoke_meat"}),
	_r(&"fired_pottery", {&"clay_pot_unfired": 1}, &"fired_pottery", 1, KILN, 10.0, &"pottery", [], {"action": &"fire_pottery"}),
	_r(&"copper_bead", {&"malachite": 2, &"charcoal": 1}, &"copper_bead", 1, KILN, 12.0, &"copper", [&"blowpipe"], {"action": &"smelt_malachite"}),
]

## Bauwerke: id, Tiles (b, h), Station (-1 = keine), Platzhalterfarbe
var STRUCTURES: Array[Dictionary] = [
	{"id": &"campfire", "size": Vector2i(1, 1), "station": CAMPFIRE, "color": Color("e88a2a")},
	{"id": &"drying_rack", "size": Vector2i(2, 1), "station": RACK, "color": Color("c8a86a")},
	{"id": &"kiln", "size": Vector2i(2, 2), "station": KILN, "color": Color("b8703a")},
	{"id": &"workspot", "size": Vector2i(2, 1), "station": WORKSPOT, "color": Color("8a5a2b")},
	{"id": &"lean_to", "size": Vector2i(2, 2), "color": Color("a06a3a")},
	{"id": &"hut", "size": Vector2i(3, 3), "color": Color("b8703a")},
	{"id": &"longhouse", "size": Vector2i(5, 3), "color": Color("8a4e24")},
	{"id": &"storage_pit", "size": Vector2i(1, 1), "color": Color("5a3a1a")},
	{"id": &"field_plot", "size": Vector2i(2, 2), "color": Color("6a4222")},
	{"id": &"animal_pen", "size": Vector2i(4, 4), "color": Color("6a8a3a")},
]


func _i(id: StringName, dname: String, desc: String, cat: Enums.ItemCategory, stack: int, o: Dictionary = {}) -> Dictionary:
	return {"id": id, "name": dname, "desc": desc, "cat": cat, "stack": stack, "tool": o.get("tool", NO),
			"power": o.get("power", 0.0), "dur": o.get("dur", 0), "nutr": o.get("nutr", 0.0),
			"hydr": o.get("hydr", 0.0), "warm": o.get("warm", 0.0), "spoil": o.get("spoil", 0),
			"scene": o.get("scene", ""), "icon": o.get("icon", [])}


func _r(id: StringName, inputs: Dictionary, out: StringName, n: int, station: Enums.Station, secs: float,
		disc: StringName, tools: Array, o: Dictionary = {}) -> Dictionary:
	return {"id": id, "inputs": inputs, "out": out, "n": n, "station": station, "secs": secs, "disc": disc,
			"tools": tools, "knap": o.get("knap", false), "fail": o.get("fail", &""), "fail_n": o.get("fail_n", 1),
			"keeps": o.get("keeps", []), "action": o.get("action", &"")}


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var do_icons: bool = args.is_empty() or "icons" in args
	var do_data: bool = args.is_empty() or "data" in args
	if do_icons:
		_write_icons()
	if do_data:
		_write_data()
	quit()


# ---------------------------------------------------------------- Daten

func _write_data() -> void:
	for d in [ITEM_DIR, RECIPE_DIR, STRUCT_DIR]:
		DirAccess.make_dir_recursive_absolute(d)
	for e in ITEMS:
		var it: ItemData = ItemData.new()
		it.id = e["id"]
		it.display_name = e["name"]
		it.description = e["desc"]
		var icon_path: String = "%s/item_%s.png" % [ICON_DIR, e["id"]]
		if ResourceLoader.exists(icon_path):
			it.icon = load(icon_path)
		else:
			push_warning("Icon fehlt (erst 'icons' + --import ausführen): " + icon_path)
		it.category = e["cat"]
		it.max_stack = e["stack"]
		it.tool_type = e["tool"]
		it.tool_power = e["power"]
		it.max_durability = e["dur"]
		it.nutrition = e["nutr"]
		it.hydration = e["hydr"]
		it.warmth = e["warm"]
		it.spoil_days = e["spoil"]
		it.placeable_scene_path = e["scene"]
		_save(it, "%s/%s.tres" % [ITEM_DIR, e["id"]])
	for e in RECIPES:
		var r: CraftingRecipe = CraftingRecipe.new()
		r.id = e["id"]
		var inputs: Dictionary[StringName, int] = {}
		for k in e["inputs"]:
			inputs[k] = e["inputs"][k]
		r.inputs = inputs
		r.output_id = e["out"]
		r.output_amount = e["n"]
		r.station = e["station"]
		r.craft_seconds = e["secs"]
		r.required_discovery = e["disc"]
		r.required_tools.assign(e["tools"])
		r.uses_knapping = e["knap"]
		r.fail_output_id = e["fail"]
		r.fail_output_amount = e["fail_n"]
		r.fail_keeps.assign(e["keeps"])
		r.action_id = e["action"]
		_save(r, "%s/%s.tres" % [RECIPE_DIR, e["id"]])
	for e in STRUCTURES:
		var s: StructureInfo = StructureInfo.new()
		s.id = e["id"]
		s.footprint = e["size"]
		s.provides_station = e.has("station")
		if s.provides_station:
			s.station = e["station"]
		s.placeholder_color = e["color"]
		_save(s, "%s/%s.tres" % [STRUCT_DIR, e["id"]])
	print("Daten geschrieben: %d Items, %d Rezepte, %d Bauwerke" % [ITEMS.size(), RECIPES.size(), STRUCTURES.size()])


func _save(res: Resource, path: String) -> void:
	var err: int = ResourceSaver.save(res, path)
	if err != OK:
		push_error("Speichern fehlgeschlagen (%d): %s" % [err, path])


# ---------------------------------------------------------------- Icons

var _img: Image


func _write_icons() -> void:
	DirAccess.make_dir_recursive_absolute(ICON_DIR)
	for e in ITEMS:
		var spec: Array = e["icon"]
		_img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		_img.fill(Color(0, 0, 0, 0))
		_draw_shape(spec[0], Color(spec[1]), Color(spec[2]))
		_outline()
		_img.save_png("%s/item_%s.png" % [ICON_DIR, e["id"]])
	print("Icons geschrieben: %d" % ITEMS.size())


func _px(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < 16 and y < 16:
		_img.set_pixel(x, y, c)


func _rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(xx, yy, c)


func _ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in 16:
		for x in 16:
			var dx: float = (x + 0.5 - cx) / rx
			var dy: float = (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_px(x, y, c)


func _line(x0: int, y0: int, x1: int, y1: int, c: Color, thick: int = 1) -> void:
	var steps: int = maxi(absi(x1 - x0), absi(y1 - y0))
	for i in steps + 1:
		var t: float = float(i) / maxf(1.0, steps)
		var x: int = roundi(lerpf(x0, x1, t))
		var y: int = roundi(lerpf(y0, y1, t))
		_rect(x, y, thick, thick, c)


func _poly(pts: Array[Vector2], c: Color) -> void:
	var poly: PackedVector2Array = PackedVector2Array(pts)
	for y in 16:
		for x in 16:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				_px(x, y, c)


func _outline() -> void:
	var src: Image = _img.duplicate()
	for y in 16:
		for x in 16:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < 16 and ny < 16 and src.get_pixel(nx, ny).a > 0.0:
					_img.set_pixel(x, y, Color(0.12, 0.09, 0.07, 1))
					break


func _draw_shape(shape: String, a: Color, b: Color) -> void:
	match shape:
		"stick":
			_line(3, 13, 13, 3, a, 2)
			_px(5, 9, b)
			_px(9, 5, b)
		"blob":
			_ellipse(8, 9, 5.5, 4.5, a)
			_ellipse(9.5, 10.5, 3, 2.2, b)
			_px(6, 7, a.lightened(0.3))
		"chunk":
			_poly([Vector2(3, 10), Vector2(5, 4), Vector2(11, 3), Vector2(13, 8), Vector2(11, 13), Vector2(5, 13)], a)
			_poly([Vector2(8, 8), Vector2(13, 8), Vector2(11, 13), Vector2(6, 13)], b)
		"shard":
			_poly([Vector2(3, 12), Vector2(8, 2), Vector2(12, 12)], a)
			_line(8, 4, 8, 11, b)
		"blade":
			_poly([Vector2(5, 14), Vector2(8, 1), Vector2(11, 14)], a)
			_line(8, 3, 8, 13, b)
		"log":
			_rect(2, 6, 12, 6, a)
			_ellipse(13, 9, 2.2, 3, b)
			_line(3, 8, 11, 8, b)
		"leaf":
			_ellipse(8, 8, 6, 3, a)
			_line(3, 12, 13, 4, b)
		"coil":
			_ellipse(8, 8, 5.5, 5.5, a)
			_ellipse(8, 8, 2.5, 2.5, Color(0, 0, 0, 0))
			_line(3, 8, 13, 8, b)
		"tuft":
			for i in 5:
				_line(4 + i * 2, 13, 3 + i * 2 + (i % 2) * 2, 4 + (i % 3), a)
			_line(3, 13, 13, 13, b)
		"hide":
			_poly([Vector2(3, 3), Vector2(6, 2), Vector2(10, 3), Vector2(14, 4), Vector2(13, 9), Vector2(14, 13), Vector2(8, 13), Vector2(4, 14), Vector2(3, 8)], a)
			_ellipse(8, 8, 3, 3, b)
		"bone":
			_line(4, 12, 12, 4, a, 2)
			_ellipse(4, 12, 2, 2, a)
			_ellipse(3, 10, 1.5, 1.5, a)
			_ellipse(12, 4, 2, 2, a)
			_ellipse(13, 6, 1.5, 1.5, a)
			_px(8, 8, b)
		"drop":
			_poly([Vector2(8, 2), Vector2(12, 9), Vector2(8, 14), Vector2(4, 9)], a)
			_ellipse(8, 10, 3.5, 3.5, a)
			_px(6, 9, b)
		"feather":
			_poly([Vector2(3, 13), Vector2(5, 5), Vector2(12, 2), Vector2(13, 8), Vector2(8, 12)], a)
			_line(3, 13, 12, 3, b)
		"sack":
			_ellipse(8, 10, 5.5, 4.5, a)
			_rect(6, 3, 4, 4, a)
			_line(5, 6, 10, 6, b)
		"pot":
			_poly([Vector2(3, 5), Vector2(13, 5), Vector2(12, 13), Vector2(4, 13)], a)
			_rect(3, 3, 10, 2, b)
			_rect(5, 8, 6, 1, b)
		"bead":
			_ellipse(8, 8, 5, 5, a)
			_ellipse(8, 8, 1.8, 1.8, Color(0, 0, 0, 0))
			_px(5, 5, b.lightened(0.5))
		"berries":
			_ellipse(5, 10, 3, 3, a)
			_ellipse(11, 10, 3, 3, a)
			_ellipse(8, 6, 3, 3, a)
			_px(8, 3, Color("4a9a3a"))
			_px(4, 9, b)
			_px(10, 9, b)
		"meat":
			_ellipse(7, 9, 5.5, 4.5, a)
			_ellipse(8, 10, 3, 2, b)
			_line(11, 6, 14, 3, Color("e8e0c8"), 2)
		"fish":
			_ellipse(7, 8, 5, 3, a)
			_poly([Vector2(11, 8), Vector2(15, 4), Vector2(15, 12)], a)
			_px(4, 7, Color("161616"))
			_line(6, 10, 9, 10, b)
		"bread":
			_ellipse(8, 9, 6, 3.5, a)
			_line(4, 9, 11, 9, b)
		"mushroom":
			_ellipse(8, 7, 5.5, 4, a)
			_rect(6, 8, 4, 5, b)
			_px(6, 5, b)
			_px(10, 6, b)
		"axe":
			_line(4, 13, 11, 4, b, 2)
			_poly([Vector2(8, 2), Vector2(14, 5), Vector2(11, 9), Vector2(6, 6)], a)
		"scraper":
			_line(4, 13, 9, 8, b, 2)
			_ellipse(10, 6, 4, 3, a)
		"spear":
			_line(2, 14, 12, 4, a, 1)
			_poly([Vector2(11, 6), Vector2(14, 1), Vector2(15, 5)], b)
		"bow":
			for i in 13:
				var t: float = i / 12.0
				_px(roundi(10.0 - sin(t * PI) * 6.0), 2 + i, a)
				_px(roundi(11.0 - sin(t * PI) * 6.0), 2 + i, a)
			_line(11, 2, 11, 14, b)
		"arrow":
			_line(2, 14, 12, 4, a)
			_poly([Vector2(11, 6), Vector2(14, 1), Vector2(15, 5)], b)
			_line(2, 12, 2, 14, Color("e8e8e8"))
			_line(4, 14, 2, 14, Color("e8e8e8"))
		"trap":
			_ellipse(8, 8, 6, 4.5, a)
			_line(4, 5, 4, 11, b)
			_line(8, 4, 8, 12, b)
			_line(12, 5, 12, 11, b)
		"grindstone":
			_ellipse(8, 10, 6.5, 3.5, a)
			_ellipse(8, 8, 4, 2, b)
		"drill":
			_line(8, 2, 8, 13, a, 2)
			_rect(7, 13, 3, 2, b)
			_line(4, 3, 12, 3, Color("c8a86a"))
		"pipe":
			_line(3, 13, 13, 3, a, 3)
			_line(4, 12, 12, 4, b)
		"clothing":
			_poly([Vector2(5, 2), Vector2(11, 2), Vector2(14, 5), Vector2(12, 7), Vector2(11, 6), Vector2(11, 14), Vector2(5, 14), Vector2(5, 6), Vector2(4, 7), Vector2(2, 5)], a)
			_line(6, 3, 10, 3, b)
		"campfire":
			_line(2, 13, 13, 10, b, 2)
			_line(3, 10, 13, 13, b, 2)
			_poly([Vector2(8, 1), Vector2(12, 8), Vector2(10, 11), Vector2(6, 11), Vector2(4, 8)], a)
			_poly([Vector2(8, 5), Vector2(10, 9), Vector2(6, 9)], Color("f8d84a"))
		"rack":
			_line(2, 14, 3, 3, a, 2)
			_line(13, 14, 12, 3, a, 2)
			_line(2, 4, 13, 4, a, 2)
			_rect(5, 6, 2, 5, b)
			_rect(9, 6, 2, 5, b)
		"kiln":
			_ellipse(8, 10, 6.5, 5.5, a)
			_rect(1, 10, 14, 4, a)
			_ellipse(8, 11, 3, 3, b)
		"hut":
			_poly([Vector2(1, 8), Vector2(8, 2), Vector2(15, 8)], a)
			_rect(3, 8, 10, 6, b)
			_rect(7, 10, 3, 4, Color("2a1a10"))
		"longhouse":
			_poly([Vector2(0, 8), Vector2(4, 3), Vector2(12, 3), Vector2(16, 8)], a)
			_rect(1, 8, 14, 6, b)
			_rect(6, 10, 4, 4, Color("2a1a10"))
		"pit":
			_ellipse(8, 8, 6.5, 5, a)
			_ellipse(8, 8, 4.5, 3, b)
		"plot":
			_rect(2, 3, 12, 10, a)
			for i in 3:
				_line(3, 5 + i * 3, 13, 5 + i * 3, b)
		"pen":
			for i in 4:
				_line(2 + i * 4, 4, 2 + i * 4, 13, a, 1)
			_line(2, 6, 14, 6, b)
			_line(2, 10, 14, 10, b)
		"table":
			_rect(2, 6, 12, 3, a)
			_rect(3, 9, 2, 5, a)
			_rect(11, 9, 2, 5, a)
			_rect(4, 4, 3, 2, b)
		_:
			_ellipse(8, 8, 5, 5, a)
