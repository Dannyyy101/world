extends CharacterBody2D
## Top-down 4-direction caveman controller (Godot 4).

@export var speed: float = 60.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var facing := "down"

func _physics_process(_delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input * speed
	move_and_slide()
	_update_animation(input)

func _update_animation(input: Vector2) -> void:
	if input == Vector2.ZERO:
		sprite.play("idle_" + facing)
		return
	# Pick the dominant axis so diagonals don't flicker between directions.
	if abs(input.x) > abs(input.y):
		facing = "right" if input.x > 0 else "left"
	else:
		facing = "down" if input.y > 0 else "up"
	sprite.play("walk_" + facing)
