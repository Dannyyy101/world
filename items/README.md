# items/ – Items, Inventar, Crafting & Bauen

**Besitzer:** Agent 2

## Was gebaut wurde
| Bereich | Dateien |
|---|---|
| Daten | `data/*.tres` (53 `ItemData`, alle IDs des Registers + `spoiled_meat`), `recipes/*.tres` (33 Rezepte), `structures/*.tres` (Grundfläche/Station je Bauwerk), `art/placeholder/item_<id>.png` (16×16) |
| Inventar | `inventory.gd` (Autoload, ersetzt den Stub), `item_stack.gd` |
| Crafting | `crafting/crafting_system.gd` (`Inventory.crafting`), `crafting/crafting_recipe.gd` (RecipeData + `required_tools` …) |
| Feuerstein schlagen | `knapping/knapping_minigame.gd` (`Inventory.knapping`) |
| Bauen | `build/build_manager.gd` (`Inventory.build`), `build/build_ghost.gd`, `scenes/workspot.tscn`, `scenes/structure_placeholder.tscn` |
| Drops | `drops/item_drop.gd/.tscn`, `drops/drop_manager.gd` |
| UI | `ui/inventory_ui.gd` (Hotbar + Fenster, `Inventory.ui`), `ui/slot_ui.gd` |
| Generator | `tools/generate_data.gd` – erzeugt Icons + alle `.tres` (Werte dort ändern und neu erzeugen, Aufruf im Skriptkopf) |
| Test | `tests/test_items.tscn` |

## Bedienung im Spiel
`1`–`9`/Mausrad: Hotbar · `I`: Inventar & Herstellen · Drag & Drop zum Sortieren/Stapeln, aus dem Fenster ziehen = wegwerfen ·
Rechtsklick auf Essen = essen · Platzierbares in der Hand: Geist am Raster (grün/rot), Linksklick platziert ·
E am Werkplatz öffnet das Herstellen-Menü · Feuerstein-Rezepte starten das Minispiel (Klick/E/Leertaste, Esc = abbrechen).

## Öffentliche API (Autoload `Inventory`)
```gdscript
Inventory.add_item(id, amount) -> int          # Rest, der nicht passte
Inventory.remove_item(id, amount) -> bool
Inventory.has_item(id, amount := 1) -> bool
Inventory.count(id) -> int
Inventory.get_equipped() -> ItemData           # null = Hände
Inventory.damage_equipped(amount)              # bei 0 zerbricht das Werkzeug
# zusätzlich
Inventory.add_item_ex(id, amount, durability := -1, age := 0.0) -> int
Inventory.can_add(id, amount := 1) -> bool
Inventory.get_slot(i) -> ItemStack             # null = leer; Slots 0–8 = Hotbar, 24 gesamt
Inventory.select_slot(i) / cycle_slot(step) / selected_slot / get_equipped_stack()
Inventory.move_slot(from, to) / drop_slot(i) / drop_item(id, amount, pos := INF)
Inventory.advance_spoilage(days)               # passiert automatisch bei day_started
Inventory.crafting: CraftingSystem  ·  .knapping: KnappingMinigame  ·  .build: BuildManager  ·  .ui: InventoryUI
```
`CraftingSystem`: `get_visible_recipes()`, `can_craft(recipe)`, `craft(recipe_id) -> bool`, `cancel()`, `get_stations_in_reach()`,
`missing_inputs/missing_tools(recipe)`, Signale `craft_started/craft_progressed/craft_finished/craft_cancelled`.
`BuildManager`: `place(id, center) -> bool`, `check_placement(id, center)`, `get_structures()`, Signal `structure_added`.
`ItemDrop.spawn(id, amount, position)` (statisch).

Lokale Signale von `Inventory`: `slot_changed(index)`, `inventory_changed`, `selected_slot_changed(index)`, `equipped_changed(item)`.

## EventBus
**Emittiert:** `item_collected`, `item_removed` (Inventory) · `item_crafted` (Crafting) · `structure_placed` (Bau) ·
`action_performed`: `knap_flint {quality 0–2}`, `build {structure_id, position}`, und bei Rezeptabschluss `grind_grain`, `cook`,
`smoke_meat`, `harden_spear`, `fire_pottery`, `smelt_malachite` · `notification_requested` (Werkzeug zerbrochen, Essen verdorben).
**Hört auf:** `day_started` (Verderben), `tool_used` (Platzieren im Bau-Modus), `discovery_unlocked` (Rezeptliste).

## Regeln, die im Code stecken
- Rezepte erscheinen nur bei erfüllter `required_discovery` **und** Station in Reichweite (40 px; Gruppe `crafting_station`, Property/Meta `station`).
- Zutaten werden erst beim Abschluss verbraucht; Abbrechen kostet nichts. Werkzeuge (`required_tools`) werden nicht verbraucht.
- Feuerstein schlagen: 3 Schläge, Summe ≥5 perfekt (Haltbarkeit ×1,5), ≥3 gut, sonst nur Splitter (Schlagstein bleibt). Zielbereich wächst
  und Nadel wird langsamer mit Übung (40 Versuche = Maximum).
- Werkzeuge mit Haltbarkeit stapeln nie. Verderben: `spoil_days` je Item; rohes/gebratenes Fleisch und Fisch → `spoiled_meat`, sonst weg.

## Speicherstände (SaveManager-Keys)
`inventory` (Slots, Haltbarkeit, Alter, Auswahl) · `knapping` (Übungszähler) · `structures` (platzierte Bauwerke: ID + Position, werden
beim Laden neu instanziiert) · `item_drops` (liegende Items).

## Tests
`godot --headless --path . res://items/tests/test_items.tscn` (Exit 0 = ok, ~100 Prüfungen). Ohne `--headless` (F6): Startausrüstung,
alle Entdeckungen freigeschaltet, zwei Drops zum Einsammeln.
Voraussetzung nach frischem Checkout: einmal `godot --headless --path . --import`.

## Offene Punkte
- Sounds/Partikel für Sammeln/Herstellen/Schlagen: Agent 8 (Hooks: siehe `docs/interface_requests.md`).
- `RecipeData.required_tools` im Kern (Antrag gestellt); bis dahin `CraftingRecipe`.
- `core/tests/test_core.gd` prüft noch das Stub-Verhalten (`get_equipped() == null`), siehe Antrag.
- Bauwerks-Szenen der anderen Agents fehlen noch → Platzhalter. Kein Abreißen/Aufheben platzierter Bauwerke.
- Platzierte Bauwerke ohne Kollisionskörper auf Ebene 1 werden nur gegen andere Bauwerke geprüft.
