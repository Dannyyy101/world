class_name FireArt
extends RefCounted
## Platzhalter-Grafik, zur Laufzeit erzeugt (16x16, Pixel-Art-tauglich).
## Ersetzbar: liegt res://fire/art/placeholder/<name>.png, wird diese Datei stattdessen benutzt.

const ART_DIR: String = "res://fire/art/placeholder"

static var _cache: Dictionary = {}


static func campfire(lit: bool) -> Texture2D:
	return _get(&"campfire_lit" if lit else &"campfire_unlit", _paint_campfire.bind(lit))


static func drying_rack() -> Texture2D:
	return _get(&"drying_rack", _paint_rack)


static func kiln(hot: bool) -> Texture2D:
	return _get(&"kiln_hot" if hot else &"kiln_cold", _paint_kiln.bind(hot))


static func _get(key: StringName, painter: Callable) -> Texture2D:
	if _cache.has(key):
		return _cache[key] as Texture2D
	var tex: Texture2D = null
	var path: String = "%s/%s.png" % [ART_DIR, key]
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		painter.call(img)
		tex = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _r(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)


static func _paint_campfire(img: Image, lit: bool) -> void:
	var stone: Color = Color(0.5, 0.5, 0.52)
	var wood: Color = Color(0.42, 0.27, 0.14)
	for p: Vector2i in [Vector2i(2, 11), Vector2i(5, 13), Vector2i(9, 13), Vector2i(12, 11)]:
		_r(img, p.x, p.y, 3, 2, stone)
	_r(img, 3, 10, 10, 2, wood)
	_r(img, 5, 9, 6, 2, Color(0.33, 0.2, 0.1))
	if lit:
		_r(img, 6, 5, 4, 5, Color(0.95, 0.45, 0.1))
		_r(img, 7, 3, 2, 4, Color(0.98, 0.7, 0.15))
		_r(img, 7, 6, 2, 3, Color(1.0, 0.95, 0.5))
	else:
		_r(img, 6, 8, 4, 2, Color(0.15, 0.12, 0.1))


static func _paint_rack(img: Image) -> void:
	var wood: Color = Color(0.45, 0.3, 0.16)
	_r(img, 2, 4, 2, 11, wood)
	_r(img, 12, 4, 2, 11, wood)
	_r(img, 2, 4, 12, 2, wood)
	_r(img, 5, 6, 2, 4, Color(0.65, 0.2, 0.18))
	_r(img, 9, 6, 2, 5, Color(0.6, 0.18, 0.16))


static func _paint_kiln(img: Image, hot: bool) -> void:
	var clay: Color = Color(0.6, 0.4, 0.28)
	_r(img, 2, 6, 12, 9, clay)
	_r(img, 4, 3, 8, 4, clay)
	_r(img, 6, 1, 4, 3, Color(0.5, 0.33, 0.22))
	var mouth: Color = Color(1.0, 0.55, 0.12) if hot else Color(0.12, 0.09, 0.08)
	_r(img, 6, 10, 4, 5, mouth)
