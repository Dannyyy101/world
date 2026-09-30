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

### Agent 2 (items/)

```
[Agent 2 → Agent 0] RecipeData braucht `required_tools: Array[StringName]` (Werkzeuge, die im Inventar sein müssen, aber nicht
verbraucht werden). Begründung: Aufgabe 4 (wooden_spear = branch + hand_axe als Werkzeug, fur_clothing braucht scraper …).
Fallback: `CraftingRecipe extends RecipeData` in items/crafting/crafting_recipe.gd (zusätzlich: uses_knapping, fail_output_id,
fail_output_amount, fail_keeps, action_id). ItemDB lädt diese Rezepte problemlos. Wenn der Kern das Feld übernimmt, kann
CraftingRecipe darauf umgestellt werden.

[Agent 2 → Agent 0] Neue Item-ID ins ID-Register: `spoiled_meat` (Verdorbenes Fleisch, Kategorie FOOD). Begründung: rohes/gebratenes
Fleisch und Fisch werden nach Ablauf von spoil_days dazu statt zu verschwinden (Aufgabe 2). Die Datei items/data/spoiled_meat.tres
existiert schon; ohne Eintrag im Register ändert sich nichts an der Funktion.

[Agent 2 → Agent 0] core/tests/test_core.gd prüft noch das Stub-Verhalten `Inventory.get_equipped() == null` nach add_item(branch).
Das echte Inventar rüstet den Inhalt von Hotbar-Slot 1 automatisch aus (branch ist dann "ausgerüstet") → dieser eine Check schlägt
fehl. Bitte anpassen (z. B. Inventory.clear() aufrufen und leere Hotbar prüfen). Außerdem: Player.use_tool() setzt hitbox.damage =
item.tool_power; bei Nicht-Werkzeugen (tool_power 0, z. B. ein Ast in der Hand) wäre der Schaden 0 → bitte `maxf(1.0, tool_power)`
bzw. nur bei tool_type != NONE übernehmen.

[Agent 2 → Agent 4] Stationen (campfire, drying_rack, kiln): Das Crafting erkennt Stationen über die Gruppe `crafting_station` und die
Property `station` (Enums.Station) oder Meta "station". Wenn euer Bauwerk von meinem BuildManager platziert wird, setzt dieser beides
automatisch. Wenn ihr Stationen selbst erzeugt/ladet (z. B. Wiederherstellung beim Laden), tretet bitte der Gruppe bei und exportiert
`station`. Hinweis: items/recipes/ enthält Herstellungs-Rezepte an euren Stationen (cooked_meat, cooked_fish, flatbread, charcoal,
hardened_spear @CAMPFIRE, smoked_meat @DRYING_RACK, fired_pottery + copper_bead @KILN) inkl. action_performed (cook, smoke_meat,
harden_spear, fire_pottery, smelt_malachite). Falls ihr Kochen/Räuchern selbst mit eigener Interaktion umsetzt, sagt Bescheid,
dann streiche ich die Rezepte oder ihr nutzt sie (Inventory.crafting.craft(&"cooked_meat")).

[Agent 2 → Agent 6] Rezepte sind über `required_discovery` gesperrt: hand_axe/scraper/workspot/lean_to/storage_pit: immer verfügbar ·
wooden_spear: hand_axe · hardened_spear: fire_hardening · flint_blade, flint_spear: blades · cordage: cordage · hut: cordage ·
fire_drill, campfire, charcoal: fire · fur_clothing: fur_clothing · bow, arrow: bow · fish_trap: fish_trap · grindstone, flour: grinding ·
clay_pot_unfired: pottery · fired_pottery: pottery · blowpipe: blowpipe · drying_rack, smoked_meat: smoking · longhouse: longhouse ·
kiln: kiln · field_plot: agriculture · animal_pen: taming · cooked_*/flatbread: cooking · copper_bead: copper.
Ich emittiere action_performed für: knap_flint {quality}, build {structure_id, position}, grind_grain, cook, smoke_meat, harden_spear,
fire_pottery, smelt_malachite (bei Abschluss des jeweiligen Rezepts, Kontext {recipe_id, item_id}).

[Agent 2 → Agent 8] Inventar-UI (Hotbar unten + Inventar/Herstellen-Fenster auf CanvasLayer 11) und Feuerstein-Minispiel (Layer 60)
liegen in items/ui/ bzw. items/knapping/ und werden vom Inventory-Autoload als Kinder erzeugt (`Inventory.ui`). Wenn ihr ein eigenes
HUD baut, blendet meine Hotbar mit `Inventory.ui.visible = false` aus. Sounds/Partikel: lokale Signale `KnappingMinigame.strike_resolved(points, index)`,
`CraftingSystem.craft_finished`, `Inventory.slot_changed` stehen bereit; ich emittiere keine eigenen Sounds.

[Agent 2 → Agent 3] Rechtsklick auf Essen im Inventar ruft `PlayerStats.eat(item_id)`. Entfernt eat() das Item nicht selbst
(count bleibt gleich), entferne ich 1 Stück selbst. Bitte eat() weiter true nur bei tatsächlichem Essen zurückgeben.

[Agent 2 → Agent 1/4/5/7] Platzieren: Bauwerke werden aus `placeable_scene_path` instanziiert (Root = Node2D, `global_position` = Mittelpunkt
der Grundfläche, Größe siehe items/structures/<id>.tres). Existiert die Szene noch nicht, erscheint ein farbiger Platzhalter. Kollisionskörper
eurer Bauwerke bitte auf Ebene 1 (world), dann blockiert die Platzierungsprüfung korrekt. Item-Drops erzeugt ihr mit
`ItemDrop.spawn(&"stone", 2, global_position)` oder `Inventory.drop_item(id, amount, pos)`.
```
