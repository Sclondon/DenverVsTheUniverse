# Denver Vs The Universe: design document

What the game is and how it plays. `README.md` covers how to run, test and rebuild it. Where a
number appears here the code is the authority, and the file is named.

Sections 1 to 9 are the design. The appendices hold status, open questions and art notes.

## 1. The pitch

A roguelike Space Invaders played on a home-made model of Denver. Three toy robots hold a
cardboard city on a table against alien action figures that hang from fishing line and toy kaiju
that stomp down the street. You steer one robot; two more steer themselves. Between waves you
pick an upgrade card and then spend alien scrap in a workshop. You lose when your robot is down
or half the city's health is gone.

It runs in the Scareathon arcade as an iframe behind the code DENVS, and phones are the target.
It sends the arcade its score when a run ends; the arcade does not keep a leaderboard for it yet.

**Words used here**

| Word | Meaning |
| --- | --- |
| Figure | Any 3D toy: a robot, an alien, a kaiju |
| Squad | A block of aliens marching together, Space Invaders style |
| Rank | One kind of alien within an invasion |
| Invasion | Five waves of one alien people |
| Front street | The street the fight mostly happens on, with city on both sides of it |
| Ring | The loop of streets round the city: front street, two ends, back road |
| Shortcut | A street across the ring through a park |
| City | The on-screen reading, 100 when whole and 0 when half the buildings' health is gone |
| Scrap | What kills pay, spent in the workshop |

## 2. The vibe

**Buzz Lightyear plus Banjo-Kazooie, staged as a Colorado alien sideshow act.** Someone built
this in a garage beside the UFO Watchtower outside Alamosa and charges two dollars to see it.

| Pillar | What it means on screen |
| --- | --- |
| Hand-made, not slick | Buildings are thin cardboard cut to shape with pixel art painted on and paint splatter where the brush flicked. The UI is cardboard cut with scissors, outlined in marker, stuck up with masking tape. |
| Toys, not machines | Robots, aliens and kaiju are glossy plastic figures. The gun is a foam-dart blaster. The townsfolk are peg people. Nothing is gritty. |
| Carnival, not sci-fi | Marquee bulbs chase along the table front, searchlights rake the sky, the lettering is a sideshow poster face, the colours are lime, hot pink, cyan and gold on a purple dusk. |
| A real small thing | Plank table, scenic turf, resin lakes and hanging spot lamps, with real textures and shadows. |
| Seen through an old console | The 3D picture is drawn small and stretched, with a light dither. This is also what keeps phones fast. It can be switched off. |

When two of these pull against each other, hand-made wins: a wobbly edge beats a clean one.

## 3. The loop

1. **Wave.** Aliens arrive over the neighbourhoods nearest your robot. Shoot them before they
   bomb, land on or stomp the city.
2. **Card.** Pick one of three.
3. **Workshop.** Spend scrap on repairs and on reverse-engineered alien tech.
4. Next wave. Every fifth wave is a mothership; every five waves a new invasion begins.

A run ends when your robot's hearts are gone or City reads 0. There is no win: the last invasion
repeats and gets harder.

## 4. The table

One long table in a dark room, a lamp over each district, everything stopping just past the ends
of the city (`scripts/diorama.gd`, `scripts/city.gd`).

**Along the table, left to right**

| District | What is there |
| --- | --- |
| Cherry Creek | Tidy mid-rises |
| Wash Park | Lake, trees, a shortcut |
| Capitol Hill | Old apartment blocks |
| Downtown | Denver's eight tallest towers, the Capitol, the Civic Center colonnade, the D&F Tower, the Blue Bear |
| LoDo | Brick blocks |
| City Park | Lake, trees, the other shortcut |
| RiNo | Warehouses in loud paint |

**Front to back**

| Band | What is there |
| --- | --- |
| Table edge | Marquee bulbs, the audience of peg people, district signs |
| Front suburbs | Houses, churches, schools and trees (scenery) |
| Front rows | Five low rows of city; the camera is low enough that they hide the robots' feet |
| Front street | Where most of the fight happens |
| The city | About twelve rows, towers and landmarks in the first few |
| Back road | With Elitch Gardens, Union Station, a LoHi sign and Sloan's Lake beyond it |
| Back suburbs | Rows of houses out to the railway (scenery) |
| Railway | A freight train on an embankment that never stops |
| Mountains | Three still layers: Mount Blue Sky pale and snowy, a darker foothill ridge, a darkest near ridge |
| Backdrop | A painted dusk fading to a starry night |

**Buildings**

- Every building is a thin cardboard slab cut to the outline of its pixel art.
- Small buildings are houses, townhomes, churches, schools, shops and firehouses, not boxes.
- Damage comes in stages: grime, scorch marks with an ember glow, holes blown through, then the
  roof coming down to a stump below about half health.
- Suburbs, trees, the train and Elitch Gardens are scenery: nothing lands on them.

**The streets** (`scripts/roads.gd`): a ring with rounded corners round the city, and a shortcut
across it through each park.

## 5. Playing

### Controls

| Action | Touch | Keyboard |
| --- | --- | --- |
| Run | The first finger down, anywhere, is a joystick | Arrows or WASD |
| Jump | A quick tap, or a flick up | Space or Enter |
| Dash | Flick sideways | Shift |
| Aim and fire | Automatic | Automatic |
| Pick a card | Tap it | 1, 2, 3 |
| Mute | Options | M |

- The robot goes exactly the way pushed, along whichever street runs that way. Round a bend the
  push has to follow the street. Let go and it stops.
- Within about four units of a shortcut, pushing up or down takes it, even with the stick
  leaning a little to one side.
- A flick is a quick movement. With the joystick finger it must come in the first fifth of a
  second after touching down. A second finger may rest first and flick later.
- A dash runs its course before steering takes over again.
- Jump and dash are there from the start; cards and tech make the jump higher and the dash ready sooner.
- It shoots the nearest alien inside the faint ring round it, and straight up when there is none.
  The ring is exactly the gun's reach and does not move with the robot's animation.

### Rules

- **Shots are settled in one flat plane along the table.** A bomb falling at your position hits
  you whichever street you are on.
- **What a falling shot hits, in order:** the Mile High Dome, your robot, a wingman, a building.
- **What a landing alien hits, in order:** your robot, a wingman, then a building within reach,
  unless the City Wall has a charge left.
- **Kaiju** only touch a robot on the front street. Yours is also safe above a low jump's height.
- **After a hit** your robot cannot be hurt for 1.6 seconds, a wingman for 1.2. A force field
  that soaks a hit gives 0.6. A dash cannot be hurt at all.
- **Hearts:** yours start at six; wingmen have three.

### What the streets are for

The ring and shortcuts are how you get to a far district, and the back road keeps you out of a
kaiju's reach. Beyond that, depth is for looks: fights do not change with which street you are
on. Whether the back road should matter more is an open question (appendix B).

### The camera

- Head on and almost level, far enough back to see the table's front board and its bulbs.
- Follows your robot along the table. Arrows at the screen edges count aliens out of view.
- Nearly still in play, a slow wide drift on the title screen, a small swivel toward the run.
- On the back road it climbs a little to see over the roofs.

## 6. The robots

**Yours** is a slim, long-limbed robot that is an F-15 stood on end, in Buzz Lightyear's white,
purple and lime. It runs with knees and elbows, spins on its heel when it doubles back,
cartwheels through a dash, flips through a jump, and backflips when a wave is beaten. It holds
the blaster with a bent elbow along the line of fire, lowers it to the ready when there is
nothing to shoot, and turns its head to watch its target.

**The wingmen** are two orange copies that steer themselves, one to each side of you. Each
stands under the alien furthest out on its side and shoots. They keep to the front street. A
destroyed wingman stays gone for the rest of the game unless rebuilt in the workshop; both return
for the next game. Their hearts show under the score. They can be switched off in the options.

Not to be confused with the **Gun Drone** card, which hangs small gun drones over your own robot.

## 7. The aliens

Few and large, not a swarm. A wave is a squad or two, plus whatever lands.

**Five invasions of five waves** (`Swarm.INVASIONS`); the last repeats for ever.

| Waves | Invasion | Colours | Ranks, one new each wave | Kaiju |
| --- | --- | --- | --- | --- |
| 1-5 | The Venusians | As modelled | Grey, small saucer, rocket, brain Martian | Dinosaur |
| 6-10 | The Europans | Icy blue | Small saucer, brain Martian, grey, two-headed | Turtle |
| 11-15 | The Titans | Orange | Tin robot, grey, rocket, two-headed | Dinosaur |
| 16-20 | The Oort Cloud Collective | Pale violet | Crystal, two-headed, rocket, crystal again | Turtle |
| 21 on | From deep space | As modelled | Harrier, crystal, tin robot, brain Martian | Dinosaur |

- Until wave 7 a squad is a single row of that wave's newest rank, so wave 2 is all small
  saucers and wave 3 all rockets. From wave 7 there is a second row drawn from the ranks met so far.
- A tin-robot row is one robot with greys beside it.
- The fifth wave of each invasion is the mothership. Wave 5 has it alone; later ones bring squads.
- One kaiju lands from wave 4, two from wave 9, none on mothership waves.

**The figures** (`Alien.TYPES`). Scrap is points divided by 8, rounded up.

| Figure | Job | Health | Points | Scrap |
| --- | --- | --- | --- | --- |
| Grey in a silver jumpsuit | Basic invader, drops bombs | 5 | 40 | 5 |
| Small saucer with a pilot | Tougher bomber | 9 | 80 | 10 |
| Chrome rocket | Breaks formation to dive on the robot | 3 | 90 | 12 |
| Brain Martian in a cape | Fires aimed shots | 7 | 100 | 13 |
| Two-headed one | Splits into two small heads (2 health each) when killed | 8 | 120 | 15 |
| Tin-toy robot | Very tough, drops a bigger bomb | 30 | 320 | 40 |
| Crystal | A flawless blue eight-sided gem that fires aimed shots | 12 | 160 | 20 |
| Harrier | White, eyeless, winged, with a two-bladed spear; dives | 9 | 150 | 19 |
| Abduction saucer | Parks over a building and pulls it apart; drops a supply crate | 12 | 240 | 30 |
| Dinosaur kaiju | Wind-up toy; stomps after your robot kicking buildings down | 26 | 350 | 44 |
| Turtle kaiju | Slower and tougher | 42 | 450 | 57 |
| Mothership | Spreads, divers and a charged death ray | 110 | 2000 | 250 |

**Difficulty** (`Swarm.spawn_wave`)

- Health is as listed through wave 5, then grows by 18% of the base each wave, and steeply after
  wave 12. The mothership's health also multiplies by how many motherships have come.
- Squads: one over the nearest district at first, then one of the nearest two, then two at once
  from wave 5 and three from wave 8.

**Score** (`scripts/main.gd`): each kill is worth its points times `1 + 0.25 x (wave - 1)`, plus 2
for a bomb shot down, 100 for a supply crate, and `5 x wave x City` at the end of each wave. An
alien that lands gives no points and no scrap.

## 8. Cards

One of three after each wave (`scripts/upgrades.gd`). A defense is always among them while any
is left. Emergency Repairs (rebuild one wreck to half health, three floors back on every damaged
building, one heart) is offered when City reads below 75, and fills a gap when few cards are left.

| City defense | Levels | What it does |
| --- | --- | --- |
| Rooftop Flak | 4 | An auto-cannon on a downtown roof per level |
| Blucifer | 3 | The airport's horse stares the toughest alien down |
| Mile High Dome | 3 | A shield over downtown that soaks 4 bombs a wave per level |
| Front Range Battery | 3 | Homing missiles |
| Tesla Spire | 3 | Chain lightning from Republic Plaza |
| Hail Storm | 3 | Colorado weather pelts the sky |
| Big Blue Bear Crew | 3 | Patches 2, 4 or 7 floors after each wave |
| Decoy Cow | 1 | Abduction saucers go for it instead of buildings |
| UFO Watchtower | 2 | Speeds up every defense that works on a timer by a quarter per level |
| City Wall | 3 | Stops 3, 6 or 10 landings and stomps a wave that would have hit a building |
| Summit Laser | 3 | A gun on the peak of Mount Blue Sky burns the toughest alien every 5, 3.5 or 2 seconds |

| Robot upgrade | Levels | What it does |
| --- | --- | --- |
| Rapid Fire | 5 | A quarter faster per level |
| Extra Barrel | 3 | One more barrel per level |
| Heavy Rounds | 4 | +1 damage per level |
| Piercing Rounds | 3 | Darts go through one more alien per level |
| Green Chile Rounds | 3 | Darts burst on impact |
| Targeting Radar | 3 | Reach of 17 units, +4 per level |
| Afterburners | 3 | A fifth faster per level |
| Extra Armor | 3 | +1 heart and a full refill |
| Shoulder Rockets | 3 | Homing rockets at the toughest alien |
| Gun Drone | 2 | A small gun drone over the robot per level |
| Vector Dash | 2 | The dash is ready twice as fast, then faster still |
| Vertical Takeoff | 2 | A higher jump and faster fire in the air, then higher still |
| Strike Eagle Refit | 2 | Hearts, damage and a force field. Not before wave 3; always offered after a mothership |
| Wingman Drills | 4 | Wingmen shoot faster, harder and farther; twin barrels at level 3. Not offered with none in the fight |

## 9. The workshop

After the card, the workshop (`scripts/workshop.gd`). Everything costs scrap. Things that would
do nothing right now are greyed out and cannot be bought.

| Shop | Cost | Effect |
| --- | --- | --- |
| Patch up the town | 40 | Two floors back on every damaged building still standing |
| Spare heart | 30 | Mend one heart |
| Rebuild a wingman | 90 | A destroyed wingman returns |

**Alien tech:** three lines of three, each needing the one above it, at 60, 140 and 260 scrap.
Each gives a level of an existing upgrade, on top of any cards and past a card's own limit.

| Weapons | Movement | Protection |
| --- | --- | --- |
| Ray Optics: +1 damage | Saucer Lift: run faster | Alien Alloy: +1 heart, full refill |
| Plasma Rounds: darts pierce | Gravity Boots: a higher jump | Force Field: a refit tier (or +1 heart if both are held), full refill |
| Mothership Core: fire faster | Warp Dash: a dash ready sooner | Hive Mind: better wingmen |

**Scrap against cost, by arithmetic and not yet by play:** wave 1 pays 10, a wave of two small
saucers 20, a kaiju 44, a mothership 250. A first-tier tech should be affordable around wave 3
or 4 and a whole line somewhere in the second invasion.

## Appendix A. Where things stand

**Asked for by the owner and built, in outline:** the vibe, the table with its districts and
landmarks, cardboard pixel-art buildings from the photos, Blender figures, the F-15 robot and its
poses, the ring of streets with park shortcuts, joystick and swipes, auto-aim with a range ring,
three robots, the five invasions by name, Evangelion-inspired aliens, kaiju, peg people, the shop
and tech tree, the wall and a mountain-top gun, the menu.

**Chosen while building and open to change:** every number; which ranks each invasion has; what
each tech piece and shop item does; that tech re-uses existing upgrades; the wingmen's hearts and
that they keep to the front street.

**Not done, thin, or not checked**

- No person has played it since most of this went in. Balance is run by an autopilot
  (`tests/smoke.gd`) that only uses the front street. The street graph and steering have their
  own test (`tests/roads.gd`). Touch input itself has no test.
- It has not been run on a phone. Frame rate and touch feel are unmeasured.
- Invasions two to four are mostly the first invasion's figures in a different colour. Only the
  crystal, the harrier and the turtle are new models, and the crystal behaves like the brain
  Martian. The mothership is the same for every invasion.
- Tech and shop items are existing effects under new names; there is no new mechanic behind them.
- LoHi is a sign. Union Station cannot be seen from the front street.
- One mountain-top defense exists, not a family of them.
- No music. Sound effects are synthesized. No attract video for the arcade cart.

**Tried and switched off at the owner's request:** a tilt-shift blur (the lens code remains,
unused), mountains that slid with the camera, a camera that looked down at an angle, and running
that carried on round the ring by itself.

## Appendix B. Open questions

- **What should a run feel like?** No target has been set for how long a run lasts or what wave
  a good one reaches. The autopilot reaches waves 6 to 10.
- **Should depth matter in a fight?** Today only kaiju care which street you are on.
- **Should each invasion have its own mothership and its own behaviours,** not just its own colours?
- **Should tech be new mechanics** (a tractor beam, a ray gun) and not levels of existing upgrades?
- **How should the wingmen read on a phone** once their hearts, yours and the city are all on screen?

## Appendix C. Art notes

- **The towers.** Downtown is Denver's eight tallest buildings at their true heights relative to
  each other (Wikipedia's list), in the left-to-right order of the reference photograph: Four
  Seasons, Wells Fargo "Cash Register", Republic Plaza, 707 17th, 555 17th, 1144 Fifteenth, 1999
  Broadway, 1801 California. Filler is capped well below them.
- **Where the art comes from.** For five of the towers the outline, faces and colours are taken
  from the photo and repainted as flat-faced pixel art. Four Seasons, 1144 Fifteenth and 1999 Broadway are drawn by
  hand as flat faces. All eight then get the same painted windows: separate square panes, spaced
  apart and low in contrast, because rows of windows close together read as scan lines when a
  building is small. Everything else is drawn by hand and pixelated (`tools/cut_buildings.gd`).
  Building textures need mipmaps switched on in their import settings for the same reason. Which photo crop is 707 17th and which is 555 17th is a
  guess, and so is where Four Seasons and 1144 Fifteenth stand.
- **The reference photographs** are other people's and stay out of the repository. Art derived
  from them ships.
- **The figures** are built in Blender by a script (`tools/blender/figures.py`) with bevels,
  baked shading and small details, and editable `.blend` files beside it. No sculpting, painted
  textures or skinned animation. The robot: radome head under a horn, intake shoulders with the
  twin tails rising from them, canopy on the chest, wings down the back, engines for calves,
  tail number 15.
- **Evangelion.** The crystal is after Ramiel; the harrier is after the mass-production units.
- **Picture quality** has three steps (`Diorama.QUALITY`): lines drawn, how near a lamp must be
  to cast shadows, shadow map size. Phones start on the second and a slow device steps down by
  itself. Options: sound, picture (auto, sharp, fast), retro filter, wingmen.
- **The townsfolk.** About 150 peg people along the front edge of the table and in the parks.
  They hop, jump for joy at a kill nearby and run from a building that is hit. Nothing hurts them.
