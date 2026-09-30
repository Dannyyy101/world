class_name FireDrillMinigame
extends CanvasLayer
## Feuerbohrer-Minispiel: Rhythmus + Durchhalten.
## Ein Marker pendelt über die Leiste; mit E im grünen Bereich "bohren" -> Glut wächst.
## Daneben drücken kostet Glut, ohne Nachlegen kühlt sie ab. tinder macht den Bereich breiter.
## Erfolg = Glut voll. Zeit abgelaufen = Fehlschlag (das Tinder ist dann verbraucht).

signal finished(success: bool)

const TIME_LIMIT: float = 14.0
const BAR_WIDTH: float = 200.0

var use_tinder: bool = false
var marker: float = 0.0
var zone_center: float = 0.5
var zone_half: float = 0.11
var progress: float = 0.0
var time_left: float = TIME_LIMIT

var _dir: float = 1.0
var _speed: float = 0.9
var _done: bool = false
var _flash: float = 0.0
var _flash_color: Color = Color.WHITE
var _canvas: Control
var _player_was_enabled: bool = false


func _ready() -> void:
	layer = 20
	zone_half = 0.17 if use_tinder else 0.11
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_draw)
	add_child(_canvas)
	var player: Object = GameState.player
	if is_instance_valid(player):
		_player_was_enabled = bool(player.get("input_enabled"))
		player.set("input_enabled", false)


func _process(delta: float) -> void:
	if _done:
		return
	time_left -= delta
	marker += _dir * _speed * delta
	if marker >= 1.0:
		marker = 1.0
		_dir = -1.0
	elif marker <= 0.0:
		marker = 0.0
		_dir = 1.0
	progress = maxf(0.0, progress - 0.05 * delta)
	_flash = maxf(0.0, _flash - delta * 3.0)
	if time_left <= 0.0:
		_finish(false)
		return
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("interact"):
		press()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_finish(false)
		get_viewport().set_input_as_handled()


## Ein "Bohr-Stoß". Öffentlich, damit Tests/UI ihn auslösen können.
func press() -> bool:
	if _done:
		return false
	if absf(marker - zone_center) <= zone_half:
		progress += 0.27 if use_tinder else 0.2
		zone_center = randf_range(0.2, 0.8)
		_speed = 0.9 + progress * 0.7
		_flash = 1.0
		_flash_color = Color(0.4, 1.0, 0.4)
		if progress >= 1.0:
			progress = 1.0
			_finish(true)
		return true
	progress = maxf(0.0, progress - 0.12)
	_flash = 1.0
	_flash_color = Color(1.0, 0.35, 0.3)
	return false


func _finish(success: bool) -> void:
	if _done:
		return
	_done = true
	var player: Object = GameState.player
	if is_instance_valid(player):
		player.set("input_enabled", _player_was_enabled)
	finished.emit(success)
	queue_free()


func _on_draw() -> void:
	var size: Vector2 = _canvas.size
	var x0: float = (size.x - BAR_WIDTH) * 0.5
	var y0: float = size.y * 0.72
	_canvas.draw_rect(Rect2(x0 - 6, y0 - 30, BAR_WIDTH + 12, 66), Color(0, 0, 0, 0.7))
	var font: Font = ThemeDB.fallback_font
	_canvas.draw_string(font, Vector2(x0, y0 - 18), "Feuerbohrer: E im grünen Bereich!", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
	# Leiste + Zielzone
	_canvas.draw_rect(Rect2(x0, y0, BAR_WIDTH, 10), Color(0.25, 0.2, 0.15))
	var zx: float = x0 + (zone_center - zone_half) * BAR_WIDTH
	_canvas.draw_rect(Rect2(zx, y0, zone_half * 2.0 * BAR_WIDTH, 10), Color(0.3, 0.7, 0.3))
	_canvas.draw_rect(Rect2(x0 + marker * BAR_WIDTH - 1.0, y0 - 3, 3, 16), _flash_color.lerp(Color.WHITE, 1.0 - _flash))
	# Glut
	_canvas.draw_rect(Rect2(x0, y0 + 20, BAR_WIDTH, 6), Color(0.2, 0.15, 0.12))
	_canvas.draw_rect(Rect2(x0, y0 + 20, BAR_WIDTH * progress, 6), Color(1.0, 0.5, 0.1).lerp(Color(1, 0.9, 0.3), progress))
	# Restzeit
	_canvas.draw_rect(Rect2(x0, y0 + 29, BAR_WIDTH * (time_left / TIME_LIMIT), 2), Color(0.7, 0.7, 0.75))
