# CyborgOS - the decision services

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

How CyborgOS's decision making works, from the ports up to the virtual pet, how to get an AI
to write models for it, and how to hook a model up to an IO board. The file format is in full in `src/bas/cyborgos320kb/apps/rat/RATMODEL.TXT`
(also on disc 6); this document is the whole picture.

## 1. The idea

A game or a tool knows the state of things (health, hunger, what is in sight, a sensor's reading).
It does not decide what to do: it asks a service "of these things I could do, which?" and gets one
answer back. The deciding lives in a **model** - a plain text file of weights - not in the game's
code. The same game with another model behaves differently; one decision service serves every
game and tool running.

It is decision making, not talk: deterministic rules over weights, every answer explainable
(the plan says how it was reached), no hallucination. It is not for mission critical work.

## 2. The pieces

All of them are CyborgOS programs (`.CYB`, built for cpm with `cmds/CybSys.cls`), each in a slot
(a 64K bank) of its own, talking through **ports**.

| Program | What it is |
|---|---|
| **Ports** (CyborgOS, BDOS 131 ops 28-34) | a program opens a named port; others call it by name - a 128-byte message, a 128-byte answer. 8 ports. A caller waiting sleeps until the next tick. Slots don't matter: names do |
| `MODEL file` | serves one model (`FILE.MDL`) on a port named after the file (`MODEL PET` -> port `PET`). Holds the weights, changes them (habit, praise, `V` from outside), saves them back to the file |
| `RAT` | the decision service, port `RAT`. Holds no model: each call names one. Applies the rules (section 3), asks the model for weights, tells it what was picked |
| `NEURAL file` | the other decision service: learns records from examples (`FILE.NN`, jNeuralNetwork's way), gives back the best match (section 6) |
| `PROBE` | the test drive: its own command line - decisions with their plans, dry or real runs, a model's weights, the ports running, any port asked |
| `ASK port message` | any port called from CyborgOS's command line |
| `PET` | the virtual pet (Tamagotchi style), on RAT and `PET.MDL` |
| `RATS` | the first sample: a rat in a box, on RAT and `RATMODEL.MDL` |
| `RATBOX` | a box of up to 100 rats: a swarm on one model (`RATBOX.MDL`), a LUN a rat (section 7) |
| `WATCH` | NEURAL fed with CyborgOS's own numbers (free memory, programs running) |

Start them in any free slots - only the port names matter:

    RUN 2 MODEL PET
    RUN 3 RAT
    PET Rex

A 576K CPC has 4 slots (your command line is one), 4MB has 20: one application, RAT and up to 18
models.

## 3. How RAT decides

A call:

    model tag tag:level tag ...

The **tags** are what could be done now - the caller decides that from its senses and state (a
dungeon NPC that sees the player passes `attack flee:<hp> hide shout`; one that only hears,
`investigate wait flee:<hp>`). `:level` (0-100, how much there is: health, food, energy) goes with
necessities. The answer is one path and a value: `food.fruit.apple 34`.

The model is a tree under four categories:

| | | |
|---|---|---|
| **N** | necessities | live or die. The N weight is the **threshold**: below it, the need takes over |
| **R** | requirements | what WE want of it - its role in a game |
| **L** | likes | its own preferences - they grow with habit |
| **D** | dislikes | its own aversions |

The rules, the same for every model:

1. **Necessity.** A tag under N whose level is below its N weight is in danger; the lowest (its
   level as a part of its threshold) wins over everything. `flee 10` is a brave creature (it runs
   below 10 health), `flee 60` a fearful one.
2. **Requirement.** Otherwise the tags under R with the highest weight go on (all of them, when
   none is under R).
3. **Taste.** Among those, the highest L - D wins.

**Tolerance and the deadband.** Weights within 5 of the best are as good. Among them, the one this
model picked last time stays picked - a deadband, so near-equal choices don't flip back and forth
(as a drone holding altitude would fight over itself); only when the last pick drops out does RAT
pick one of the contenders at random.

**Multilevel.** A model is as deep as its maker makes it - 2 levels or 50. When the tag chosen has
branches under it, RAT chooses among them by the same rules (2 and 3), and on down to a branch with
none: `food` -> `food.fruit` -> `food.fruit.apple`. A caller can start lower by passing paths
(`food.meat.chicken food.meat.fish`).

**Habit.** Every level's pick raises its L weight a point (to 100); MODEL saves the weights to the
file every 10 changes and when it ends. A program can move likes itself (`P tag n` up, `X tag n`
down - PET's praise and scolding) and set any weight from outside (`V cat\tag\tag\x` - a game, a
sensor).

**The plan.** A call starting `?` gets how RAT got there, a level a part, like a database's query
plan:

    food.fruit.orange 34 |N food=66 |LD fruit=50 +2 |LD apple=60 orange=55 +3 rnd/2

each level's stage (N, R, LD), its contenders with their weights (+n others), then `kept` (the
deadband) or `rnd/n`. A call starting `~` is **dry**: decided, but nothing learnt and nothing kept.

## 4. A model file

    ' PET: the virtual pet's mind
    N
     food 30
     bed 25
     play 20
    L
     food 30
     bed 25
     play 40
     tv 40
     wander 20

A category letter alone on its line; each branch a line, its depth the spaces before it, a name
(no spaces or dots, 15 characters) and a weight 0-100 (none: 50 - give a D parent 0 when only its
branches are disliked). `'` starts a comment. Up to 401 lines. The port name is the file name (8
characters). `RATMODEL.TXT` has every detail.

## 5. Testing a model: PROBE

    RUN 2 MODEL FOOD
    RUN 3 RAT
    PROBE

    probe> food food:20 sleep:80
    -> food.fruit.orange 34
       N food=66
       LD fruit=50 +2
       LD apple=60 orange=55 +3 rnd/2
       dry
    probe> show food sleep apple
    tag                N    R    L    D   (-: not in it)
    sleep             25    -   30    -
    apple              -    -   60    -
    probe> set food N\sleep\90
    set

DRY is on as PROBE starts (probing changes nothing); `TRY` is a dry run and `RUN` a real one, this
once; `DRY OFF` makes every call real. `SHOW model` lists every line; `LIKE` / `DISLIKE` move a
like; `SET` sets a weight as a sensor would; `PORTS` lists the services running; `ASK port message`
asks anything (NEURAL too). `PROBE command` runs one command from CyborgOS's command line.

## 6. NEURAL

`NEURAL file` learns from examples instead of hand-written weights - jNeuralNetwork's way: a record
is `prop=value` words, and each prop=value's weight is how often it was seen.

    sense=see dist=1 hp=20 courage=high action=flee *3

`Q action? sense=see dist=2 hp=30 courage=high` gives the best match (`93 action=flee`): numbers
match by how near they are, text the same (or `val*` by its start), ties by how often seen. `T ...`
teaches it a record. Give every record the same props. Use RAT for behaviour you can describe as
rules and weights; NEURAL for behaviour you have examples of.

## 7. The virtual pet

PET keeps the stats and draws the room; every decision is RAT's, from `PET.MDL`. You fill the bowl
(F), switch the TV (T), clean its mess (C, the `%`s), give medicine (M), praise (+) or scold (-) -
the model's like for what it is doing moves 3 - and quit (Q, saved to `PET.SAV`). Doing the same
thing three times running bores it (that like down 2), so habits form but it keeps some variety.
It grows a day a minute; dirt or starving makes it ill; at 0 health it dies. PET offers only what
is possible (food when the bowl has some, TV when it is on); the model decides among those.

### LUNs and the box of rats

One model can drive a swarm. MODEL keeps copies of the model's weights, called **LUNs**. It keeps
as many as fit in 30000 bytes (a byte a line each), 250 at most: a 16-line model has 250. LUN 0 is
the file's. Each other LUN starts as a copy of it and learns its own habits; they're kept in
`NAME.LUN`. Each creature is a LUN: RAT's call `RATBOX:5 food:30 bed:80 play` decides for LUN 5,
with its weights, its habit and its own deadband.

- `LUNS model` to RAT: how many LUNs the model has (`250 16`: LUNs, lines). A game asks it first
  to know how many creatures it can have.
- `!model message` to RAT: the message goes to the model as it is.
- `#n R` to MODEL: LUN n gets the file's weights again (a new creature). `R` alone reads the file
  again.
- `#c B a b` to MODEL: LUN c is bred from LUNs a and b. Each weight is one parent's or the other's,
  -2 to +2, so babies take after their parents.

**RATBOX** is the sample: a box of rats on `RATBOX.MDL`, a LUN a rat. You give it the numbers of
males and females (`RATBOX 5 5`). RAT decides for each rat: eat, sleep, play, TV, wander, groom a
friend, mate, fight a rival, nurse its babies.

- **Relationships:** rats like or dislike each other. Grooming and mating raise it; fighting
  lowers it.
- **Breeding:** healthy adults of the two sexes mate. Two males after the same female fight in
  the boxing ring (bottom middle); the loser is hurt and the winner mates.
- **Babies:** born in the pen (right side), 1-3 three days after mating. They live on their
  mother's nursing until they are weaned at 3 days. Each is bred from its parents' LUNs.
- **Death:** the dead go to the graveyard (left side). Their LUNs are reused for new babies.
- **Crowding:** over 20 rats the box gets dirty faster, the rats eat more, fall ill, like each
  other less and fight more, and breed less.
- **The keeper:** the naughty bed (top middle) is yours. Choose a rat (`.` and `,`), then `N`
  sends it there for a while and scolds what it was doing.

RATBOX only offers what is possible: `mate` when there's a healthy adult of the other sex it
likes, `fight` for a male when there's a male it dislikes, `nurse` for a mother with babies in
the pen. The model decides among those.

### How RATBOX, RAT and MODEL work together

Three programs, three jobs:

| Program | Holds | Does |
|---|---|---|
| `RATBOX` | the box: each rat's place, sex, age, food, energy, fun, health, illness, pregnancy, mother; how much each rat likes each other rat; the bowl, the mess, the TV, the graves | draws the box, runs the rats' lives tick by tick, works out what each rat *could* do now, asks RAT what it *will* do, then carries it out |
| `RAT` | each LUN's last pick (the deadband), nothing else | decides: applies the rules to the weights it is given |
| `MODEL RATBOX` | `RATBOX.MDL`'s tree, LUN 0's weights (the file's), every other LUN's weights | answers weight questions, changes weights (habit, praise, scolding, breeding), saves them |

RATBOX never reads the model and never decides; RAT never knows what a rat is; MODEL never knows
there is a box. Each talks to the next through a port.

**The model.** `RATBOX.MDL` is one flat tree of 16 lines:

    N                L                D
     food 30          food 30          fight 15
     bed 25           bed 25
     play 20          play 40
                      tv 35
                      wander 20
                      mate 45
                      groom 35
                      nurse 55
                      fight 25

(in the file each category's branches follow it, one a line). N says when a need takes over:
below 30 food a rat must eat, below 25 energy it must sleep, below 20 fun it must play. L and D
are its personality. Every rat starts with these weights; from then on each rat's own copy
drifts.

**Starting up.**

1. `RUN 2 MODEL RATBOX`: MODEL reads `RATBOX.MDL` (16 lines), works out its LUNs (1 + 30000 / 16,
   cut to 250) and reads `RATBOX.LUN` if it is there and was made for 16 lines. It opens the port
   `RATBOX`.
2. `RUN 3 RAT`: RAT opens the port `RAT`.
3. `RATBOX 5 5`: RATBOX calls RAT `LUNS RATBOX`. RAT passes `U` to MODEL, which answers `250 16`.
   LUN 0 stays the model's own, so RATBOX can have 249 rats; it keeps to 100. If RAT or the model
   isn't there yet, RATBOX asks again for up to 9 seconds.
4. A new box: rat *i* is LUN *i* + 1. For each, RATBOX calls RAT `!RATBOX #n R`; RAT passes
   `#n R` to MODEL, which gives LUN *n* the file's weights again - a fresh rat, whatever an earlier
   box left in that LUN. The rats' liking for each other starts between 40 and 70, at random.
5. `RATBOX` alone loads `RATBOX.SAV` instead (the box), and the rats' weights are already in
   MODEL from `RATBOX.LUN`: the rats come back with the habits they had.

**One decision, call by call.** A rat that has finished what it was doing (state 0) gets a
decision. RATBOX makes 2 a tick at most, taking turns round the box, so 100 rats don't stop the
box while they all think. Say rat 4 (LUN 5) has energy 70, fun 15, food 60, the bowl has food,
the TV is off, and there's a female it likes:

1. RATBOX builds the call from what is possible: `RATBOX:5 bed:70 play:15 wander food:60 mate`
   (`food` only with food in the bowl, `tv` only when it's on, `mate`, `groom`, `fight`, `nurse`
   only when there's someone to do it with). It calls RAT.
2. RAT reads `RATBOX:5`: the model `RATBOX`, LUN 5. Every message it sends MODEL for this call
   starts `#5 `. It finds LUN 5's deadband slot (`RATBOX#5`; it keeps 128).
3. RAT asks the weights, 6 tags a message: `#5 W bed play wander food mate`. MODEL answers each
   tag's N, R, L and D from LUN 5's copy: `25,-1,25,-1 20,-1,40,-1 -1,-1,20,-1 30,-1,30,-1
   -1,-1,45,-1` (-1: not in that category).
4. RAT applies the rules. Necessity: play's level 15 is below its threshold 20 - 75% of it; bed's
   70 and food's 60 are above theirs. So `play` wins over everything, value 100 - 75 = 25.
5. RAT tells MODEL the pick: `#5 P play`. LUN 5's like for play goes up 1 - a habit, this rat's
   alone. Then `#5 C play`: no branches under it, so that's the answer. RAT keeps `PLAY` as LUN
   5's last pick (the deadband) and answers `play 25`.
6. RATBOX sends the rat to the PLAY corner. When it gets there it plays for a while: fun up,
   energy down. Then it's back to state 0 and another decision.

When nothing is low, rule 1 passes, there's no R, and rule 3 takes the highest L - D. LUN 5 might
like `mate` 45 against `play` 40: `mate` wins. If two are within 5 (`tv` 35, `play` 38), the
deadband keeps whichever this rat chose last time; with neither, one at random. So one rat settles
into the TV and another into play: each LUN has its own deadband and its own habits.

**What RATBOX does with the answer.**

| Answer | RATBOX |
|---|---|
| `bed`, `food`, `play`, `tv` | walks it to that corner; sleeps, eats (a portion from the bowl, maybe a mess), plays, watches |
| `wander` | walks it somewhere at random, a short look round |
| `groom` | walks it to the friend it likes best (60 or more): both have fun, and like each other 2 more every second |
| `mate` | finds the partner it likes best (40 or more, the other sex, adult, healthy, not expecting). If another adult male likes her as much and dislikes the suitor (under 50), the two males go to the ring instead. Otherwise they meet and mate: she expects (3 days), they like each other 10 more |
| `fight` | it and the male it dislikes most go to the ring. The stronger (health plus luck) wins; the loser loses 25 health, the winner 5; they like each other 20 less. If it was over a female, the winner mates her |
| `nurse` | the mother goes to the pen and feeds her babies (each 15 food every second); she loses some food and energy |

**Training, from you and from boredom.** All of these go through RAT as `!RATBOX` messages, so
they change only that rat's LUN:

- `+` on the chosen rat: `!RATBOX #n P play 3` - that rat likes what it was doing 3 more.
- `-`: `!RATBOX #n X play 3` - 3 less.
- `N`, the naughty bed: `X ... 3` as well, and it sits out 10 seconds.
- Boredom: the same pick three times running, and RATBOX sends `#n X pick 2`, so habits form but
  don't take over.

**Breeding.** When a mother gives birth (3 days after mating), each baby takes a free place: a dead
rat's, or a new one up to the limit. For each baby RATBOX calls `!RATBOX #c B m f`. MODEL builds
LUN *c* line by line: each weight from the mother's LUN or the father's at random, then -2 to +2.
A baby of two TV lovers likes TV; a litter of a fighter and a homebody is mixed. Babies don't
decide: they live in the pen on their mother's milk until they are 3 days old, then leave it and
start asking RAT like the rest. They like everyone 50 to start, and their mother 90.

**Dying and reuse.** A rat at 0 health dies: a grave on the left, and its place - its LUN - is free.
The next baby born gets that LUN, and `B` overwrites the dead rat's weights with the new rat's
inheritance.

**Saving.** MODEL saves the LUN weights to `RATBOX.LUN` every 100 changes, on `S` and when it ends
(`Q`); LUN 0's weights go back into `RATBOX.MDL` as for any model. RATBOX's `Q` writes
`RATBOX.SAV` (the box and the likings: a line a rat) and sends `!RATBOX S`, so the box and the
rats' minds are saved together. A LUN that has never changed is still the file's: MODEL copies it
only when it is first changed, so starting MODEL costs nothing however many LUNs there are.

**Crowding.** Over 20 rats RATBOX makes things harder - the box dirties faster, food runs down
faster, illness comes easier, a rat's liking for another drops now and then, and `mate` is
offered only one time in three. The rats aren't told the box is crowded: their needs go low sooner
and they dislike each other more, and the same model makes different choices.

**The cost.** One decision is about 4 port calls (W, P, C, and a second W past 6 tags), each a turn
of the slots. RATBOX's 2 decisions a tick keep it moving with 100 rats, but each rat waits longer
for its turn as the box fills: a big swarm is slow to change its mind, never stuck.

**Your own swarm.** The same pieces work for any group: orcs in a dungeon, traders in a market,
cars in a town.

1. Write one model for the kind of creature.
2. Run it with MODEL. At the start, ask RAT `LUNS model` to know how many you can have.
3. Give each creature a LUN; `!model #n R` makes it fresh.
4. Ask `model:n tag tag:level ...` with only what that creature can do now.
5. Use `!model #n P/X tag k` to reward and punish, `!model #c B a b` to breed, and `!model S` to
   save.

## 8. Getting an AI to build a model

Give the AI `RATMODEL.TXT` and a description. It needs to know four things - say them plainly:

1. **The caller's tags**: every action the game or tool will offer, and which come with a level.
2. **What each level means** (0 = none left, 100 = full) and when the creature should panic.
3. **The role** - what you want it to do (a guard, a scout, a worker), in order of priority.
4. **The personality** - what it likes and dislikes, how brave or fearful, how strongly.

Then ask for the file and for worked examples, so you can check it with PROBE. A prompt that works:

> Read RATMODEL.TXT. Make a RAT model, GUARD.MDL, for a castle guard NPC in a dungeon game.
> The game offers these tags: when it sees the player `attack flee:<hp> shout`; when it hears
> something `investigate wait flee:<hp>`; when nothing `patrol sleep eat:<food>`. hp and food are
> 0-100. Its role: protect the gate - attack before anything else, then investigate, then patrol.
> It is brave (runs only when nearly dead) but greedy (eats when food is below 40). It likes
> shouting at intruders and dislikes waiting around. For attack, add branches for how it attacks
> (sword, shield bash, kick) with its favourite first.
> Write the file exactly in RATMODEL.TXT's format. Then give 5 example calls and the answer RAT's
> rules give for each, worked through step by step (necessity, requirement, taste, ties).

Then:

    RUN 2 MODEL GUARD
    RUN 3 RAT
    PROBE
    probe> guard attack flee:80 shout

and compare PROBE's plans with the AI's worked examples. If they differ, either the file breaks the
format (`SHOW guard` shows how MODEL read it) or the AI applied a rule wrongly - tell it which line
of the plan differs. Tune by editing weights (or `SET` / `LIKE` in PROBE, then `SAVE`).

What to watch for in an AI's model:

- **Levels without N lines** (or N lines the caller never passes a level for) - the necessity never
  fires.
- **R weights too far apart** - more than 5 apart, the higher always wins; within 5, taste picks.
- **Likes 5 apart that should be a fair choice** - habit makes the first winner pull ahead; keep them
  equal, or put the variety in R, or use a dislike for what should tire.
- **A D parent with no weight** - it defaults to 50, disliking the whole branch.
- **Names with spaces or dots**, or longer than 15 characters.

For NEURAL, ask for a `.NN` file instead: records of the same props, one a line, covering the cases
(the corners and the middle of each number's range), with `*n` for the common ones.

## 9. Hooking up an IO board

A model doesn't care where its numbers come from. With an IO board on the CPC (an ADC for sensors,
a parallel or relay board for outputs) a small program of your own - the **bridge** - sits in a
slot, reads the board, asks RAT, and drives the outputs. The model holds the behaviour; the bridge
only translates between the ports on the board and the ports in CyborgOS.

    sensors -> IO board -> bridge (Inp) -> RAT -> model
                                   bridge (Out) -> IO board -> relays, motors, LEDs

### The three ways in

1. **Levels in the call** - a reading becomes a necessity's level: `water:<moisture>`. Below its N
   weight, it takes over. RAT's levels mean "how much is left" (0 none, 100 full), so a reading
   where high is bad goes in turned over: too hot is `cool:<100 - temperature>`.
2. **What is possible** - the bridge offers only the tags that can happen now: no `water` when the
   tank switch says empty, no `lamp` in daylight. (As PET offers food only when the bowl has some.)
3. **Weights set from outside** - `V` changes the model itself: a light sensor making a pet
   sleepy at night (`V N\bed\<darkness>`: the darker, the sooner it is tired), a dial on the board
   setting how brave an NPC is (`V N\flee\<dial>`). The next decisions follow.

NEURAL takes readings the same way, as `prop=value` (numbers match by how near they are): `WATCH`
does it with CyborgOS's own numbers - free memory and programs running - instead of a board.

### An example: a greenhouse

The model, `GREEN.MDL`:

    ' GREEN: a greenhouse - water when the soil is dry, cool it when hot, light it when dark
    N
     water 30
     cool 20
     lamp 15
    L
     wait 50
     water 10
     cool 10
     lamp 10

Water below 30% moisture comes first; cooling when the coolness (100 - temperature) is below 20;
the lamp when the light is below 15; otherwise `wait` (the highest like) - do nothing.

The bridge, `GREEN.bas` (in `apps/rat` with `GREEN.MDL`, and on disc 6 as `GREEN.CYB`; built for
cpm with `cmds/CybSys.cls`). The port
numbers are the board's - put in your own; here an ADC that takes a channel number written to one
port and gives its reading (0-255) on another, and an output port with a bit a relay:

    ' GREEN: the greenhouse bridge - the board's sensors to RAT, its answer to the relays
    Option Explicit
    Const ADCSEL = &HF8E0                         ' your board: the ADC's channel select
    Const ADCDAT = &HF8E1                         ' its reading, 0-255
    Const RELAYS = &HF8E2                         ' the outputs: bit 0 pump, 1 fan, 2 lamp
    Dim a As String Max 128, t As Integer, ch As Integer, r As Integer, b As Integer
    r = CybSys.Claim("IO", 0)                     ' (the board: this program's alone)
    If r <> 0 Then Print "The IO board is in use by slot"; r : End
    Do
      a = "~GREEN water:" + Lv(0) + " cool:" + Lv2(1) + " lamp:" + Lv(2) + " wait"
      a = CybSys.PortCall("RAT", a)
      If CybSys.PortStatus() <> 0 Then Print "No RAT (RUN 2 MODEL GREEN, RUN 3 RAT)" : Exit Do
      b = 0
      If Left$(a, 5) = "water" Then b = 1
      If Left$(a, 4) = "cool" Then b = 2
      If Left$(a, 4) = "lamp" Then b = 4
      Out RELAYS, b
      Print a
      t = CybSys.Clock()
      Do While CybSys.Clock() - t < 1500          ' every 5 seconds; Q stops it
        ch = Inkey
        If ch = 81 Or ch = 113 Then Exit Do
      Loop
      If ch = 81 Or ch = 113 Then Exit Do
    Loop
    Out RELAYS, 0                                 ' (everything off at the end)
    r = CybSys.Release("IO", 0)
    End

    ' channel c's reading as a level 0-100
    Function Lv(ByVal c As Integer) As String
      Out ADCSEL, c
      Lv = Trim$(Str$(((Inp(ADCDAT) And 255) * 100) \ 255))
    End Function

    ' the same, turned over (high is bad: temperature)
    Function Lv2(ByVal c As Integer) As String
      Lv2 = Trim$(Str$(100 - Val(Lv(c))))
    End Function

Run it:

    RUN 2 MODEL GREEN
    RUN 3 RAT
    GREEN

and test the model first, without the board, in PROBE: `try green water:20 cool:60 lamp:80 wait`
gives `water`; `set green N\water\10` makes it hold off watering until the soil is drier.

### Things to know

- **The deadband stops relay chatter.** When two choices are within 5 of each other, RAT keeps the
  last one, so a reading hovering at a threshold doesn't switch a pump or fan on and off every
  call - the same reason a drone needs it.
- **Dry or learning.** The `~` in the call makes it dry: the model stays as written. Leave it out and
  habit changes the likes - right for a pet or an NPC, usually not for a machine.
- **Claim the board** (`CybSys.Claim`) so two programs never drive it at once; `CLAIMS` shows who
  has it, and ending, `KILL` or `RESET` gives it back.
- **One bridge, many decisions.** The bridge can ask several models (`GREEN` for the plants, `ALARM`
  for the doors) with the same readings, and several bridges can share one model.
- **Not mission critical.** Hardware limits (a float switch on the pump, a thermostat cut-out)
  belong in the hardware. The model decides what is sensible; it doesn't guarantee safety.
- **Timing.** Decide every second or few, not in a tight loop: a decision is a few port calls, and
  sensors and relays don't need more.

## 10. Limits

- A message or answer is 128 characters: a path 110 at most (about 15 levels of 7-letter names),
  16 tags a call, the plan cut at 127.
- 8 ports; a model 401 lines; NEURAL 200 records, 8 props each.
- The disc's read stream is one for every slot: NEURAL reads its file in one go (8K) so it holds it
  only briefly.
- A decision is a few port calls (2 or 3 a level of the tree), each a turn of the slots: fine for
  NPCs, pets and tools deciding now and then, not for hundreds of characters every frame. RATBOX
  makes 2 decisions a tick at most; the others carry on with what they're doing.

## 11. Messages (for programs)

| To | Message | Answer |
|---|---|---|
| RAT | `[?][~]model[:lun] tag tag:level ...` | `path value` [`|plan`], `?` none |
| RAT | `LUNS model` | `luns lines` |
| RAT | `!model message` | the model's answer |
| MODEL | `#n ` before any message | that message for LUN n |
| MODEL | `U` | `luns lines` |
| MODEL | `R` / `#n R` | the file read again / LUN n the file's weights again: `ok` |
| MODEL | `#c B a b` | LUN c bred from LUNs a and b: `ok` |
| MODEL | `W [@path] tag ...` | each tag's `n,r,l,d` (-1 not there) |
| MODEL | `C path` | the branches under it |
| MODEL | `P tag [n]` / `X tag [n]` | a like up / down n: `ok` |
| MODEL | `V [cat\]tag\...\x` | a weight set to x: `ok`, `?` no such branch |
| MODEL | `D n` | line n: `L 1 FOOD 40`, `end` past the last |
| MODEL | `S` / `Q` | save / save and end |
| NEURAL | `Q prop=value ... [prop?]` | `score prop=value ...`, `?` none |
| NEURAL | `T prop=value ...` / `S` / `E` | learn (`ok n`) / save / save and end |

From a program: `answer = CybSys.PortCall("RAT", "PET bed:80 play:70 tv food:60")`, then
`CybSys.PortStatus()` (0 answered, 2 no such port).
