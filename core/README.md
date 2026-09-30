# core/ – Fundament

**Besitzer:** Agent 0 (Architekt)

## Inhalt
| Pfad | Zweck |
|---|---|
| `enums.gd` | `Enums` (Season, Phase, ItemCategory, ToolType, Station) |
| `resources/` | `ItemData`, `RecipeData`, `DiscoveryData` |
| `autoload/` | `EventBus`, `GameState`, `TimeManager`, `ItemDB`, `SaveManager` |
| `components/` | `Interactable`, `Hitbox`, `Hurtbox` (Skript + Szene) |
| `theme/main_theme.tres` | Basis-Theme (Silkscreen-Pixelfont, erdige Farben) – für alle UI nutzen |
| `fonts/` | Silkscreen (SIL OFL 1.1, Lizenz liegt daneben) |
| `tests/test_core.tscn` | Testet Autoloads, Stubs, Save/Load, Zeit |

Die vollständige API steht in [`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md).

## Offene Punkte
- Wetter (`weather_changed`) hat noch keinen Besitzer im Kern – Vorschlag: Agent 1 (world).
- Die Stubs (`items/inventory.gd`, `survival/player_stats.gd`, `discovery/discovery_manager.gd`,
  `tribe/tribe_manager.gd`) gehören den jeweiligen Agents und werden von ihnen ersetzt.
