class_name FireStation
extends Node2D
## Gemeinsame Basis für Lagerfeuer, Trockengestell und Ofen (Besitzer: Agent 4).
## Kümmert sich um: Spielzeit-Schritte (auch beim Schlafen), Interactable, Prompt, Registry/Speichern.

const STEP_HOURS: float = 0.05
const MAX_CATCH_UP_HOURS: float = 30.0

@export var prompt_radius: float = 14.0

var _interactable: Interactable
var _sprite: Sprite2D
var _clock: float = 0.0


func _ready() -> void:
	_clock = FireClock.hours()
	_sprite = Sprite2D.new()
	_sprite.texture = _get_texture()
	add_child(_sprite)
	_interactable = Interactable.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = prompt_radius
	shape.shape = circle
	_interactable.add_child(shape)
	_interactable.interacted.connect(_on_interacted)
	add_child(_interactable)
	FireRegistry.track(self)
	_station_ready()


func _exit_tree() -> void:
	FireRegistry.untrack(self)


func _process(_delta: float) -> void:
	var now: float = FireClock.hours()
	var remaining: float = clampf(now - _clock, 0.0, MAX_CATCH_UP_HOURS)
	_clock = now
	while remaining > 0.0:
		var step: float = minf(remaining, STEP_HOURS)
		_advance(step)
		remaining -= step
	_interactable.prompt_text = _get_prompt()
	_sprite.texture = _get_texture()
	queue_redraw()


# --- Für Unterklassen ---------------------------------------------------------

func _station_ready() -> void:
	pass


## Ein Zeitschritt in Spielstunden (<= STEP_HOURS).
func _advance(_dh: float) -> void:
	pass


func _on_interacted(_by: Node2D) -> void:
	pass


func _get_prompt() -> String:
	return "Benutzen"


func _get_texture() -> Texture2D:
	return null


func get_state() -> Dictionary:
	return {}


func set_state(_data: Dictionary) -> void:
	pass


# --- Helfer -------------------------------------------------------------------

func _notify(text: String) -> void:
	EventBus.notification_requested.emit(text, null)


func _item_name(id: StringName) -> String:
	var item: ItemData = ItemDB.get_item(id)
	if item != null and item.display_name != "":
		return item.display_name
	return String(id)


## Legt Items ins Inventar. Rückgabe: Rest, der nicht passte.
func _give(id: StringName, amount: int) -> int:
	return Inventory.add_item(id, amount)


func _draw_bar(center_x: float, y: float, width: float, ratio: float, color: Color) -> void:
	draw_rect(Rect2(center_x - width * 0.5 - 1.0, y - 1.0, width + 2.0, 4.0), Color(0, 0, 0, 0.65))
	draw_rect(Rect2(center_x - width * 0.5, y, width * clampf(ratio, 0.0, 1.0), 2.0), color)
