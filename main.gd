extends Node
## Hauptszene: lädt Welt, Player und UI-Ebene.

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")


func _ready() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	# Der Player gehört in die y-sortierte Objekt-Ebene der Welt (Gruppe "entity_layer"),
	# damit er korrekt hinter/vor Bäumen und Tieren gezeichnet wird.
	var layer: Node = get_tree().get_first_node_in_group("entity_layer")
	if layer == null:
		layer = self
	layer.add_child(player)
