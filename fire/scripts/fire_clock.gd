class_name FireClock
extends RefCounted
## Monotone Spielzeit in Stunden (Besitzer: Agent 4).
## TimeManager.hour springt bei Mitternacht auf 0 (gleicher Tag) und beim Schlafen auf 6:00 des
## Folgetags. Hier wird das zu einer stetig wachsenden Zahl, damit Feuer/Ofen/Trockengestell
## auch durch Schlafen ("Zeit überspringen") korrekt weiterrechnen.


static func hours() -> float:
	var h: float = TimeManager.hour
	if h < TimeManager.WAKE_HOUR:
		h += 24.0
	return float(TimeManager.day - 1) * 24.0 + h
