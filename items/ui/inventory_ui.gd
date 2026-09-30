class_name InventoryUI
extends CanvasLayer
## Hotbar (immer sichtbar, unten) + Inventar-/Herstellen-Fenster (Taste I). Nutzt core/theme/main_theme.tres.
## Wird vom Inventory-Autoload als Kind erzeugt (Inventory.ui). Agent 8 kann es per `visible`/`queue_free` ersetzen.
##
## Fenster links: Rucksack (Slots 9–23, Drag & Drop), rechts: Herstellen (Rezepte, die durch Entdeckungen
## freigeschaltet sind und deren Station in Reichweite ist).

signal opened()
signal closed()

const THEME_PATH: String = "res://core/theme/main_theme.tres"
const STATION_NAMES: Dictionary = {
	Enums.Station.HAND: "",
	Enums.Station.CAMPFIRE: "Feuer",
	Enums.Station.WORKSPOT: "Werkplatz",
	Enums.Station.DRYING_RACK: "Trockengestell",
	Enums.Station.KILN: "Ofen",
}

var is_open: bool = false

var _root: Control
var _catcher: Control
var _window: PanelContainer
var _slots: Array[InventorySlotUI] = []
var _equipped_label: Label
var _recipe_list: VBoxContainer
var _detail: RichTextLabel
var _craft_button: Button
var _progress: ProgressBar
var _station_label: Label
var _selected_recipe: StringName = &""
var _prev_input_enabled: bool = true
var _label_time: float = 0.0
var _button_group: ButtonGroup = ButtonGroup.new()


func _ready() -> void:
	layer = 11
	_root = Control.new()
	_root.theme = load(THEME_PATH)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_catcher()
	_build_window()
	_build_hotbar()
	Inventory.slot_changed.connect(func(_i: int) -> void: _refresh_slots())
	Inventory.inventory_changed.connect(_on_inventory_changed)
	Inventory.selected_slot_changed.connect(func(_i: int) -> void: _on_selected_changed())
	EventBus.discovery_unlocked.connect(func(_id: StringName) -> void: _rebuild_recipes())
	var crafting: CraftingSystem = Inventory.crafting
	if crafting != null:
		crafting.craft_started.connect(_on_craft_started)
		crafting.craft_progressed.connect(_on_craft_progressed)
		crafting.craft_finished.connect(func(_r: RecipeData, _o: StringName) -> void: _on_craft_ended())
		crafting.craft_cancelled.connect(func(_r: RecipeData, _why: String) -> void: _on_craft_ended())
	_refresh_slots()
	_update_equipped_label(false)
	_set_window_visible(false)


# ------------------------------------------------------------ Aufbau

## Unsichtbare Fläche hinter dem Fenster: Items, die hierher gezogen werden, werden in die Welt geworfen.
func _build_catcher() -> void:
	_catcher = DropCatcher.new()
	_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_catcher)


func _build_hotbar() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -3.0
	_root.add_child(panel)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	panel.add_child(row)
	for i in Inventory.HOTBAR_SIZE:
		var slot: InventorySlotUI = InventorySlotUI.new(i)
		_slots.append(slot)
		row.add_child(slot)
	_equipped_label = Label.new()
	_equipped_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_equipped_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_equipped_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_equipped_label.offset_bottom = -34.0
	_equipped_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_equipped_label)


func _build_window() -> void:
	_window = PanelContainer.new()
	_window.set_anchors_preset(Control.PRESET_CENTER)
	_window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_window.grow_vertical = Control.GROW_DIRECTION_BOTH
	_window.offset_top = -12.0
	_window.custom_minimum_size = Vector2(404, 170)
	_root.add_child(_window)
	var cols: HBoxContainer = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 8)
	_window.add_child(cols)

	# links: Rucksack
	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 3)
	cols.add_child(left)
	var title: Label = Label.new()
	title.text = "Rucksack"
	left.add_child(title)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	left.add_child(grid)
	for i in range(Inventory.HOTBAR_SIZE, Inventory.SLOT_COUNT):
		var slot: InventorySlotUI = InventorySlotUI.new(i)
		_slots.append(slot)
		grid.add_child(slot)
	var hint: Label = Label.new()
	hint.text = "Ziehen: sortieren\nRechtsklick: essen\nHotbar: 1–9 / Mausrad"
	hint.add_theme_color_override("font_color", Color(0.6, 0.53, 0.45))
	left.add_child(hint)

	cols.add_child(VSeparator.new())

	# rechts: Herstellen
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 3)
	cols.add_child(right)
	var ctitle: Label = Label.new()
	ctitle.text = "Herstellen"
	right.add_child(ctitle)
	_station_label = Label.new()
	_station_label.add_theme_color_override("font_color", Color(0.6, 0.53, 0.45))
	right.add_child(_station_label)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 66)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	_recipe_list = VBoxContainer.new()
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_list.add_theme_constant_override("separation", 1)
	scroll.add_child(_recipe_list)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = true
	_detail.scroll_active = false
	_detail.custom_minimum_size = Vector2(0, 40)
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_detail)
	var bottom: HBoxContainer = HBoxContainer.new()
	right.add_child(bottom)
	_craft_button = Button.new()
	_craft_button.text = "Herstellen"
	_craft_button.pressed.connect(_on_craft_pressed)
	bottom.add_child(_craft_button)
	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = 1.0
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 8)
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress.visible = false
	bottom.add_child(_progress)


# ------------------------------------------------------------ Öffnen / Schließen

func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	if GameState.player != null:
		var v: Variant = GameState.player.get("input_enabled")
		_prev_input_enabled = v == null or bool(v)
		GameState.player.set("input_enabled", false)
	_set_window_visible(true)
	_rebuild_recipes()
	opened.emit()


## Das Herstellen-Menü liegt im selben Fenster (z. B. vom Werkplatz aus aufgerufen).
func open_crafting() -> void:
	open()


func close() -> void:
	if not is_open:
		return
	is_open = false
	if Inventory.crafting != null and Inventory.crafting.current != null and not Inventory.knapping.is_active():
		Inventory.crafting.cancel()
	if GameState.player != null:
		GameState.player.set("input_enabled", _prev_input_enabled)
	_set_window_visible(false)
	closed.emit()


func _set_window_visible(on: bool) -> void:
	_window.visible = on
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _label_time > 0.0:
		_label_time -= delta
		if _label_time <= 0.0:
			_equipped_label.text = ""


# ------------------------------------------------------------ Inventar-Anzeige

func _refresh_slots() -> void:
	for s in _slots:
		s.refresh()


func _on_inventory_changed() -> void:
	_refresh_slots()
	if is_open:
		_rebuild_recipes()


func _on_selected_changed() -> void:
	_refresh_slots()
	_update_equipped_label(true)


func _update_equipped_label(show_it: bool) -> void:
	var item: ItemData = Inventory.get_equipped()
	_equipped_label.text = item.display_name if (show_it and item != null) else ""
	_label_time = 1.6 if _equipped_label.text != "" else 0.0


# ------------------------------------------------------------ Herstellen

func _rebuild_recipes() -> void:
	if not is_open or Inventory.crafting == null:
		return
	var crafting: CraftingSystem = Inventory.crafting
	for c in _recipe_list.get_children():
		_recipe_list.remove_child(c)
		c.queue_free()
	var recipes: Array[RecipeData] = crafting.get_visible_recipes()
	var stations: Array[int] = crafting.get_stations_in_reach()
	var names: PackedStringArray = PackedStringArray()
	for st in stations:
		if st != Enums.Station.HAND:
			names.append(STATION_NAMES.get(st, "?"))
	_station_label.text = "Station: " + (", ".join(names) if not names.is_empty() else "bloße Hände")
	var found: bool = false
	for r in recipes:
		var b: Button = Button.new()
		var tag: String = STATION_NAMES.get(r.station, "")
		b.text = crafting.recipe_name(r) + ("  [%s]" % tag if tag != "" else "")
		var item: ItemData = ItemDB.get_item(r.output_id)
		if item != null:
			b.icon = item.icon
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.toggle_mode = true
		b.button_group = _button_group
		b.custom_minimum_size = Vector2(0, 18)
		b.modulate = Color.WHITE if crafting.can_craft(r) else Color(1, 1, 1, 0.5)
		b.pressed.connect(_select_recipe.bind(r.id))
		_recipe_list.add_child(b)
		if r.id == _selected_recipe:
			b.set_pressed_no_signal(true)
			found = true
	if not found:
		_selected_recipe = &""
	_update_detail()


func _select_recipe(id: StringName) -> void:
	_selected_recipe = id
	_update_detail()


func _update_detail() -> void:
	var crafting: CraftingSystem = Inventory.crafting
	var recipe: RecipeData = ItemDB.get_recipe(_selected_recipe) if _selected_recipe != &"" else null
	if recipe == null:
		_detail.text = "[color=#9a8873]Wähle ein Rezept. Neue Rezepte entdeckst du durch Handeln und Beobachten.[/color]"
		_craft_button.disabled = true
		return
	var lines: PackedStringArray = PackedStringArray()
	var out_item: ItemData = ItemDB.get_item(recipe.output_id)
	lines.append("[color=#e8c170]%s[/color] ×%d" % [crafting.recipe_name(recipe), recipe.output_amount])
	var parts: PackedStringArray = PackedStringArray()
	for id in recipe.inputs:
		var have: int = Inventory.count(id)
		var need: int = recipe.inputs[id]
		var item: ItemData = ItemDB.get_item(id)
		var nm: String = item.display_name if item != null else String(id)
		parts.append("[color=%s]%s %d/%d[/color]" % ["#9ad07a" if have >= need else "#e07060", nm, mini(have, need), need])
	lines.append(", ".join(parts))
	var tools: Array[StringName] = crafting.required_tools(recipe)
	if not tools.is_empty():
		var tparts: PackedStringArray = PackedStringArray()
		for t in tools:
			var ti: ItemData = ItemDB.get_item(t)
			tparts.append("[color=%s]%s[/color]" % ["#9ad07a" if Inventory.has_item(t) else "#e07060", ti.display_name if ti != null else String(t)])
		lines.append("Werkzeug: " + ", ".join(tparts))
	var knap: bool = recipe is CraftingRecipe and (recipe as CraftingRecipe).uses_knapping
	if knap:
		lines.append("[color=#9a8873]Minispiel – gelingt besser mit Übung (%d)[/color]" % Inventory.knapping.attempts)
	elif out_item != null and recipe.craft_seconds > 0.0:
		lines.append("[color=#9a8873]Dauer: %s s[/color]" % str(snappedf(recipe.craft_seconds, 0.1)))
	_detail.text = "\n".join(lines)
	_craft_button.text = "Schlagen" if knap else "Herstellen"
	_craft_button.disabled = crafting.is_crafting() or not crafting.can_craft(recipe)


func _on_craft_pressed() -> void:
	if _selected_recipe != &"":
		Inventory.crafting.craft(_selected_recipe)


func _on_craft_started(recipe: RecipeData) -> void:
	var knap: bool = recipe is CraftingRecipe and (recipe as CraftingRecipe).uses_knapping
	if knap:
		_window.visible = false
	else:
		_progress.value = 0.0
		_progress.visible = true
	_craft_button.disabled = true


func _on_craft_progressed(_recipe: RecipeData, ratio: float) -> void:
	_progress.value = ratio


func _on_craft_ended() -> void:
	_progress.visible = false
	if is_open:
		_window.visible = true
		_rebuild_recipes()


## Fläche, auf die Slots gezogen werden können, um sie in die Welt zu werfen.
class DropCatcher extends Control:
	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return data is Dictionary and (data as Dictionary).get("type", "") == InventorySlotUI.DRAG_TYPE

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		Inventory.drop_slot(int((data as Dictionary)["from"]))
