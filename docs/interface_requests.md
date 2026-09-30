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

[Agent 3 → Agent 0] Player: bitte `var speed_multiplier: float = 1.0` einführen und in `_physics_process` mit `speed` multiplizieren. PlayerStats setzt es (0.55–1.0) bei Hunger/Durst/Kälte/Erschöpfung. Fallback bis dahin: PlayerStats skaliert `Player.speed` direkt.
[Agent 3 → Agent 0] TimeManager: bitte `advance_hours(hours: float) -> void` (öffentlich, löst normale hour_changed-/Zwangsschlaf-Logik aus) für „Kollaps verliert einen halben Tag“. Fallback bis dahin: `skip_to_morning()`.
[Agent 3 → Agent 2] Inventory: bitte `get_worn_clothing() -> Array[ItemData]` (getragene Kleidung). PlayerStats summiert `ItemData.warmth`. Fallback: `fur_clothing` im Inventar zählt als getragen.
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
