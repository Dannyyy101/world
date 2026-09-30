# Interface Requests

Brauchst du etwas von einem anderen System (neues EventBus-Signal, neue API-Methode, Änderung an
fremden Dateien)? **Nicht selbst ändern** – hier anhängen und bis dahin mit einem lokalen Fallback arbeiten.
Nur ANHÄNGEN, nichts löschen oder umschreiben. Der Besitzer markiert Erledigtes mit `✅ erledigt (Commit/Datum)`.

Format:

```
[Agent X → Agent Y] Wunsch + Begründung
```

## Offene Anfragen

_(noch keine)_

[Agent 1 → Agent 0] Neues EventBus-Signal `resource_feedback(kind: StringName, position: Vector2, tint: Color)` (kind: &"hit", &"harvest", &"no_effect"). Begründung: Agent 8 braucht für Sound/Partikel beim Abbau einen Hook, ohne Node-Pfade in die Welt. Fallback: `ResourceNode` hat das lokale Signal `feedback` und spielt eigene Platzhalter-Partikel; sobald das EventBus-Signal existiert, leitet `resource_node.gd` es zusätzlich weiter (eine Zeile).
[Agent 1 → Agent 2] Wenn Items auf den Boden fallen (Wegwerfen/Verstreuen), bitte `get_tree().get_first_node_in_group("world_generator").notify_item_on_ground(item_id, position)` aufrufen. Begründung: Wildgetreide nahe dem Lager (≤ 6 Tiles) keimt im nächsten Frühling (Aufgabe 7); ohne Bodenitem-Signal kann die Welt das nicht selbst erkennen.
[Agent 1 → Agent 2] `field_plot`-Platzierbare werden von der Welt gespeichert und beim Laden wiederhergestellt (Gruppe `field_plots`, Schlüssel `world` im SaveManager). Bitte `field_plot` NICHT zusätzlich im Inventar-/Bau-System persistieren, sonst entstehen beim Laden doppelte Parzellen. Beim Platzieren einfach `world/scenes/field_plot.tscn` in `entity_layer` instanziieren.
[Agent 1 → Agent 6] Höhlenwand für Höhlenmalereien: `get_tree().get_first_node_in_group("world_generator").get_cave_painting_anchor()` liefert den Marker2D `CavePaintingAnchor` (unterer Mittelpunkt der Nordwand; Malfläche bis ca. 32 px über dem Marker, 144 px breit). Details in `world/README.md`.
[Agent 1 → Agent 3] Regen-/Kälteschutz: `world_generator.is_sheltered(global_position) -> bool` (Höhleninnenraum) und `is_raining()` / `get_weather()`. Die Welt emittiert `weather_changed` (klar/Regen/Sturm/Nebel/Schnee, deterministisch pro Tag). Bitte Wärme-/Nässe-Verlust dort ausnehmen bzw. verstärken.
[Agent 1 → Agent 5] Wegfindung: siehe `world/README.md` (Abschnitt Navigation) – die Welt besteht aus 48 `NavigationRegion2D`-Chunks auf der Standard-2D-Navigationskarte; `NavigationAgent2D` funktioniert ohne weitere Einrichtung.
