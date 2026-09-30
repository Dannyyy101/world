# fire/

**Besitzer:** Agent 4 – Feuer, Kochen, Räuchern, Keramik & Ofen

## Gebaut
| Datei | Inhalt |
|---|---|
| `scenes/campfire.tscn` (`Campfire`) | Brennstoff branch/wood_log, brennt ab, Regen löscht, PointLight2D-Flackern, Funken, Zeitbalken fürs Garen, Feuerhärtung, Ton über Nacht |
| `scenes/drying_rack.tscn` (`DryingRack`) | Räuchern über Tage; 2,5× schneller mit brennendem Feuer in 64 px |
| `scenes/kiln.tscn` (`Kiln`) | Temperatur 0–1200 °C, Brennstoffe, Blasen im Rhythmus, Keramik ≥ 600 °C, Kupfer ≥ 1085 °C, Holzkohle |
| `scripts/fire_drill_minigame.gd` | Feuerbohrer-Minispiel (Rhythmus + Durchhalten, tinder = größere Zone) |
| `scripts/fire_process.gd` + `data/processes/*.tres` | Kochen/Härten/Räuchern/Brennen/Schmelzen als Daten (Zeiten in Spielstunden) |
| `scripts/fire_station.gd`, `fire_clock.gd`, `fire_registry.gd`, `fire_art.gd` | Basisklasse, monotone Spielzeit (Schlafen zählt), Save-Registry, Platzhalter-Grafik (zur Laufzeit; `art/placeholder/<name>.png` überschreibt) |

Alles läuft in Spielstunden (`FireClock`): Schlafen lässt Feuer abbrennen, Essen anbrennen, Ton härten und Fleisch trocknen.

## Bedienung (E, eine Taste, Priorität)
- **Lagerfeuer:** Fertiges nehmen › Brennstoff bei < 2 h › Garen/Härten (raw_meat, raw_fish, flour, wooden_spear) › Ton (clay_pot_unfired, clay) ans Feuer › Brennstoff. Unentzündet: Feuerbohrer-Minispiel (braucht `fire_drill`, verbraucht `tinder` für breitere Zone).
- **Gestell:** Fertiges nehmen › raw_meat aufhängen.
- **Ofen:** Fertiges nehmen › Rohling/Malachit(+1 charcoal) laden › Brennstoff (< 2 Stücke) › mit `blowpipe` blasen (E, wenn der Ring voll/grün ist) › Brennstoff.
  Ohne Luftzufuhr max. 1000 °C; Kupfer braucht Luft (2 Kohle oder Holz+Kohle + Blasen).

## Öffentliche API
- `Campfire`: `burning`, `fuel_hours`, `heat_radius`, `is_burning()`, `get_heat_strength()`, `add_fuel(id)`, `can_light()`, `ignite()`, `extinguish(reason)`, `start_process(p)`, `place_clay(id)`, `collect()`; Signale `ignited`, `extinguished(reason)`, `clay_hardened(item_id)`.
- `DryingRack`: `load_item(p)`, `collect()`, `is_smoking()`.
- `Kiln`: `temperature`, `bellows`, `add_fuel(id)`, `load_item(p)`, `blow()`, `collect()`, `target_temperature()`; Signal `copper_smelted(kiln)`; Gruppe `kiln`.
- **Wärme (Agent 3):** Gruppe `heat_source`; Methoden `is_burning()`, `get_heat_strength()`, Property `heat_radius` (px).
- **Unterschlupf (Agent 1/7):** Node2D in Gruppe `shelter` innerhalb 64 px schützt ein Feuer vor Regen (oder `Campfire.sheltered = true`).

## Signale
Emittiert: `fire_lit(fire)`, `fire_extinguished(fire)`, `action_performed` mit `light_fire`, `cook`, `harden_spear`, `smoke_meat`, `clay_hardened`, `fire_pottery`, `smelt_malachite`, `notification_requested(text, null)`.
Empfängt: `weather_changed`. Setzt beim ersten Feuer `GameState.set_camp()`, Flags `first_fire`, `copper_smelted`.

## Offen / Hinweise
- **Nicht in Godot ausgeführt** (im Build-Container war keine Godot-Binary): erst `godot --headless --import`, dann `godot --headless --path . res://fire/tests/test_fire.tscn` ausführen und ggf. Tippfehler beheben.
- Ton "über Nacht": Ton wird per Interaktion ans Feuer gelegt und härtet nach 6 Spielstunden Brenndauer. Herumliegende Welt-Items (Agent 2) werden noch nicht gescannt.
- Für Spielstart-Load Autoload `FireSaveHub` nötig (siehe `docs/interface_requests.md`). Items/Icons kommen von Agent 2.
- Tinder/Feuerbohrer nutzen keine Haltbarkeit.
