class_name DrinkSpot
extends Node2D
## Trinkstelle am Ufer: Interactable, füllt den Durst (PlayerStats.modify(&"thirst", +...)).

signal drunk(position: Vector2)

@export var thirst_gain: float = 25.0
## Kurze Pause zwischen zwei Schlucken (Sekunden) – nur Animationsrhythmus, keine Wartezeit-Mechanik.
@export var sip_pause: float = 0.6

var node_id: String = ""

@onready var _interactable: Interactable = $Interactable
@onready var _splash: CPUParticles2D = $Splash


func _ready() -> void:
	_interactable.prompt_text = "Trinken"
	_interactable.interacted.connect(_on_interacted)


func _on_interacted(_by: Node2D) -> void:
	PlayerStats.modify(&"thirst", thirst_gain)
	_splash.restart()
	_splash.emitting = true
	drunk.emit(global_position)
	_interactable.enabled = false
	get_tree().create_timer(sip_pause).timeout.connect(func() -> void:
		if is_instance_valid(_interactable):
			_interactable.enabled = true
	)
