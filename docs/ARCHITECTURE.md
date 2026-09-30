# Architektur

Godot 4.4+ (Projekt angelegt mit 4.7, getestet mit 4.6), GDScript mit **statischer Typisierung überall**.
Viewport 480×270, Integer-Skalierung, Texturfilter Nearest, Pixel-Snapping aktiv.

## 1. Grundregeln
1. Jeder Agent besitzt **nur seinen Ordner**. Fremde Dateien nie ändern – Wünsche in
   [`interface_requests.md`](interface_requests.md) anhängen (`[Agent X → Agent Y] Wunsch + Begründung`)
   und mit lokalem Fallback weiterarbeiten.
2. Systeme sprechen **nur** über Signale im `EventBus` und über die öffentlichen Autoload-APIs.
   Kein `get_node("/root/World/...")`, keine Pfade in fremde Szenen.
3. Daten (Items, Rezepte, Entdeckungen, Tiere) sind **Resources (.tres)**, nie hartkodiert.
4. Speicherwürdiger Zustand → bei `SaveManager` registrieren.
5. Platzhalter-Grafik unter `res://<ordner>/art/placeholder/`, klar benannt (`item_branch.png`).
6. Pro Ordner: `README.md` (gebaut, API, Signale, offene Punkte) + `tests/test_<name>.tscn`.

## 2. Ordner & Besitzer
```
core/ (0)  player/ (0)  world/ (1)  items/ (2)  survival/ (3)  fire/ (4)  animals/ (5)
discovery/ (6)  tribe/ (7)  ui/ + audio_fx/ (8)  progression/ (9)  docs/ (alle: nur ANHÄNGEN)
main.tscn + main.gd (0)   – Hauptszene: World + UI-CanvasLayer; Player wird per Skript eingehängt
```
`main.tscn`: `Main` → `World` (Instanz `world/scenes/world.tscn`), `UI` (CanvasLayer, layer 10) → `Root`
(Control mit `main_theme`, `mouse_filter = IGNORE`) – **Platzhalter für Agent 8**. Der Player wird von `main.gd`
in den Node der Gruppe `entity_layer` (y-sortierte Objektebene der Welt) gehängt.

## 3. Autoloads
Ladereihenfolge: EventBus, SaveManager, GameState, TimeManager, ItemDB, Inventory, PlayerStats, Discoveries, Tribe.
Autoload-Skripte haben **kein** `class_name` (Namenskonflikt mit dem Autoload-Namen).

### EventBus (Agent 0) – nur Signale
```gdscript
EventBus.item_collected.emit(&"stone", 1)
EventBus.discovery_unlocked.connect(_on_discovery)   # func _on_discovery(id: StringName) -> void
```
Vollständige Liste (Signaturen exakt so; neue Signale nur per interface_requests.md):
```
item_collected(item_id: StringName, amount: int)          item_removed(item_id: StringName, amount: int)
item_crafted(recipe_id: StringName, item_id: StringName)  item_consumed(item_id: StringName)
tool_used(item_id: StringName, target_position: Vector2, facing: Vector2)
action_performed(action_id: StringName, context: Dictionary)
discovery_unlocked(discovery_id: StringName)
hint_requested(discovery_id: StringName, source: StringName)   # &"dream" | &"tribe" | &"observation"
phase_changed(phase: int)          epoch_completed(epoch_id: StringName)
day_started(day: int)  day_ended(day: int)  season_changed(season: int)  hour_changed(hour: int)
weather_changed(weather: StringName)   # &"clear" &"rain" &"storm" &"snow" &"fog"
player_stat_changed(stat: StringName, value: float, max_value: float)
player_collapsed(reason: StringName)
animal_killed(animal_id: StringName, position: Vector2)
fire_lit(fire: Node2D)  fire_extinguished(fire: Node2D)
structure_placed(structure_id: StringName, position: Vector2)
tribe_member_joined(member_id: StringName)  tribe_member_left(member_id: StringName, reason: StringName)
notification_requested(text: String, icon: Texture2D)
rare_find(item_id: StringName, position: Vector2)
world_generated()
```
Wer emittiert was (Konvention): `item_collected/removed` = Inventory · `item_crafted` = Crafting (Agent 2) ·
`tool_used` = Player · `action_performed` = das System, in dem die Aktion passiert ·
`player_collapsed` = TimeManager (`&"forced_sleep"`) und Survival (`&"exhaustion"` …) ·
Zeit-Signale = TimeManager · `phase_changed` = GameState.set_phase().

### GameState (Agent 0)
```gdscript
GameState.phase            # Enums.Phase
GameState.set_phase(Enums.Phase.MITTELSTEINZEIT)   # emittiert phase_changed
GameState.camp_position; GameState.has_camp; GameState.set_camp(pos)
GameState.player           # Node2D (Player), gesetzt vom Player selbst
GameState.set_flag("first_fire", true); GameState.get_flag("first_fire", false)
```
Flags: freie Schlüssel (String), Werte JSON-tauglich. Registriert sich als `"game_state"` im SaveManager.

### TimeManager (Agent 0)
```gdscript
TimeManager.day; TimeManager.season; TimeManager.year; TimeManager.hour   # hour: float 0..24
TimeManager.DAYS_PER_SEASON        # 28
TimeManager.is_night()             # 20:00–06:00
TimeManager.pause(); TimeManager.resume(); TimeManager.skip_to_morning()
TimeManager.get_time_string()      # "14:30"
TimeManager.time_scale = 60.0      # Debug-Zeitraffer
```
- Tageslänge: Konstante `DAY_REAL_MINUTES` (14) in `core/autoload/time_manager.gd`.
- Wachzeit 6:00–2:00 (20 Spielstunden = 14 Echtminuten). Um 2:00: `player_collapsed(&"forced_sleep")`,
  dann `skip_to_morning()`: `day_ended(alt)` → Tag+1, 6:00 → `hour_changed(6)`, ggf. `season_changed`, `day_started(neu)`.
- Freiwilliges Schlafen (Survival/Tribe): `TimeManager.skip_to_morning()` aufrufen.
- Tag 1 = Frühling. Beim Start werden `season_changed`, `hour_changed`, `day_started(1)` einmal (deferred) emittiert.

### ItemDB (Agent 0)
```gdscript
var item: ItemData = ItemDB.get_item(&"flint")            # null wenn unbekannt
var r: RecipeData = ItemDB.get_recipe(&"hand_axe")
var all: Array[RecipeData] = ItemDB.all_recipes()
ItemDB.all_items(); ItemDB.has_item(id); ItemDB.recipes_for_station(Enums.Station.CAMPFIRE)
```
Lädt beim Start rekursiv alle `.tres` aus `res://items/data/` (ItemData) und `res://items/recipes/` (RecipeData).
Doppelte/leere `id` → Warnung. `ItemDB.reload()` liest neu ein.

### SaveManager (Agent 0)
```gdscript
func _ready() -> void:
    SaveManager.register("fire", self)
func get_save_data() -> Dictionary:
    return {"lit_fires": lit_positions, "fuel": fuel}       # Vector2/Color/StringName sind erlaubt
func load_save_data(data: Dictionary) -> void:
    lit_positions = data.get("lit_fires", [])
SaveManager.save_game(1); SaveManager.load_game(1); SaveManager.has_save(1); SaveManager.delete_save(1)
```
Datei: `user://saves/slot_<n>.json`, Struktur `{version, timestamp, systems: {key: data}}`
(`SAVE_VERSION`, Migration bei Bedarf in `load_game`). Wichtig:
- `Vector2`, `Vector2i`, `Vector3`, `Color`, `StringName` werden automatisch (de)kodiert. **Keine Node-/Resource-Referenzen** speichern – IDs oder Pfade.
- JSON kennt nur eine Zahlenart: ganzzahlige Zahlen kommen als `int` zurück, alles andere als `float`.
  Ein `float`-Wert wie `2.0` kommt daher als `int 2` zurück – bei Divisionen `float(x)` verwenden.
- Beim Laden ruft der SaveManager `load_save_data` in Registrierungsreihenfolge auf; Systeme dürfen sich nicht
  auf die Existenz anderer Systeme beim Laden verlassen (kein Nachlade-Zwang).
- Nach `load_game` ist `SaveManager.loaded(slot)` (lokales Signal) verfügbar.
- Szenen-Nodes (z. B. platzierte Lagerfeuer) müssen ihr System selbst neu erzeugen: das *System* (Manager) speichert die Liste,
  nicht der Node.

### Stubs (Besitzer ersetzt die Datei, Signaturen bleiben)
```gdscript
# Inventory (Agent 2, items/inventory.gd)
Inventory.add_item(&"stone", 2) -> int        # Rest, der nicht passte
Inventory.remove_item(&"stone", 1) -> bool
Inventory.has_item(&"stone", 3) -> bool       # amount default 1
Inventory.count(&"stone") -> int
Inventory.get_equipped() -> ItemData          # null = bloße Hände
Inventory.damage_equipped(1)
# PlayerStats (Agent 3, survival/player_stats.gd)
PlayerStats.get_value(&"hunger") -> float     # &"health" &"hunger" &"thirst" &"warmth" &"energy"
PlayerStats.modify(&"warmth", -5.0)
PlayerStats.eat(&"berries") -> bool
# Discoveries (Agent 6, discovery/discovery_manager.gd)
Discoveries.is_unlocked(&"fire") -> bool; Discoveries.unlock(&"fire"); Discoveries.get_progress(&"fire") -> float  # 0..1
# Tribe (Agent 7, tribe/tribe_manager.gd)
Tribe.get_size() -> int; Tribe.get_members() -> Array
```
Der Inventory-Stub ist ein einfacher Zähler (nützlich zum Testen); die übrigen liefern Dummy-Werte.

## 4. Resource-Klassen (`core/resources/`, alle Felder `@export`)
- `ItemData`: id, display_name, description, icon, category, max_stack=99, tool_type, tool_power, max_durability (0 = unzerstörbar),
  nutrition, hydration, warmth, spoil_days (0 = verdirbt nicht), placeable_scene_path, required_discovery
- `RecipeData`: id, inputs (`Dictionary[StringName, int]`), output_id, output_amount, station, craft_seconds, required_discovery
- `DiscoveryData`: id, display_name, description, cave_painting, phase, trigger_type (`DiscoveryData.TriggerType`:
  ACTION_COUNT, ITEM_COUNT, CUSTOM), trigger_id, trigger_count, prerequisites, hint_text, unlocks_recipes

## 5. Komponenten (`core/components/`)
| Komponente | Ebene / Maske | Nutzung |
|---|---|---|
| `Interactable` (Area2D) | Layer 4 / – | `prompt_text`, `enabled`, Signal `interacted(by: Node2D)` |
| `Hitbox` (Area2D) | Layer 5 / Maske 6 | `damage`, `tool_type`, `source`; `activate(dauer)`; trifft jede Hurtbox 1× pro Aktivierung |
| `Hurtbox` (Area2D) | Layer 6 / – | Signal `hit(damage: float, tool_type: int, source: Node)` |

Kollisionsebenen: 1 world · 2 player · 3 animals · 4 interactables · 5 hitbox · 6 hurtbox · 7 npcs.
Feste Hindernisse (Bäume, Felsen, Hütten) = `StaticBody2D` auf Ebene 1. Die Komponenten setzen ihre Ebenen selbst.

## 6. Player (`player/`, Details in `player/README.md`)
`GameState.player` → `Player` mit `facing`, `input_enabled`, `interact()`, `use_tool()`, `get_nearest_interactable()`.
Eingabe: E = `interact`, Linksklick = `use_tool`. Kollisionsebene 2, Maske 1.

## 7. Input-Map
`move_up/down/left/right` (WASD), `interact` (E), `use_tool` (Linksklick), `inventory` (I), `hotbar_1`–`hotbar_9` (1–9),
`pause` (Esc), `debug_console` (F1). Neue Aktionen: per interface_requests.md anfragen.
Für UI: `_unhandled_input` benutzen, damit sich Klicks auf Controls und Spielaktionen nicht überlagern.

## 8. Anleitungen

### Neues Item hinzufügen (Agent 2)
1. `res://items/data/<id>.tres` als `ItemData` anlegen (Inspector → Neue Resource → ItemData). `id` exakt aus dem ID-Register.
2. Icon: Platzhalter unter `res://items/art/placeholder/item_<id>.png`.
3. Platzierbar? `category = PLACEABLE`, `placeable_scene_path` setzen (Szene gehört dem jeweiligen Agent).
4. Rezept: `res://items/recipes/<id>.tres` als `RecipeData`. Nichts weiter registrieren – ItemDB findet die Datei selbst.
5. `ItemDB.get_item(&"<id>")` benutzen, nie Werte hartkodieren.

### Neues Interactable bauen
```gdscript
# berry_bush.gd  (Node2D-Szene mit einer Interactable-Instanz als Kind, Shape anpassen)
extends Node2D
@onready var _interactable: Interactable = $Interactable
func _ready() -> void:
    _interactable.prompt_text = "Beeren pflücken"
    _interactable.interacted.connect(_on_interacted)
func _on_interacted(_by: Node2D) -> void:
    if Inventory.add_item(&"berries", 2) == 0:
        EventBus.action_performed.emit(&"gather", {"item_id": &"berries"})
        _interactable.enabled = false      # leer bis nachwachsen
```
Ein sichtbares Hindernis zusätzlich als `StaticBody2D` (Ebene 1). Objekte in die y-sortierte Ebene einhängen,
z. B. `get_tree().get_first_node_in_group("entity_layer").add_child(node)`.

### Etwas treffbar machen (Baum, Tier)
Eine `Hurtbox`-Instanz als Kind, `hurtbox.hit.connect(_on_hit)`; im Handler `tool_type` prüfen (`Enums.ToolType.AXE`),
Schaden abziehen, danach `EventBus.action_performed.emit(&"chop_tree", {...})` und `Inventory.damage_equipped(1)`.

### Daten speichern
Siehe SaveManager (§3): `register` in `_ready`, `get_save_data`/`load_save_data` implementieren, nur IDs und Werte speichern.

### Auf Ereignisse reagieren
```gdscript
func _ready() -> void:
    EventBus.day_started.connect(_on_day_started)
func _on_day_started(day: int) -> void: ...
```
Bei temporären Nodes in `_exit_tree` trennen (`disconnect`) – oder Callable an den Node binden lassen (Standard, Node freigegeben → automatisch getrennt).

### Testszene
`res://<ordner>/tests/test_<name>.tscn` – läuft isoliert mit F6. Vorbilder: `core/tests/test_core.tscn`,
`player/tests/test_player.tscn` (headless: `godot --headless --path . res://core/tests/test_core.tscn`, Exit 0 = ok).
Wer ein Feature ohne Player testen will, nutzt `player/player.tscn` als Instanz.

## 9. ID-Register (verbindlich, exakt so schreiben)
- **Material:** branch, stone, flint, flint_flake, flint_blade, wood_log, clay, nettle, cordage, tinder, hide, bone, fat, feather,
  wild_grain, flour, charcoal, clay_pot_unfired, fired_pottery, malachite, copper_bead, amber
- **Nahrung:** berries, raw_meat, cooked_meat, smoked_meat, raw_fish, cooked_fish, flatbread, mushroom
- **Werkzeug/Waffe:** hand_axe, scraper, wooden_spear, hardened_spear, flint_spear, bow, arrow, fish_trap, grindstone, fire_drill, blowpipe
- **Kleidung:** fur_clothing
- **Platzierbar:** campfire → `res://fire/scenes/campfire.tscn` · drying_rack → `res://fire/scenes/drying_rack.tscn` ·
  kiln → `res://fire/scenes/kiln.tscn` · lean_to → `res://tribe/scenes/lean_to.tscn` · hut → `res://tribe/scenes/hut.tscn` ·
  longhouse → `res://tribe/scenes/longhouse.tscn` · storage_pit → `res://tribe/scenes/storage_pit.tscn` ·
  field_plot → `res://world/scenes/field_plot.tscn` · animal_pen → `res://animals/scenes/animal_pen.tscn` ·
  workspot → `res://items/scenes/workspot.tscn`
- **Tiere:** deer, boar, rabbit, wolf, bear, fish, aurochs, white_deer (selten)
- **Aktionen (`action_performed`):** knap_flint, chop_tree, gather, hunt_kill, cook, smoke_meat, fish, observe_fish, plant_seed,
  seed_sprouted_at_camp, clay_hardened, fire_pottery, feed_animal, tame_animal, grind_grain, smelt_malachite, build, sleep,
  survive_night, survive_winter, light_fire, harden_spear
- **Entdeckungen:** fire, hand_axe, fire_hardening, cooking, cordage, fur_clothing, smoking, blades, bow, fish_trap, grinding,
  agriculture, pottery, taming, longhouse, kiln, blowpipe, copper

## 10. Bekannte Einschränkungen
- Kein Wetter-Autoload; `weather_changed` hat keinen festgelegten Emittenten (Vorschlag: Agent 1).
- Font Silkscreen deckt Umlaute, ß und typografische Anführungszeichen ab; für andere Sonderzeichen Fallback-Font im Theme ergänzen (Agent 8).
