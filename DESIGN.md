# Denver Vs The Universe: design document

What the game is meant to be, why it looks the way it does, and what is and isn't settled.
`README.md` covers how to run, test and rebuild it; this covers intent.

## The pitch

A roguelike Space Invaders played on a home-made model of Denver. You are a toy robot running a
street cut through the middle of a plywood city on a table, shooting foam darts at alien action
figures that hang from fishing line. Between waves you pick one of three cards: a city defense, a
robot upgrade or a new ability. You lose when the robot is down or half the city is rubble.

It lives in the Scareathon arcade as an iframe and reports a score when the run ends.

## The vibe

**Buzz Lightyear plus Banjo-Kazooie, staged as a Colorado alien sideshow act.** Someone built
this in a garage beside the UFO Watchtower outside Alamosa and charges two dollars to see it.

- **Hand-made, not slick.** Buildings are jigsawed plywood with pixel art painted on, paint
  splatter where the brush flicked, and visible sheet thickness. The UI is cardboard cut with
  scissors, outlined in marker and stuck up with masking tape.
- **Toys, not machines.** The robot and the aliens are glossy plastic figures. The gun is a foam-dart
  blaster in orange, yellow and blue. Nothing is gritty.
- **Carnival, not sci-fi.** Marquee bulbs chase along the table front, searchlights rake the sky,
  the lettering is a sideshow poster face, and the colours are loud: lime, hot pink, cyan, gold on
  a purple dusk.
- **A real small thing photographed.** Plank table, scenic turf, resin lakes and spot lamps use real
  textures and lighting; a tilt-shift lens keeps only the play plane sharp so it reads as a model.
- **Seen through an N64.** The whole picture is drawn at under 300 lines in dithered 15-bit colour.

When two of these pull against each other, hand-made wins: a wobbly edge beats a clean one.

## The set

One long table in a dark room, a lamp over each district, the camera leaning over it.

| Left to right | What is there |
| --- | --- |
| Cherry Creek | Tidy mid-rises |
| Wash Park | Lake, trees, a few houses at the back |
| Capitol Hill | Old apartment blocks |
| Downtown | The towers and every named landmark |
| LoDo | Brick blocks |
| City Park | Lake, trees |
| RiNo | Warehouses in loud paint |

- The street is the play line. The city is about ten rows deep behind it and four in front, so
  the robot runs through the city, not along its edge. Front rows are low so it stays in view.
- Downtown is Denver's eight tallest buildings at their true heights relative to each other
  (Wikipedia's list), in the left-to-right order of the reference photograph: Four Seasons, Wells
  Fargo "Cash Register", Republic Plaza, 707 17th, 555 17th, 1144 Fifteenth, 1999 Broadway, 1801
  California. Everything else is filler kept well below them.
- Buildings are thin cardboard slabs cut to the outline of their art. Damage comes in stages:
  grime, scorch marks, holes blown through, then the roof coming down to a stump.
- Mount Blue Sky, as seen from Denver, stands along the back wall with a freight train running
  on an embankment in front of it.
- Building art takes each real tower's outline, faces and colours from a reference photo and
  repaints it as flat-faced pixel art with a drawn window grid. The landmarks that are not in the
  photo (Capitol, Union Station, D&F Tower, the Blue Bear) are drawn by hand and given the same treatment.

## The camera

- Looks at the table head on from a little above, far enough back to see the front board of the
  table and its bulbs.
- Almost still in play (a slight drift), with a wide slow orbit on the title screen.
- Swivels a little toward the way the robot is running.
- Follows the robot along the table; arrows at the screen edges count aliens out of view.

## The robot

A slim, long-limbed robot that is an F-15 stood on end, in Buzz Lightyear's white, purple and
lime: radome for a head under a horn, intakes for shoulders with the twin tails rising from them,
canopy on the chest, wings folded down the back, engines for calves.

- **Moves like an athlete.** A real run cycle with knees and elbows, turning into the run, a heel
  spin when it doubles back, a crouch on landing, a backflip when a wave is beaten.
- **Aims for itself.** It shoots the nearest alien in range and straight up otherwise. The gun arm
  stays on target through every flip. Range is an upgrade (Targeting Radar).
- **Abilities are earned.** Vector Dash (a cartwheel nothing can hit it during) and Vertical
  Takeoff (a flipping jump) are cards, not starting moves.
- **Refits.** The Strike Eagle Refit card adds hearts, damage and a force field that soaks one hit
  and recharges.

## The aliens

Few and large, not a swarm. Each wave is a squad or two of figures marching down Space Invaders
style over the neighbourhoods nearest the robot; every fifth wave is a mothership that hunts it.

| Figure | Job |
| --- | --- |
| Grey in a silver jumpsuit | The basic invader, drops bombs |
| Small saucer with a pilot | Tougher bomber |
| Chrome rocket | Dives at the robot |
| Brain Martian in a cape | Spits aimed shots |
| Two-headed one | Splits into two small heads when killed |
| Tin-toy robot | Slow, very tough |
| Abduction saucer | Parks over a building and pulls it apart; drops a supply crate |
| Mothership | Boss: spreads, divers and a charged death ray |

## Controls

Phones first. Tap where the robot should go and it runs there; drag and it follows the finger. It aims and fires by itself. Jump and Dash appear as two big cardboard
buttons at the bottom right once their cards are picked. Keyboard: arrows or A/D to run, Space, Up
or W to jump, Shift to dash.

## The run

- Waves start gentle (two greys over downtown) and steepen: more squads, more districts at once,
  tougher figures, and after wave 12 health grows faster than any build can keep up with.
- Bombs chew buildings down from the roof. Aliens that reach a rooftop or the street crash into it.
- Cards: city defenses (rooftop flak, Blucifer, the Mile High Dome, a missile battery, a Tesla
  spire, hail, the Blue Bear repair crew, a decoy cow, the UFO Watchtower), robot upgrades (fire
  rate, twin barrels, heavy rounds, piercing, green-chile splash, speed, armour, rockets, drones,
  radar), abilities (dash, jump), and repairs when the city needs them.
- Score is kills plus a bonus per wave for how much of the city still stands.

## Where things stand

Settled by the person whose game this is: the table and lamps, the three-times-longer city with
parks, plywood pixel-art buildings from the photos, 3D figures built in Blender, an
Evangelion-slim F-15 robot, few large aliens, tilt-shift and N64 filters, the orbiting camera,
dash and jump as unlocks, auto-aim with a range upgrade, 2D trees, the train, the DIY UI, and the
vibe statement above.

Chosen while building and open to change: district names and order, which abilities and upgrades
exist beyond those asked for, all numbers (health, speeds, ranges, costs), the alien cast, the
card art, and the fonts.

Not done or not checked:

- Balance has only been run by an autopilot since auto-aim, the longer table and the resized
  robot went in. It reaches waves 7 to 13; no person has tuned it.
- Phones are the target. The 3D view renders at 240 to 400 lines and steps its quality down by
  itself on a slow device, but this has not been measured on a real phone yet.
- The figures are built in Blender by a script, with bevelled edges, baked contact shading and
  small details (tail numbers, roundels, chest buttons, fingers). Editable `.blend` files are in
  `tools/blender/blend/`. They still have no sculpting, painted textures or skinned animation.
- No music. Sound effects are synthesized.
- No attract video for the arcade cabinet yet, and no leaderboard while it is in testing.
- The reference photographs are other people's and stay out of the repository; the building art
  derived from them ships.
