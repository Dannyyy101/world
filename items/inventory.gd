extends Node
## Inventory – Autoload (Besitzer: Agent 2). Ersetzt den Stub von Agent 0.
##
## 24 Slots; Slot 0–8 sind die Hotbar. Stapel, Haltbarkeit pro Slot, Ausrüsten (Hotbar-Taste / Mausrad),
## Verderben über Tage. Baut außerdem die restlichen Item-Systeme als Kinder auf:
## crafting, knapping, build, drops, ui.
##
## Kern-API (Signaturen wie in docs/ARCHITECTURE.md):
##   add_item(id, amount) -> int · remove_item(id, amount) -> bool · has_item(id, amount) -> bool
##   count(id) -> int · get_equipped() -> ItemData · damage_equipped(amount)

signal slot_changed(index: int)
signal inventory_changed()
signal selected_slot_changed(index: int)
signal equipped_changed(item: ItemData)

const SLOT_COUNT: int = 24
const HOTBAR_SIZE: int = 9
const SAVE_KEY: String = "inventory"
## Verderbendes Essen wird hierzu (falls die ID in ItemDB existiert), sonst verschwindet es.
const SPOILED_ITEM: StringName = &"spoiled_meat"
const SPOIL_INTO_SPOILED: Array[StringName] = [&"raw_meat", &"cooked_meat", &"smoked_meat", &"raw_fish", &"cooked_fish"]
## Bauwerke, Drops, UI: false = nur die reine Datenschicht (z. B. für Server-Tests).
var create_subsystems: bool = true

var selected_slot: int = 0

var crafting: CraftingSystem
var knapping: KnappingMinigame
var build: BuildManager
var drops: DropManager
var ui: InventoryUI

var _slots: Array[ItemStack] = []
var _last_spoil_day: int = 0


func _init() -> void:
	_slots.resize(SLOT_COUNT)


func _ready() -> void:
	SaveManager.register(SAVE_KEY, self)
	EventBus.day_started.connect(_on_day_started)
	if create_subsystems:
		_create_subsystems()


func _create_subsystems() -> void:
	crafting = CraftingSystem.new()
	crafting.name = "Crafting"
	add_child(crafting)
	knapping = KnappingMinigame.new()
	knapping.name = "Knapping"
	add_child(knapping)
	crafting.knapping = knapping
	build = BuildManager.new()
	build.name = "Build"
	add_child(build)
	drops = DropManager.new()
	drops.name = "Drops"
	add_child(drops)
	ui = InventoryUI.new()
	ui.name = "UI"
	add_child(ui)


# ------------------------------------------------------------ Kern-API

## Fügt Items hinzu. Rückgabe: Rest, der nicht mehr in den Rucksack passte.
func add_item(id: StringName, amount: int = 1) -> int:
	return add_item_ex(id, amount)


## Wie add_item, aber mit expliziter Haltbarkeit (-1 = volle Haltbarkeit) und Alter (Verderben).
func add_item_ex(id: StringName, amount: int, durability: int = -1, age: float = 0.0) -> int:
	if amount <= 0:
		return 0
	var data: ItemData = ItemDB.get_item(id)
	if data == null:
		push_warning("Inventory.add_item: unbekanntes Item '%s'" % id)
		return amount
	var remaining: int = amount
	var dur: int = data.max_durability if durability < 0 else durability
	var max_stack: int = 1 if data.max_durability > 0 else maxi(1, data.max_stack)
	var touched: Array[int] = []
	if max_stack > 1:
		for i in SLOT_COUNT:
			var s: ItemStack = _slots[i]
			if s != null and s.id == id and s.amount < max_stack:
				var n: int = mini(remaining, max_stack - s.amount)
				# Mischalter: gewichteter Durchschnitt, damit frisches Essen nicht "altert" oder verjüngt wird.
				s.age = (s.age * s.amount + age * n) / float(s.amount + n)
				s.amount += n
				remaining -= n
				touched.append(i)
				if remaining == 0:
					break
	if remaining > 0:
		for i in SLOT_COUNT:
			if _slots[i] == null:
				var n: int = mini(remaining, max_stack)
				_slots[i] = ItemStack.create(id, n, dur, age)
				remaining -= n
				touched.append(i)
				if remaining == 0:
					break
	var added: int = amount - remaining
	if added > 0:
		_notify_slots(touched)
		EventBus.item_collected.emit(id, added)
	return remaining


func remove_item(id: StringName, amount: int = 1) -> bool:
	if amount <= 0:
		return true
	if not has_item(id, amount):
		return false
	var remaining: int = amount
	var touched: Array[int] = []
	# Hinten anfangen: Rucksack vor Hotbar, damit Werkzeuge/Ausrüstung möglichst stehen bleiben.
	for i in range(SLOT_COUNT - 1, -1, -1):
		var s: ItemStack = _slots[i]
		if s == null or s.id != id:
			continue
		var n: int = mini(remaining, s.amount)
		s.amount -= n
		remaining -= n
		if s.amount <= 0:
			_slots[i] = null
		touched.append(i)
		if remaining == 0:
			break
	_notify_slots(touched)
	EventBus.item_removed.emit(id, amount)
	return true


func has_item(id: StringName, amount: int = 1) -> bool:
	return count(id) >= amount


func count(id: StringName) -> int:
	var total: int = 0
	for s in _slots:
		if s != null and s.id == id:
			total += s.amount
	return total


## Aktuell ausgerüstetes Item (null = bloße Hände).
func get_equipped() -> ItemData:
	var s: ItemStack = get_equipped_stack()
	return null if s == null else s.data()


## Verringert die Haltbarkeit des ausgerüsteten Werkzeugs; bei 0 zerbricht es.
func damage_equipped(amount: int) -> void:
	var s: ItemStack = get_equipped_stack()
	if s == null or amount <= 0:
		return
	var data: ItemData = s.data()
	if data == null or data.max_durability <= 0:
		return
	s.durability -= amount
	if s.durability <= 0:
		_slots[selected_slot] = null
		EventBus.notification_requested.emit("%s ist zerbrochen." % data.display_name, data.icon)
		EventBus.item_removed.emit(s.id, 1)
		_notify_slots([selected_slot])
	else:
		slot_changed.emit(selected_slot)


# ------------------------------------------------------------ Erweiterte API

func get_slot(index: int) -> ItemStack:
	if index < 0 or index >= SLOT_COUNT:
		return null
	return _slots[index]


func get_equipped_stack() -> ItemStack:
	return _slots[selected_slot]


## Freier Platz für `amount` Stück von `id`?
func can_add(id: StringName, amount: int = 1) -> bool:
	var data: ItemData = ItemDB.get_item(id)
	if data == null:
		return false
	var max_stack: int = 1 if data.max_durability > 0 else maxi(1, data.max_stack)
	var room: int = 0
	for s in _slots:
		if s == null:
			room += max_stack
		elif s.id == id:
			room += max_stack - s.amount
		if room >= amount:
			return true
	return false


func select_slot(index: int) -> void:
	index = clampi(index, 0, HOTBAR_SIZE - 1)
	if index == selected_slot:
		return
	selected_slot = index
	selected_slot_changed.emit(index)
	equipped_changed.emit(get_equipped())


func cycle_slot(step: int) -> void:
	select_slot(posmod(selected_slot + step, HOTBAR_SIZE))


## Verschiebt/tauscht/stapelt Slots (Drag & Drop).
func move_slot(from: int, to: int) -> void:
	if from == to or from < 0 or to < 0 or from >= SLOT_COUNT or to >= SLOT_COUNT:
		return
	var a: ItemStack = _slots[from]
	var b: ItemStack = _slots[to]
	if a == null:
		return
	if b != null and b.id == a.id and b.max_stack() > 1:
		var n: int = mini(a.amount, b.max_stack() - b.amount)
		if n > 0:
			b.age = (b.age * b.amount + a.age * n) / float(b.amount + n)
			b.amount += n
			a.amount -= n
			if a.amount <= 0:
				_slots[from] = null
			_notify_slots([from, to])
			return
	_slots[from] = b
	_slots[to] = a
	_notify_slots([from, to])


## Wirft einen ganzen Slot als Item-Drop in die Welt.
func drop_slot(index: int) -> void:
	var s: ItemStack = get_slot(index)
	if s == null:
		return
	_slots[index] = null
	_notify_slots([index])
	_spawn_drop(s)
	EventBus.item_removed.emit(s.id, s.amount)


## Wirft `amount` Stück von `id` (z. B. Rest, der nicht mehr passt) in die Welt.
func drop_item(id: StringName, amount: int, world_position: Vector2 = Vector2.INF) -> void:
	if amount > 0:
		_spawn_drop(ItemStack.create(id, amount, _full_durability(id)), world_position)


func _spawn_drop(s: ItemStack, world_position: Vector2 = Vector2.INF) -> void:
	if drops == null:
		return
	var pos: Vector2 = world_position
	if pos == Vector2.INF:
		pos = Vector2.ZERO
		if GameState.player != null:
			pos = GameState.player.global_position + Vector2(0, 4)
			var facing: Variant = GameState.player.get("facing")
			if facing is Vector2:
				pos += (facing as Vector2) * 14.0
	ItemDrop.spawn(s.id, s.amount, pos, s.durability, s.age)


func _full_durability(id: StringName) -> int:
	var data: ItemData = ItemDB.get_item(id)
	return 0 if data == null else data.max_durability


## Alle belegten Stapel (nur lesen!).
func get_all_stacks() -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	for s in _slots:
		if s != null:
			out.append(s)
	return out


func clear() -> void:
	for i in SLOT_COUNT:
		_slots[i] = null
	_last_spoil_day = 0
	selected_slot = 0
	for i in SLOT_COUNT:
		slot_changed.emit(i)
	inventory_changed.emit()
	equipped_changed.emit(null)


func _notify_slots(indices: Array[int]) -> void:
	var was_selected: bool = false
	for i in indices:
		slot_changed.emit(i)
		if i == selected_slot:
			was_selected = true
	inventory_changed.emit()
	if was_selected:
		equipped_changed.emit(get_equipped())


# ------------------------------------------------------------ Eingabe (Hotbar)

func _unhandled_input(event: InputEvent) -> void:
	for i in HOTBAR_SIZE:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			select_slot(i)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_slot(-1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_slot(1)


# ------------------------------------------------------------ Verderben

func _on_day_started(day: int) -> void:
	if _last_spoil_day > 0 and day > _last_spoil_day:
		advance_spoilage(day - _last_spoil_day)
	_last_spoil_day = day


## Lässt verderbliche Items um `days` Tage altern (wird bei day_started aufgerufen; auch für Tests).
func advance_spoilage(days: int) -> void:
	var touched: Array[int] = []
	var spoiled_names: Array[String] = []
	var spoiled_icon: Texture2D = null
	for i in SLOT_COUNT:
		var s: ItemStack = _slots[i]
		if s == null:
			continue
		var data: ItemData = s.data()
		if data == null or data.spoil_days <= 0:
			continue
		s.age += days
		if s.age < data.spoil_days:
			slot_changed.emit(i)
			continue
		_slots[i] = null
		if s.id in SPOIL_INTO_SPOILED and ItemDB.has_item(SPOILED_ITEM):
			_slots[i] = ItemStack.create(SPOILED_ITEM, s.amount)
		touched.append(i)
		if not spoiled_names.has(data.display_name):
			spoiled_names.append(data.display_name)
			spoiled_icon = data.icon
		EventBus.item_removed.emit(s.id, s.amount)
	if not touched.is_empty():
		_notify_slots(touched)
		EventBus.notification_requested.emit("Verdorben: %s" % ", ".join(spoiled_names), spoiled_icon)


# ------------------------------------------------------------ Speichern

func get_save_data() -> Dictionary:
	var out: Array = []
	for s in _slots:
		out.append(null if s == null else s.to_dict())
	return {"slots": out, "selected": selected_slot, "last_spoil_day": _last_spoil_day}


func load_save_data(data: Dictionary) -> void:
	var raw: Array = data.get("slots", [])
	for i in SLOT_COUNT:
		_slots[i] = null
		if i < raw.size() and raw[i] is Dictionary:
			var s: ItemStack = ItemStack.from_dict(raw[i])
			if ItemDB.has_item(s.id) and s.amount > 0:
				_slots[i] = s
			elif s.id != &"":
				push_warning("Inventory: unbekanntes Item '%s' im Spielstand verworfen." % s.id)
	selected_slot = clampi(int(data.get("selected", 0)), 0, HOTBAR_SIZE - 1)
	_last_spoil_day = int(data.get("last_spoil_day", 0))
	for i in SLOT_COUNT:
		slot_changed.emit(i)
	inventory_changed.emit()
	selected_slot_changed.emit(selected_slot)
	equipped_changed.emit(get_equipped())
