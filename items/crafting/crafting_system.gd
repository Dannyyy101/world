class_name CraftingSystem
extends Node
## Herstellen: prüft Rezepte (Entdeckung, Station in Reichweite, Zutaten, Werkzeuge), führt sie mit
## Herstellzeit aus oder startet das Feuerstein-Schlagen-Minispiel. Erreichbar über `Inventory.crafting`.
##
## Zutaten werden erst beim Abschluss verbraucht – Abbrechen kostet also nichts.
## Emittiert EventBus.item_crafted (+ action_performed, wenn das Rezept eine action_id hat).

signal craft_started(recipe: RecipeData)
signal craft_progressed(recipe: RecipeData, ratio: float)
signal craft_finished(recipe: RecipeData, output_id: StringName)
signal craft_cancelled(recipe: RecipeData, reason: String)

const STATION_GROUP: StringName = &"crafting_station"
## Reichweite zu Stationen in Pixeln.
const STATION_REACH: float = 40.0

var knapping: KnappingMinigame
var current: RecipeData = null

var _elapsed: float = 0.0


func _process(delta: float) -> void:
	if current == null or _uses_knapping(current):
		return
	_elapsed += delta
	var total: float = maxf(current.craft_seconds, 0.01)
	craft_progressed.emit(current, clampf(_elapsed / total, 0.0, 1.0))
	if _elapsed >= total:
		var recipe: RecipeData = current
		current = null
		_finish(recipe, -1)


# ------------------------------------------------------------ Abfragen

## Stationen, die der Spieler gerade benutzen kann (HAND immer).
func get_stations_in_reach() -> Array[int]:
	var out: Array[int] = [Enums.Station.HAND]
	var player: Node2D = GameState.player
	if player == null:
		return out
	for n in get_tree().get_nodes_in_group(STATION_GROUP):
		var node: Node2D = n as Node2D
		if node == null or not node.is_inside_tree():
			continue
		var st: int = station_of(node)
		if st >= 0 and not out.has(st) and node.global_position.distance_to(player.global_position) <= STATION_REACH:
			out.append(st)
	return out


## Station eines Nodes der Gruppe "crafting_station": Property `station` (Enums.Station) oder Meta "station".
static func station_of(node: Node) -> int:
	var v: Variant = node.get("station")
	if v == null and node.has_meta("station"):
		v = node.get_meta("station")
	return int(v) if v != null else -1


## Sichtbare Rezepte: Entdeckung erfüllt UND Station in Reichweite. Sortiert nach Station, dann Name.
func get_visible_recipes() -> Array[RecipeData]:
	var stations: Array[int] = get_stations_in_reach()
	var out: Array[RecipeData] = []
	for r in ItemDB.all_recipes():
		if is_unlocked(r) and stations.has(r.station):
			out.append(r)
	out.sort_custom(func(a: RecipeData, b: RecipeData) -> bool:
		if a.station != b.station:
			return a.station < b.station
		return recipe_name(a) < recipe_name(b))
	return out


func is_unlocked(recipe: RecipeData) -> bool:
	return recipe.required_discovery == &"" or Discoveries.is_unlocked(recipe.required_discovery)


func required_tools(recipe: RecipeData) -> Array[StringName]:
	if recipe is CraftingRecipe:
		return (recipe as CraftingRecipe).required_tools
	return []


func missing_inputs(recipe: RecipeData) -> Dictionary:
	var missing: Dictionary = {}
	for id in recipe.inputs:
		var have: int = Inventory.count(id)
		if have < recipe.inputs[id]:
			missing[id] = recipe.inputs[id] - have
	return missing


func missing_tools(recipe: RecipeData) -> Array[StringName]:
	var out: Array[StringName] = []
	for t in required_tools(recipe):
		if not Inventory.has_item(t):
			out.append(t)
	return out


func can_craft(recipe: RecipeData) -> bool:
	return is_unlocked(recipe) and get_stations_in_reach().has(recipe.station) \
			and missing_inputs(recipe).is_empty() and missing_tools(recipe).is_empty()


func recipe_name(recipe: RecipeData) -> String:
	var item: ItemData = ItemDB.get_item(recipe.output_id)
	return item.display_name if item != null else String(recipe.id)


func is_crafting() -> bool:
	return current != null or (knapping != null and knapping.is_active())


func get_progress() -> float:
	if current == null:
		return 0.0
	return clampf(_elapsed / maxf(current.craft_seconds, 0.01), 0.0, 1.0)


# ------------------------------------------------------------ Herstellen

## Startet ein Rezept. Rückgabe: false, wenn es gerade nicht geht.
func craft(recipe_id: StringName) -> bool:
	var recipe: RecipeData = ItemDB.get_recipe(recipe_id)
	if recipe == null or is_crafting() or not can_craft(recipe):
		return false
	craft_started.emit(recipe)
	if _uses_knapping(recipe):
		if knapping == null:
			return false
		current = recipe
		_elapsed = 0.0
		if not knapping.finished.is_connected(_on_knapping_finished):
			knapping.finished.connect(_on_knapping_finished)
			knapping.cancelled.connect(_on_knapping_cancelled)
		knapping.start()
		return true
	current = recipe
	_elapsed = 0.0
	if recipe.craft_seconds <= 0.0:
		var r: RecipeData = current
		current = null
		_finish(r, -1)
	return true


func cancel() -> void:
	if current == null:
		return
	var recipe: RecipeData = current
	current = null
	if knapping != null and knapping.is_active():
		knapping.abort()
	craft_cancelled.emit(recipe, "abgebrochen")


func _on_knapping_finished(quality: int) -> void:
	if current == null:
		return
	var recipe: RecipeData = current
	current = null
	_finish(recipe, quality)


func _on_knapping_cancelled() -> void:
	if current == null:
		return
	var recipe: RecipeData = current
	current = null
	craft_cancelled.emit(recipe, "abgebrochen")


func _uses_knapping(recipe: RecipeData) -> bool:
	return recipe is CraftingRecipe and (recipe as CraftingRecipe).uses_knapping


## Schließt ein Rezept ab. quality: -1 = normales Rezept, 0–2 = Ergebnis des Feuerstein-Schlagens.
func _finish(recipe: RecipeData, quality: int) -> void:
	if not missing_inputs(recipe).is_empty() or not missing_tools(recipe).is_empty():
		craft_cancelled.emit(recipe, "Zutaten fehlen")
		return
	var out_id: StringName = recipe.output_id
	var out_amount: int = recipe.output_amount
	var durability: int = -1
	var keeps: Array[StringName] = []
	if recipe is CraftingRecipe:
		var cr: CraftingRecipe = recipe
		if cr.uses_knapping:
			if quality == 0 and cr.fail_output_id != &"":
				out_id = cr.fail_output_id
				out_amount = cr.fail_output_amount
				keeps = cr.fail_keeps
			elif quality == 2:
				var data: ItemData = ItemDB.get_item(out_id)
				if data != null and data.max_durability > 0:
					durability = int(ceil(data.max_durability * 1.5))
	for id in recipe.inputs:
		if not keeps.has(id):
			Inventory.remove_item(id, recipe.inputs[id])
	var rest: int = Inventory.add_item_ex(out_id, out_amount, durability)
	if rest > 0:
		Inventory.drop_item(out_id, rest)
	EventBus.item_crafted.emit(recipe.id, out_id)
	if recipe is CraftingRecipe and (recipe as CraftingRecipe).action_id != &"":
		EventBus.action_performed.emit((recipe as CraftingRecipe).action_id, {"recipe_id": recipe.id, "item_id": out_id})
	craft_finished.emit(recipe, out_id)
