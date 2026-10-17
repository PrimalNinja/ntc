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
  NPCs, pets and tools deciding now and then, not for hundreds of characters every frame.

## 11. Messages (for programs)

| To | Message | Answer |
|---|---|---|
| RAT | `[?][~]model tag tag:level ...` | `path value` [`|plan`], `?` none |
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
