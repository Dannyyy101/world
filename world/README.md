# world/

**Besitzer:** Agent 1

Vom Architekten übernommen/verschoben (ab jetzt Agent 1):
- `scenes/world.tscn` – TileMapLayer + `Objects` (y-sortiert, Gruppe **`entity_layer`**) mit `Trees`
- `scripts/tree_spawner.gd` – deterministischer Baumgenerator (Seed, Noise-Wälder, Mindestabstand)
- `scenes/tree.tscn` – Baum (StaticBody2D, Ebene 1 „world“)
- `art/` – Platzhalter-Grafik (Gras-Tileset, Baum)

Der Player wird von `main.gd` in den Node der Gruppe `entity_layer` eingehängt (damit Y-Sortierung mit
Bäumen/Tieren funktioniert). **Bitte den Node mit dieser Gruppe in der Welt-Szene behalten.**

Bäume haben noch keine `Hurtbox` / kein `world_generated`-Signal – Aufgabe von Agent 1.
