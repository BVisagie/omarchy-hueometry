# Changelog

## 0.2.1 (2026-11-24)

- Every screen fits without scrolling at the default size on any 16:9,
  16:10, 21:9 or 4:3 screen: the main menu shows all five buttons (Quit
  was below the fold) and Settings shows every row.
- Where a screen still scrolls, at a larger interface size or in a small
  window, a "more" cue says so.

## 0.2.0 (2026-11-24)

- New music: a theme for the menu and one for each kind of area (forest,
  river, temple), in stereo, with tunes that follow their chords and end
  on a resolving note. The ambience is in stereo too, and birds, frogs and
  drips now sound at random while you play instead of repeating in a loop.
- Each area's landmark stands out: standing stones, a river under a rope
  bridge, ruined arches, a waterfall with rising mist, the temple and its
  shrine, and the heart tree. The map shows each area as a small picture.
- A soft bell rings in a pillar's colour when a move fills it, an orb
  squashes a little as it lands, and a hinted pillar's light breathes.
- A monkey cheers solved puzzles in the ruins and the temple.
- Redo (Ctrl+Shift+Z, or its button) replays a move you undid.
- The bundled Nunito typeface, so the game looks the same everywhere.
- Fixes: the results card fits small windows, cards are no longer
  see-through, the keys card scrolls when the window is short, and the
  board-shape previews keep their labels clear.
- The sounds are evened out and every one starts without a click; the
  settings say when Qt Multimedia is missing and the game is silent.
- The shell plugin opens through the shell's own API, and a check guards
  the plugin against anything the marketplace's security scan rejects.

## 0.1.0 (2026-11-24)

- First playable version: a Bend 2 rules engine whose gameplay laws are
  machine-checked proofs; seeded puzzle generation with a proof that every
  generated puzzle is solvable; hints along known solutions.
- A tutorial and six areas of the Lost Jungle Temple (48 levels), and free
  play in five sizes from a pool of 270 pre-solved puzzles.
- The jungle, pillars and orbs drawn in QML, with symbols for colour
  blindness, line and circle boards, reduced motion and interface scaling.
- Synthesised music, jungle ambience and effects, each orb colour with its
  own note.
- Full keyboard play, undo, restart, hints, personal bests and saved
  progress, all offline.
- Moss and ferns at the foot of each pillar, and a flower in the pillar's
  colour that opens when the pillar holds one colour and is full.
- The main menu shows the version, with the commit for builds that are not
  a release.
- A standalone app (Arch package with a launcher entry) and an Omarchy shell
  plugin (full-screen overlay with a bar button), sharing one save.
