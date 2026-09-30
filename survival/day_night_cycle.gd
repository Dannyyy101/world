class_name DayNightCycle
extends CanvasModulate
## Tag/Nacht-Beleuchtung (Besitzer: Agent 3): färbt die Spielwelt (Standard-Canvas) nach Tageszeit,
## Wetter und Jahreszeit. UI-CanvasLayer bleiben unberührt. Nachts dunkel; Feuer (Agent 4) hellt
## per PointLight2D auf. Wird von PlayerStats als Kind erzeugt.

## Farbverlauf über den Tag: [Stunde, Farbe]. Stunde 0–24, danach wird zyklisch interpoliert.
const KEYS: Array = [
	[0.0, Color(0.14, 0.16, 0.32)],
	[5.0, Color(0.14, 0.16, 0.32)],
	[6.5, Color(0.86, 0.68, 0.66)],
	[8.5, Color(1.0, 1.0, 0.98)],
	[17.0, Color(1.0, 0.98, 0.92)],
	[19.0, Color(1.0, 0.70, 0.52)],
	[20.5, Color(0.45, 0.40, 0.60)],
	[22.0, Color(0.14, 0.16, 0.32)],
	[24.0, Color(0.14, 0.16, 0.32)],
]
const WEATHER_TINT: Dictionary = {
	&"clear": Color(1, 1, 1),
	&"rain": Color(0.82, 0.86, 0.92),
	&"storm": Color(0.62, 0.66, 0.76),
	&"snow": Color(0.94, 0.97, 1.0),
	&"fog": Color(0.90, 0.92, 0.94),
}
const SEASON_TINT: Dictionary = {
	Enums.Season.SPRING: Color(1.0, 1.02, 1.0),
	Enums.Season.SUMMER: Color(1.03, 1.0, 0.96),
	Enums.Season.AUTUMN: Color(1.03, 0.97, 0.92),
	Enums.Season.WINTER: Color(0.92, 0.96, 1.04),
}
const SMOOTHING: float = 2.0

var _weather: StringName = &"clear"
var _weather_tint: Color = Color.WHITE


func _ready() -> void:
	EventBus.weather_changed.connect(func(w: StringName) -> void: _weather = w)
	color = _target_color()
	_weather_tint = WEATHER_TINT.get(_weather, Color.WHITE)


func _process(delta: float) -> void:
	var w: float = clampf(delta * SMOOTHING, 0.0, 1.0)
	_weather_tint = _weather_tint.lerp(WEATHER_TINT.get(_weather, Color.WHITE), w)
	color = _target_color()


## Tageszeitfarbe ohne Wetter/Jahreszeit (auch für Tests).
static func color_for_hour(hour: float) -> Color:
	var h: float = fposmod(hour, 24.0)
	for i in range(1, KEYS.size()):
		var a: Array = KEYS[i - 1]
		var b: Array = KEYS[i]
		if h <= float(b[0]):
			var span: float = float(b[0]) - float(a[0])
			var t: float = 0.0 if span <= 0.0 else (h - float(a[0])) / span
			return (a[1] as Color).lerp(b[1] as Color, t)
	return KEYS[KEYS.size() - 1][1]


func _target_color() -> Color:
	var base: Color = color_for_hour(TimeManager.hour)
	var season_tint: Color = SEASON_TINT.get(TimeManager.season, Color.WHITE)
	var c: Color = base * _weather_tint * season_tint
	c.a = 1.0
	return c
