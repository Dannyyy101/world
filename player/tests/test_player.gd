extends Node2D
## Isolierter Test des Players: Bewegung, Interaktion (E), Werkzeug (Linksklick).
## Interaktiv: F6 -> WASD laufen, E am gelben Kreis, Linksklick gegen den roten Block.
## Headless: godot --headless --path . res://player/tests/test_player.tscn  (Exit 0 = ok)

var _failures: int = 0
var _interacted: int = 0
var _hurt: int = 0
var _tool_signals: int = 0

@onready var _player: Player = $Player
@onready var _interactable: Interactable = $Interactable
@onready var _hurtbox: Hurtbox = $Dummy/Hurtbox
@onready var _label: Label = $CanvasLayer/Label


func _ready() -> void:
	_interactable.interacted.connect(func(_by: Node2D) -> void: _interacted += 1)
	_hurtbox.hit.connect(func(_d: float, _t: int, _s: Node) -> void: _hurt += 1)
	EventBus.tool_used.connect(func(_i: StringName, _p: Vector2, _f: Vector2) -> void: _tool_signals += 1)
	_label.text = "WASD laufen · E interagieren · Linksklick Werkzeug"
	if DisplayServer.get_name() == "headless":
		_run_checks()


func _check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_failures += 1


func _run_checks() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(GameState.player == _player, "Player registriert sich in GameState.player")
	# Interaktion: Interactable liegt in Reichweite
	_check(_player.get_nearest_interactable() == _interactable, "nächstes Interactable gefunden")
	_check(_player.interact() and _interacted == 1, "interact() löst interacted aus")
	# Werkzeug: Hurtbox liegt 12px unter dem Player (facing = DOWN)
	_check(_player.facing == Vector2.DOWN, "facing startet nach unten")
	_check(_player.use_tool() and _tool_signals == 1, "use_tool() emittiert tool_used")
	for i in 6:
		await get_tree().physics_frame
	_check(_hurt == 1, "Hitbox trifft Hurtbox genau einmal")
	_check(not _player.use_tool(), "Cooldown verhindert sofortigen zweiten Schlag")
	# Bewegung
	Input.action_press("move_right")
	for i in 10:
		await get_tree().physics_frame
	Input.action_release("move_right")
	_check(_player.global_position.x > 1.0 and _player.facing == Vector2.RIGHT, "Bewegung nach rechts + facing")
	print("== ", "ALLE TESTS BESTANDEN" if _failures == 0 else "%d FEHLER" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
