class_name InventorySlotUI
extends Control
## Ein Inventar-/Hotbar-Slot (20x20 px). Zeichnet Icon, Menge, Haltbarkeitsbalken; unterstützt Drag & Drop,
## Tooltip, Klick (Hotbar-Auswahl) und Rechtsklick (essen).

const SLOT_SIZE: Vector2 = Vector2(20, 20)
const DRAG_TYPE: String = "inventory_slot"

var index: int = 0


func _init(slot_index: int = 0) -> void:
	index = slot_index
	custom_minimum_size = SLOT_SIZE
	size = SLOT_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func refresh() -> void:
	tooltip_text = "x" if Inventory.get_slot(index) != null else ""
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, SLOT_SIZE)
	var selected: bool = index < Inventory.HOTBAR_SIZE and index == Inventory.selected_slot
	draw_rect(rect, Color(0.17, 0.12, 0.09), true)
	draw_rect(rect, Color(0.95, 0.75, 0.3) if selected else Color(0.42, 0.32, 0.21), false, 1.0)
	var font: Font = get_theme_default_font()
	var fs: int = get_theme_default_font_size()
	if index < Inventory.HOTBAR_SIZE:
		draw_string(font, Vector2(2, 7), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(fs - 3, 5), Color(0.6, 0.53, 0.45, 0.8))
	var s: ItemStack = Inventory.get_slot(index)
	if s == null:
		return
	var data: ItemData = s.data()
	if data == null:
		return
	if data.icon != null:
		draw_texture(data.icon, Vector2(2, 2))
	if s.amount > 1:
		draw_string(font, Vector2(2, 19), str(s.amount), HORIZONTAL_ALIGNMENT_RIGHT, SLOT_SIZE.x - 3.0, fs, Color(1, 1, 1))
	if data.max_durability > 0:
		var ratio: float = clampf(float(s.durability) / data.max_durability, 0.0, 1.0)
		draw_rect(Rect2(2, 17, 16, 2), Color(0, 0, 0, 0.7), true)
		draw_rect(Rect2(2, 17, 16.0 * ratio, 2), Color(0.35, 0.8, 0.3).lerp(Color(0.85, 0.25, 0.2), 1.0 - ratio), true)
	if data.spoil_days > 0 and s.age >= data.spoil_days * 0.6:
		draw_rect(Rect2(15, 2, 3, 3), Color(0.55, 0.65, 0.2), true)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return
	var mb: InputEventMouseButton = event
	if mb.button_index == MOUSE_BUTTON_LEFT and index < Inventory.HOTBAR_SIZE:
		Inventory.select_slot(index)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_use()


func _use() -> void:
	var s: ItemStack = Inventory.get_slot(index)
	if s == null:
		return
	var data: ItemData = s.data()
	if data == null or data.category != Enums.ItemCategory.FOOD:
		return
	var before: int = Inventory.count(s.id)
	if PlayerStats.eat(s.id) and Inventory.count(s.id) == before:
		# PlayerStats hat gegessen, aber das Item nicht selbst entfernt.
		Inventory.remove_item(s.id, 1)


func _get_drag_data(_at_position: Vector2) -> Variant:
	var s: ItemStack = Inventory.get_slot(index)
	if s == null or s.data() == null:
		return null
	var preview: TextureRect = TextureRect.new()
	preview.texture = s.data().icon
	preview.modulate = Color(1, 1, 1, 0.8)
	preview.position = Vector2(-8, -8)
	var holder: Control = Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	return {"type": DRAG_TYPE, "from": index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).get("type", "") == DRAG_TYPE


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	Inventory.move_slot(int((data as Dictionary)["from"]), index)


func _make_custom_tooltip(_for_text: String) -> Object:
	var s: ItemStack = Inventory.get_slot(index)
	if s == null or s.data() == null:
		return null
	var d: ItemData = s.data()
	var box: VBoxContainer = VBoxContainer.new()
	var title: Label = Label.new()
	title.text = d.display_name
	title.add_theme_color_override("font_color", Color(0.91, 0.76, 0.44))
	box.add_child(title)
	var desc: Label = Label.new()
	desc.text = d.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(140, 0)
	box.add_child(desc)
	var facts: PackedStringArray = PackedStringArray()
	if d.max_durability > 0:
		facts.append("Haltbarkeit: %d" % s.durability)
	if d.nutrition > 0.0:
		facts.append("Nahrung +%d" % roundi(d.nutrition))
	if d.hydration > 0.0:
		facts.append("Durst +%d" % roundi(d.hydration))
	if d.warmth > 0.0:
		facts.append("Wärme +%d" % roundi(d.warmth))
	if d.spoil_days > 0:
		var left: int = maxi(0, ceili(d.spoil_days - s.age))
		facts.append("Verdirbt in %d Tag%s" % [left, "" if left == 1 else "en"])
	if not facts.is_empty():
		var l: Label = Label.new()
		l.text = " · ".join(facts)
		l.add_theme_color_override("font_color", Color(0.75, 0.68, 0.55))
		box.add_child(l)
	return box
