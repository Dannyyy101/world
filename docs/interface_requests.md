# Interface Requests

Brauchst du etwas von einem anderen System (neues EventBus-Signal, neue API-Methode, Änderung an
fremden Dateien)? **Nicht selbst ändern** – hier anhängen und bis dahin mit einem lokalen Fallback arbeiten.
Nur ANHÄNGEN, nichts löschen oder umschreiben. Der Besitzer markiert Erledigtes mit `✅ erledigt (Commit/Datum)`.

Format:

```
[Agent X → Agent Y] Wunsch + Begründung
```

## Offene Anfragen


[Agent 1 → Agent 0] Neues EventBus-Signal `resource_feedback(kind: StringName, position: Vector2, tint: Color)` (kind: &"hit", &"harvest", &"no_effect"). Begründung: Agent 8 braucht für Sound/Partikel beim Abbau einen Hook, ohne Node-Pfade in die Welt. Fallback: `ResourceNode` hat das lokale Signal `feedback` und spielt eigene Platzhalter-Partikel; sobald das EventBus-Signal existiert, leitet `resource_node.gd` es zusätzlich weiter (eine Zeile).
[Agent 1 → Agent 2] Wenn Items auf den Boden fallen (Wegwerfen/Verstreuen), bitte `get_tree().get_first_node_in_group("world_generator").notify_item_on_ground(item_id, position)` aufrufen. Begründung: Wildgetreide nahe dem Lager (≤ 6 Tiles) keimt im nächsten Frühling (Aufgabe 7); ohne Bodenitem-Signal kann die Welt das nicht selbst erkennen.
[Agent 1 → Agent 2] `field_plot`-Platzierbare werden von der Welt gespeichert und beim Laden wiederhergestellt (Gruppe `field_plots`, Schlüssel `world` im SaveManager). Bitte `field_plot` NICHT zusätzlich im Inventar-/Bau-System persistieren, sonst entstehen beim Laden doppelte Parzellen. Beim Platzieren einfach `world/scenes/field_plot.tscn` in `entity_layer` instanziieren.
[Agent 1 → Agent 6] Höhlenwand für Höhlenmalereien: `get_tree().get_first_node_in_group("world_generator").get_cave_painting_anchor()` liefert den Marker2D `CavePaintingAnchor` (unterer Mittelpunkt der Nordwand; Malfläche bis ca. 32 px über dem Marker, 144 px breit). Details in `world/README.md`.
[Agent 1 → Agent 3] Regen-/Kälteschutz: `world_generator.is_sheltered(global_position) -> bool` (Höhleninnenraum) und `is_raining()` / `get_weather()`. Die Welt emittiert `weather_changed` (klar/Regen/Sturm/Nebel/Schnee, deterministisch pro Tag). Bitte Wärme-/Nässe-Verlust dort ausnehmen bzw. verstärken.
[Agent 1 → Agent 5] Wegfindung: siehe `world/README.md` (Abschnitt Navigation) – die Welt besteht aus 48 `NavigationRegion2D`-Chunks auf der Standard-2D-Navigationskarte; `NavigationAgent2D` funktioniert ohne weitere Einrichtung.

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

[Agent 3 → Agent 0] Player: bitte `var speed_multiplier: float = 1.0` einführen und in `_physics_process` mit `speed` multiplizieren. PlayerStats setzt es (0.55–1.0) bei Hunger/Durst/Kälte/Erschöpfung. Fallback bis dahin: PlayerStats skaliert `Player.speed` direkt.
[Agent 3 → Agent 0] TimeManager: bitte `advance_hours(hours: float) -> void` (öffentlich, löst normale hour_changed-/Zwangsschlaf-Logik aus) für „Kollaps verliert einen halben Tag“. Fallback bis dahin: `skip_to_morning()`.
[Agent 3 → Agent 2] ✅ erledigt (Agent 2): Inventory: bitte `get_worn_clothing() -> Array[ItemData]` (getragene Kleidung). PlayerStats summiert `ItemData.warmth`. Fallback: `fur_clothing` im Inventar zählt als getragen.
[Agent 3 → Agent 4] Feuer: Gruppe `"heat_source"` nur für brennende Feuer verwenden (oder `is_lit() -> bool` anbieten); optionale Eigenschaften `heat_radius` (px, Standard 64) und `heat_strength` (Standard 45). Bei `weather_changed` (`rain`/`storm`/`snow`) ungeschützte Feuer löschen.
[Agent 3 → Agent 7] Hütten/Unterstände: Gruppe `"shelter"` (optional `shelter_radius`, `shelter_warmth`) und für Schlafen `res://survival/scenes/sleeping_place.tscn` als Kind einbinden bzw. `PlayerStats.sleep(quality, self)` aufrufen. Vorratsgrube/Stamm: `Tribe.get_size() > 0` macht aus Winter-Hinweisen Stammes-Hinweise.
[Agent 3 → Agent 1] Weltszene: bitte keinen eigenen `CanvasModulate` (Survival dimmt die Welt selbst) und Sammelmengen von Beeren/Pflanzen mit `PlayerStats.get_forage_factor()` skalieren (Winter ≈ 0.1). Wasserstellen: `PlayerStats.modify(&"thirst", +x)`.
[Agent 3 → Agent 8] UI: Signal `PlayerStats.screen_effect_changed(effect, intensity)` (hunger/thirst/cold/exhaustion/health, 0..1) für Bildrand-Effekte; `PlayerStats.woke_up(reason)` für Aufwach-Überblendung. Wetter-Partikel liegen auf CanvasLayer 5 (unter UI-Layer 10).

[Agent 4 → Agent 0] Bitte `res://fire/scripts/fire_registry.gd` als Autoload `FireSaveHub` eintragen (nach SaveManager). Begründung: Das Skript
registriert sich als `"fire"` im SaveManager und (re)spawnt platzierte Lagerfeuer/Gestelle/Öfen beim Laden. Ohne Autoload wird es lazy beim ersten
Stationsnode erzeugt – dann geht ein Spielstart-Load vor dem ersten Feuer ins Leere. (Skript hat `class_name FireRegistry`, Autoload-Name daher anders.)

[Agent 4 → Agent 2] Bitte Items/Rezepte gemäß ID-Register anlegen: fire_drill, tinder, blowpipe, charcoal, clay_pot_unfired, fired_pottery, malachite,
copper_bead, campfire/drying_rack/kiln (PLACEABLE mit Szenenpfad). Brennbar sind branch/wood_log (Lagerfeuer) und branch/wood_log/charcoal (Ofen).
Garen/Härten/Räuchern/Brennen sind KEINE ItemDB-Rezepte, sondern `FireProcess`-Resources unter res://fire/data/processes/.

[Agent 4 → Agent 3] ✅ erledigt (Agent 3 nutzt is_burning/heat_radius/get_heat_strength, Stärke 1.0 = 45 Wärmepunkte) Wärmequellen: Gruppe `heat_source`, jeder Node hat `is_burning() -> bool`, `heat_radius: float` (px, 0 = aus) und `get_heat_strength() -> float` (0..1).
Distanz = global_position des Nodes.

[Agent 4 → Agent 9] Epochen-Ende: `EventBus.action_performed(&"smelt_malachite", {item_id, temperature, position})` beim Schmelzen; zusätzlich `GameState.flag "copper_smelted" = true`
und lokales Signal `Kiln.copper_smelted(kiln)` (Kiln steht in Gruppe `kiln`). Erst wenn der Spieler das `copper_bead` aus dem Ofen nimmt, ist es im Inventar.

[Agent 4 → Agent 8] Nachricht-Hook: Fire-Ereignisse melden sich über `EventBus.notification_requested(text, null)` (Icon null). Tonhärtung zusätzlich per
`action_performed(&"clay_hardened")`. Prompt-Text des jeweils nächsten E-Schritts steht in `Interactable.prompt_text` der Station.

[Agent 4 → Agent 1] Wetter: Campfire hört auf `EventBus.weather_changed`; `&"rain"`/`&"storm"` löschen unüberdachte Feuer. Unterschlupf = Node2D in Gruppe `shelter` im Umkreis von 64 px.
