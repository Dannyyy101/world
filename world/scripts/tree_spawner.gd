class_name TreeSpawner
extends Node2D
## Verteilt Bäume biomabhängig, aber reproduzierbar (gleicher Seed = gleiche Welt).
## Laubwald -> Laubbäume (dicht), Nadelwald -> Nadelbäume (dicht), Wiese/Flussaue -> vereinzelt Laubbäume,
## Felsgebiet -> vereinzelt Nadelbäume. An den "Trees"-Node hängen (Y Sort Enabled: On).

@export var deciduous_scene: PackedScene
@export var conifer_scene: PackedScene
@export var noise_frequency: float = 0.09  ## kleiner = größere Baumgruppen

## Wahrscheinlichkeit je Zelle (vor Cluster-Rauschen), pro Terrain.
const DENSITY: Dictionary = {
	Biome.Terrain.DECIDUOUS: 0.5,
	Biome.Terrain.CONIFER: 0.5,
	Biome.Terrain.MEADOW: 0.03,
	Biome.Terrain.FLOODPLAIN: 0.07,
	Biome.Terrain.ROCK: 0.04,
}


func clear() -> void:
	for child in get_children():
		child.queue_free()


## Wird vom WorldGenerator aufgerufen, nachdem das Terrain steht.
func spawn(gen: WorldGenerator) -> int:
	clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = gen.world_seed ^ 0x7EE5
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = gen.world_seed + 31
	noise.frequency = noise_frequency
	var rect: Rect2i = gen.map_rect
	var count: int = 0
	for cy in range(rect.position.y, rect.end.y):
		for cx in range(rect.position.x, rect.end.x):
			var cell: Vector2i = Vector2i(cx, cy)
			var t: int = gen.get_terrain_cell(cell)
			var density: float = DENSITY.get(t, 0.0)
			# rng.randf() immer ziehen, damit die Folge unabhängig von der Belegung bleibt
			var roll: float = rng.randf()
			var jx: int = rng.randi_range(-5, 5)
			var jy: int = rng.randi_range(-3, 3)
			if density <= 0.0 or gen.is_occupied(cell):
				continue
			var n: float = (noise.get_noise_2d(cx, cy) + 1.0) * 0.5
			if roll > density * (0.4 + n * 1.2):
				continue
			if _has_occupied_neighbor(gen, cell):
				continue
			var use_conifer: bool = t == Biome.Terrain.CONIFER or t == Biome.Terrain.ROCK
			var scene: PackedScene = conifer_scene if use_conifer else deciduous_scene
			var tree: ResourceNode = scene.instantiate()
			tree.node_id = "tree@%d,%d" % [cx, cy]
			tree.position = (gen.cell_center(cell) + Vector2(jx, 4 + jy)).floor()
			add_child(tree)
			gen.register_node(tree)
			gen.mark_occupied(cell)
			count += 1
	return count


func _has_occupied_neighbor(gen: WorldGenerator, cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and gen.is_occupied(cell + Vector2i(dx, dy)):
				return true
	return false
