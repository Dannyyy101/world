class_name ResourceNode
extends Node2D
## Abbaubarer / sammelbarer Ressourcen-Node (Baum, Busch, Stein, Beeren, Pilze, Malachit ...).
## Alle konkreten Szenen erben von res://world/scenes/resources/resource_node.tscn und überschreiben nur Exporte.
##
## HAND: Interactable (E) -> sammeln.    TOOL: Hurtbox -> passendes Werkzeug (required_tool) schlagen.
## Nach dem Abbau ist der Node erschöpft und wächst nach `regrow_days` Tagen nach (-1 = nie).
## Saison-Fenster (`season_windows`) und `required_discovery` steuern, wann er nutzbar/sichtbar ist.
##
## Feedback: Wackler + Partikel (lokal) und das Signal `feedback` als Hook für Agent 8 (Sound/Partikel).

## Ein Abbau ist abgeschlossen (lokaler Hook, kein EventBus).
signal harvested(node: ResourceNode, item_id: StringName, amount: int)
## Treffer/Abbau-Feedback. kind: &"hit" (Treffer), &"harvest" (Abbau), &"no_effect" (falsches Werkzeug).
signal feedback(kind: StringName, world_position: Vector2, tint: Color)

enum Mode { HAND, TOOL }
enum Foliage { NONE, DECIDUOUS, CONIFER, PLANT }

@export_group("Ertrag")
@export var mode: Mode = Mode.HAND
@export var item_id: StringName = &""
@export var amount_min: int = 1
@export var amount_max: int = 1
## Zusätzliche Drops: StringName/String -> Vector2i(min, max).
@export var extra_drops: Dictionary = {}
@export var rare_item_id: StringName = &""
@export_range(0.0, 1.0) var rare_chance: float = 0.0
## Löst bei jedem Abbau EventBus.rare_find(item_id, ...) aus (z. B. Bernstein am Ufer).
@export var announce_as_rare: bool = false
@export var action_id: StringName = &"gather"
@export var prompt_text: String = "Sammeln"

@export_group("Werkzeug")
@export var required_tool: Enums.ToolType = Enums.ToolType.NONE
@export var hit_points: float = 4.0

@export_group("Zustand")
## Tage bis zum Nachwachsen; -1 = wächst nie nach.
@export var regrow_days: int = 5
## Jahreszeit (int) -> Vector2i(erster_tag, letzter_tag) der Jahreszeit, in dem nutzbar. Leer = immer.
@export var season_windows: Dictionary = {}
## Sichtbar/nutzbar erst nach dieser Entdeckung (z. B. &"kiln" für Malachit).
@export var required_discovery: StringName = &""
@export var foliage: Foliage = Foliage.NONE
## Bernstein-Glitzern: Sprite pulsiert.
@export var shimmer: bool = false

@export_group("Aussehen")
@export var texture_full: Texture2D
@export var texture_depleted: Texture2D
@export var texture_off_season: Texture2D
@export var sprite_offset: Vector2 = Vector2.INF
@export var particle_color: Color = Color(0.6, 0.5, 0.3)

@export_group("Kollision")
@export var blocks_movement: bool = false
@export var body_size: Vector2 = Vector2(10, 6)
@export var hurtbox_size: Vector2 = Vector2(14, 16)
@export var interact_radius: float = 14.0

## Stabile ID ("<regel>@x,y"), vom WorldGenerator vergeben; Schlüssel im Speicherstand.
var node_id: String = ""

var _hp: float = 0.0
var _depleted: bool = false
var _regrow_day: int = -1
var _tint_jitter: float = 1.0
var _shimmer_tween: Tween = null
var _hittable: bool = true

@onready var _sprite: Sprite2D = $Sprite
@onready var _body: StaticBody2D = $Body
@onready var _interactable: Interactable = $Interactable
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _particles: CPUParticles2D = $HitParticles


func _ready() -> void:
	add_to_group("world_resources")
	_hp = hit_points
	_tint_jitter = 0.94 + float(hash(node_id if node_id != "" else str(get_instance_id())) % 100) / 100.0 * 0.12
	_setup_shapes()
	_particles.color = particle_color
	_interactable.prompt_text = prompt_text
	_interactable.interacted.connect(_on_interacted)
	_hurtbox.hit.connect(_on_hit)
	refresh_state()


func _setup_shapes() -> void:
	var body_shape: RectangleShape2D = RectangleShape2D.new()
	body_shape.size = body_size
	($Body/CollisionShape2D as CollisionShape2D).shape = body_shape
	($Body/CollisionShape2D as CollisionShape2D).position = Vector2(0, -body_size.y / 2.0)
	($Body/CollisionShape2D as CollisionShape2D).disabled = not blocks_movement
	var hurt_shape: RectangleShape2D = RectangleShape2D.new()
	hurt_shape.size = hurtbox_size
	($Hurtbox/CollisionShape2D as CollisionShape2D).shape = hurt_shape
	($Hurtbox/CollisionShape2D as CollisionShape2D).position = Vector2(0, -hurtbox_size.y / 2.0)
	var int_shape: CircleShape2D = CircleShape2D.new()
	int_shape.radius = interact_radius
	($Interactable/CollisionShape2D as CollisionShape2D).shape = int_shape
	($Interactable/CollisionShape2D as CollisionShape2D).position = Vector2(0, -6)


# --- Zustand -------------------------------------------------------------------------------

func is_depleted() -> bool:
	return _depleted


## Tag, an dem der Node nachwächst (-1 = nicht erschöpft oder wächst nie nach).
func get_regrow_day() -> int:
	return _regrow_day


## Setzt den erschöpften Zustand (Laden). regrow_day = -1 & depleted = true -> nie nachwachsen.
func set_depleted(depleted: bool, regrow_day: int = -1) -> void:
	_depleted = depleted
	_regrow_day = regrow_day
	_hp = hit_points
	refresh_state()


## Ist der Node laut Kalender/Entdeckung gerade nutzbar (unabhängig vom Erschöpft-Zustand)?
func is_in_season() -> bool:
	if season_windows.is_empty():
		return true
	var window: Variant = season_windows.get(int(TimeManager.season), null)
	if window == null:
		return false
	var w: Vector2i = window
	var d: int = TimeManager.get_day_of_season()
	return d >= w.x and d <= w.y


func is_discovered() -> bool:
	return required_discovery == &"" or Discoveries.is_unlocked(required_discovery)


func is_available() -> bool:
	return not _depleted and is_in_season() and is_discovered()


## Wird täglich, bei Jahreszeitenwechsel und bei neuen Entdeckungen aufgerufen (Gruppe "world_resources").
func refresh_state() -> void:
	if not is_node_ready():
		return
	if _depleted and _regrow_day >= 0 and TimeManager.day >= _regrow_day:
		_depleted = false
		_regrow_day = -1
		_hp = hit_points
	var discovered: bool = is_discovered()
	visible = discovered
	var available: bool = is_available()
	var tex: Texture2D = texture_full
	if _depleted:
		tex = texture_depleted
	elif not is_in_season():
		tex = texture_off_season if texture_off_season != null else texture_depleted
	_set_texture(tex)
	var tint: Color = WorldArt.foliage_tint(int(foliage), int(TimeManager.season))
	_sprite.modulate = Color(tint.r * _tint_jitter, tint.g * _tint_jitter, tint.b * _tint_jitter, 1.0)
	_interactable.enabled = available and mode == Mode.HAND
	var hittable: bool = available and mode == Mode.TOOL
	if hittable != _hittable:
		_hittable = hittable
		# deferred: Abbau geschieht meist mitten im Physik-Callback (Hitbox.area_entered)
		_hurtbox.set_deferred("monitorable", hittable)
	_update_shimmer(available)


func _set_texture(tex: Texture2D) -> void:
	_sprite.texture = tex
	if tex == null:
		return
	if sprite_offset != Vector2.INF and tex == texture_full:
		_sprite.offset = sprite_offset
	else:
		_sprite.offset = Vector2(0, -tex.get_height() / 2.0 + 3.0)


func _update_shimmer(available: bool) -> void:
	if not shimmer or available == (_shimmer_tween != null):
		return
	if _shimmer_tween != null:
		_shimmer_tween.kill()
		_shimmer_tween = null
	if available:
		_shimmer_tween = create_tween().set_loops()
		_shimmer_tween.tween_property(_sprite, "self_modulate:a", 0.55, 0.7)
		_shimmer_tween.tween_property(_sprite, "self_modulate:a", 1.0, 0.7)
	else:
		_sprite.self_modulate.a = 1.0


# --- Abbau ---------------------------------------------------------------------------------

func _on_interacted(_by: Node2D) -> void:
	if mode == Mode.HAND and is_available():
		_harvest()


func _on_hit(damage: float, tool_type: int, _source: Node) -> void:
	if mode != Mode.TOOL or not is_available():
		return
	if required_tool != Enums.ToolType.NONE and tool_type != int(required_tool):
		_wobble(0.5)
		feedback.emit(&"no_effect", global_position, particle_color)
		return
	_hp -= maxf(damage, 0.0)
	Inventory.damage_equipped(1)
	_wobble(1.0)
	_burst(4)
	feedback.emit(&"hit", global_position, particle_color)
	if _hp <= 0.0:
		_harvest()


func _harvest() -> void:
	var amount: int = randi_range(amount_min, maxi(amount_min, amount_max))
	var gained: int = 0
	if item_id != &"" and amount > 0:
		var rest: int = Inventory.add_item(item_id, amount)
		gained = amount - rest
		if gained <= 0:
			EventBus.notification_requested.emit("Inventar voll", null)
			_hp = hit_points
			return
	for key in extra_drops:
		var range_v: Vector2i = extra_drops[key]
		var n: int = randi_range(range_v.x, maxi(range_v.x, range_v.y))
		if n > 0:
			Inventory.add_item(StringName(key), n)
	if rare_item_id != &"" and randf() < rare_chance:
		Inventory.add_item(rare_item_id, 1)
		EventBus.rare_find.emit(rare_item_id, global_position)
	if announce_as_rare and item_id != &"":
		EventBus.rare_find.emit(item_id, global_position)
	EventBus.action_performed.emit(action_id, {"item": item_id, "position": global_position, "node_id": node_id})
	harvested.emit(self, item_id, gained)
	feedback.emit(&"harvest", global_position, particle_color)
	_burst(10)
	_wobble(1.4)
	_depleted = true
	_regrow_day = TimeManager.day + regrow_days if regrow_days >= 0 else -1
	refresh_state()


# --- Feedback ------------------------------------------------------------------------------

func _wobble(strength: float) -> void:
	if not is_inside_tree():
		return
	var tw: Tween = create_tween()
	var s: float = 1.5 * strength
	tw.tween_property(_sprite, "position:x", s, 0.04)
	tw.tween_property(_sprite, "position:x", -s, 0.06)
	tw.tween_property(_sprite, "position:x", s * 0.5, 0.05)
	tw.tween_property(_sprite, "position:x", 0.0, 0.05)


func _burst(n: int) -> void:
	_particles.amount = maxi(n, 1)
	_particles.restart()
	_particles.emitting = true
