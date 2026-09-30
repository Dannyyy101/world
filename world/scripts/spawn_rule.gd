class_name SpawnRule
extends Resource
## Platzierungsregel für Ressourcen-Nodes (.tres unter res://world/data/spawn_rules/).
## Der WorldGenerator liest alle Regeln und streut die Szenen deterministisch (Seed-abhängig).

## Kurzname, Teil der stabilen Node-ID ("<id>@x,y").
@export var id: StringName = &""
@export var scene: PackedScene
## Erlaubte Terrain-Typen (Biome.Terrain).
@export var terrains: Array[int] = []
## Zielanzahl über die ganze Karte.
@export var count: int = 20
## Mindestabstand zwischen zwei Nodes dieser Regel (in Tiles).
@export var min_spacing: float = 3.0
## Nur Zellen mit Abstand ≤ max_water_dist (Tiles) zum Wasser; -1 = egal.
@export var max_water_dist: int = -1
## Nur Zellen mit Abstand ≥ min_water_dist zum Wasser.
@export var min_water_dist: int = 0
## > 1: es entstehen Gruppen (Cluster) mit dieser Größe; count = Anzahl Nodes insgesamt.
@export var cluster_size: int = 1
## Radius (Tiles) eines Clusters.
@export var cluster_radius: float = 2.0
