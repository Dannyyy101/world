extends Node2D
## Verteilt Bäume zufällig, aber reproduzierbar (gleicher Seed = gleiche Welt).
## An den "Trees"-Node hängen (Y Sort Enabled: On).

@export var tree_scene: PackedScene
@export var ground: TileMapLayer            ## zum Prüfen, ob dort Gras liegt
@export var grass_source_id: int = 0        ## Source-ID von grass_base.png im TileSet

@export_group("Bereich")
@export var area := Rect2(-400, -300, 800, 600)
@export var clear_center := Vector2.ZERO    ## z. B. Spawnpunkt des Players
@export var clear_radius := 48.0            ## hier wachsen keine Bäume

@export_group("Verteilung")
@export var world_seed: int = 12345
@export var attempts: int = 600             ## mehr Versuche = dichter
@export var min_distance := 20.0            ## Mindestabstand zwischen Bäumen
@export var noise_frequency := 0.008        ## kleiner = größere Waldflächen
@export_range(-1.0, 1.0) var forest_threshold := 0.1  ## höher = weniger Wald


func _ready() -> void:
	generate()


func generate() -> void:
	for child in get_children():
		child.queue_free()

	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed

	var noise := FastNoiseLite.new()
	noise.seed = world_seed
	noise.frequency = noise_frequency

	var placed: Array[Vector2] = []
	var min_dist_sq := min_distance * min_distance

	for i in attempts:
		var p := Vector2(
			rng.randf_range(area.position.x, area.end.x),
			rng.randf_range(area.position.y, area.end.y)
		).floor()  # ganze Pixel -> scharfe Pixelart

		# 1. Nur in "Waldgebieten" laut Noise -> natürliche Cluster statt Gleichverteilung
		if noise.get_noise_2dv(p) < forest_threshold:
			continue
		# 2. Spawnbereich freihalten
		if p.distance_to(clear_center) < clear_radius:
			continue
		# 3. Nur auf Gras (nicht im Fluss, nicht auf Wegen)
		if not _is_grass(p):
			continue
		# 4. Mindestabstand zu anderen Bäumen
		var too_close := false
		for q in placed:
			if p.distance_squared_to(q) < min_dist_sq:
				too_close = true
				break
		if too_close:
			continue

		placed.append(p)
		var tree := tree_scene.instantiate()
		tree.position = p
		add_child(tree)


func _is_grass(p: Vector2) -> bool:
	if ground == null:
		return true
	var cell := ground.local_to_map(ground.to_local(to_global(p)))
	return ground.get_cell_source_id(cell) == grass_source_id
