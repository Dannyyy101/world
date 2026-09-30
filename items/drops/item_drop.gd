class_name ItemDrop
extends Node2D
## Aufsammelbares Item in der Welt: hüpft beim Erscheinen, schwebt leicht und wird vom Spieler angezogen.
## Erzeugen: ItemDrop.spawn(&"stone", 2, position)  (hängt sich in die Gruppe "entity_layer").

const SCENE_PATH: String = "res://items/drops/item_drop.tscn"
const GROUP: StringName = &"item_drops"
const GRAVITY: float = 260.0

var item_id: StringName = &""
var amount: int = 1
var durability: int = 0
var age: float = 0.0

## Ab diesem Abstand zum Spieler wird das Item angezogen (Pixel).
var magnet_radius: float = 34.0
var pickup_radius: float = 5.0
## Sekunden nach dem Erscheinen, in denen es nicht aufgehoben werden kann (damit man den Hüpfer sieht).
var pickup_delay: float = 0.5

var _time: float = 0.0
var _z: float = 0.0
var _vz: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _bounces: int = 0
var _pull_speed: float = 0.0
var _retry_in: float = 0.0
var _sprite: Sprite2D
var _shadow: Sprite2D
var _label: Label


## Erzeugt einen Drop. `parent` = null: y-sortierte Objektebene der Welt oder aktuelle Szene.
## hop = false: Item liegt sofort still (beim Laden eines Spielstands).
static func spawn(id: StringName, count: int, pos: Vector2, dur: int = 0, item_age: float = 0.0,
		hop: bool = true, parent: Node = null) -> ItemDrop:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if parent == null:
		parent = tree.get_first_node_in_group("entity_layer")
	if parent == null:
		parent = tree.current_scene
	if parent == null:
		return null
	var drop: ItemDrop = (load(SCENE_PATH) as PackedScene).instantiate()
	drop.item_id = id
	drop.amount = count
	drop.durability = dur
	drop.age = item_age
	parent.add_child(drop)
	drop.global_position = pos
	if hop:
		drop.launch()
	return drop


func _ready() -> void:
	add_to_group(GROUP)
	_shadow = Sprite2D.new()
	_shadow.texture = _make_shadow_texture()
	_shadow.modulate = Color(0, 0, 0, 0.35)
	add_child(_shadow)
	_sprite = Sprite2D.new()
	var data: ItemData = ItemDB.get_item(item_id)
	if data != null:
		_sprite.texture = data.icon
	add_child(_sprite)
	_label = Label.new()
	_label.theme = load("res://core/theme/main_theme.tres")
	_label.position = Vector2(2, -4)
	add_child(_label)
	_update_label()
	_update_visual()


## Hüpft mit zufälliger Richtung heraus.
func launch(direction: Vector2 = Vector2.ZERO) -> void:
	var dir: Vector2 = direction if direction != Vector2.ZERO else Vector2.from_angle(randf() * TAU)
	_velocity = dir.normalized() * randf_range(14.0, 30.0)
	_vz = randf_range(70.0, 100.0)
	_z = 0.1
	_bounces = 0


func _process(delta: float) -> void:
	_time += delta
	_retry_in = maxf(0.0, _retry_in - delta)
	if _z > 0.0 or _vz > 0.0:
		_vz -= GRAVITY * delta
		_z += _vz * delta
		global_position += _velocity * delta
		if _z <= 0.0:
			_z = 0.0
			if _bounces < 2 and absf(_vz) > 20.0:
				_vz = -_vz * 0.45
				_velocity *= 0.5
				_bounces += 1
			else:
				_vz = 0.0
				_velocity = Vector2.ZERO
	_update_visual()
	if _time >= pickup_delay:
		_try_magnet(delta)


func _try_magnet(delta: float) -> void:
	var player: Node2D = GameState.player
	if player == null or _retry_in > 0.0:
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()
	if dist > magnet_radius:
		_pull_speed = 0.0
		return
	if not Inventory.can_add(item_id, 1):
		return
	_pull_speed = minf(_pull_speed + 320.0 * delta, 140.0)
	global_position += to_player.normalized() * minf(_pull_speed * delta, dist)
	if dist <= pickup_radius:
		_collect()


func _collect() -> void:
	var rest: int = Inventory.add_item_ex(item_id, amount, durability if durability > 0 else -1, age)
	if rest <= 0:
		queue_free()
		return
	amount = rest
	_retry_in = 1.0
	_update_label()


func _update_visual() -> void:
	var bob: float = 0.0
	if _z <= 0.0:
		bob = sin(_time * 3.0) * 1.0
	_sprite.position = Vector2(0, -6.0 - _z - bob)
	var s: float = clampf(1.0 - _z / 80.0, 0.5, 1.0)
	_shadow.scale = Vector2(s, s)


func _update_label() -> void:
	_label.text = str(amount) if amount > 1 else ""


func _make_shadow_texture() -> Texture2D:
	var img: Image = Image.create(10, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 4:
		for x in 10:
			var dx: float = (x + 0.5 - 5.0) / 5.0
			var dy: float = (y + 0.5 - 2.0) / 2.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)
