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
