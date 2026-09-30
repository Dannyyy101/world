class_name Hitbox
extends Area2D
## Schadensbereich (Ebene 5, erkennt Ebene 6). Standardmäßig inaktiv;
## `activate(duration)` schaltet ihn kurz ein. Jede Hurtbox wird pro Aktivierung nur einmal getroffen.

signal hit_landed(hurtbox: Hurtbox)

@export var damage: float = 1.0
@export var tool_type: Enums.ToolType = Enums.ToolType.NONE
## Wer schlägt (z. B. der Player); wird an Hurtbox.hit weitergereicht.
@export var source: Node

const LAYER_HITBOX: int = 1 << 4
const MASK_HURTBOX: int = 1 << 5

var _already_hit: Array[Hurtbox] = []
var _timer: SceneTreeTimer = null


func _init() -> void:
	collision_layer = LAYER_HITBOX
	collision_mask = MASK_HURTBOX
	monitoring = false
	monitorable = false


func _ready() -> void:
	area_entered.connect(_on_area_entered)


## Schaltet die Hitbox für `duration` Sekunden ein.
func activate(duration: float = 0.12) -> void:
	_already_hit.clear()
	set_deferred("monitoring", true)
	_timer = get_tree().create_timer(duration)
	var t: SceneTreeTimer = _timer
	t.timeout.connect(func() -> void:
		if t == _timer:
			deactivate()
	)


func deactivate() -> void:
	_timer = null
	set_deferred("monitoring", false)


func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox and not _already_hit.has(area):
		var hb: Hurtbox = area
		_already_hit.append(hb)
		hb.receive_hit(damage, int(tool_type), source)
		hit_landed.emit(hb)
