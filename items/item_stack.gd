class_name ItemStack
extends RefCounted
## Ein belegter Inventar-Slot: Item-ID, Menge, Haltbarkeit (nur Werkzeuge) und Alter in Tagen (Verderben).

var id: StringName = &""
var amount: int = 0
## Verbleibende Haltbarkeit; nur relevant, wenn ItemData.max_durability > 0.
var durability: int = 0
## Tage seit Herstellung/Fund; nur relevant, wenn ItemData.spoil_days > 0.
var age: float = 0.0


static func create(item_id: StringName, count: int, dur: int = 0, item_age: float = 0.0) -> ItemStack:
	var s: ItemStack = ItemStack.new()
	s.id = item_id
	s.amount = count
	s.durability = dur
	s.age = item_age
	return s


func data() -> ItemData:
	return ItemDB.get_item(id)


## Maximale Stapelgröße: Gegenstände mit Haltbarkeit stapeln nie (jeder hat eigenen Verschleiß).
func max_stack() -> int:
	var d: ItemData = data()
	if d == null:
		return 1
	return 1 if d.max_durability > 0 else maxi(1, d.max_stack)


func to_dict() -> Dictionary:
	return {"id": id, "amount": amount, "durability": durability, "age": age}


static func from_dict(d: Dictionary) -> ItemStack:
	return create(StringName(d.get("id", "")), int(d.get("amount", 0)), int(d.get("durability", 0)), float(d.get("age", 0.0)))
