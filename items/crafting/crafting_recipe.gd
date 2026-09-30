class_name CraftingRecipe
extends RecipeData
## Erweiterung von RecipeData (lokal, bis `required_tools` im Kern existiert – siehe docs/interface_requests.md).
## ItemDB lädt Instanzen normal, weil CraftingRecipe ein RecipeData ist.

## Werkzeuge, die im Inventar vorhanden sein müssen, aber nicht verbraucht werden.
@export var required_tools: Array[StringName] = []
## true = kein Fortschrittsbalken, sondern das Feuerstein-Schlagen-Minispiel.
@export var uses_knapping: bool = false
## Nur Knapping: Ergebnis bei misslungenem Schlag (Splitter statt Werkzeug).
@export var fail_output_id: StringName = &""
@export var fail_output_amount: int = 1
## Nur Knapping: Zutaten, die bei einem Fehlschlag NICHT verbraucht werden (z. B. der Schlagstein).
@export var fail_keeps: Array[StringName] = []
## Optional: Aktion, die nach dem Herstellen per action_performed gemeldet wird (z. B. &"cook").
@export var action_id: StringName = &""
