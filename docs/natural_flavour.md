# The Natural flavour

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

**Status (2026-11-23): built** - `js/ntc_flavour_natural.js` (the `natural` entry in the
flavour factory). Near-English sentences are turned into VB5 text for NTC's one parser and
compiler, so they compile to the thread a hand-written program makes. The compiler is not
touched. `node test/cli.js Maze.nat Robot.cls --platform=test --vb` shows the VB text.

```
with the robot
enter the maze
while not home
  if clear right
    turn right
    forward
  else
    if clear ahead forward else turn left end
  end
end
say "Out in" steps "steps."
```

## 1. The two forms

**A natural file.** Its first line is `Option Flavour Natural` (or the file is named `.nat`).
The whole file is sentences, except:

- `#ntc` ... `#endntc`: plain NTC BASIC, passed through as it is (declarations, Subs, anything).
- `#asm` ... `#endasm`: assembler, passed through as it is.
- A line starting `#` otherwise (`#If`, `#Const`) and an `Option` line: passed through.

**A plain file with natural parts.** In an ordinary `.bas` or `.cls`, `#natural` ...
`#endnatural` is the natural part and the rest is passed through. A class stays a class; a part
can sit inside a Sub.

Each tag is on a line of its own.

## 2. Words

- Words are separated by a space, a line break, a colon or a comma. All four are the same, so a
  sentence can run over several lines and several sentences can share a line.
- Case is ignored. `'` starts a comment to the end of the line.
- Noise words are dropped: `the a an then please`. The list is `NTC_NATURAL_NOISE` at the top of
  `ntc_flavour_natural.js`: add to it.
- A noise word can still be a name. Where a name is being given and no other name follows
  (`set a to 0`, `count a from 1 to 5`), it is the name, and stays one for the rest of the file.

## 3. Values and names

A value is one of:

- a number: `12`, `-3`, `&HFF`
- a string: `"The door is closed."`
- a name: one the file declares (`Dim`, `Const`, a Sub's parameter inside that Sub), a `count`'s
  counter, or one a sentence made (below)
- a value word of the context's class (section 5): `balance`, `steps`
- a name given with `name` (section 5): its id
- `variable x`: any name, as it is
- `( ... )`: a VB expression, passed through as it is: `set x to ( y * 2 + 1 )`

A bare word that is none of these is the start of the next sentence. That is how a sentence's
end is found.

**Names are made for you.** A bare name that `set`, `ask`, `pick` or `into` writes to, and that
nobody has declared, is declared where it is first used: a String when it is set to `"text"`, a
Long when it is set to a number past an Integer, else an Integer. So a small program needs no
`#ntc` part at all. (`variable x` and a dotted name are never declared for you.)

## 4. Built-in sentences

| Sentence | Becomes |
|---|---|
| `say "Score" score` | `Print "Score"; " "; score` (a space between the things said) |
| `ask "Your guess" into g` | `Input "Your guess"; g` |
| `pick n from 1 to 6` | `n = Rnd(6) + 1` |
| `set x to 5` | `x = 5` |
| `add 5 to x` | `x = x + 5` |
| `subtract 1 from x` | `x = x - 1` |
| `multiply x by 2` | `x = x * 2` |
| `divide x by 10` | `x = x \ 10` |
| `remainder of x by 10 into r` | `r = x Mod 10` |
| `if <condition> ... else ... end` | `If ... Then` / `Else` / `End If` |
| `repeat 10 times ... end` | a `For` on a counter of its own |
| `count n from 1 to 8 ... end` | `For n = 1 To 8` / `Next n` |
| `count n from 8 down to 1 ... end` | `For n = 8 To 1 Step -1` |
| `while <condition> ... end` | `Do While ...` / `Loop` |
| `forever ... end` | `Do` / `Loop` |
| `leave` | `Exit For` / `Exit Do` for the innermost loop |
| `to square using size ... end` | `Sub Square(ByVal size As Integer)` ... `End Sub`: a word of your own |

The marker words (`to from by into of times using`) are required and checked.

Conditions:

- `a is above b`, `is below`, `is equal to`, `is not equal to`, `is at least`, `is at most`
- a value by itself: true when it is not 0 (`if prime ...`, `while not home ...`)
- a state word of the context's class: `closed` is `Door.Closed(3) <> 0`
- `not` in front; `and`, `or` between

**Words of your own.** `to square using size repeat 4 times forward size turn right end end`
makes `square`, used as `square 5`. The values after `using` are Integers; leave `using` out
for a word that takes none. It is made outside any `if` or loop, before it is used, and the
context in force where it is written is its context.

## 5. The context: a class is the vocabulary

- `with sprite 1` opens a context: class `Sprite`, id `1`. The id is any value (`with sprite n`).
- `with turtle` is a class with no ids.
- The context lasts until the next `with`, or the `end` of the block (`if`, loop, `to`) it was
  opened in: at that `end` the context from before the block comes back.
- `name red door is door 3`: from here on `red door` means class `Door`, id `3`
  (`with red door`, or as a value: `transfer 50 to savings`).

A noun is a class. Its Public Subs are the verbs, and its Functions are the values and the
state words. Where a Sub's or Function's first parameter is named `id`, the context's id is
passed there. Nothing is registered anywhere: write the Sub and the word exists.

**When the class is one of the project's files** the flavour reads it, and so:

- A word can be several words: `turn left` is `TurnLeft`, `enter maze` is `EnterMaze`,
  `pay interest 2` is `PayInterest id, 2`. The longest match wins.
- Each verb takes as many values as it has parameters; too few is an error on that line.
- `to from by into of at` between a verb's values read well and mean nothing:
  `transfer 50 to savings`.
- A Function is a value (`say balance`, `if balance is below 400`) and a state word
  (`if overdrawn`, `while not home`).
- A word the class has not got is an error in the sentence's own terms, with the words it has.
- The class says whether it has ids (any first parameter named `id`).

**When the class comes from elsewhere** (NTC's library): a word is one word, it takes the values
that follow it, the class has an id when a value follows its name in the `with`, and a word
nobody has written is the compiler's usual "not found" on that line.

A Sub of the project's own modules, and a word of your own, is called as it is whatever the
context. A dotted word is a call as written: `Door.Shut 5`. A built-in word wins over a class's
word that starts the same (`add interest` would be `add`: call it `pay interest`).

## 6. Messages

The flavour's own messages start `natural:` and carry the source line:

```
natural: add expects "to", got "score"
natural: bump expects 1 value, got "say"
natural: "jump" is not a tally word (tally has: bump, value)
natural: "value" is a value of the tally's, not something to do (say value)
natural: "closed" needs a with before it (with door 3 ... closed)
natural: this if has no end
```

One mistake gives one message: after it the pass moves on to the next word that starts a
sentence. The compiler's own messages are in VB terms, on the right line.

## 7. The examples (`src/bas/natural_demo/`, and in the IDE's examples)

| Files | What it is |
|---|---|
| `Primes.nat` | the primes up to 60 |
| `Fibonacci.nat` | twenty Fibonacci numbers |
| `Guess.nat` | guess the number: `pick`, `ask`, `forever`, `leave` |
| `Bank.nat`, `Account.cls` | two accounts over three months: names, verbs with values, value and state words |
| `Draw.nat`, `Turtle.cls` | a turtle draws on a sheet of characters: words of your own (`square`, `stairs`, `spiral`) |
| `Maze.nat`, `Robot.cls` | a robot leaves a maze by the right-hand wall: words of several words |
| `Main.nat`, `Door.cls` | every kind of sentence |

## 8. Not in it

- `each sprite ... end`: it needs a rule for how a class says how many ids it has.
- A word of your own that gives a value back, or takes a String.
- Arrays in a sentence (use `( list(i) )` as a value; write to one in an `#ntc` part).
- The vocabulary of NTC's library classes (their words work, but one word at a time and
  unchecked: the flavour reads the project's files only).
- Natural parts in a JS, PHP or Locomotive file.
- The command line with one `.nat` file alone knows it by its `Option Flavour Natural` line,
  not by its name.

## 9. Files

- `src/js/ntc_flavour_natural.js`: the flavour (plain ES5, as the others).
- `src/bas/natural_demo/`: the examples.
- `test/natural/`: `Blocks.bas` and `Tally.cls` (natural parts in plain files), `Errors.nat`,
  `Words.nat` (the messages).
- `test/regress.sh`: the examples and the parts on test, cpc, cpcmin, cpcfw and cpm in both
  modes, the translation, the messages.
