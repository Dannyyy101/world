class_name FieldPlot
extends Node2D
## Ackerparzelle (placeable `field_plot`, Jungsteinzeit). Nach der Entdeckung `agriculture` nutzbar.
##
## Ablauf mit E: Hacken (braucht hand_axe im Inventar) -> Säen (1 wild_grain) -> Gießen -> Ernte.
## Wachstum: pro Tag +1, wenn die Parzelle an diesem Tag gegossen wurde oder es geregnet hat.
## Trockene Tage kosten nur Zeit – die Pflanze stirbt nie (Druck ja, Frust nein).
## Gießen von Hand braucht ein Gefäß (fired_pottery, wird nicht verbraucht); Regen ist gratis.

signal state_changed(state: int)

enum State { UNTILLED, TILLED, GROWING, RIPE }

const GROW_DAYS: int = 6

var state: State = State.UNTILLED
var growth: int = 0
var watered: bool = false

@onready var _sprite: Sprite2D = $Sprite
@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	add_to_group("field_plots")
	_interactable.interacted.connect(_on_interacted)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.weather_changed.connect(_on_weather_changed)
	_hook_discoveries()
	_refresh()


func _hook_discoveries() -> void:
	EventBus.discovery_unlocked.connect(func(_id: StringName) -> void: _refresh())


func _is_raining() -> bool:
	for node in get_tree().get_nodes_in_group("world_generator"):
		if node.has_method("is_raining"):
			return node.call("is_raining")
	return false


func _on_weather_changed(weather: StringName) -> void:
	if state == State.GROWING and (weather == &"rain" or weather == &"storm"):
		watered = true
		_refresh()


func _on_day_ended(_day: int) -> void:
	if state != State.GROWING:
		return
	if watered or _is_raining():
		growth += 1
		if growth >= GROW_DAYS:
			state = State.RIPE
			state_changed.emit(int(state))
	watered = false
	_refresh()


func _on_interacted(_by: Node2D) -> void:
	if not Discoveries.is_unlocked(&"agriculture"):
		return
	match state:
		State.UNTILLED:
			if Inventory.has_item(&"hand_axe"):
				_set_state(State.TILLED)
			else:
				EventBus.notification_requested.emit("Zum Hacken fehlt ein Werkzeug", null)
		State.TILLED:
			if Inventory.remove_item(&"wild_grain", 1):
				growth = 0
				watered = false
				_set_state(State.GROWING)
				EventBus.action_performed.emit(&"plant_seed", {"position": global_position, "field": true})
			else:
				EventBus.notification_requested.emit("Du hast kein Saatgut (Wildgetreide)", null)
		State.GROWING:
			if watered or _is_raining():
				return
			if Inventory.has_item(&"fired_pottery"):
				watered = true
				_refresh()
			else:
				EventBus.notification_requested.emit("Regen hilft – oder ein Gefäß zum Gießen", null)
		State.RIPE:
			var amount: int = randi_range(4, 6)
			var rest: int = Inventory.add_item(&"wild_grain", amount)
			if rest >= amount:
				EventBus.notification_requested.emit("Inventar voll", null)
				return
			EventBus.action_performed.emit(&"gather", {"item": &"wild_grain", "field": true, "position": global_position})
			growth = 0
			_set_state(State.TILLED)


func _set_state(s: State) -> void:
	state = s
	state_changed.emit(int(s))
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	var tex_name: String = "field_untilled"
	var prompt: String = "Hacken"
	match state:
		State.UNTILLED:
			tex_name = "field_untilled"
			prompt = "Boden hacken"
		State.TILLED:
			tex_name = "field_tilled"
			prompt = "Säen"
		State.GROWING:
			var third: int = mini(2, growth * 3 / GROW_DAYS)
			tex_name = "field_stage%d" % (1 + mini(third, 1))
			prompt = "Gießen"
			if watered or _is_raining():
				prompt = "Bewässert"
		State.RIPE:
			tex_name = "field_ripe"
			prompt = "Ernten"
	_sprite.texture = WorldArt.tex(tex_name)
	_sprite.modulate = Color(0.75, 0.85, 1.0) if (state == State.GROWING and watered) else Color.WHITE
	_interactable.prompt_text = prompt
	_interactable.enabled = Discoveries.is_unlocked(&"agriculture")


func get_save_data() -> Dictionary:
	return {"position": global_position, "state": int(state), "growth": growth, "watered": watered}


func apply_save_data(data: Dictionary) -> void:
	state = int(data.get("state", 0)) as State
	growth = int(data.get("growth", 0))
	watered = bool(data.get("watered", false))
	_refresh()
