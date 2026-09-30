extends Node
## ItemDB – lädt alle ItemData/RecipeData-.tres rekursiv (Besitzer: Agent 0).
## Quellen: res://items/data/ (Items) und res://items/recipes/ (Rezepte).

const ITEM_DIR: String = "res://items/data"
const RECIPE_DIR: String = "res://items/recipes"

var _items: Dictionary[StringName, ItemData] = {}
var _recipes: Dictionary[StringName, RecipeData] = {}


func _ready() -> void:
	reload()


## Liest alle Ressourcen neu ein (z. B. für Tests).
func reload() -> void:
	_items.clear()
	_recipes.clear()
	for path in _collect_tres(ITEM_DIR):
		var res: Resource = load(path)
		if res is ItemData:
			var item: ItemData = res
			if item.id == &"":
				push_warning("ItemDB: Item ohne id: %s" % path)
			elif _items.has(item.id):
				push_warning("ItemDB: doppelte Item-id '%s' (%s)" % [item.id, path])
			else:
				_items[item.id] = item
	for path in _collect_tres(RECIPE_DIR):
		var res: Resource = load(path)
		if res is RecipeData:
			var recipe: RecipeData = res
			if recipe.id == &"":
				push_warning("ItemDB: Rezept ohne id: %s" % path)
			elif _recipes.has(recipe.id):
				push_warning("ItemDB: doppelte Rezept-id '%s' (%s)" % [recipe.id, path])
			else:
				_recipes[recipe.id] = recipe


func get_item(id: StringName) -> ItemData:
	return _items.get(id)


func has_item(id: StringName) -> bool:
	return _items.has(id)


func all_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	out.assign(_items.values())
	return out


func get_recipe(id: StringName) -> RecipeData:
	return _recipes.get(id)


func all_recipes() -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	out.assign(_recipes.values())
	return out


## Rezepte, die an einer Station herstellbar sind.
func recipes_for_station(station: Enums.Station) -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	for r in _recipes.values():
		if (r as RecipeData).station == station:
			out.append(r)
	return out


func _collect_tres(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				out.append_array(_collect_tres(dir_path.path_join(entry)))
		else:
			# Im Export heißen Dateien "x.tres.remap" bzw. "x.res".
			var name: String = entry.trim_suffix(".remap")
			if name.ends_with(".tres") or name.ends_with(".res"):
				out.append(dir_path.path_join(name))
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out
