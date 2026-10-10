# Contributing

Use handwritten annotated Lua 5.3, test-first changes and explicit native boundaries. Keep runtime modules under
`src/wrappers/`; tests/tools/examples must stay outside `src/`. No Node.js or npm dependencies. Expected gameplay misuse
raises contextual Lua errors. Review each task and the final change. Work on main; push once the checks pass.

A new function checks an argument in two cases: before the library computes with it (arithmetic, concatenation, a
comparison, a loop bound), and where a call of an older release would still resolve and mean something else. Every
other plain value goes to the native as it is.

## Tools

- The `moonwell` program, 0.12.0 or later, on the PATH (or set `MOONWELL` to the executable: a path, not a command
  line). The tools themselves are Lua, run with `yue -e`: there is no Deno.
- YueScript 0.34.3, installed by Moonwell setup (or set `MOONWELL_YUE` to its executable).
- Pkl 0.32.1, on PATH (or set `MOONWELL_PKL` to its executable).
- A sibling Moonwell checkout (or `MOONWELL_REPO` pointing to that checkout): integration links its consumer map to
  the checkout's Pkl schema, so the program and the checkout must have the same major and minor version. The library
  itself needs Moonwell 0.5.1 or later, which knows the `UnitAlive` native.
- LuaLS 3.19.1 (or `MOONWELL_LUALS` pointing to the Lua extension's `server/bin/lua-language-server.exe`).
- Lua 5.3.6 `luac` (or `MOONWELL_LUAC` pointing to it).

No tool is installed globally by the tests. Environment overrides are paths to executables, except MOONWELL_REPO.
Integration creates a fresh ignored `.test-work/integration-*/consumer`; reports and a latest-run pointer are retained
there. It uses the real `moonwell` program, Pkl schema, generated editor files and bundler. All tests run from this
repository root.

On Windows, a small portable Lua syntax checker can be built from the official source using Tiny C Compiler. The
archives and compiled tools belong in ignored `.tools/`. Download sources:

- [Lua 5.3.6 source](https://www.lua.org/ftp/lua-5.3.6.tar.gz), SHA-256
  `fc5fd69bb8736323f026672b1b7235da613d7177e72558893a0bdcd320466d60`.
- [TinyCC 0.9.27 Win64](https://download-mirror.savannah.gnu.org/releases/tinycc/tcc-0.9.27-win64-bin.zip), SHA-256
  observed for the verified local setup: `34a721949a2583fdff725312da092fa0f5f1f284b702e6f811c6954714faabb2`.

After downloading those files into `.tools/`, verify hashes with Get-FileHash and extract with Windows tar:

```powershell
tar -xf .tools/tcc-0.9.27-win64-bin.zip -C .tools
tar -xf .tools/lua-5.3.6.tar.gz -C .tools
New-Item -ItemType Directory -Force .tools/lua53
$luaSources = Get-ChildItem .tools/lua-5.3.6/src -Filter '*.c' |
  Where-Object Name -ne lua.c | Select-Object -ExpandProperty FullName
& ./.tools/tcc/tcc.exe -o .tools/lua53/luac53.exe @luaSources
$env:MOONWELL_LUAC = (Resolve-Path .tools/lua53/luac53.exe).Path
```

On other platforms, build the same Lua release with the platform's C compiler and point MOONWELL_LUAC at its luac. The
check requires version 5.3.6 and proves that the parser rejects Lua 5.4-only syntax. Yue's embedded VM is Lua 5.4, so
its passing runtime tests alone do not establish game syntax compatibility.

## Automated checks

```text
yue -e tools/test.lua          # the behavior suites, one process each; name suites to run only those
yue -e tools/check.lua         # Lua 5.3.6 syntax of src/, tests/ and tools/
yue -e tools/integration.lua   # a real consumer map, LuaLS and the bundler
```

Tests use real wrappers and stand-ins for unavailable Warcraft natives, checking arguments, return values and callback
lifecycle. Integration checks both Lua and compiled Yue with LuaLS, requires intentional negative diagnostics at exact
locations, builds normal/minified maps, excludes unused modules and executes a real bundle with native stand-ins. It
also checks `src/wrappers` on its own against Moonwell's native declarations (native names, argument counts and types):
every library file must be clean, and `tests/natives-negative.lua` must report exactly its planted mistakes. This
replaces the manual direct LuaLS run of earlier releases. The consumer's positive run diagnoses the library's copies in
`.moonwell/lua/` too (planted checks, 2026-09-30); the separate check proves detection and does not depend on that view.

The line-local LuaLS suppressions on native calls that pass a null boolexpr filter document a mismatch in Moonwell's
generated JASS signatures; each carries the same comment. Do not suppress diagnostics broadly. fromHandle is
conservatively nullable in LuaLS 3.19.1; narrow it or assert it. Factories validate and return a non-null wrapper.

## In-game release gate (maintainer)

Use Warcraft III Reforged 3.0.0.24268 and World Editor 3.00, recording actual versions if different.

The maintainer runs each gate run in a throwaway map and reads the printed lines against the steps below. The map is
a Moonwell project linked to the Moonwell checkout, whose `moonwell.toml` names this library by a local path, and
whose `src/main.yue` is a copy of `examples/gate.yue` with the run's switch set and one camera line added
(`SetCameraPosition 0, 0`, after `owner = Player.fromIndex 0`). The example needs no object data of its own: it uses
the game's stock rawcodes. The frames run needs one file, the TOC that the example loads
(`Frame.loadTOC "war3mapImported\\wrappers-gate.toc"`): it goes into the map as
`assets/war3mapImported/wrappers-gate.toc`, and holds the paths of the game's own FDF files, one per line, ending with
an empty line (a TOC must):

```text
UI\FrameDef\UI\EscMenuTemplates.fdf
UI\FrameDef\Glue\StandardTemplates.fdf
UI\FrameDef\Glue\BattleNetTemplates.fdf
UI\FrameDef\UI\QuestDialog.fdf

```

The map is built with `moonwell build --entry src/main.yue` (`--minify` for a minified run), and the game is started on
`dist/bin/map.w3x`. One map is built per run. The runs are the seven switches near the top of the example
(`probes = false` and the six lines after it):
`core` leaves them all false (steps 2 to 5), and `probes` (step 6), `presentation` (step 7), `ui` (step 8), `frames`
(step 9), `port` (step 13), `additions` (step 14) and `dispose` (step 15) each set their own to `true`.

Every run writes each line it prints to `Documents\Warcraft III\CustomMapData\moonwell-wrappers-gate.pld`, written
anew at every line, so a run is read from that file afterwards and needs no screenshot. A run with something to watch
(presentation, classic UI, frames, and the rain of the additions run) shows one thing at a time: one line on screen
says what to look for or to do, `Step 4 of 23. Look: … Then press Esc.`, and Esc goes on to the next. The file has a
line for each step that was reached; what the maintainer reports is the number of a step that did not look as its line
says.

1. The gate starts just after the map loads (times below count from there). Play the `core` and `probes` runs until
   `Wrapper weak cache probe` prints (about 50 seconds). The presentation, classic UI and frames runs end when their
   last step is left with Esc, and say so on screen. Then read the run's file.
2. Foundation (as in v0.1.0): the footman appears, moves, changes life and color (disable ally color mode with Alt+A if
   needed), and the attached effect appears. `Wrapper group size` prints at start. Timer and trigger ticks print every
   second; `Wrapper unit death event` prints at tick 3; `Wrapper gate cleanup passed` prints at tick 5 and no later
   foundation ticks print.
3. Broad: at start, `Wrapper hero level` (above 1), `Wrapper ability level 2` (Storm Bolt) with a cooldown near 30,
   `Wrapper item <item name> charges 3`, `Wrapper force players <count>` and `Wrapper filtered heroes 1` print.
   `Wrapper region entered` prints when the footman walks into the rect. After about 2 seconds the hero walks to the
   item and `Wrapper item picked up true` prints; at 4 seconds the tree dies and `Wrapper tree death event` prints; at 6
   seconds `Wrapper tree restored` prints with its life, and the tree stands again.
4. Type `-gate` in chat twice within the first ~30 seconds, while the hero is alive. The chat trigger has a condition
   that removes itself during its first evaluation. `Wrapper chat once` prints only after the first `-gate`;
   `Wrapper chat accepted` prints both times; `ERROR removed action ran` never prints. The game does not crash and no
   `[wrappers] ... failed` line prints. At 30 seconds `Wrapper broad cleanup passed` prints and the hero, item and tree
   disappear.
5. Weak cache probe: at 30 seconds five probe footmen appear (twenty more are created and removed at once). At 50
   seconds twenty more are created and removed in the same callback;
   `Wrapper weak cache probe collected=<bool> stale=<bool> identity=<bool>` prints and the five kept footmen disappear.
   It passes when all three are `true`, and `Wrapper weak cache probe passed` then prints too. `collected=false` means
   Lua's collector had not yet freed the weak sentinel: the result is inconclusive, not a failure. Run again, or tell
   the maintainer.
6. Set `probes = true` and run again. The intentional timer and trigger errors print
   (`[wrappers] Timer callback failed: ... intentional timer probe` and
   `[wrappers] Trigger callback failed: ... intentional trigger probe`) and both callbacks continue;
   `[wrappers] Trigger condition failed: ... intentional condition probe` prints, and the action behind that condition
   never runs (no `ERROR condition probe action ran`). Since v0.6.0 the probes run also prints:
   - `Wrapper exists after raw removal true false false`: a unit, an item and a destructable removed with the raw
     natives; the unit still reads `true` in that instant. Then `Wrapper unit exists after 0 s false` and
     `Wrapper unit exists after 1 s false`. An item or destructable printing `true`, or the unit still `true` a frame
     later, means that class's `exists()` must be dropped before release.
   - `Wrapper killed unit alive, exists false true`.
   - `Wrapper error location war3map.lua:<line>: [wrappers] Unit.issueTargetOrder: Unit is disposed`. Moonwell bundles
     one chunk, so check the line in the built `dist/stage/map.w3x/war3map.lua`: it must be the gate's own `pcall` line,
     not a line of the wrappers.
   - Since v0.10.0, at start: `Wrapper integral floats true nil`. The gate calls `Player.fromIndex 0.0`, a multiboard's
     `setRowCount 2.0` and a unit's `setColor 255.0, 255.0, 255.0, 255.0` under one `pcall`; `false` and a message mean
     that a whole number held as a float was refused. `setRowCount` gives the native its own loop's integer, so its
     call shows only that the loop ends; the other two give their natives the floats.
   - Since v0.10.0, three seconds after the start: `Wrapper timer restart first 0 second 1`. A one-shot timer of 1
     second was started with a first callback and started again at once with a second one: the first callback never
     runs and the second runs once.

   Restore `probes = false`.
7. Presentation (v0.3.0): set `presentation = true`; only the presentation gate runs, at the map centre, where a
   footman stands and a fog modifier reveals the area. The file starts with
   `Wrapper presentation started; sound duration <n>` (record `n`, in seconds since v0.10.0; 0 can mean the file was
   not loaded yet), `Wrapper enumerated potions 2` and `Wrapper enumerated trees 2` (three items and two trees are
   created, counted and removed at once). Then 23 steps, one thing each, Esc for the next:
   - 1 to 3, text tags: a yellow `Wrapper text tag` up and left of the footman; it jumps onto the footman and reads
     `Wrapper tag moved`; `Wrapper float` rises and fades, shown again every three seconds, and
     `Wrapper float for another player` never appears.
   - 4 and 5, lightning: a Drain Life beam below the footman that stays (chain lightning faded right after creation
     in an earlier run); it moves above the footman (its `setColor` red showed no visible change on 3.0.0.24268; see
     README).
   - 6 to 8, image: the area-of-effect circle under the footman; it turns green and moves up; it disappears
     (`setVisibleFor` another player).
   - 9 and 10, ubersplat: a building-base splat up and right of the footman; it fades out.
   - 11 to 14, effects: a red, half-transparent, slowed Footman model left of the footman, turned 90 degrees (yaw
     90), raised and attacking; a Footman model in blue (player 2's colour) in its place; a thunder clap that flashes
     below the footman, then one on the footman, each shown again every two seconds.
   - 15 to 17, fog modifiers on the minimap, far out from the gate's area: a revealed circle towards the top right; a
     revealed square towards the bottom left; the square's modifier is stopped. A stopped modifier leaves its area
     explored and out of sight, which is easy to take for still lit, so the file says it:
     `Wrapper fog square in sight before the stop true`, and as the step is left
     `Wrapper fog square in sight after the stop false fogged true`.
   - 18 to 23, sounds, each played once as its step begins: the warning sound (`Wrapper sound play`); a knight's
     voice (`Wrapper sound duration after play <n>`, record whether it differs from the start value, then
     `Wrapper playOnce first call`); the knight's voice again (`Wrapper playOnce second call`); the footman voice
     from the centre (`Wrapper 3D sound`); nothing (`Wrapper playFor and playOnce for another player`: playOnce for
     another player plays at volume 0 locally); the footman voice again (`Wrapper playOnce 3D`). If step 19 is silent
     and step 20 audible, record first-play silence (spec §5.2) and stop: the fix is decided with the maintainer
     before release. If step 23 is silent while step 21 was audible, record it: `playOnce` may need default sound
     distances (spec §5.2), decided with the maintainer before release.

   Leaving the last step prints `Wrapper presentation cleanup passed`. If a sound, model or splat never appears or
   plays in any run, its path or name may not exist in this game version: substitute one from World Editor and record
   it.
8. Classic UI (v0.4.0): set `ui = true`; only the classic UI gate runs. A dialog appears whose title says what to
   press next: `Wrapper dialog: press K`, then `click Plain`, `click Rebuild`, `click After clear` and
   `click Destroy dialog`. It closes at each press and comes back half a second later, after `Rebuild` with only
   `After clear` and `Destroy dialog`. The file has `Wrapper dialog keyed by <your name>`,
   `Wrapper dialog plain by <your name>`, `Wrapper dialog rebuilt`, `Wrapper dialog after clear by <your name>` and
   `Wrapper dialog destroyed from its own button`; the dialog never comes back, and no `[wrappers] ... failed` line
   prints. Then 16 steps, one thing each, Esc for the next:
   - 1 to 6, multiboard, top right: titled `Wrapper multiboard` (yellow) with 3 × 3 cells, a yellow `Name` and
     `Kills` in row 1, `Footman` with its icon in row 2, `Row 3` in row 3, footman icons down column 3 and a wider
     first column (`Wrapper multiboard Wrapper multiboard 3 3`); 6 rows with `Row 6` in the last
     (`Wrapper multiboard rows 6`); 2 rows (`Wrapper multiboard rows 2`); minimized to its title; expanded again;
     gone (`Wrapper multiboard hidden for another player`).
   - 7 to 9, leaderboard: titled `Wrapper leaderboard` (yellow) with `Other 9` (blue value) above `You 5`
     (`Wrapper leaderboard items 2`); `You (12)` on top and no icons; `Other` removed, one row
     (`Wrapper leaderboard items 1 has other false`).
   - 10 to 12, quests, each read in the quest log (F9), which is closed with its own button before Esc: the quest
     button flashes and the log lists `Wrapper quest` (required, footman icon, two items), `Wrapper optional quest`
     (optional) and the defeat condition `Wrapper defeat condition`; the first item shows as completed
     (`Wrapper quest item completed true`); the quest shows completed and the optional quest failed
     (`Wrapper quest completed true optional failed true`).
   - 13 to 16, timer dialog: `Wrapper timer dialog` (yellow title, green time) counts down from about 10:00; it
     counts faster (`speed 4`; record what it shows); it shows about 0:10; it disappears.

   Leaving the last step prints `Wrapper ui cleanup passed; quest item disposed true`, and the quests leave the log.
9. Frames (v0.5.0): set `frames = true`; only the frames gate runs. The file starts with
   `Wrapper frames shown: <name> children <n>` (record both). Nine steps, Esc for the next:
   1. a panel in the centre with a yellow title `Wrapper frames`, a `Click me` button, an edit box, a slider, a check
      box and a `Close` button; `ERROR visible for another player` never appears;
   2. a footman icon top left;
   3. hovering `Click me` shows `Wrapper tooltip`;
   4. clicking `Click me` prints `Wrapper frame clicked by <your name> count 1` (then 2, …), and Enter right after a
      click opens the chat box (focus was released);
   5. typing in the edit box and pressing Enter prints `Wrapper edit box enter by <your name> <text>`;
   6. dragging the slider prints `Wrapper slider value <n>`;
   7. ticking and unticking the check box print `Wrapper checkbox checked by <your name>` and `... unchecked ...`;
   8. the footman icon jumps into the panel's top right (`Wrapper badge moved into the panel`);
   9. clicking `Close` removes the panel and the icon and prints
      `Wrapper frames closed; badge disposed true button disposed true`.

   Leaving the last step prints `Wrapper frames gate done; panel disposed true`, and no `[wrappers] ... failed` line
   prints. The probes that came before the first classic UI and frames gates (ui-init and frame-init) went with the
   old gate map; their answers are in the v0.4.0 and v0.5.0 records below.
10. Build with `--minify` and play the packed map; repeat steps 2–5 and 7–9 (without the probes). Open the packed map in
    World Editor.
11. Two-player run: deferred. Reforged's latest patch removed LAN, and online multiplayer and desync checks are the last
    step before Moonwell 1.0 (Moonwell's backlog). Then: host an online game of the minified map for two players and
    play past the weak cache probe (about a minute). Neither machine may desync. Each machine prints its own probe line,
    from its own Lua collector; record both. The same online check covers v0.3.0's local visibility: setVisibleFor,
    playFor and the player options of TextTag.float and Sound.playOnce show or play only for that player, with no
    desync. It also covers `playFor` followed by `destroy()` (the other machines never started that sound) and whether
    `getDuration()` agrees across machines. It also covers v0.4.0: `setVisibleFor` on Multiboard and TimerDialog shows
    only for that player; `leaderboard:assign` and a dialog shown to one player appear only on that player's screen; a
    dialog click by the second player prints that player's name on both machines; no desync. It also covers v0.5.0:
    frames created in the same order on both machines, `setVisibleFor` and `releaseFocusFor` acting only for that
    player, and frame events from the second player printing that player's name on both machines; no desync. It also
    covers v0.8.0: `wrappers.input` listeners running on both machines for the second player's keys and mouse, and
    `weather:setEnabledFor` drawing only for that player; no desync.
12. Record results here and in CHANGELOG, including Warcraft/editor versions. Automated native doubles cannot replace
    this gate. Do not declare the release ready while this is pending. The spec's fallback (strong widget caches plus
    `forget()`) applies only if a run with `collected=true` prints `stale=false` or `identity=false`, or if a desync
    occurs. Then stop and apply it.
13. Port prerequisites (v0.7.0): set `port = true` (normal build only). Only the port gate runs; a footman stands at the
    centre with another one to its left, and a line of trees runs north–south to their right. Messages, one step per
    second:
    - at start: `Wrapper collision size <n>` (record it) and `Wrapper port gate started`;
    - step 1: `Wrapper damaged step 1 amount <X>` and `Wrapper life loss step 1 <X>`: the baseline, 100 reduced by
      armor;
    - step 2: `Wrapper damaging Footman Footman false 100.0 200.0` (`isAttack` is false for `damageTarget` even with
      `attack` true: the native's value), then `Wrapper damaged step 2 amount <Y>` and `Wrapper life loss step 2 <Y>`,
      with Y about twice X;
    - step 3: the attack type changed to magic before armor: `Wrapper damaged step 3 amount <Z>` with Z different from X
      (record it);
    - step 4: the attack type changed with the raw native after armor: `Wrapper life loss step 4 <X>`, unchanged, which
      confirms that type changes after armor do nothing;
    - step 5: a nested 10-damage hit inside the outer hit's DAMAGING listener, then `setAmount 0` on the outer event.
      Record every `Wrapper damaged step 5` line and the life loss: if the outer line reads amount 0 and the life loss
      is only the nested hit's, the outer setter still works after a nested hit;
    - step 6: `Wrapper stale damage event false <…>DamagingEvent.setAmount: the damage event is over`;
    - step 7: `Wrapper life loss step 7 <X>` with no `Wrapper damaged` line, then `Wrapper damage listeners removed`;
    - step 8: a third footman appears left of the trees with pathing off and is ordered across them; it walks around the
      end of the tree line (the pathfinder still avoids trees); at step 12 `Wrapper pathing walker x <n>` with n over
      448;
    - step 13: `Wrapper sync sent true`, `Wrapper sync 256 bytes rejected true <…>over the 255-byte limit`, then shortly
      `Wrapper sync received from <your name> 255 true` and the prefix lines: record which of `prefix 16 arrived`,
      `prefix 17 arrived whole/cut to 16` and `prefix 32 arrived whole/cut to 16` print;
    - step 15: `Wrapper port gate done`, and no `[wrappers] ... failed` line at any point.
14. Additions (v0.8.0): set `additions = true` (normal build only). Only the additions gate runs. Every line starts with
    `Wrapper additions`.
    - Printed at once, nothing to watch:
      - `art: Thunder Clap caster <a path ending in ThunderClapCaster.mdl>`, `art: Thunder Clap missile nil`,
        `art: Flame Strike special, third entry <a path ending in FlameStrike.mdl>`,
        `art: Chain Lightning lightning CLPB` and
        `art: a missing art refused true [wrappers] Effect.create: expected a model path`;
      - `player state: gold 1000 and the event's player is the owner: true`, and the same line for 1001;
      - `alliance change: firings after the same value 0 and after two changes 2`;
      - `event: the dying unit is the footman: true`, `event: picked up Claws of Attack +12 by the hero: true` and
        `event: the dying destructable is the tree: true`;
      - `weather ids created: 21 <the ids>` and `weather ids refused: 0`. If an id is refused, take it out of the
        README's table before the release;
      - `weather: an unknown id refused true [wrappers] WeatherEffect.create: unknown weather effect id: 2054847098`;
      - `rain: created and its rect destroyed. Not enabled: no rain yet` and `gate started`;
      - within a second: `event: the entered region is the zone: true by the hero: true`,
        `game state: the time of day reached 12.00` and `timer expiry: trigger for this timer true, then callback`.
    - Two seconds in, six steps, one thing each, Esc for the next. The rain is in the middle of the screen and takes
      a second or two to start and to stop:
      1. no rain;
      2. `rain 1: enabled for everyone NOW`: rain;
      3. `rain 2: enabled for another player only NOW`: the rain stops;
      4. `rain 3: enabled for you only NOW`: it falls again;
      5. `rain 4: destroyed NOW`: it stops;
      6. `art: a Thunder Clap appears NOW in the middle`: the effect plays at the centre.
    - Then the game shows six input steps, one at a time; do each, then press Esc. After each Esc one line prints:
      1. tap Q once: `input 1: downs 1 with repeats 1 of which repeated 0 ups 1 meta 0`;
      2. hold Q for about two seconds: `input 2: downs 1 with repeats <many> of which repeated <one fewer> ups 1`;
      3. Shift with Q: `input 3: downs 1 … ups 1 meta 1`;
      4. a left click on the ground: `input 4: … clicks 1 (left at <x> <y>) releases 1`;
      5. moving the mouse for two seconds: `input 5: … moves <over 100>`, then `input: every listener removed`;
      6. Q and a click after the listeners are removed: every count is 0 (`input 6: downs 0 … moves 0`), then
         `gate done`.
    - No `[wrappers] ... failed` line at any point.
15. Automatic disposal (v0.9.0): set `dispose = true` (normal build only). Only the dispose gate runs, for about four
    seconds, and nothing needs watching: five units stand in a row, of which some die. Every line starts with
    `Wrapper dispose`.
    - `1 same instant, after a sweep: removed disposed false exists true | exploded disposed <…> exists <…>`: a unit
      removed by raw code is not seen in the instant of its removal. Record what the exploded unit reads.
    - `2 the timer's sweep disposed the removed unit after <at most 0.30> s`.
    - `3 after 1 s: living disposed false exists true | removed disposed true exists false | exploded disposed true
      exists false | corpse disposed false exists true | dead hero disposed false exists true`.
    - `4 error: war3map.lua:<line>: [wrappers] Unit.getX: Unit is disposed`.
    - `5 stopped, then removed by raw code: disposed false exists false`: nothing sweeps after `stop()`.
    - `6 after a sweep by hand: disposed true exists false`.
    - `7 handle ids: the removed unit had <id> and a unit created now has <id>`: record both.
    - `8 sweep cost: 200 more wrappers, <n> microseconds per sweep`: record the number.
    - `9 corpse and dead hero at the end: disposed false exists true | disposed false exists true`, then `gate done`.
    - No `[wrappers] ... failed` line at any point.

The records up to v0.9.1 were made with a gate map kept beside this repository. It was deleted on 2026-10-03 with the
probe notes it held; what the probes measured is written in the records and in the changelog.

v0.1.0: Passed 2026-09-28, confirmed by the maintainer on Warcraft III Reforged 3.0.0.24268 and World Editor 3.00 (file
version 3.0.0.24268). Normal gameplay/cleanup, callback-error recovery, minified packed-map gameplay and World Editor
opening all passed. The probe screenshot confirms both intentional errors followed by ticks, death and cleanup in F12.
The disposable gate used three-second ticks, death at nine seconds and cleanup at fifteen seconds, with camera and
selection adjustments for visibility. Library code was commit `3b923d5` throughout.

v0.2.0: Passed 2026-09-29, confirmed by the maintainer's message-log screenshots on Warcraft III Reforged 3.0.0.24268
and World Editor 3.00 (file version 3.0.0.24268). Steps 2, 3, 5 (`collected=true stale=true identity=true`), 6 and 7
(the minified run, now step 8) passed with library `7f4261f`. Gate copies added one camera line. Step 4: the first
`-gate` printed `Wrapper chat once` and `Wrapper chat accepted` on `faa54f3` (same library code); the second `-gate` was
not observed. Step 8 (the two-player run, now step 9) is deferred.

v0.3.0: Passed 2026-09-29, confirmed by the maintainer's message-log screenshots and observations on Warcraft III
Reforged 3.0.0.24268 and World Editor 3.00, library code `f685abe` (unchanged since), run from a disposable map with one
command per run. Steps 2–5 and 6 passed as in v0.2.0, normal and minified, including
`collected=true stale=true
identity=true`. Step 7 found four gate problems, each fixed in the gate and documented: trees
snap to a 64-unit grid and the native enumeration left out one that landed on the box edge (wider box); Chain Lightning
fades right after creation (the gate uses Drain Life); Warcraft draws no effect attached to an item or a destructable
(README; an editor error is in Moonwell's backlog); `lightning:setColor` stores the colour but showed no visible change
(README). After the fixes, step 7 passed normal and minified: the first-play knight voice and the 3D `playOnce` were
audible, sound duration 1903 before and after play, potions 2 and trees 2, the image slightly off-centre under the
footman (within the footman's placement; an origin error would be 128 units), and every other listed observation. Step
8: the minified runs passed and the packed map opened in World Editor. Step 9 is deferred.

v0.3.1: Not re-run (maintainer's decision, 2026-09-29). The release changes documentation, tests and one runtime check,
`Image.create`'s wrong-path error; a dedicated probe run on Warcraft III 3.0.0.24268 measured the behaviour it relies on
(handle id -1 for a wrong path; `DestroyImage` on it does not crash). Library code is otherwise that of v0.3.0.

v0.4.0: `ui-init` probe run 2026-09-29 by the maintainer on Warcraft III Reforged 3.0.0.24268 (library `b4f4201`): a
dialog and a multiboard shown directly in `on_main` did not appear; a quest, leaderboard and multiboard created in
`on_main` did not crash, the leaderboard later showed its item and the quest was listed in the log; one
`MultiboardSetRowCount` from 0 to 5 showed 5 rows, as did the wrapper's stepped change; a new 2 × 2 multiboard showed an
eye icon in each cell and no text. The gate passed the same day with library `c2f2b2c`, confirmed by the maintainer's
message-log screenshots and observations: step 8 printed every listed line in order, from `Wrapper dialog keyed by` to
`Wrapper ui cleanup passed; quest item disposed true`, with no `[wrappers] ... failed` line; every listed visual
matched, and `setSpeed 4` made the countdown run faster. Step 9: the minified `ui-min` run gave the same result and the
packed map opened in World Editor. Steps 2–7 were not re-run (their code is unchanged since v0.3.1). Step 10 is
deferred.

v0.5.0: `frame-init` probe run 2026-09-29 by the maintainer on Warcraft III Reforged 3.0.0.24268 (library `a565d2c`):
the origin frame existed in `on_main` and an icon made there showed; BlzGetFrameByName returned the created frame
(identity); all nine templates tried (`ScriptDialogButton`, `EscMenuBackdrop`, `EscMenuTitleTextTemplate`,
`EscMenuLabelTextTemplate`, `EscMenuEditBoxTemplate`, `EscMenuSliderTemplate`, `QuestCheckBox`,
`QuestButtonBaseTemplate`, `BattleNetTextAreaTemplate`) created without a TOC, and again after loading the gate map's
TOC (which returned true); a missing TOC returned false; an unknown template returned nil; destroying a parent removed
it, its child and a frame re-parented onto it, and the child was no longer found by name; after clicking a plain button
Enter did not open the chat box, after a button that called `releaseFocusFor` it did; a button destroyed itself in its
own click event without a crash. The frames gate (step 9) and its minified run (step 10) passed the same day, as the
maintainer reported. Steps 2–8 were not re-run (their code is unchanged since v0.4.0). Step 11 is deferred.

v0.5.1: Not re-run (maintainer's decision, 2026-09-30). The release changes LuaLS annotations (`Effect.attach` and
`Effect.flashOn` take a Unit), a comment, fixtures and documentation; runtime code is that of v0.5.0.

v0.6.0: run 2026-09-30 by the maintainer on Warcraft III Reforged 3.0.0.24268, normal builds from the gate map
(the runs `core`, `probes`, `presentation`, `ui` and `perf`). Steps 2–8 passed as described. The probes run was
repeated once after adding the delayed `exists()` check.

- `Wrapper exists after raw removal true false false`: the unit still reads `true` in that instant.
- `Wrapper unit exists after 0 s false` and `after 1 s false`.
- `Wrapper killed unit alive, exists false true`.
- `Wrapper error location war3map.lua:4055: … Unit is disposed`: bundle line 4055 is the gate's own `pcall` line in
  `gate_probes`.

Step 9 (frames) and step 10 (minified) were not re-run, by the maintainer's decision. Frames changed only by the
parentheses on raising returns and the shared `require`, which the unit tests and the sweep cover, and minified builds
run the same code. Performance against v0.5.1 is recorded in the CHANGELOG.

v0.7.0: run 2026-09-30 by the maintainer on Warcraft III Reforged 3.0.0.24268, the `port` run (step 13), normal
build. Every step printed as described, with two corrections to the expectations, now written into step 13: `isAttack`
reads false for `damageTarget` (the native's value), and the footman with pathing off walked around the tree line, not
through it (`Wrapper pathing walker x 563.7461`). Collision size 31.0; step 3 gave 178.5714 (magic against heavy armor
doubles); the nested hit's outer `setAmount 0` took effect; prefixes of 16, 17 and 32 characters arrived whole. Steps
2–10 were not re-run: this release adds modules and two Unit methods and changes no existing code path.

v0.8.0: run 2026-10-01 by the maintainer on Warcraft III Reforged 3.0.0.24268, the `additions` run (step 14),
normal build, one machine. Every line printed as described, read from the gate's file, with two corrections now written
into step 14: the Claws of Attack read `+12`, and the region line arrives a moment after the start, not with the first
lines. All 21 weather ids were created. The maintainer saw the rain start, stop, start and stop at the four lines, and
the Thunder Clap. The input steps read: one down and one up for a tap; one down against 60 with repeats (59 repeated)
for a held key; `meta 1` with Shift; one click `left at -109 133` with one release; 1041 mouse moves in step 5; and
nothing after the listeners were removed. Steps 2–10 and 13 were not re-run: the release adds modules and functions, and
its one change to existing code is a type check in front of four natives. Two probes came before the design.

v0.8.1: Not re-run (maintainer's decision, 2026-10-02). The release adds `moonwell-library.json` and changes tools and
documentation; no file under `src/` changed since v0.8.0.

v0.9.0: run 2026-10-02 by the maintainer on Warcraft III Reforged 3.0.0.24268, the `dispose` run (step 15),
normal build, one machine. Every line printed as described, read from the gate's file. The exploded unit read
`disposed false exists true` in the instant of its death, like the removed one; the timer's sweep disposed the removed
unit after 0.25 s; the error named `war3map.lua:5417`, the gate's own line; the handle ids were 1048696 and 1048703;
a sweep over 200 more wrappers took 90.0 microseconds. Steps 2–10, 13 and 14 were not re-run: the release adds two
functions and changes `exists()` for a disposed wrapper only.

v0.9.1: run 2026-10-02 by the maintainer on Warcraft III Reforged 3.0.0.24268, the probe run `probe-release` (six
steps), before and after the fix. The results are in the changelog: with the fix the press after Alt+Tab, after a click
on another window and after the chat box reached `onKeyDown`, and the press one second of game time after the menu did
not. The numbered steps above were not re-run: the change is inside `wrappers.input`.

v0.9.2: Not re-run (2026-10-09). The release changes tools and documentation for Moonwell 0.12; no file under `src/`
changed since v0.9.1.

v0.10.0: run 2026-10-09 by the maintainer on Warcraft III Reforged 3.0.0.24268 (the version of the game's executable),
in throwaway maps built with Moonwell 0.12.0: every run as a normal build, and `core` and `presentation` minified.
The gate example was rewritten during the gate, to one thing at a time with Esc and every printed line in one file:
`core` and `probes` ran before that and were read from the maintainer's screenshots of the message log, every other
run after it and from the file. No file under `src/` changed in between, and no `[wrappers] ... failed` line printed
in any run but the three intended ones.

- Steps 2, 3 and 5 passed, normal and minified, with `collected=true stale=true identity=true`. Step 4 passed in the
  minified run: `Wrapper chat once` after the first `-gate` only, `Wrapper chat accepted` both times; `-gate` was not
  typed in the normal run.
- Step 6: the three intended errors printed and the ticks went on; `Wrapper exists after raw removal true false false`,
  then `false` after 0 s and after 1 s; `Wrapper killed unit alive, exists false true`; the error location was
  `war3map.lua:5032`, the gate's own `pcall` line. The two new lines read `Wrapper integral floats true nil` and
  `Wrapper timer restart first 0 second 1`.
- Step 7, normal and minified: every step was seen and heard. Sound duration 1.903 before and after play (seconds
  now); potions 2 and trees 2; the knight's voice was audible at its first call and the 3D `playOnce` too; the Drain
  Life beam stayed and moved; the red model stood with its back to the camera, which is yaw 90. In the normal run the
  square on the minimap looked still lit after its modifier was stopped; the example then got the two fog lines and
  both reveals were moved far out, and the minified run read `in sight before the stop true` and
  `in sight after the stop false fogged true`, with the square seen out of sight and still explored.
- Step 8, normal: the five presses of the dialog and all 16 steps, ending with
  `Wrapper ui cleanup passed; quest item disposed true`.
- Step 9, normal: `Wrapper frames shown: EscMenuBackdrop children 8`; the click (`count 1`), the edit box's text, the
  slider's values from 5 to 7, `Wrapper checkbox checked by`, the badge moved, and
  `Wrapper frames closed; badge disposed true button disposed true`. The `unchecked` line did not print, and the
  maintainer is not sure that the box was unticked: not observed in this gate.
- Step 10: the minified `ui` and `frames` runs were not played and the packed map was not opened in World Editor, by
  the maintainer's decision. Step 11 is deferred.
- Step 13: as in v0.7.0, value for value (collision size 31.0, 89.28571 doubled to 178.5714, magic 178.5714, the
  nested hit's outer `setAmount 0`, the walker at x 563.7461, prefixes of 16, 17 and 32 characters whole).
- Step 14: every line as described, and the maintainer saw the rain start, stop, start and stop and the Thunder Clap.
  All 21 weather ids were created. A tap gave one down and one up; a held key one down against 109 with repeats (108
  repeated); `meta 1` with Shift; one click `left at -17 -132` with one release; 1299 mouse moves; nothing after the
  listeners were removed.
- Step 15: every line as described. The sweep disposed the removed unit after 0.25 s; the error named
  `war3map.lua:5810`, the gate's own line; the handle ids were 1048696 and 1048703; a sweep over 200 more wrappers
  took 70.0 microseconds.

Of the three behaviours no probe had measured: a whole number held as a float is accepted where a native takes an
integer (`Player.fromIndex 0.0` and `setColor 255.0, …` reached their natives). The timer line pins what a map sees
and cannot tell whether the game delivers a replaced schedule, and `BlzGetFrameByName` after a re-parent was not
probed: both stay unmeasured.

## First publication and tag gate (maintainer)

After all automated checks and the in-game gate pass, tag the verified commit `vX.Y.Z` and push the tag to
`mdlsvensson/moonwell-wrappers`. Tags are immutable. This library is not a JSR or Pkl package. Before tagging, change
the Unreleased changelog heading to the released version/date, record the gate evidence, and update README: the Status
paragraph, the sentence introducing the GitHub example and that example's `tag` must name the new tag, because the
consumption check below uses that configuration.

In a fresh Moonwell map, use the README GitHub configuration, run check/build, and inspect/commit moonwell.lock. Confirm
it records the tagged commit. Remove only that disposable map's `.moonwell/` cache and repeat check; the lock must stay
unchanged. Record the result and only then mark first-tag consumption verified. Do not retag a moved release.

v0.1.0: Passed 2026-09-28 for `v0.1.0` with Moonwell 0.5.0: check, normal and minified builds; `moonwell.lock` recorded
commit `c1209f5fb3141d91df2234e765e66c43bb01fc02`, the fetched files matched the tag's `src/`, and the lock stayed
unchanged after removing the map's `.moonwell/` and checking again.

v0.2.0: Passed 2026-09-29 for `v0.2.0` with Moonwell 0.5.0: check, normal and minified builds of the gate example;
`moonwell.lock` recorded commit `4b2c845b6775541896a5652c17e40ff5544affca`, the fetched files matched the tag's `src/`,
and the lock stayed unchanged after removing the map's `.moonwell/` and checking again.

v0.3.0: Passed 2026-09-29 for `v0.3.0` with Moonwell 0.5.0: check, normal and minified builds of the gate example;
`moonwell.lock` recorded commit `5da96d8d3f69402e872c07a708dfd667979ed714`, the fetched files matched the tag's `src/`,
and the lock stayed unchanged after removing the map's `.moonwell/` and checking again.

v0.3.1: Passed 2026-09-29 for `v0.3.1` with Moonwell at `9186220` (0.5.0 plus `UnitAlive` in its natives list): check,
normal and minified builds of the gate example; `moonwell.lock` recorded commit
`b37aef4f45045b146b065a3ea1c1530814283f65`, the fetched files matched the tag's `src/` (plus Moonwell's
`.moonwell-library.json`), and the lock stayed unchanged after removing the map's `.moonwell/` and checking again.

v0.4.0: Passed 2026-09-29 for `v0.4.0` with Moonwell at `b998bec` (0.5.0 plus `UnitAlive` in its natives list): check,
normal and minified builds of the gate example; `moonwell.lock` recorded commit
`be7dc97e0071e5f9b0b6674af69e888b6bd6bcc5`, the fetched files matched the tag's `src/` byte for byte, and the lock
stayed unchanged after removing the map's `.moonwell/` and checking again.

v0.5.0: Passed 2026-09-29 for `v0.5.0` with Moonwell at `b1acd76` (0.5.0 plus `UnitAlive` in its natives list), in a map
made fresh with `init --link`: check, normal and minified builds of the gate example; `moonwell.lock` recorded commit
`76d515c3ab64105d3abd9715334517079c36ff98`, the 28 fetched files matched the tag's `src/` byte for byte, and the lock
stayed unchanged after removing the map's `.moonwell/` and checking again.

v0.5.1: Passed 2026-09-30 for `v0.5.1` with Moonwell 0.5.1 (`8a86425`), in a map made fresh with `init --link`: check,
normal and minified builds of the gate example; `moonwell.lock` recorded commit
`26c208d6b9d7cc006b4221940e755171913719d7`, the 28 fetched files matched the tag's `src/` byte for byte, and the lock
stayed unchanged after removing the map's `.moonwell/` and checking again.

v0.6.0: Passed 2026-09-30 for `v0.6.0` with Moonwell 0.5.2 (`main`), in a map made fresh with `init --link`: check,
normal and minified builds of the gate example; `moonwell.lock` recorded commit
`e908b2e1717f996cc52f1c6c98409306bb841171`, the 28 fetched files matched the tag's `src/` byte for byte, and the lock
stayed unchanged after removing the map's `.moonwell/` and checking again.

v0.7.0: Passed 2026-09-30 for `v0.7.0` with Moonwell 0.5.2 (`main`), in a map made fresh with `init --link`: check,
normal and minified builds of the gate example; `moonwell.lock` recorded commit
`9a8456e4d2c16dbb46cecaf92b303f7fac8017c3`, the 31 fetched files matched the tag's `src/` byte for byte, and the lock
stayed unchanged after removing the map's `.moonwell/` and checking again.

v0.8.0: Passed 2026-10-01 for `v0.8.0` with Moonwell 0.5.2 (`main`), in a map made fresh with `init --link`: check,
normal and minified builds of the gate example; `moonwell.lock` recorded commit
`75724acdda02364d2dc4ac99e6b0e6cb6063dd1e`, the 33 fetched files matched the tag's `src/` byte for byte, and the lock
stayed unchanged after removing the map's `.moonwell/` and checking again.

v0.8.1: Passed 2026-10-02 for `v0.8.1` with Moonwell 0.8.1, in a map made fresh with `init --link` whose entry has no
`dir` (the README configuration): check, normal and minified builds of the gate example (34 modules); `moonwell.lock`
recorded commit `4d1d6e977ea3755cf6f85c95a65d985ca5b5c2db` with `"dir": ""`, the 33 fetched files matched the tag's
`src/` byte for byte, and the lock stayed unchanged after removing the map's `.moonwell/` and checking again.

v0.9.0: Passed 2026-10-02 for `v0.9.0` with Moonwell 0.8.1, in a map made fresh with `init --link` whose entry has no
`dir`: check, normal and minified builds of the gate example (34 modules); `moonwell.lock` recorded commit
`0b6c1800a7f26963519da63b064150ae6425fb84`, the 33 fetched files matched the tag's `src/` byte for byte, and the lock
stayed unchanged after removing the map's `.moonwell/` and checking again.

v0.9.1: Passed 2026-10-02 for `v0.9.1` with Moonwell 0.9.0, in a map made fresh with `init --link` whose entry has no
`dir`: check, normal and minified builds of the gate example (34 modules); `moonwell.lock` recorded commit
`667cdc50a7625e6a61e12f2e52778a2bf40300ad`, the 33 fetched files matched the tag's `src/` byte for byte, and the lock
stayed unchanged after removing the map's `.moonwell/` and checking again.

v0.9.2: Passed 2026-10-09 for `v0.9.2` with Moonwell 0.12.0, in a map made fresh with `init --link` whose entry is the
README's, in `moonwell.toml`: check, normal and minified builds of the gate example (34 modules); `moonwell.lock`
recorded commit `3721f8d221f21389a5aa59532605bdce549a0704`, the 33 fetched files matched the tag's `src/` byte for
byte, and the lock stayed unchanged after removing the map's `.moonwell/` and checking again.

v0.10.0: Passed 2026-10-09 for `v0.10.0` with Moonwell 0.12.0, in a map made fresh with `init --link` whose entry is
the README's, in `moonwell.toml`: check, normal and minified builds of the gate example (35 modules); `moonwell.lock`
recorded commit `abd8badf39ad806234565db8fa40f87c3aaee199`, the 35 fetched files matched the tag's `src/` byte for
byte, and the lock stayed unchanged after removing the map's `.moonwell/` and checking again.
