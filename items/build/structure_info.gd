class_name StructureInfo
extends Resource
## Daten zu einem platzierbaren Bauwerk (Größe am Raster, Station, Platzhalterfarbe).
## Liegt als .tres unter res://items/structures/<item_id>.tres.

@export var id: StringName = &""
## Grundfläche in Tiles (16x16 px).
@export var footprint: Vector2i = Vector2i(1, 1)
## true = Bauwerk ist eine Herstellungsstation (Gruppe "crafting_station").
@export var provides_station: bool = false
@export var station: Enums.Station = Enums.Station.WORKSPOT
## Farbe des Platzhalter-Bauwerks, falls die echte Szene noch nicht existiert.
@export var placeholder_color: Color = Color(0.5, 0.4, 0.3)
