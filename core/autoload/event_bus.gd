extends Node
## EventBus – nur Signale. Systeme kommunizieren ausschließlich hierüber.
## Neue Signale nur per docs/interface_requests.md anfragen (Besitzer: Agent 0).
## Signale werden hier nur deklariert; die Warnung "unused signal" ist daher unterdrückt.

# --- Items ---
@warning_ignore("unused_signal")
signal item_collected(item_id: StringName, amount: int)
@warning_ignore("unused_signal")
signal item_removed(item_id: StringName, amount: int)
@warning_ignore("unused_signal")
signal item_crafted(recipe_id: StringName, item_id: StringName)
@warning_ignore("unused_signal")
signal item_consumed(item_id: StringName)
@warning_ignore("unused_signal")
signal tool_used(item_id: StringName, target_position: Vector2, facing: Vector2)
@warning_ignore("unused_signal")
signal action_performed(action_id: StringName, context: Dictionary)

# --- Entdeckungen ---
@warning_ignore("unused_signal")
signal discovery_unlocked(discovery_id: StringName)
## source: &"dream", &"tribe", &"observation"
@warning_ignore("unused_signal")
signal hint_requested(discovery_id: StringName, source: StringName)

# --- Fortschritt ---
@warning_ignore("unused_signal")
signal phase_changed(phase: int)
@warning_ignore("unused_signal")
signal epoch_completed(epoch_id: StringName)

# --- Zeit & Wetter ---
@warning_ignore("unused_signal")
signal day_started(day: int)
@warning_ignore("unused_signal")
signal day_ended(day: int)
@warning_ignore("unused_signal")
signal season_changed(season: int)
@warning_ignore("unused_signal")
signal hour_changed(hour: int)
## &"clear", &"rain", &"storm", &"snow", &"fog"
@warning_ignore("unused_signal")
signal weather_changed(weather: StringName)

# --- Spieler ---
@warning_ignore("unused_signal")
signal player_stat_changed(stat: StringName, value: float, max_value: float)
@warning_ignore("unused_signal")
signal player_collapsed(reason: StringName)

# --- Welt ---
@warning_ignore("unused_signal")
signal animal_killed(animal_id: StringName, position: Vector2)
@warning_ignore("unused_signal")
signal fire_lit(fire: Node2D)
@warning_ignore("unused_signal")
signal fire_extinguished(fire: Node2D)
@warning_ignore("unused_signal")
signal structure_placed(structure_id: StringName, position: Vector2)
@warning_ignore("unused_signal")
signal world_generated()

# --- Stamm ---
@warning_ignore("unused_signal")
signal tribe_member_joined(member_id: StringName)
@warning_ignore("unused_signal")
signal tribe_member_left(member_id: StringName, reason: StringName)

# --- UI / Feedback ---
@warning_ignore("unused_signal")
signal notification_requested(text: String, icon: Texture2D)
@warning_ignore("unused_signal")
signal rare_find(item_id: StringName, position: Vector2)
