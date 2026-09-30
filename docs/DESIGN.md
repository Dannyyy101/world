# Design

## Das Spiel
2D-Top-Down-Spiel im Stil von Stardew Valley, Pixel-Art (16x16 Tiles), Godot 4 (GDScript).
Der Spieler entwickelt sich durch historische Epochen. Aktuell wird **nur die Steinzeit** gebaut,
in drei Phasen: **Altsteinzeit → Mittelsteinzeit → Jungsteinzeit** (`Enums.Phase`).
Ende der Epoche: Malachit im Keramikofen schmelzen → erste Kupferperle → Übergang Kupferzeit
(`EventBus.epoch_completed`).

## Design-Prinzipien (verbindlich)
- Fortschritt durch **HANDELN und BEOBACHTEN**, nie durch Skillpunkte oder Tutorial-Popups.
- Jede Spieleraktion bekommt **sofortiges Feedback** (Sound, Partikel, Animation).
- **Drei Zielebenen gleichzeitig:** Minuten (sammeln/craften), Tage (Vorräte, Werkzeug),
  Jahreszeiten (Winter, Entdeckungen, Stamm).
- **Druck ja, Frust nein:** Scheitern kostet Ressourcen, nie Fortschritt.
- **Realismus:** Technologien entstehen so, wie sie historisch plausibel entstanden sind.
- **Keine manipulativen Mechaniken** (keine Login-Belohnungen, keine künstlichen Wartezeiten, kein FOMO).

## Tageszyklus
1 Spieltag = 14 Echtminuten (`TimeManager.DAY_REAL_MINUTES`). Wachzeit 6:00–2:00 Uhr, um 2:00 Uhr
Zwangsschlaf. 28 Tage je Jahreszeit.

## Entdeckungen
`fire, hand_axe, fire_hardening, cooking, cordage, fur_clothing, smoking, blades, bow, fish_trap,
grinding, agriculture, pottery, taming, longhouse, kiln, blowpipe, copper`
