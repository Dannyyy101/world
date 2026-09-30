class_name KnappingMinigame
extends CanvasLayer
## Feuerstein-Schlagen: Eine Nadel schwingt über einen Halbkreis. Im grünen Bereich (Zielwinkel) zuschlagen.
## Drei Schläge pro Versuch, je 0 (daneben) / 1 (gut) / 2 (perfekt) Punkte.
##   Summe >= 5 -> Qualität 2 (perfekt: Bonus-Haltbarkeit), >= 3 -> 1 (gut: Werkzeug), sonst 0 (nur Splitter).
## Mit Übung (Zähler `attempts`, eigener Spielstand-Eintrag "knapping") wird der Zielbereich größer und die Nadel langsamer.
## Emittiert am Ende EventBus.action_performed(&"knap_flint", {"quality": 0–2}) und das lokale Signal `finished`.
## Bedienung: Linksklick / E / Leertaste = zuschlagen, Esc = abbrechen (kostet nichts).

signal finished(quality: int)
signal cancelled()
signal strike_resolved(points: int, index: int)

const SAVE_KEY: String = "knapping"
const STRIKES: int = 3
const AMPLITUDE: float = 70.0 # Grad links/rechts von oben
const PRACTICE_CAP: int = 40 # ab so vielen Versuchen ist die volle Erleichterung erreicht

## Wie lange das Ergebnis nach dem letzten Schlag stehen bleibt (Tests: 0).
var result_delay: float = 1.1
var attempts: int = 0
var perfect_hits: int = 0

var needle_angle: float = 0.0
var target_angle: float = 0.0
var points: Array[int] = []

var _active: bool = false
var _time: float = 0.0
var _finish_in: float = -1.0
var _flash: String = ""
var _flash_time: float = 0.0
var _shake: float = 0.0
var _locked_until_next: float = 0.0
var _sparks: Array[Dictionary] = []
var _prev_input_enabled: bool = true
var _dim: ColorRect
var _view: Control


func _ready() -> void:
	layer = 60
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.register(SAVE_KEY, self)
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.theme = load("res://core/theme/main_theme.tres")
	add_child(_dim)
	_view = Control.new()
	_view.custom_minimum_size = Vector2(220, 150)
	_view.size = Vector2(220, 150)
	_view.position = Vector2(130, 60)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_view)
	_dim.add_child(_view)


# ------------------------------------------------------------ Ablauf

func is_active() -> bool:
	return _active


## 0.0 (Anfänger) … 1.0 (Meister).
func practice() -> float:
	return clampf(float(attempts) / PRACTICE_CAP, 0.0, 1.0)


## Halbe Breite des „guten“ Bereichs in Grad.
func good_half_width() -> float:
	return lerpf(11.0, 24.0, practice())


func perfect_half_width() -> float:
	return good_half_width() * 0.35


## Dauer einer Nadel-Schwingung in Sekunden.
func period() -> float:
	return lerpf(1.5, 2.3, practice())


func start() -> void:
	if _active:
		return
	_active = true
	_time = 0.0
	_finish_in = -1.0
	points.clear()
	_sparks.clear()
	_flash = ""
	_pick_target()
	visible = true
	if GameState.player != null:
		var v: Variant = GameState.player.get("input_enabled")
		_prev_input_enabled = v == null or bool(v)
		GameState.player.set("input_enabled", false)
	_view.queue_redraw()


## Bricht ab, ohne Zutaten zu kosten.
func abort() -> void:
	if not _active:
		return
	_close()
	cancelled.emit()


## Schlag mit der aktuellen Nadelposition. Rückgabe: erreichte Punkte (0–2), -1 wenn gerade nicht möglich.
func strike() -> int:
	return strike_at(needle_angle)


## Schlag bei einem bestimmten Winkel (Tests und interne Nutzung).
func strike_at(angle: float) -> int:
	if not _active or points.size() >= STRIKES or _finish_in >= 0.0:
		return -1
	var dist: float = absf(angle - target_angle)
	var p: int = 0
	if dist <= perfect_half_width():
		p = 2
	elif dist <= good_half_width():
		p = 1
	points.append(p)
	_flash = ["Daneben!", "Gut!", "Perfekt!"][p]
	_flash_time = 0.7
	_shake = 0.18 if p > 0 else 0.3
	_spawn_sparks(p)
	strike_resolved.emit(p, points.size() - 1)
	if points.size() >= STRIKES:
		_finish_in = result_delay
		if result_delay <= 0.0:
			_finalize()
	else:
		_pick_target()
		_locked_until_next = 0.25
	return p


func total_points() -> int:
	var t: int = 0
	for p in points:
		t += p
	return t


static func quality_for(total: int) -> int:
	if total >= 5:
		return 2
	if total >= 3:
		return 1
	return 0


func _pick_target() -> void:
	var limit: float = AMPLITUDE - good_half_width() - 6.0
	target_angle = randf_range(-limit, limit)


func _finalize() -> void:
	var quality: int = quality_for(total_points())
	attempts += 1
	if quality == 2:
		perfect_hits += 1
	_close()
	EventBus.action_performed.emit(&"knap_flint", {"quality": quality})
	finished.emit(quality)


func _close() -> void:
	_active = false
	_finish_in = -1.0
	visible = false
	if GameState.player != null:
		GameState.player.set("input_enabled", _prev_input_enabled)


# ------------------------------------------------------------ Eingabe & Update

func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("pause"):
		abort()
		get_viewport().set_input_as_handled()
		return
	var hit: bool = false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		hit = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventKey:
		var k: InputEventKey = event
		hit = k.pressed and not k.echo and (k.keycode == KEY_SPACE or k.is_action("interact"))
	if hit and _locked_until_next <= 0.0:
		strike()
	if event is InputEventMouseButton or event is InputEventKey:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	_locked_until_next = maxf(0.0, _locked_until_next - delta)
	_flash_time = maxf(0.0, _flash_time - delta)
	_shake = maxf(0.0, _shake - delta)
	needle_angle = AMPLITUDE * sin(TAU * _time / period())
	for s in _sparks:
		s["life"] = float(s["life"]) - delta
		s["pos"] = (s["pos"] as Vector2) + (s["vel"] as Vector2) * delta
		s["vel"] = (s["vel"] as Vector2) + Vector2(0, 160.0) * delta
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return float(s["life"]) > 0.0)
	if _finish_in >= 0.0:
		_finish_in -= delta
		if _finish_in <= 0.0:
			_finalize()
			return
	_view.position = Vector2(130, 60) + (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 2.0 if _shake > 0.0 else Vector2.ZERO)
	_view.queue_redraw()


func _spawn_sparks(p: int) -> void:
	var origin: Vector2 = _dial_center() + _dial_point(needle_angle, 44.0)
	var n: int = [3, 8, 16][p]
	var col: Color = [Color("8a8a90"), Color("f8d84a"), Color("ffffff")][p]
	for i in n:
		_sparks.append({"pos": origin, "vel": Vector2.from_angle(randf() * TAU) * randf_range(20.0, 70.0) + Vector2(0, -30),
				"life": randf_range(0.25, 0.6), "col": col})


# ------------------------------------------------------------ Zeichnen

func _dial_center() -> Vector2:
	return Vector2(110, 112)


func _dial_point(angle_deg: float, radius: float) -> Vector2:
	var a: float = deg_to_rad(angle_deg)
	return Vector2(sin(a), -cos(a)) * radius


func _arc(from_deg: float, to_deg: float, radius: float, color: Color, width: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = maxi(2, int(absf(to_deg - from_deg) / 3.0))
	for i in steps + 1:
		pts.append(_dial_center() + _dial_point(lerpf(from_deg, to_deg, float(i) / steps), radius))
	_view.draw_polyline(pts, color, width)


func _draw_view() -> void:
	var font: Font = _view.get_theme_default_font()
	var fs: int = _view.get_theme_default_font_size()
	# Tafel
	_view.draw_rect(Rect2(Vector2.ZERO, _view.size), Color(0.29, 0.21, 0.15), true)
	_view.draw_rect(Rect2(Vector2.ZERO, _view.size), Color(0.54, 0.42, 0.27), false, 1.0)
	_view.draw_string(font, Vector2(0, 14), "Feuerstein schlagen", HORIZONTAL_ALIGNMENT_CENTER, _view.size.x, fs, Color(0.94, 0.89, 0.77))
	# Skala, Ziel
	_arc(-AMPLITUDE, AMPLITUDE, 56.0, Color(0.16, 0.11, 0.08), 6.0)
	_arc(target_angle - good_half_width(), target_angle + good_half_width(), 56.0, Color(0.35, 0.65, 0.3), 6.0)
	_arc(target_angle - perfect_half_width(), target_angle + perfect_half_width(), 56.0, Color(0.95, 0.85, 0.35), 6.0)
	# Nadel + Stein
	var tip: Vector2 = _dial_center() + _dial_point(needle_angle, 62.0)
	_view.draw_line(_dial_center(), tip, Color(0.94, 0.89, 0.77), 2.0)
	_view.draw_circle(_dial_center(), 11.0, Color(0.2, 0.23, 0.27))
	_view.draw_circle(_dial_center() + Vector2(-3, -3), 4.0, Color(0.35, 0.4, 0.46))
	# Schlag-Anzeige
	for i in STRIKES:
		var c: Color = Color(0.16, 0.11, 0.08)
		if i < points.size():
			c = [Color(0.7, 0.25, 0.2), Color(0.35, 0.65, 0.3), Color(0.95, 0.85, 0.35)][points[i]]
		_view.draw_circle(Vector2(90 + i * 20, 132), 5.0, c)
	# Funken
	for s in _sparks:
		_view.draw_rect(Rect2(s["pos"] as Vector2, Vector2(2, 2)), s["col"] as Color)
	if _flash_time > 0.0:
		_view.draw_string(font, Vector2(0, 34), _flash, HORIZONTAL_ALIGNMENT_CENTER, _view.size.x, fs, Color(1, 1, 1))
	_view.draw_string(font, Vector2(0, 146), "Klick/E/Leertaste · Esc = abbrechen · Übung: %d" % attempts,
			HORIZONTAL_ALIGNMENT_CENTER, _view.size.x, fs - 2 if fs > 6 else fs, Color(0.6, 0.53, 0.45))


# ------------------------------------------------------------ Speichern

func get_save_data() -> Dictionary:
	return {"attempts": attempts, "perfect_hits": perfect_hits}


func load_save_data(data: Dictionary) -> void:
	attempts = int(data.get("attempts", 0))
	perfect_hits = int(data.get("perfect_hits", 0))
