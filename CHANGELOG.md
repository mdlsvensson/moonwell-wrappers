# Changelog

## 0.9.1 (2026-10-02)

- **Fixed:** `Input.onKeyDown` no longer skips the press that follows a lost key release. The game sends no release
  for a key let go while it takes no keyboard input (another program in front, the chat box or the menu open), and the
  next press was taken for a repeat. A down that comes more than two seconds of game time after the key's last down
  now counts as a new press, and `repeated` is `false` for it.
- The first key listener starts one game timer, which the module reads game time from.
- Not fixed, and now documented: `onKeyUp` does not run for a lost release, and a press within two seconds of game
  time after the last down is still skipped. In a single-player game that time stands still while the menu is open and
  runs slower while another program is in front.

### Release gate

Automated checks passed 2026-10-02 on Windows, with Moonwell 0.9.0 and YueScript 0.34.3: 34 suites (227 tests); Lua
5.3.6 syntax checks (75 files); integration (normal and minified builds, the one-module bundles, LuaLS 3.19.1 fixtures
with 28 expected negative diagnostics, the native-call check and the gate example); 10 mutations of the new code, each
caught by a test.

In game, 2026-10-02, Warcraft III 3.0.0.24268, one machine, the probe `yue -e gate.lua probe-release` in the gate map
(`../wrappers-gate/PROBE-RELEASE-RESULTS.md`), run twice by the maintainer: hold Q, do something, let go, tap Q.

- **Before the fix (v0.9.0):** the release was lost after Alt+Tab, after a click on another window, with the chat box
  open and with the menu open, and in all four the tap did not reach an `onKeyDown` listener. With Shift pressed
  while Q was held the release arrived, with `meta` 1.
- **With the fix:** the tap ran after Alt+Tab (8.25 s of game time since the last down), after the click on another
  window (3.19 s) and after the chat box (4.00 s). After the menu it did not run: 1.00 s of game time had passed in
  3.33 s, inside the two-second window.
- Game time ran slower than the machine's clock while the game was in the background: 14.05 s counted as 8.25 s, and
  8.73 s as 3.19 s.
- A held key's first repeat came 0.50 s after the press; pressing another key stopped its repeats.

The other gate runs were not re-run: the change is inside `wrappers.input`. Two machines are not part of this; game
time is the same on every machine.

## 0.9.0 (2026-10-02)

- New `Unit.autoDispose(interval?)`: one game timer that disposes the wrappers of units the game has removed (decay,
  or removal by code that bypassed the wrapper), every 0.25 seconds unless told otherwise. It returns a function that
  stops it, and nothing runs until a map calls it.
- New `Unit.sweep()`: the same check, once, at a moment the map chooses.
- A swept wrapper is like one `remove()` was called on: its methods raise `Unit is disposed` at the calling line, and
  it lets go of the handle. A corpse is still a unit, so its wrapper stays valid until the corpse is gone.
- **Changed:** `exists()` on Unit, Item and Destructable returns `false` for a disposed wrapper; before, it raised.
  Migration: none is needed, unless code relied on that error.

### Release gate

Automated checks passed 2026-10-02 on Windows, with Moonwell 0.8.1 and YueScript 0.34.3:

- 34 suites (225 tests), among them the sweep, the timer and `exists()` on the three widget classes;
- Lua 5.3.6 syntax checks (75 files);
- Moonwell normal and minified builds, the one-module bundles and bundled execution;
- LuaLS 3.19.1 fixtures (28 expected negative diagnostics, the new one a text passed as the interval);
- the native-call check of `src/wrappers` against Moonwell's declarations;
- the gate example builds with clean editor diagnostics;
- 20 mutations of the new code, each caught by a test;
- moonwell-systems' 21 suites and its integration against this code: it needs no change.

In-game gate, 2026-10-02, Warcraft III 3.0.0.24268, the new `dispose` run, normal build, one machine (the other runs
were not re-run: the release adds two functions and changes `exists()` for a disposed wrapper only):

- A sweep in the same instant as a raw `RemoveUnit` and an exploding death saw neither: both wrappers still read
  `disposed false exists true`.
- The timer's sweep, at the default 0.25 seconds, disposed the removed unit after 0.25 s.
- After one second the removed and the exploded unit read `disposed true exists false`; the living unit, the corpse and
  the dead hero read `disposed false exists true`, and the last two still did at the end of the run.
- A method on a swept wrapper raised `war3map.lua:5417: [wrappers] Unit.getX: Unit is disposed`, the gate's own line.
- After `stop()`, a unit removed by raw code read `disposed false exists false` a second later; a sweep by hand then
  disposed it.
- 100 sweeps over 200 more wrappers took 90 microseconds each, about 0.45 per wrapper.
- The removed unit's handle id was 1048696 and a unit created two seconds later got 1048703: the id was not used again
  within the run.
- No `[wrappers] ... failed` line printed.

Two machines are not part of this gate. The sweep's order differs between machines, and nothing observes it.

## 0.8.1 (2026-10-02)

- New `moonwell-library.json` at the library's root, naming `src` as its module folder. A map on Moonwell 0.6.0 or
  later leaves `dir = "src"` out of its `libraries` entry; an entry that still has it keeps working. With Moonwell 0.5,
  keep `dir = "src"`.
- The repository's tools are Lua run with `yue -e` (`tools/test.lua`, `tools/check.lua`, `tools/integration.lua`), and
  integration runs the `moonwell` program of Moonwell 0.8.0. Deno is no longer needed.
- The tools need YueScript 0.34.3, the compiler Moonwell 0.8.1 pins, in place of 0.34.2.

No library code changed: `src/` is that of 0.8.0.

### Release gate

Automated checks passed 2026-10-02 on Windows, with Moonwell 0.8.1 and YueScript 0.34.3: 34 suites (218 tests); Lua
5.3.6 syntax checks (75 files, now with `tools/`); integration, whose consumer map names the library by `path` alone,
so the file is what places its modules: normal and minified builds, the one-module bundles, LuaLS 3.19.1 fixtures (27
expected negative diagnostics), the native-call check and the gate example.

The in-game gate was not re-run: no file under `src/` changed.

## 0.8.0 (2026-10-01)

- New `wrappers.input`: `onKeyDown`, `onKeyUp`, `onMouseDown`, `onMouseUp` and `onMouseMove` listeners for one player,
  removable with `Input.off`. Key listeners run whatever modifier keys are held and get them as `meta`; `onKeyDown` runs
  once per press unless the option `repeats` is true.
- New `wrappers.weathereffect`: `create(Rect, effectId)`, `enable(flag)`, `enableFor(Player)` and `destroy()`. An
  unknown id raises.
- New `Effect.abilityArt(abilityId, effecttype, index?)`: the model path or lightning code an ability's data names, or
  nil.
- New Trigger registrations: `registerPlayerStateEvent`, `registerPlayerAllianceChange`, `registerGameStateEvent` and
  `registerTimerExpireEvent`.
- New `fromEvent()` on Unit, Player, Item, Destructable, Timer and Region: the wrapper of the object the running event
  is about, or nil.
- **Changed:** `Effect.create`, `Effect.attach`, `Effect.flash` and `Effect.flashOn` raise `expected a model path` for a
  model that is not a string; before, the value went to the game. Migration: pass a string, and check the result of
  `Effect.abilityArt` for nil first.

### Release gate

Automated checks passed 2026-10-01 on Windows:

- 34 suites (218 tests) with YueScript 0.34.2, including the new `input` (7 tests) and `weathereffect` (5 tests) suites
  and the sweep of every input function;
- Lua 5.3.6 syntax checks (71 files);
- Moonwell normal and minified builds, the one-module bundles (now also Input-only and WeatherEffect-only) and bundled
  execution;
- LuaLS 3.19.1 fixtures (27 expected negative diagnostics, among them a missing ability art passed to `Effect.flash` and
  an unchecked `Unit.fromEvent()`);
- the native-call check of `src/wrappers` against Moonwell's declarations;
- the gate example builds with clean editor diagnostics;
- 66 mutations of the new code, each caught by a test.

Two probes came before the design, on 2026-10-01, Warcraft III 3.0.0.24268 (`../wrappers-gate/PROBE-EXTRAS-RESULTS.md`).
They measured what the README now records: a held key repeats; the game matches modifier keys exactly; typing in chat
fires no key event; mouse move fires 150 to 190 times a second; an unknown weather id gives a handle with id -1; art
read from ability data draws the same effect as `AddSpellEffectById`; and when each of the four trigger events fires.

In-game gate, 2026-10-01, Warcraft III 3.0.0.24268, the new `additions` run, normal build, one machine (the other runs
were not re-run: the release's one change to existing code is a type check in front of four natives):

- **Art:** Thunder Clap's caster art, Flame Strike's third special entry and Chain Lightning's lightning code (`CLPB`)
  read as expected; Thunder Clap's missing missile art read nil, and `Effect.create` refused it with
  `expected a model path`. A Thunder Clap made from the art's path played at the centre.
- **Trigger events:** the player state event fired for gold 1000 and 1001 with `Player.fromEvent()` the owner; the
  alliance event fired for two real changes and not for the same value; the time-of-day event fired at 12.00; the timer
  expiry trigger ran before the timer's callback, with `Timer.fromEvent()` the timer.
- **`fromEvent()`:** the dying footman, the picked-up item with its hero, the dying tree, and the entered region with
  the entering hero were each the expected wrapper.
- **Weather:** all 21 ids of the README's table were created, and an unknown id was refused. Rain fell only after
  `enable(true)`, stopped after `enableFor` another player, fell again after `enableFor` the maintainer's player, and
  stopped after `destroy()`; its rect had been destroyed right after creation.
- **Input:** a tap of Q gave one down and one up; Q held for two seconds gave one down for the default listener and 60
  for the `repeats` listener, 59 of them repeated; Shift with Q arrived with `meta` 1; a left click gave one down with
  its world point and one up; two seconds of mouse movement gave 1041 move events; after `Input.off` on every listener,
  a key press and a click counted nothing.
- No `[wrappers] ... failed` line printed.

Two machines are not part of this gate: the online checks before Moonwell 1.0 cover `wrappers.input` and
`weather:enableFor`.

## 0.7.0 (2026-09-30)

- New `unit:getCollisionSize()` and `unit:setPathing(flag)`.
- New `wrappers.damage`: listeners before armor (`onDamaging`) and after armor (`onDamaged`), removable with
  `Damage.off`. One event per hit, shared by its listeners, with the source, target, amount, attack flag and types.
  DAMAGING events can change the amount and the three types; DAMAGED events only the amount. Setters raise once the
  hit's listeners have run.
- New `wrappers.sync`: `Sync.send` raises for data over 255 bytes (the game cuts it silently) and for an empty prefix;
  `Sync.on` and `Sync.off` manage listeners per prefix.
- Nothing existing changes; there are no migrations.

### Release gate

Automated checks passed 2026-09-30 on Windows:

- 32 suites with YueScript 0.34.2, including the new `damage` (11 tests) and `sync` (5 tests) suites and the sweep of
  every damage and sync function;
- Lua 5.3.6 syntax checks (67 files);
- Moonwell normal and minified builds, the one-module bundles (now also Damage-only and Sync-only) and bundled
  execution;
- LuaLS 3.19.1 fixtures (20 expected negative diagnostics, among them a type setter on a DAMAGED event);
- the native-call check of `src/wrappers` against Moonwell's declarations;
- the gate example builds with clean editor diagnostics.

In-game gate, 2026-09-30, Warcraft III 3.0.0.24268, the new `port` run, normal build (the other runs were not re-run:
this release changes no existing code path):

- Footman collision size: 31.0.
- Damage from `damageTarget` with 100 and a normal attack type: 89.29 after armor, equal to the life lost. A DAMAGING
  listener doubled it to 200 (178.57 after armor and lost). Changing the attack type to magic before armor also gave
  178.57; changing it with the raw native after armor changed nothing (89.29 lost).
- `isAttack` read false for `damageTarget` with its `attack` argument true: that is the native's value (README).
- A nested 10-damage hit inside a DAMAGING listener got its own event (8.93 after armor), and `setAmount 0` on the outer
  event afterwards still worked: the outer hit read 0.0 and only 8.93 life was lost.
- A setter on a stored event raised `DamagingEvent.setAmount: the damage event is over`; after `Damage.off`, a hit
  printed no listener line.
- `setPathing(false)`: a footman ordered across a tree line walked around it, so pathing off does not make orders cross
  trees (README; the method comment said otherwise before the gate and was corrected).
- Sync on one machine: a 255-byte message arrived intact; `send` rejected 256 bytes; prefixes of 16, 17 and 32
  characters all arrived whole, so no prefix length limit was added.
- No `[wrappers] ... failed` line printed.

## 0.6.0 (2026-09-30)

- Errors point at the line that called the wrapper. Before, a wrong or disposed argument and a wrong receiver pointed at
  a line inside the library, and `getHandle`, `isDisposed` and factories lost the position entirely (a tail call).
  Messages are unchanged. A new sweep test checks every class.
- Methods are cheaper: the check that a receiver is a live wrapper is one lookup instead of two calls.
- Group enumeration (`getUnits`, `forEach` and filtered enumerations) builds one table instead of two, with the same
  snapshot semantics.
- `unit:isAlive()` uses the `UnitAlive` native. The library now needs Moonwell 0.5.1 or later.
- New `exists()` on Unit, Item and Destructable: false once the game has removed the object (its type id reads 0). A
  unit reads false from the frame after its removal; in the same instant it still reads true (measured in game).
- When several options are wrong, the first in sorted order is reported, the same on every machine.
- README: an API reference section per module, the callback rule in one place, and a conventions table (colours, angles,
  visibility, time units).

### Release gate

Automated checks passed 2026-09-30 on Windows:

- 30 suites with YueScript 0.34.2, including the new `blame` sweep, which found 380 misplaced errors before the fix;
- Lua 5.3.6 syntax checks (62 files);
- Moonwell normal and minified builds, the one-module bundles and bundled execution;
- LuaLS 3.19.1 fixtures (17 expected negative diagnostics);
- the native-call check of `src/wrappers` against Moonwell's declarations, now including `UnitAlive`;
- the gate example builds with clean editor diagnostics.

In-game gate, 2026-09-30, Warcraft III 3.0.0.24268, normal builds (the minified runs and the frames run were not re-run,
by the maintainer's decision):

- `core` passed: the chat condition that removes itself; `collected=true stale=true identity=true`.
- `probes` passed. The timer, trigger and condition errors printed and play went on. The new wrong-argument error
  printed `war3map.lua:<line>` at the gate's own `pcall` line in the bundle, not a wrappers line. `exists()`: a unit,
  item and destructable removed with the raw natives read `true false false`, and the unit read `false` a frame later
  and after 1 s. A killed unit read `isAlive false`, `exists true`.
- `presentation` and `ui` passed. Every options table (text tags, sounds, splats, dialog buttons, multiboard cells)
  validated.
- Performance (`deno task gate perf`, against v0.5.1 the same day):

  | Case                                  | v0.5.1           | v0.6.0           |
  | ------------------------------------- | ---------------- | ---------------- |
  | Wrapped `getX`, `setX`, `setPosition` | 440, 580, 590 ns | 390, 530, 550 ns |
  | The fixed wrapper cost per method     | ~120 ns          | ~70 ns           |
  | Wrapped enumeration of 20 units       | 29.2 µs          | 27.0 µs          |
  | `Options.read`, three fields          | 950 ns           | 1,090 ns         |
  | The 100-missile tick                  | 1.690 ms         | 1.680 ms         |

  `Options.read` got slower (sorted checks). It runs only on creation paths. The missile tick is unchanged within noise:
  natives dominate it.

## 0.5.1 (2026-09-30)

- `Effect.attach` and `Effect.flashOn` take a Unit in the editor, so LuaLS flags an Item or a Destructable: Warcraft
  drew no effect attached to them in the v0.3.0 gate. The runtime still accepts any widget, for custom models.
- `unit:isAlive()`'s comment: Moonwell 0.5.1 knows `UnitAlive`; the method still avoids it, so the library keeps working
  with Moonwell 0.5.0.

### Release gate

Automated checks passed 2026-09-30 on Windows: 167 behavior tests in 29 suites with YueScript 0.34.2; Lua 5.3.6 syntax
checks (60 files); Moonwell normal/minified builds, unused-module exclusion, Trigger-, TextTag-, Multiboard-, Dialog-
and Frame-only bundles and bundled execution; LuaLS 3.19.1 positive fixtures (an effect now attaches to a unit) and 17
expected negative diagnostics, including an Item passed to `Effect.attach` and a Destructable passed to
`Effect.flashOn`; a direct LuaLS check of `src/wrappers` with the native declarations, no problems; the gate example
builds with clean editor diagnostics. The in-game gate was not re-run: only annotations and comments changed.

## 0.5.0 (2026-09-29)

- New `wrappers.frame`: the `BlzFrame` API with an owned frame tree. Frames made by `Frame.create`, `createSimple` and
  `createByType` are owned; `destroy()` disposes the wrappers of their whole subtree. Template parts (`findChild`,
  `getChild`) belong to their frame; game frames (`Frame.origin`, `byName`, `fromHandle`) are borrowed and never
  destroyed through a wrapper. Create contexts are allocated automatically.
- Frame events go to callbacks: `frame:on(eventType, callback)` with removable tokens; callbacks receive the Player and
  the event's synced text and value. `releaseFocusFor(player)` gives keyboard focus back after a click.
- `Frame.loadTOC` raises when a TOC file cannot be loaded; README shows how to import templates.
- `setVisibleFor(Player)` on frames. No getters for machine-local frame state.
- `Callback.call` (internal) takes any number of callback arguments.
- README, measured by an in-game probe on 3.0.0.24268: the game's own templates (nine tried) create without a TOC file;
  an unknown template gives nil; origin frames exist in `on_main`; destroying a frame removes its children, including a
  re-parented one; a clicked button keeps the keyboard focus until `releaseFocusFor`.

### Release gate

Automated checks passed 2026-09-29 on Windows: 167 behavior tests in 29 suites with YueScript 0.34.2; Lua 5.3.6 syntax
checks (60 files); Moonwell 0.5.0 normal/minified builds, unused-module exclusion, Trigger-, TextTag-, Multiboard-,
Dialog- and Frame-only bundles (Dialog and Frame bundle only Player besides themselves) and bundled execution; LuaLS
3.19.1 positive fixtures and 15 expected negative diagnostics, including a frame callback's parameter typed as Player; a
direct LuaLS check of `src/wrappers` with the native declarations, no problems; the gate example builds with clean
editor diagnostics.

In game (maintainer, Warcraft III Reforged 3.0.0.24268): the `frame-init` probe answered the community notes the
wrappers rely on (see README), then the frames gate (CONTRIBUTING step 9) passed normal and minified. The earlier gate
steps were not re-run (their code is unchanged). Multiplayer checks, including frame creation order and events from a
second player, are deferred until before Moonwell 1.0.

## 0.4.0 (2026-09-29)

- New classic UI wrappers: Dialog, Multiboard, Leaderboard, Quest, DefeatCondition and TimerDialog, all owned by the map
  and destroyed explicitly.
- Dialog buttons take a callback that receives the clicking Player; the dialog owns one internal trigger. Buttons and
  quest items belong to their dialog or quest, which dispose them on `clear()`/`destroy()`.
- Multiboard rows and columns count from 1; cell methods (`setCell`, `setRow`, `setColumn`, `setAll`) obtain and release
  the native cell handles themselves. `setRowCount` changes the count one row at a time.
- Leaderboard items are keyed by player and resize the board.
- `setVisibleFor(Player)` on Multiboard and TimerDialog. No getters for display or minimized state.
- A TimerDialog raises once its Timer is destroyed, except for `destroy()`.
- README, measured by an in-game probe on 3.0.0.24268: dialogs and multiboards shown directly in `on_main` do not
  appear, while creating quests, leaderboards and multiboards there works; a direct row-count change from 0 to 5 works
  (stepping is kept as a safeguard); new multiboard cells show an eye icon and no text until styled.

### Release gate

Automated checks passed 2026-09-29 on Windows: 147 behavior tests in 26 suites with YueScript 0.34.2; Lua 5.3.6 syntax
checks (56 files); Moonwell 0.5.0 normal/minified builds, unused-module exclusion, Trigger-, TextTag-, Multiboard- and
Dialog-only bundles (the Dialog map bundles only Dialog and Player) and bundled execution; LuaLS 3.19.1 positive
fixtures and 13 expected negative diagnostics, including a Dialog button callback's parameter typed as Player; a direct
LuaLS check of `src/wrappers` with the native declarations, no problems; the gate example builds with clean editor
diagnostics.

In game (maintainer, Warcraft III Reforged 3.0.0.24268, World Editor 3.00): the `ui-init` probe answered w3ts's classic
UI notes (see README), then the classic UI gate (CONTRIBUTING step 8) passed normal and minified, and the packed map
opened in World Editor. The earlier gate steps were not re-run (their code is unchanged). Multiplayer checks, including
local visibility and dialog clicks by a second player, are deferred until before Moonwell 1.0.

## 0.3.1 (2026-09-29)

- **Changed:** `Image.create` raises `[wrappers] Image.create: invalid image path: <path>` when the game cannot load the
  path. Warcraft returns an invalid image (handle id -1) rather than nil; the wrapper destroys it first. Found by an
  in-game probe, which also showed that destroying such an image does not crash.
- README: behaviour measured by that probe on 3.0.0.24268: `sound:play()` on a sound that still plays cuts it off and
  nothing plays; `splat:finish()` fades the splat and `reset()` does not bring it back; `lightning:setColor` shows no
  visible alpha either; Healing Wave and Spirit Link fade by themselves; lightning heights are absolute.
- README: a new "Reported native caveats" section, from comparing w3ts and WCSharp (not tested by our gates):
  locale-dependent `getName()`, `GetHandleId` desyncs, Locust in `enumOfPlayer`, `getRemaining` after a pause, unit
  position and facing notes, `Avul`, negative XP, orders inside attack events, `restore` life values, image layering.
- Tests: setter checks now also run each row with its boolean arguments flipped, so a wrapper that ignores a flag fails.

### Release gate

Automated checks passed 2026-09-29 on Windows: 108 behavior tests in 20 suites with YueScript 0.34.2; Lua 5.3.6 syntax
checks (44 files); Moonwell 0.5.0 normal/minified builds, unused-module exclusion, Trigger-only and TextTag-only bundles
and bundled execution; LuaLS 3.19.1 positive fixtures and the expected negative diagnostics; a direct LuaLS check of
`src/wrappers` with the native declarations, no problems; the gate example builds with clean editor diagnostics. A
planted hard-coded `setInvulnerable` flag failed the new setter check.

The in-game gate was **not re-run**, by the maintainer's decision: the only runtime change is the wrong-path check, and
the probe run (2026-09-29, Warcraft III 3.0.0.24268; Moonwell's
`docs/superpowers/research/2026-09-29-wcsharp-comparison.md` §9) measured what it relies on: a wrong path gives a
non-nil image with handle id -1, and `DestroyImage` on it does not crash.

## 0.3.0 (2026-09-29)

- New wrappers: TextTag, Sound, Lightning, Image, Ubersplat and FogModifier. They exist only for objects the map owns
  and destroys: `TextTag.create` makes a permanent tag, and a Sound wrapper is never released when done.
- Fire-and-forget helpers that return nothing: `TextTag.float`, `Sound.playOnce`, `Effect.flash`, `Effect.flashOn`.
- Local visibility: `setVisibleFor(Player)` on TextTag, Image and Ubersplat; `sound:playFor(Player)`; a `player` option
  on `TextTag.float` and `Sound.playOnce`.
- Effect: `setColor`, `setAlpha`, `setPlayerColor`, `setTimeScale`, `setOrientation`, `setHeight`, `setZ`,
  `playAnimation`.
- `Item.enumInRect(Rect, filter?)` and `Destructable.enumInRect(Rect, filter?)` return snapshots.
- **Changed:** `Effect.attach` accepts any widget (Unit, Item, Destructable). A wrong argument now reports
  `[wrappers] Effect.attach: expected Widget wrapper` (formerly `expected Unit wrapper`). Items and destructables are
  accepted, but in the gate Warcraft drew no effect attached to them (see README, Widgets).

### Release gate

Automated checks passed 2026-09-29 on Windows: 107 behavior tests in 20 suites with YueScript 0.34.2; Lua 5.3.6 syntax
checks (44 files); Moonwell 0.5.0 normal/minified builds, unused-module exclusion, Trigger-only and TextTag-only bundles
and bundled execution; LuaLS 3.19.1 positive Lua/Yue fixtures and eleven expected negative diagnostics; a direct LuaLS
check of `src/wrappers` with no problems; the gate example builds with clean editor diagnostics.

The in-game gate **passed 2026-09-29**, confirmed by the maintainer's message-log screenshots and observations on
Warcraft III Reforged 3.0.0.24268 and World Editor 3.00, library code `f685abe`:

- **Core, probes and weak cache (normal and minified):** as in v0.2.0, `collected=true stale=true identity=true`.
- **Presentation (normal and minified):** text tags (owned and floating, hidden for another player), sounds (first-play
  knight voice, 3D sound, 3D `playOnce`, silence for another player; duration 1903 before and after play), image centred
  under the footman within its placement, splat, fog reveals, effect colour/alpha/player colour/orientation, flashes, a
  lasting Drain Life bolt that moved, potions 2 and trees 2 from `enumInRect`.
- **Found in game and documented:** Chain Lightning fades by itself; `lightning:setColor` showed no visible change;
  effects attached to items and destructables are not drawn. The gate example was fixed for these and for trees snapping
  to a 64-unit grid.
- **World Editor:** opened the packed minified map.
- **Deferred:** the two-player run and the multiplayer checks of local visibility (Moonwell's pre-1.0 online checks).

## 0.2.0 (2026-09-29)

- New wrappers: Item, Destructable, Rect, Region and Force.
- Unit: hero, ability, inventory, mana, movement, presentation and by-id order methods, `isAlive()` and `damageTarget`.
  `issueTargetOrder` accepts any widget (Unit, Item, Destructable).
- Player: gold and lumber, alliances, tech, slot state, start location and `isLocal()`.
- Trigger: any-player unit, player, chat, region, death, range, unit-state and game events; predicate conditions;
  `addAction` returns a token; `removeAction`, `removeCondition`, `clearActions`, `clearConditions`, `evaluate`,
  `execute`.
- Group: `enumInRect`, `enumOfPlayer`, `enumSelected`, an optional Lua filter on every enumeration, `forEach`, `first`.
- **Changed:** Unit, Item and Destructable wrappers use a weak cache. A wrapper nothing references may be collected, and
  a later `fromHandle` returns a fresh one; identity is unchanged while any reference exists. Do not key weak tables
  (`__mode = 'k'`) by these wrappers for game data: each client drops entries at its own collection time, which can
  desync.
- **Changed:** wrong or disposed wrapper arguments now report the method that was called, for example
  `[wrappers] Effect.attach: expected Unit wrapper` (formerly `[wrappers] Unit.getHandle: expected Unit wrapper`; the
  same for Group, Trigger and Player arguments to Unit). `issueTargetOrder` now reports `expected Widget wrapper`.
- Trigger and Effect no longer import Unit or Player: wrapper arguments convert through the loaded classes.

### Release gate

Automated checks passed 2026-09-29 on Windows: 69 behavior tests in 13 suites with YueScript 0.34.2; Lua 5.3.6 syntax
checks (30 files); Moonwell normal/minified builds, unused-module exclusion, a Trigger-only bundle and bundled
execution; LuaLS 3.19.1 positive Lua/Yue fixtures and eight expected negative diagnostics; the gate example builds with
clean editor diagnostics.

The in-game gate **passed 2026-09-29**, confirmed by the maintainer's message-log screenshots on Warcraft III Reforged
3.0.0.24268 and World Editor 3.00 (file version 3.0.0.24268), library commit `7f4261f`:

- **Normal and minified runs:** startup messages (hero level 4, ability level 2 with a 30-second cooldown, item charges
  3, filtered heroes 1), region entry, item pickup, unit and tree death events, both cleanups, the tree restore, and
  `Wrapper broad cleanup passed` at 30 seconds.
- **Weak cache probe:** `collected=true stale=true identity=true` and `Wrapper weak cache probe passed` (normal run).
- **Probe run:** all three intentional errors printed (timer, trigger, condition), then recovery.
- **World Editor:** opened the packed minified map.
- **Chat:** the first `-gate` printed `Wrapper chat once` and `Wrapper chat accepted`, so the self-removing action and
  condition both ran in game. That was the first run, on `faa54f3`, which has the same library code. The second `-gate`
  was not observed.
- **Gate fix during the run:** it printed its startup messages while the map loaded, where they never reach the log;
  `7f4261f` starts it just after loading.

Deferred, not passed: the two-player no-desync run. Reforged's latest patch removed LAN, and online multiplayer and
desync checks wait until the last step before Moonwell 1.0 (Moonwell's backlog).

GitHub-tag consumption **passed 2026-09-29** with Moonwell 0.5.0: a fresh map configured with the README GitHub settings
ran check, build and `build --minify` with the gate example; `moonwell.lock` recorded tag `v0.2.0` at commit
`4b2c845b6775541896a5652c17e40ff5544affca`, and the fetched files matched the tag's `src/`. After removing only that
map's `.moonwell/`, check downloaded the tag again and left the lock unchanged. (The tagged commit's copy of this
section does not include this check; the tag was not moved.)

## 0.1.0 (2026-09-28)

- Annotated Lua wrappers for Player, Unit, Timer, Trigger, Group and Effect, consumed through Moonwell 0.5.0 libraries.
- Stable handle identity, explicit idempotent cleanup and disposed-object checks.
- Protected timer/trigger callbacks, stale-schedule suppression and dense group snapshots.
- Lua and Yue examples, native-boundary behavior tests, Lua 5.3 syntax checks and Moonwell/LuaLS integration tests.

### Release gate

The in-game gate **passed 2026-09-28**, confirmed by the maintainer on Warcraft III Reforged 3.0.0.24268 and World
Editor 3.00 (file version 3.0.0.24268): normal gameplay and cleanup, intentional timer/trigger errors followed by
continued ticks and cleanup, minified packed-map gameplay, and opening the packed map in World Editor. The probe
screenshot shows both intentional errors, later ticks, the death event and successful cleanup retained in F12.

First GitHub-tag consumption **passed 2026-09-28** with Moonwell 0.5.0: a fresh map configured with the README GitHub
settings ran check, build and `build --minify`; `moonwell.lock` recorded tag `v0.1.0` at commit
`c1209f5fb3141d91df2234e765e66c43bb01fc02`, and the fetched files matched the tag's `src/`. After removing only that
map's `.moonwell/`, check downloaded the tag again and left the lock unchanged. (The tagged commit's copy of this
section still said this check was pending; the tag was not moved.)

Automated checks passed 2026-09-28 on Windows: 23 behavior tests with YueScript 0.34.2; Lua 5.3.6 syntax checks;
Moonwell 0.5.0 normal/minified builds and bundled execution; LuaLS 3.19.1 positive Lua/Yue fixtures and four expected
negative diagnostics. The all-six-wrapper gate example builds and has clean editor diagnostics. Integration passed with
explicit absolute/relative compiler paths and with Yue available only on PATH.
