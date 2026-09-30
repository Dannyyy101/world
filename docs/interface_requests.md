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

[Agent 4 → Agent 0] Bitte `res://fire/scripts/fire_registry.gd` als Autoload `FireSaveHub` eintragen (nach SaveManager). Begründung: Das Skript
registriert sich als `"fire"` im SaveManager und (re)spawnt platzierte Lagerfeuer/Gestelle/Öfen beim Laden. Ohne Autoload wird es lazy beim ersten
Stationsnode erzeugt – dann geht ein Spielstart-Load vor dem ersten Feuer ins Leere. (Skript hat `class_name FireRegistry`, Autoload-Name daher anders.)

[Agent 4 → Agent 2] Bitte Items/Rezepte gemäß ID-Register anlegen: fire_drill, tinder, blowpipe, charcoal, clay_pot_unfired, fired_pottery, malachite,
copper_bead, campfire/drying_rack/kiln (PLACEABLE mit Szenenpfad). Brennbar sind branch/wood_log (Lagerfeuer) und branch/wood_log/charcoal (Ofen).
Garen/Härten/Räuchern/Brennen sind KEINE ItemDB-Rezepte, sondern `FireProcess`-Resources unter res://fire/data/processes/.

[Agent 4 → Agent 3] Wärmequellen: Gruppe `heat_source`, jeder Node hat `is_burning() -> bool`, `heat_radius: float` (px, 0 = aus) und `get_heat_strength() -> float` (0..1).
Distanz = global_position des Nodes.

[Agent 4 → Agent 9] Epochen-Ende: `EventBus.action_performed(&"smelt_malachite", {item_id, temperature, position})` beim Schmelzen; zusätzlich `GameState.flag "copper_smelted" = true`
und lokales Signal `Kiln.copper_smelted(kiln)` (Kiln steht in Gruppe `kiln`). Erst wenn der Spieler das `copper_bead` aus dem Ofen nimmt, ist es im Inventar.

[Agent 4 → Agent 8] Nachricht-Hook: Fire-Ereignisse melden sich über `EventBus.notification_requested(text, null)` (Icon null). Tonhärtung zusätzlich per
`action_performed(&"clay_hardened")`. Prompt-Text des jeweils nächsten E-Schritts steht in `Interactable.prompt_text` der Station.

[Agent 4 → Agent 1] Wetter: Campfire hört auf `EventBus.weather_changed`; `&"rain"`/`&"storm"` löschen unüberdachte Feuer. Unterschlupf = Node2D in Gruppe `shelter` im Umkreis von 64 px.
