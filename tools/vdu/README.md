# VDU - remote displays over plain HTTP

Extra displays for any program that can make an HTTP GET: game stats, debug stats, billboards,
commentary, spectating. A CPC (CyborgOS's `RVDU`), a PC, a script or a browser writes display
commands to a *screen* on the server. Any number of viewers show it:

- a browser, drawn as an Amstrad CPC would draw it;
- a text page;
- a CPC's console;
- a Nintendo DS or 3DS rolling log.

The viewers can send taps and keys back to the screen's writer. These are extra displays a
program writes to beside its own screen, not a replacement for the machine's own screen (not
retargetable graphics, as on the Amiga). That would work over the same mechanism, but not fast.

No database. Each screen is a folder of text files (`data/<id>/`):

| File | What it holds |
|---|---|
| `log.txt` | the screen's commands, one a line, only ever appended to |
| `log.idx` | where each line starts (4 bytes a line), so line *n* is found at once |
| `join.txt` | the number of the screen's last `MODE` line: where a viewer joining live starts |
| `ev.txt`, `ev.idx` | the events: the viewers' taps and keys, a log of their own |
| `meta.txt` | the title, the write key's hash, listed or not, when it was made and changed |

A viewer keeps a **pointer**: the number of the next line it wants. It passes it with each
request and gets the lines past it, and the new pointer:

- **Pointer 0** replays the screen from its start.
- **Pointer -1** joins it live, from its last `MODE`.
- **Past the end** (the screen was wiped): the answer starts at 0 again. The viewer sees that
  the answer's start isn't what it asked for, and starts again.

## The files

| File | What it is |
|---|---|
| `vdu.php` | the requests (below); `vducore.php` does the work |
| `index.html` | the public screens, a new screen (with a demo on it), open private ones by id |
| `view.html?s=id,id,...[&k=key,...]` | the screens live, side by side. With a screen's key: a command line, Wipe. Keys this browser made screens with are remembered. Replay, at 25-1600 lines a second |
| `test.html` | the test harness: make or pick a screen, send it tests (text, modes, inks, windows, scrolling, graphics, touch zones, a counter in place, a 500-line flood); its events listed as they come |
| `text.php?s=id[&r=secs]` | the screen as text, laid out with its colours. No script, no canvas; it refreshes itself |
| `dumb.php?s=id[&r=secs][&n=lines]` | the rolling log, for the dumbest browser (a DS, a 3DS): each `PRINT` a line at the bottom, no positions, no colours. It refreshes itself |
| `vdu.js` | the browser side: `VduScreen` draws, `VduClient` keeps a screen up to date, `VduWall` polls several |

To run it: any PHP 7+ web server with this folder in it, and `data/` writable. For a quick try:
`php -S 0.0.0.0:8080` in this folder, then `http://this-pc:8080/index.html`.

## Requests (vdu.php)

Every answer is plain text: its first line is `ok ...` or `error why`.

| Request | Answer |
|---|---|
| `?a=new&t=title[&p=0]` | `ok id key`: a new screen. `p=0`: private, left out of the list (seen by those given its id) |
| `?a=put&s=id&k=key&c=lines` | `ok total events`: lines appended (several: `%0A` between them). `events`: the screen's events so far, so a writer knows there are new ones without asking |
| `?a=get&s=id&n=pointer[&m=lines][&b=bytes]` | `ok start next total`, then the lines from *start* to *next* - 1: 100 lines at most (`m`), 16000 bytes (`b`), one at least |
| `?a=ping&w=id:pointer,id:pointer` | `ok id id ...`: those screens with lines past their pointers. One poll for a whole wall of screens; then each one named is fetched, and asked again at once while there are more (drained) |
| `?a=list` | `ok n`, then `id lines updated title` for each public screen, the latest first |
| `?a=info&s=id` | `ok lines updated public title` |
| `?a=wipe&s=id&k=key` | `ok 0`: emptied, its events too. Viewers start again from 0 |
| `?a=event&s=id&e=text` | `ok events`: an event appended (a viewer's: `TOUCH name x y`, `KEY n`) |
| `?a=events&s=id&k=key&n=pointer[&m=lines]` | `ok start next total`, then the events from *pointer* on (the writer's) |

Writing needs the screen's key; viewing needs only its id, so spectators need nothing more. A
screen you don't share (private) is seen by you alone.

## Commands

One a line. The first word in any case; unknown commands are ignored, so a newer writer doesn't
break an older viewer. Text is on a CPC's grid: `MODE` 0 is 20 columns, 1 is 40, 2 is 80, all
25 rows, columns and rows counted from 1. Graphics use the CPC's 640 x 400, (0, 0) at the
bottom left.

| Command | What it does |
|---|---|
| `MODE n` | clears the screen, the windows, the zones; a viewer joining live starts at the last one |
| `CLS` | clears the current stream's window in its paper |
| `PRINT text` | the text at the cursor, then a new line. `PRINT text;`: no new line. Wraps at the window's right edge, scrolls at its foot |
| `LOCATE x y` | the cursor, in the current window |
| `PEN i`, `PAPER i` | the current stream's ink numbers (a pen past the mode's inks wraps, as on a CPC: MODE 1's `PEN 5` is `PEN 1`) |
| `INK i c` | ink *i* is CPC colour *c* (0-26): what is already drawn in it changes too |
| `BORDER c` | the border's colour |
| `STREAM n` | the stream (0-7) the text commands use: each has its own window, cursor, pen and paper |
| `WINDOW l r t b` | the current stream's window: columns *l*-*r*, rows *t*-*b* |
| `TITLE text` | the screen's title, shown by the viewers |
| `ORIGIN x y`, `MOVE x y`, `DRAW x y`, `PLOT x y` | graphics: the origin, the graphics cursor, a line to a point, a point |
| `GPEN i`, `CLG [i]` | the graphics ink; the whole screen cleared to ink *i* (0) |
| `BOX x y w h`, `FILL x y w h`, `CIRCLE x y r` | an outlined box, a filled box (*x*, *y* its bottom left), a circle |
| `ZONE name x y w h`, `ZONE OFF` | a touch zone: a tap in it sends `TOUCH name x y` to the writer. `ZONE OFF` drops them all. `MODE` does too |

The defaults are a CPC's: MODE 1, inks 1 24 20 6 26 0 2 8 10 12 14 16 18 22 1 16, border 1.

## The way back: events

A viewer's tap in a touch zone appends `TOUCH name x y` to the screen's events. A key pressed
while a screen has the focus appends `KEY n` (its character code). RVDU sends the CPC's keys the
same way. The writer reads them with `a=events` and its key, from its own pointer. Each `put`
answer carries the events' count, so a writer that only writes notices them without polling.

## How each viewer shows a screen

| Viewer | Text | Positions, windows | Colours, inks | Graphics | Touch zones |
|---|---|---|---|---|---|
| `view.html` (a canvas) | yes | yes | yes | yes | yes, and keys |
| `text.php` | yes | yes | yes | no | no |
| RVDU on a CPC | yes | yes | no | no | keys |
| `dumb.php`, `RVDU id ROLL` | yes, a line each | no: a rolling log | no | no | no |

One screen, the same commands: each viewer takes what it can show. A positioned update
(`LOCATE` then `PRINT`, a counter in place) is a new line at the bottom of a rolling log.
