class_name BuildGhost
extends Node2D
## Geister-Vorschau für den Bau-Modus: halbtransparente Grundfläche (grün = frei, rot = blockiert) + Item-Icon.

var _size: Vector2 = Vector2(16, 16)
var _icon: Texture2D
var _valid: bool = false


func setup(size: Vector2, icon: Texture2D) -> void:
	_size = size
	_icon = icon
	queue_redraw()


func set_valid(valid: bool) -> void:
	if valid != _valid:
		_valid = valid
		queue_redraw()


func _draw() -> void:
	var col: Color = Color(0.35, 0.8, 0.35) if _valid else Color(0.85, 0.3, 0.25)
	var rect: Rect2 = Rect2(-_size * 0.5, _size)
	draw_rect(rect, Color(col, 0.35), true)
	draw_rect(rect, Color(col, 0.9), false, 1.0)
	if _icon != null:
		draw_texture(_icon, -_icon.get_size() * 0.5, Color(1, 1, 1, 0.75))
