# Denver Vs The Universe

A roguelike take on Space Invaders, staged as a home-made diorama on a long table under hanging lamps. A few
large alien action figures descend on Denver at a time; you run a toy F-15 robot along a street cut through the
plywood city and, between waves, pick one of three cards: city defenses, robot upgrades or new abilities.
`DESIGN.md` says what the game is meant to be and look like.
The run ends when the robot runs out of hearts or half the city's health is gone.

Godot 4.7, GL Compatibility, built for the web (the Scareathon arcade) and phones. Everything is made in code:
`main.tscn` is one node with `scripts/main.gd` on it.

## How it is put together

- The table is 44 units long and the camera follows the robot; arrows at the screen edges count aliens off-screen.
- Buildings are painted-plywood cut-outs whose art is pixelated crops of the real towers in the two photos in
  `conceptart/`. `tools/cut_buildings.gd` makes `art/px/*.png` from outlines listed at its top; re-run it with
  `godot --headless --path . -s tools/cut_buildings.gd` after changing them. `City.ROWS` and `City.LANDMARKS`
  lay the districts out.
- The robot and every alien are 3D models built in Blender by `tools/blender/figures.py` and exported to `models/*.glb` (editable copies are saved to `tools/blender/blend/`); re-run it with `blender -b --python tools/blender/figures.py -- --out=models [--preview=<dir>]` after changing a model. `scripts/figure.gd` loads them.
- A lamp hangs over each of the seven districts (`Diorama.DISTRICTS`); the nearest three cast shadows. The table, turf and street use CC0 textures in `textures/`. Trees and the train along the back wall are pixel-art plywood cut-outs like the buildings.
- The whole view goes through `shaders/focus.gdshader`: tilt-shift blur away from the play plane, and an N64 look (low line count, 15-bit dithered colour). Set its `lines` to 0 to turn the N64 part off.

## Playing

- Run: the first finger down is a joystick (arrows or WASD on a keyboard). The robot goes the way pushed along whichever street runs that way; at a park shortcut push up or down to take it. See `scripts/roads.gd`.
- It aims at the nearest alien inside the faint ring round it and fires on its own. Jump (swipe up, or Space) and Dash (swipe sideways, or Shift) come from cards.
- Cards: click or tap one, or press 1 / 2 / 3. M mutes.
- Bombs chew buildings down from the roof; aliens that reach a rooftop or the street crash into it.
- Shooting a bomb destroys it. Saucers park over a building and pull it apart; shoot them down for a supply crate.
- Every fifth wave is a mothership that hunts the robot. Beating one always offers the Strike Eagle Refit.


## Layout

| File | What it is |
| --- | --- |
| `scripts/main.gd` | The referee: states, wave/card loop, and what every hit does |
| `scripts/diorama.gd` | The set and the camera that fits the play box to any window shape |
| `scripts/cutout.gd` | `Cutout`: a paper cut-out quad. Nearly everything on screen is one |
| `scripts/city.gd` | The three-district city, building health and crumbling |
| `scripts/swarm.gd`, `alien.gd` | Squads per district, the march, and each alien kind's behaviour |
| `scripts/shots.gd` | Everything in flight and what it collides with |
| `scripts/tank.gd` | The player robot: stats, refit tiers (`CHASSIS`), rockets, drones, A.T. field |
| `scripts/figure.gd` | Loads a figure model from `models/` and handles its flash, tint and limb swing |
| `scripts/defenses.gd` | Flak, Blucifer, dome, missile battery, Tesla spire, hail, bear crew, decoy cow, UFO watchtower |
| `scripts/upgrades.gd` | The card list and how three are dealt |
| `scripts/hud.gd`, `fx.gd`, `sfx.gd` | Interface, effects, synthesized sound (no audio files) |
| `shaders/cutout.gdshader` | The paper edge, hit flash and roof-down damage |
| `art/*.svg` | All the art. Each file keeps a 10 px clear margin for the paper edge |

The fight is 2D on the z = 0 plane (x from -8 to 8, ground at y = 0); depth is only for looks. A tall window
gets a taller sky (`Diorama.play_top`) and the aliens start higher and step down further to match.

Adding a card: add an entry to `Upgrades.LIST`, then read its level in `Tank.apply` or `Defenses.sync/update`.
Adding an alien: add it to `Alien.TYPES`, draw `art/alien_<name>.svg`, and place it in `Swarm._row_kinds`.
New SVGs need `mipmaps/generate=true` in their `.import` file.

## Tests

```
godot --headless --path . -s tests/smoke.gd -- --runs=4     # autopilot plays whole runs, fast-forwarded
godot --path . -s tests/shots.gd -- --shots=<dir> [--portrait]   # screenshots of each screen
godot --headless --path . -s tests/roads.gd                   # walks the street graph the way the joystick does
```

## Web build

```
godot --headless --path . --export-release Web build/index.html
```

On game over the game posts `{ type: 'PLAYER_DIED', score }` to the parent page for the arcade leaderboard.

Font: Jost (SIL Open Font License, see `fonts/Jost-OFL.txt`).
