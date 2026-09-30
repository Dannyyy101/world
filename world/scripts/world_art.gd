class_name WorldArt
extends RefCounted
## Platzhalter-Grafik der Welt: Texturen laden, TileSet bauen, Jahreszeiten-Farben.
## Alle Grafiken liegen unter res://world/art/placeholder/ und sind unter gleichem Namen ersetzbar.

const DIR: String = "res://world/art/placeholder/"
const TILE: int = 16

static var _cache: Dictionary = {}
static var _tileset: TileSet = null


## Lädt eine Textur aus dem Platzhalter-Ordner (ohne Endung). Fällt auf direktes
## Bild-Laden zurück, falls die Datei noch nicht importiert wurde.
static func tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path: String = DIR + name + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	if t == null:
		var img: Image = Image.load_from_file(path)
		if img != null:
			t = ImageTexture.create_from_image(img)
	_cache[name] = t
	return t


## TileSet: Quelle 0 = Atlas (4 Varianten je Terrain-Zeile, Schnee in Zeile SNOW_ROW).
## Physik-Layer 0 (Ebene 1 "world"): Wasser und Höhlenwand blockieren.
static func get_tileset() -> TileSet:
	if _tileset != null:
		return _tileset
	var ts: TileSet = TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var src: TileSetAtlasSource = TileSetAtlasSource.new()
	src.texture = tex("tiles_atlas")
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	var half: float = TILE / 2.0
	var square: PackedVector2Array = PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	for row in Biome.TERRAIN_COUNT + 1:
		for col in Biome.VARIANTS:
			src.create_tile(Vector2i(col, row))
			if row < Biome.TERRAIN_COUNT and Biome.is_blocking(row):
				var td: TileData = src.get_tile_data(Vector2i(col, row), 0)
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, square)
	_tileset = ts
	return ts


## Farbton des Bodens je Jahreszeit (Modulate der Boden-Ebene).
static func ground_tint(season: int) -> Color:
	match season:
		Enums.Season.SPRING:
			return Color(0.95, 1.08, 0.92)
		Enums.Season.SUMMER:
			return Color(1.05, 1.02, 0.86)
		Enums.Season.AUTUMN:
			return Color(1.2, 0.95, 0.7)
		_:
			return Color(0.86, 0.9, 1.0)


## Farbton von Pflanzen je Jahreszeit. kind: ResourceNode.Foliage (0 NONE, 1 DECIDUOUS, 2 CONIFER, 3 PLANT)
static func foliage_tint(kind: int, season: int) -> Color:
	match kind:
		1:  # Laubbaum
			match season:
				Enums.Season.SPRING: return Color(0.9, 1.12, 0.85)
				Enums.Season.SUMMER: return Color(1.0, 1.0, 1.0)
				Enums.Season.AUTUMN: return Color(1.75, 0.95, 0.35)
				_: return Color(0.8, 0.74, 0.7)
		2:  # Nadelbaum
			match season:
				Enums.Season.SPRING: return Color(1.0, 1.06, 1.0)
				Enums.Season.SUMMER: return Color(1.0, 1.0, 1.0)
				Enums.Season.AUTUMN: return Color(0.95, 0.95, 0.88)
				_: return Color(1.3, 1.4, 1.55)
		3:  # Kraut/Busch
			match season:
				Enums.Season.SPRING: return Color(0.95, 1.1, 0.9)
				Enums.Season.SUMMER: return Color(1.0, 1.0, 1.0)
				Enums.Season.AUTUMN: return Color(1.3, 0.95, 0.65)
				_: return Color(0.85, 0.85, 0.9)
		_:
			return Color.WHITE
