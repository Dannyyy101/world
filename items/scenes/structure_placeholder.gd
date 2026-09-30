extends Node2D
## Platzhalter-Bauwerk, solange die echte Szene des Besitzers (fire/, tribe/, world/, animals/) noch fehlt.
## Wird von BuildManager per setup() konfiguriert. Blockiert wie ein echtes Hindernis (Ebene 1).

var structure_id: StringName = &""
var size: Vector2 = Vector2(16, 16)
var color: Color = Color(0.5, 0.4, 0.3)
var icon: Texture2D


func setup(id: StringName, footprint: Vector2, tint: Color, texture: Texture2D) -> void:
	structure_id = id
	size = footprint
	color = tint
	icon = texture
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = footprint
	($Body/Shape as CollisionShape2D).shape = shape
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(-size * 0.5, size)
	draw_rect(rect, color, true)
	draw_rect(rect, color.darkened(0.5), false, 1.0)
	if icon != null:
		draw_texture(icon, -icon.get_size() * 0.5)
