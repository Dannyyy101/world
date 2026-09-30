# survival/ – Überleben, Wetter & Jahreszeiten-Druck

**Besitzer:** Agent 3 · Autoload `PlayerStats` (`survival/player_stats.gd`) ersetzt den Stub, Signaturen unverändert.

## Was gebaut wurde
| Datei | Inhalt |
|---|---|
| `player_stats.gd` | Autoload: 5 Stats, Temperaturmodell, Konsequenzen, Kollaps, Schlaf, Speichern, Debug-Befehle |
| `weather_system.gd` | `WeatherSystem` – Wetter je Jahreszeit gewichtet (Kind von PlayerStats: `PlayerStats.weather`) |
| `day_night_cycle.gd` | `DayNightCycle` (CanvasModulate) – Tageszeit-, Wetter- und Jahreszeitenfarbe der Welt |
| `weather_effects.gd` | `WeatherEffects` (CanvasLayer 5) – Regen/Schnee-Partikel, Nebel-Shader |
| `winter_hints.gd` | `WinterHints` – Winter-Hinweise ab Herbstmitte |
| `sleeping_place.gd` + `scenes/sleeping_place.tscn` | Schlafplatz (Höhle/Hütte/Unterstand), Gruppen `shelter` + `sleeping_place` |
| `tests/test_survival.tscn` | Testszene (interaktiv + headless) |

Kinder-Nodes werden von `PlayerStats._ready()` selbst erzeugt – es ist kein weiterer Autoload und keine Änderung an fremden Dateien nötig.

## Stats & Regeln
Stats `&"health"`, `&"hunger"`, `&"thirst"`, `&"warmth"`, `&"energy"` (0–100). Alle Raten pro **Spielstunde** (Konstanten oben in `player_stats.gd`).
- Hunger −2/h, Durst −3/h, Energie −3,5/h; ×1,5 (Energie ×1,3) bei Bewegung; Hunger ×1,25 bei Kälte (<40 Wärme).
- **Wärme** strebt einer Zieltemperatur zu: Jahreszeit-Basis (Frühling 55, Sommer 80, Herbst 42, Winter 12) − Nachtkälte − Wettermalus
  (Regen −12, Sturm −20, Schnee −10, Nebel −4) + Feuer + Unterschlupf + Kleidung.
  - Feuer: Nodes der Gruppe `"heat_source"` (und alle per `fire_lit` gemeldeten). Optionale Eigenschaften am Node:
    `heat_radius` (64), `heat_strength` (45), Methode `is_lit() -> bool`.
  - Unterschlupf: Nodes der Gruppe `"shelter"`, optional `shelter_radius` (40), `shelter_warmth` (18). Im Unterschlupf entfällt der Wettermalus.
  - Kleidung: siehe interface_requests (bis dahin zählt `fur_clothing` im Inventar mit `ItemData.warmth`, Fallback 25).
- **Konsequenzen:** unter 30 → einmalige Warnung (`notification_requested`), Bildrand-Effekt, Verlangsamung bis ×0,55.
  Wert 0 → Gesundheit −3/h je leerem Wert (Energie 0: halb so viel). Gut versorgt (Hunger/Durst >50, Wärme >40) → +1,5/h.
- **Kollaps** (Gesundheit 0): `player_collapsed(&"starvation" | &"dehydration" | &"exposure" | &"exhaustion")`, 35 % der Material-/Nahrungsvorräte
  gehen verloren (nie Werkzeug/Waffen/Kleidung), ein halber Tag vergeht, Aufwachen am Lager (`GameState.camp_position`) bzw. am ersten
  `sleeping_place`, Werte teilweise wiederhergestellt. Kein Spielstandverlust.
- `player_collapsed(&"forced_sleep")` (TimeManager, 2:00) → unruhiger Schlaf: Energie mind. 60, Hunger/Durst sinken etwas.
- **Wetter:** Regen/Sturm/Schnee/Nebel/klar, Dauer 3–8 Spielstunden, Gewichte je Jahreszeit in `WeatherSystem.WEIGHTS`
  (Sommer nie Schnee, Winter nie Regen). Agent 4 löscht ungeschützte Feuer über `weather_changed`.
- **Schlaf:** Interactable am `SleepingPlace` → `PlayerStats.sleep(quality, place)`. Nur abends (ab 18:00), nachts oder bei Energie <50.
  Im Schlaf verhungert niemand (Floor 12). Energie voll, Gesundheit +20·quality, `skip_to_morning()`.
- **Winter:** Herbst Tag 14 (Traum), 20 (Stamm/Beobachtung), 26 (Frost) → `hint_requested` (`smoking`/`fur_clothing`) + Benachrichtigung.
  `get_forage_factor()` liefert Winter 0,1 (Herbst 0,8) für Sammelmengen.

## Öffentliche API (`PlayerStats`)
```gdscript
PlayerStats.get_value(&"hunger") -> float
PlayerStats.modify(&"warmth", -5.0)
PlayerStats.eat(&"berries") -> bool          # entfernt 1 Stück aus dem Inventar, emittiert item_consumed
PlayerStats.sleep(quality := 1.0, place: Node2D = null) -> bool
PlayerStats.can_sleep() -> bool
PlayerStats.is_sheltered() -> bool
PlayerStats.get_speed_multiplier() -> float   # 0.55..1.0
PlayerStats.get_screen_effects() -> Dictionary   # {effect: 0..1}
PlayerStats.get_forage_factor() -> float
PlayerStats.get_temperature_breakdown() -> Dictionary
PlayerStats.weather.current / .is_precipitation() / .is_wet() / .force_weather(id, hours)
PlayerStats.screen_effect_changed(effect, intensity)   # lokales Signal für Agent 8: &"hunger" &"thirst" &"cold" &"exhaustion" &"health"
PlayerStats.woke_up(reason)                            # lokales Signal: &"sleep" oder Kollaps-Grund (UI: Ein-/Ausblenden)
```

## EventBus
**Emittiert:** `player_stat_changed`, `player_collapsed`, `weather_changed`, `item_consumed`, `notification_requested`,
`hint_requested`, `action_performed` (`sleep`, `survive_night`, `survive_winter`).
**Lauscht auf:** `fire_lit`, `fire_extinguished`, `player_collapsed` (nur `forced_sleep`), `hour_changed`, `day_started`, `day_ended`, `season_changed`.

## Debug-Befehle (Agent 9 bindet sie an die Konsole)
```gdscript
PlayerStats.debug_set_stat(&"hunger", 20.0)
PlayerStats.debug_fill_stats()                 # alles 100
PlayerStats.debug_drain_stats()                # Hunger/Durst/Wärme/Energie 0
PlayerStats.debug_set_weather(&"storm", 6)     # clear rain storm snow fog
PlayerStats.debug_set_hour(21.0)
PlayerStats.debug_set_season(Enums.Season.WINTER)
PlayerStats.debug_set_day_of_season(Enums.Season.AUTUMN, 14)
PlayerStats.debug_collapse(&"exhaustion")
PlayerStats.debug_toggle_invulnerable() -> bool
```

## Speichern
`"player_stats"` (Werte, Winter-/Nacht-Flags), `"weather"` (aktuelles Wetter + Restdauer), `"winter_hints"` (bereits gegebene Hinweise).

## Testszene
`res://survival/tests/test_survival.tscn` – F6: WASD laufen, 1–5 Wetter, F Feuer, H leeren, R füllen, K Kollaps, T +3 h, Y Jahreszeit, E am braunen Feld schlafen.
Headless: `godot --headless --path . res://survival/tests/test_survival.tscn` (Exit 0 = ok).

## Offene Punkte
- **Nicht in Godot ausgeführt:** In der Entwicklungsumgebung war keine Godot-Binärdatei verfügbar; Skripte und Testszene sind ungetestet – bitte einmal headless laufen lassen.
- Es darf nur ein `CanvasModulate` im Standard-Canvas geben: Agent 1 sollte keinen eigenen anlegen.
- Verlangsamung, Kleidung, Zeitverlust: siehe `docs/interface_requests.md`.
- `eat()` kann ohne Item-Datensätze (`items/data/` noch leer) nichts konsumieren; Verlust-Fallbackliste `LOSSABLE_FALLBACK` entfällt, sobald ItemDB die Items kennt.
- Wetter-Grafik sind Platzhalter (Partikel-Rechtecke, Nebel-Shader).
