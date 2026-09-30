# player/

**Besitzer:** Agent 0 (Architekt)

Szene `player.tscn`, Skript `player.gd` (`class_name Player`), Grafik `art/` (Platzhalter „Caveman“).

## Öffentliche API (über `GameState.player`)
- `facing: Vector2` – letzte Blickrichtung, normalisiert (8 Richtungen)
- `input_enabled: bool` – UI setzt `false`, solange ein Menü offen ist
- `speed: float`, `tool_reach`, `tool_cooldown`, `tool_hit_duration` (@export)
- `interact() -> bool`, `use_tool() -> bool` (auch für Tests/Gamepad aufrufbar)
- `get_nearest_interactable() -> Interactable` (z. B. für „E: Beeren pflücken“-Prompt)
- Lokales Signal `nearest_interactable_changed(target: Interactable)`

## Verhalten
- **E** (`interact`): nächstes aktives `Interactable` im Radius 20 px → `interacted(by)`.
- **Linksklick** (`use_tool`): liest `Inventory.get_equipped()`; aktiviert `ToolHitbox` (0,12 s) 12 px in
  Blickrichtung mit `damage = tool_power`, `tool_type`; emittiert `EventBus.tool_used(item_id, target_position, facing)`.
  Ohne Werkzeug: bloße Hände (`ToolType.NONE`, Schaden 1, `item_id = &""`).
- Eingaben laufen über `_unhandled_input` (UI-Controls schlucken Klicks zuerst).
- Kamera: `Camera2D` am Player, Pixel-Snapping über Projekteinstellungen.
- Kollision: Layer 2 (player), Maske 1 (world).

## Offene Punkte
- Werkzeug-Animation/Sound/Partikel (Feedback) – Agent 8 kann `tool_used` abonnieren.
- Bewegung läuft noch mit Platzhalter-Sprite (4 Richtungen, je 1 Frame).
