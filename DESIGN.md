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
- **A real small thing.** Plank table, scenic turf, resin lakes and spot lamps use real textures
  and lighting. (A tilt-shift blur was tried and taken out.)
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

- The table is deep: about twelve rows of city behind the front street, the back road, then rows
  of suburbs out to the railway and the mountains. In front of the street there are five low rows and then
  suburbs out to the table edge, so the street runs through the middle of town. The camera is low
  enough that the front rows hide the robots' feet.
- The small buildings are houses, townhomes, churches, schools, shops and firehouses, not boxes.
- Downtown is Denver's eight tallest buildings at their true heights relative to each other
  (Wikipedia's list), in the left-to-right order of the reference photograph: Four Seasons, Wells
  Fargo "Cash Register", Republic Plaza, 707 17th, 555 17th, 1144 Fifteenth, 1999 Broadway, 1801
  California. Everything else is filler kept well below them.
- Buildings are thin cardboard slabs cut to the outline of their art. Damage comes in stages:
  grime, scorch marks, holes blown through, then the roof coming down to a stump.
- Landmarks beyond downtown: Elitch Gardens (wheel, coaster and drop tower), Sloan's Lake, Union
  Station and LoHi are on the back road; the Civic Center colonnade stands by the Capitol.
- Mount Blue Sky, as seen from Denver, stands along the back wall, pale and snowy, with a darker
  foothill ridge and a darkest near ridge in front of it so the three read as separate layers. A
  freight train runs on an embankment before them. They do not move.
- The table, backdrop and everything on them stop just past the ends of the city.
- Building art takes each real tower's outline, faces and colours from a reference photo and
  repaints it as flat-faced pixel art with a drawn window grid. The landmarks that are not in the
  photo (Capitol, Union Station, D&F Tower, the Blue Bear) are drawn by hand and given the same treatment.

## The camera

- Looks at the table head on and almost level, far enough back to see the front board of the
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

They come as five invasions of five waves each, every one in its own colours with its own ranks
and kaiju: the Venusians (the classic greys and saucers), the Europans (icy blue, saucers and
brain Martians, a turtle kaiju), the Titans (orange, tin robots), the Oort Cloud Collective (blue
crystals) and, from deep space, white winged things with spears. The last invasion goes on for ever.

| Figure | Job |
| --- | --- |
| Grey in a silver jumpsuit | The basic invader, drops bombs |
| Small saucer with a pilot | Tougher bomber |
| Chrome rocket | Dives at the robot |
| Brain Martian in a cape | Spits aimed shots |
| Two-headed one | Splits into two small heads when killed |
| Tin-toy robot | Slow, very tough |
| Abduction saucer | Parks over a building and pulls it apart; drops a supply crate |
| Crystal | A flawless blue eight-sided crystal that fires aimed shots (after Evangelion's Ramiel) |
| Harrier | White, eyeless, winged, grinning, with a two-bladed spear; dives on the robot (after Evangelion's mass-production units) |
| Toy kaiju | A wind-up dinosaur or an upright turtle: drops onto the street and stomps after the robot, kicking down what it passes |
| Mothership | Boss: spreads, divers and a charged death ray |

## Controls

Phones first.

- **Joystick:** the first finger down, anywhere on the screen. The robot goes exactly the way
  pushed, along whichever street runs that way: round a bend the push has to follow the street,
  and at a park shortcut pushing up or down takes it. Let go to stop.
- **Swipes:** a quick flick of any finger. Up to jump, sideways to dash, once those are unlocked.
- **Aiming** is automatic, at the nearest alien inside the faint ring round the robot.
- **Keyboard:** arrows or WASD work as the joystick, Space jumps, Shift dashes.

The streets are a ring with rounded corners round the city (front street, both ends, and a road
behind the last row) with a shortcut across it through each park. On the back road the camera
climbs a little to see over the roofs.

## The wingmen

Two orange robots that steer themselves start every game beside the player, one to each side. Each
goes and stands under the alien furthest out on its side and shoots. They have three hearts each,
can be hit by anything that can hit the player, and are gone when those run out, unless rebuilt in
the workshop. The Wingman Drills card and the Hive Mind tech improve them. They can be switched
off in the options.

## The workshop

After the card comes the workshop, where the scrap from downed aliens is spent.

- **Shop:** mend the town, mend a heart, rebuild a wingman.
- **Alien tech:** nine pieces of reverse-engineered alien technology in three lines of three
  (weapons, movement, protection), each needing the one before it. Each gives a level of an
  existing upgrade, so tech and cards stack.

## The menu

The title screen has PLAY and OPTIONS. Options, remembered between visits: sound, picture (auto,
sharp or fast), retro filter and wingman.

## The townsfolk

Peg people stand along the front edge of the table like an audience, and in the parks. They hop
on the spot, jump for joy at a kill nearby and run from a building that is hit. Nothing hurts them.

## The run

- Waves start gentle (two greys over downtown) and steepen: more squads, more districts at once,
  tougher figures, and after wave 12 health grows faster than any build can keep up with.
- Bombs chew buildings down from the roof. Aliens that reach a rooftop or the street crash into it.
- Cards: city defenses (rooftop flak, Blucifer, the Mile High Dome, a missile battery, a Tesla
  spire, hail, the Blue Bear repair crew, a decoy cow, the UFO Watchtower, a wall round the city
  that stops landings and stomps, a laser on the summit of Mount Blue Sky), robot upgrades (fire
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
