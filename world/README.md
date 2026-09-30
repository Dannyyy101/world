# world/ – Welt, Generierung & Pflanzenwachstum (Agent 1)

Prozedurale Steinzeit-Landschaft (Standard-Karte 128×96 Tiles à 16 px), die sich mit den Jahreszeiten verändert.
Start = Höhle am Weltursprung `(0,0)`; `main.tscn` funktioniert ohne Änderung (Player landet in der Höhle).

## Inhalt
| Pfad | Zweck |
|---|---|
| `scenes/world.tscn` | Wurzel (`WorldGenerator`), `Ground`/`Snow` (TileMapLayer), `Objects` (y-sortiert, Gruppe **`entity_layer`**), `Navigation`, `Cave`, `Weather` |
| `scripts/world_generator.gd` | `class_name WorldGenerator` – Terrain, Fluss, Höhle, Ressourcen, Navigation, Jahreszeiten, Speichern |
| `scripts/biome.gd` | `Biome.Terrain` (Atlas-Zeilen), Hilfsfunktionen |
| `scripts/tree_spawner.gd` | biomabhängige Bäume (Laub/Nadel) |
| `scripts/resource_node.gd` + `scenes/resources/resource_node.tscn` | generischer Ressourcen-Node; alle Ressourcenszenen sind Vererbungen davon |
| `scripts/spawn_rule.gd` + `data/spawn_rules/*.tres` | Platzierungsregeln (Anzahl, Biome, Abstand, Wasser-Nähe, Cluster) – als Resources, leicht ausbalancierbar |
| `scripts/field_plot.gd`, `scenes/field_plot.tscn` | Acker (Jungsteinzeit) |
| `scripts/drink_spot.gd`, `scenes/drink_spot.tscn` | Trinkstelle am Ufer |
| `scripts/weather.gd` | deterministisches Tageswetter (`weather_changed`) |
| `scripts/world_art.gd` | Platzhalter-Texturen laden, TileSet (zur Laufzeit) bauen, Jahreszeiten-Farben |
| `art/placeholder/` | Platzhalter-Grafik; erzeugt von `tools/gen_placeholders.py` – unter gleichem Dateinamen ersetzbar |
| `tests/test_world.tscn` | Testszene (headless: 100+ Prüfungen, Exit 0 = ok) |

## Generierung
* `world_seed` (Export, im Speicherstand). Gleicher Seed ⇒ identische Welt (Terrain **und** Node-IDs).
* Biome per `FastNoiseLite` (Höhe → Fels, Wald-Rauschen → Wald, Temperatur → Laub/Nadel). Die Schwellen werden per
  **Quantil** bestimmt (`rock_share`, `forest_share`) – jedes Biom kommt bei jedem Seed vor.
* Fluss West→Ost (`river_base_y`, 3–5 Tiles breit), **3 Furten** (begehbar), Ufer (`BANK`) begehbar, Wasser blockiert
  (TileSet-Physik, Ebene 1). Flussaue = ≤ 5 Tiles Abstand zum Wasser.
* Karten-Rand: unsichtbare `StaticBody2D`-Wände (`Boundary`).
* Erzeugung ≈ 0,4 s. `generate(seed)` kann jederzeit neu aufgerufen werden.

## Höhle (Start)
* Innenraum Zellen x −4..4, y −5..0, Eingang nach Süden bei (−1..1, 1). Player startet bei `(0,0)`.
* `Cave/PlayerStart`, `Cave/CampSpot` (beim ersten Generieren wird `GameState.set_camp(CampSpot)` gesetzt, falls noch kein Lager existiert).
* **`CavePaintingAnchor` (Marker2D)** – für Agent 6: unterer Mittelpunkt der Nordwand über dem Innenraum. Die Wand
  ist 2 Tiles (32 px) hoch und 144 px breit; ein Sprite mit `offset = Vector2(0, -h)` als Kind des Ankers sitzt auf der Wand.
  Zugriff: `get_tree().get_first_node_in_group("world_generator").get_cave_painting_anchor()`.
* Schutz: `is_sheltered(pos)`; zusätzlich `Area2D` `Cave/CaveShelter` in Gruppe `shelter`.

## Ressourcen (`ResourceNode`)
| Szene | Modus | Ertrag | Nachwachsen | Verfügbar |
|---|---|---|---|---|
| `tree_deciduous` / `tree_conifer` | Werkzeug **AXE**, 4 Treffer | wood_log 2–3, branch 1–2 · `chop_tree` | 28 Tage | immer; Laubbäume färben sich, Nadelbäume verschneien |
| `bush_branch` | Hand | branch 1–2 | 3 Tage | immer |
| `stone_node` | Hand | stone 1–2 | 10 Tage | immer |
| `flint_deposit` (Fels) | Hand | flint 1–2, 4 % amber (+`rare_find`) | 20 Tage | immer |
| `clay_deposit` (Flussaue/Ufer) | Hand | clay 2–3 | 6 Tage | immer |
| `nettle` | Hand | nettle 2–3 | 5 Tage | Frühling–Herbst |
| `berry_bush` | Hand | berries 2–4 | 4 Tage | Sommer, Herbst (sonst kahler Busch) |
| `mushroom` | Hand | mushroom 1–3 | 3 Tage | Herbst |
| `wild_grain` (Wiese) | Hand | wild_grain 2–4 | 6 Tage | Spätsommer (Sommer ab Tag 15) bis Herbst-Tag 7 |
| `malachite_deposit` (Fels, 4×) | Hand | malachite 1 | nie | **sichtbar/nutzbar erst nach `Discoveries.is_unlocked(&"kiln")`** |
| `amber_find` (Ufer, 5×) | Hand | amber 1 · `rare_find` | nie | immer, glitzert |
| `drink_spot` (Ufer, 16×) | Hand | `PlayerStats.modify(&"thirst", +25)` | – | immer |

Jeder Abbau: `Inventory.add_item(...)`, dann `action_performed(&"gather", {"item", "position", "node_id"})` bzw. `&"chop_tree"`.
`item_collected` emittiert – gemäß Konvention – der Inventory selbst (nicht doppelt emittieren!). Ist das Inventar voll, wird nicht abgebaut
(Hinweis über `notification_requested`). Falsches Werkzeug ⇒ nur Wackler. Jeder wirksame Treffer ruft `Inventory.damage_equipped(1)`.
Feedback: Wackler + Partikel (lokal), Signal `ResourceNode.feedback(kind, position, tint)` (Hook für Agent 8, siehe interface_requests).

**Neue Ressource anlegen:** Szene von `resource_node.tscn` erben, Exporte setzen (Ertrag, Saison-Fenster, Texturen) →
`SpawnRule`-`.tres` in `data/spawn_rules/` ablegen. Nichts sonst.

## Nachwachsen & Jahreszeiten
* Abgebaute Nodes sind erschöpft und wachsen nach `regrow_days` (Kalendertage des `TimeManager`) nach. `season_windows` begrenzt die Nutzbarkeit
  je Jahreszeit/Tag. Aktualisierung bei `day_started`, `season_changed`, `discovery_unlocked` (Gruppe `world_resources` → `refresh_state()`).
* Optik: Bodenfarbe je Jahreszeit (Tween 1,5 s), **Schnee** als eigene TileMapLayer (nur Winter), Pflanzen-Tönung (Laubbäume: frisch/grün/orange/kahl-grau, Nadelbäume: winterlich hell).

## Ackerbau (Jungsteinzeit)
1. **Keimung am Lager:** `item_consumed(wild_grain)` in ≤ 6 Tiles Lagernähe ⇒ 20 % Chance, Samen fällt.
   `notify_item_on_ground(&"wild_grain", pos)` merkt Bodenkörner (100 %). Beim nächsten **Frühling** (Samen aus früheren Jahren/vor Frühlingsbeginn)
   wächst ein Wildgetreide-Busch, `action_performed(&"seed_sprouted_at_camp", {"position"})`. Samen und Keimlinge werden gespeichert.
2. **`field_plot`** (nach `agriculture`): E → Hacken (braucht `hand_axe` im Inventar) → Säen (1 `wild_grain`, `plant_seed`) → Gießen → Ernte (4–6 `wild_grain`).
   Wachstum +1 pro Tag, wenn gegossen (Gefäß `fired_pottery`, wird nicht verbraucht) **oder es geregnet hat**; sonst pausiert es nur (Pflanze stirbt nie). Reif nach 6 Tagen.
   Felder werden im Weltspeicherstand gesichert (Gruppe `field_plots`).

## Navigation (für Tiere & Stammesmitglieder)
Die Karte ist in 16×16-Tile-Chunks als 48 `NavigationRegion2D` unter `Navigation` gebacken (Wasser, Höhlenwände, Bäume sind Hindernisse;
Furten sind begehbar; 4 px Sicherheitsabstand). Sie liegen auf der **Standard-Navigationskarte** von `World2D`, daher:
```gdscript
# a) NavigationAgent2D am eigenen Node – funktioniert ohne weitere Einrichtung
# b) direkt:
var world: WorldGenerator = get_tree().get_first_node_in_group("world_generator")
var path: PackedVector2Array = NavigationServer2D.map_get_path(world.get_navigation_map(), von, nach, true)
```
Hinweis: Der NavigationServer synchronisiert asynchron; direkt nach `generate()` liefert `map_get_path` erst nach einigen Frames Ergebnisse
(`NavigationServer2D.map_get_iteration_id(map) > 0`). Gebäude, die Wege blockieren, bitte per `NavigationObstacle2D` melden (Avoidance).

## Öffentliche API (`WorldGenerator`, Gruppe `world_generator`)
`generate(seed := -1)` · `get_terrain_at(pos) / get_terrain_cell(cell)` (`Biome.Terrain`) · `get_biome_at(pos)` · `is_walkable(pos)` ·
`is_sheltered(pos)` · `is_raining()` · `get_weather()` · `get_cave_painting_anchor()` · `get_start_position()` · `get_camp_position()` ·
`get_nearest_shore_position(from)` · `get_navigation_map()` · `get_map_rect_px()` · `world_to_cell(pos)` / `cell_center(cell)` ·
`get_node_by_id(id)` · `get_resource_nodes()` · `scatter_grain_seed(pos)` · `notify_item_on_ground(item_id, pos)` · `get_pending_seed_count()`.
Lokales Signal `generated`.

## Signale
**Emittiert:** `world_generated` (deferred, nach jeder Generierung, auch nach dem Laden), `action_performed` (`gather`, `chop_tree`, `plant_seed`, `seed_sprouted_at_camp`),
`rare_find` (Bernstein), `weather_changed`, `notification_requested` (Inventar voll / fehlendes Werkzeug).
**Lauscht:** `day_started`, `day_ended`, `season_changed`, `discovery_unlocked`, `item_consumed`, `rare_find` (Glitzer-Effekt an der Fundstelle), `weather_changed` (Acker).
Nutzt: `Inventory`, `PlayerStats`, `Discoveries`, `TimeManager`, `GameState` (Lagerposition), `SaveManager`.

## Speichern (`"world"`)
`{seed, depleted: {node_id: regrow_day}, seeds, sprouts, fields}`. Beim Laden wird die Welt aus dem Seed neu erzeugt und der Abbau-Zustand darübergelegt.

## Offene Punkte
* Regen-/Schnee-Partikel und Wetter-Überblendung (Agent 8/`audio_fx`); die Welt liefert nur `weather_changed` + `is_raining()`.
* EventBus-Signal für Abbau-Feedback und Bodenitem-Hook von Agent 2 (siehe `docs/interface_requests.md`).
* Finale Pixel-Art (Tileset mit Übergängen, Baum-/Buschsprites, echte Jahreszeiten-Varianten statt Farbmodulation).
* Feld-Bewässerung von Hand nutzt `fired_pottery` als Gefäß-Platzhalter (kein eigenes Wasser-Item im ID-Register).
