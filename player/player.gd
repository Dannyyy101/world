class_name Player
extends CharacterBody2D
## Spieler (Besitzer: Agent 0).
## - 8-Richtungs-Bewegung, `facing` = letzte Blickrichtung (normalisiert)
## - E: nächstes Interactable in Reichweite benutzen
## - Linksklick: ausgerüstetes Werkzeug (Inventory.get_equipped()) schwingen -> Hitbox + tool_used
## Registriert sich in GameState.player.

## Lokale Signale (für UI-Prompts; keine EventBus-Signale nötig).
signal nearest_interactable_changed(target: Interactable)

@export var speed: float = 60.0
## Abstand der Werkzeug-Hitbox vom Spieler in Blickrichtung (Pixel).
@export var tool_reach: float = 12.0
@export var tool_cooldown: float = 0.35
@export var tool_hit_duration: float = 0.12

## Letzte Blickrichtung, normalisiert (8 Richtungen). Startet nach unten.
var facing: Vector2 = Vector2.DOWN
## UI kann Eingaben sperren (Inventar offen, Dialog ...).
var input_enabled: bool = true

var _anim_dir: String = "down"
var _tool_ready_in: float = 0.0
var _nearest: Interactable = null

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _interaction_area: Area2D = $InteractionArea
@onready var _tool_hitbox: Hitbox = $ToolHitbox


func _ready() -> void:
	GameState.player = self
	_tool_hitbox.source = self


func _exit_tree() -> void:
	if GameState.player == self and is_queued_for_deletion():
		GameState.player = null


func _physics_process(delta: float) -> void:
	_tool_ready_in = maxf(0.0, _tool_ready_in - delta)
	var input: Vector2 = Vector2.ZERO
	if input_enabled:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input * speed
	move_and_slide()
	if input != Vector2.ZERO:
		facing = input.normalized()
	_update_animation(input)
	_update_nearest_interactable()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("use_tool"):
		use_tool()


## Benutzt das nächste Interactable in Reichweite. Rückgabe: true, wenn eins benutzt wurde.
func interact() -> bool:
	var target: Interactable = get_nearest_interactable()
	if target == null:
		return false
	target.interact(self)
	return true


## Nächstes aktiviertes Interactable im Interaktionsradius (oder null).
func get_nearest_interactable() -> Interactable:
	var best: Interactable = null
	var best_dist: float = INF
	for area in _interaction_area.get_overlapping_areas():
		if area is Interactable and (area as Interactable).enabled:
			var d: float = global_position.distance_squared_to(area.global_position)
			if d < best_dist:
				best_dist = d
				best = area
	return best


## Schwingt das ausgerüstete Werkzeug (oder die bloßen Hände) in Blickrichtung.
func use_tool() -> bool:
	if _tool_ready_in > 0.0:
		return false
	_tool_ready_in = tool_cooldown
	var item: ItemData = Inventory.get_equipped()
	var item_id: StringName = &""
	_tool_hitbox.tool_type = Enums.ToolType.NONE
	_tool_hitbox.damage = 1.0
	if item != null:
		item_id = item.id
		_tool_hitbox.tool_type = item.tool_type
		_tool_hitbox.damage = item.tool_power
	_tool_hitbox.position = facing * tool_reach
	_tool_hitbox.activate(tool_hit_duration)
	EventBus.tool_used.emit(item_id, global_position + facing * tool_reach, facing)
	return true


func _update_nearest_interactable() -> void:
	var n: Interactable = get_nearest_interactable()
	if n != _nearest:
		_nearest = n
		nearest_interactable_changed.emit(n)


func _update_animation(input: Vector2) -> void:
	if input == Vector2.ZERO:
		_sprite.play("idle_" + _anim_dir)
		return
	# Dominante Achse wählen, damit Diagonalen nicht flackern.
	if absf(input.x) > absf(input.y):
		_anim_dir = "right" if input.x > 0.0 else "left"
	else:
		_anim_dir = "down" if input.y > 0.0 else "up"
	_sprite.play("walk_" + _anim_dir)
