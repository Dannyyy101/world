class_name Biome
extends RefCounted
## Terrain-/Biom-Typen der Welt. Der Wert entspricht der Zeile im Tile-Atlas
## (res://world/art/placeholder/tiles_atlas.png).
##
## Biome (Landschaft):   MEADOW, DECIDUOUS, CONIFER, FLOODPLAIN, ROCK
## Wasser/Ufer:          BANK (begehbar), WATER (blockiert), FORD (begehbar, flach)
## Höhle:                CAVE_FLOOR, CAVE_WALL (blockiert)

enum Terrain {
	MEADOW,      ## Wiese
	DECIDUOUS,   ## Laubwald
	CONIFER,     ## Nadelwald
	FLOODPLAIN,  ## Flussaue
	ROCK,        ## Felsgebiet
	BANK,        ## Ufer
	WATER,       ## Fluss (nicht begehbar)
	FORD,        ## Furt (begehbar)
	CAVE_FLOOR,
	CAVE_WALL,
}

const TERRAIN_COUNT: int = 10
const VARIANTS: int = 4
## Atlas-Zeile des Schnee-Overlays.
const SNOW_ROW: int = 10

const NAMES: Dictionary = {
	Terrain.MEADOW: "Wiese",
	Terrain.DECIDUOUS: "Laubwald",
	Terrain.CONIFER: "Nadelwald",
	Terrain.FLOODPLAIN: "Flussaue",
	Terrain.ROCK: "Felsgebiet",
	Terrain.BANK: "Ufer",
	Terrain.WATER: "Fluss",
	Terrain.FORD: "Furt",
	Terrain.CAVE_FLOOR: "Höhle",
	Terrain.CAVE_WALL: "Höhlenwand",
}


static func is_blocking(t: int) -> bool:
	return t == Terrain.WATER or t == Terrain.CAVE_WALL


static func is_water(t: int) -> bool:
	return t == Terrain.WATER or t == Terrain.FORD


## Fasst Ufer, Wasser, Furt und Höhle auf die fünf Landschafts-Biome zurück.
static func to_biome(t: int) -> int:
	match t:
		Terrain.BANK, Terrain.WATER, Terrain.FORD:
			return Terrain.FLOODPLAIN
		Terrain.CAVE_FLOOR, Terrain.CAVE_WALL:
			return Terrain.ROCK
		_:
			return t
