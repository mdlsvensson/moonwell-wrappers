# Contributing

Use handwritten annotated Lua 5.3, test-first changes and explicit native boundaries. Keep runtime modules under
`src/wrappers/`; tests/tools/examples must stay outside `src/`. No Node.js or npm dependencies. Expected gameplay misuse
raises contextual Lua errors. Review each task and the final change. Work on main; push once the checks pass.

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

1. Create a disposable Moonwell map and configure this checkout with the local path example in README. Copy
   `examples/gate.yue` to its `src/main.yue`; run check and test. The gate starts just after the map loads (times below
   count from there). Play each run until `Wrapper weak cache probe` prints (about 50 seconds); the presentation run
   (step 7) never prints it and ends at about 20 seconds with `Wrapper presentation cleanup passed`; the classic UI run
   (step 8) never prints it either and ends about 45 seconds after its dialog is destroyed, with
   `Wrapper ui cleanup passed`; the frames run (step 9) never prints it either and ends when you click its `Close`
   button. Then read the whole message log (F12); opening it pauses a single-player game.
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

   Restore `probes = false`.
7. Presentation (v0.3.0): set `presentation = true` and run again; only the presentation gate runs, around the map
   centre, and a fog modifier reveals that area. At start `Wrapper presentation started; sound duration <n>` prints
   (record `n`; 0 can mean the file was not loaded yet), then `Wrapper enumerated potions 2` and
   `Wrapper enumerated trees 2`. Visible at once: a yellow `Wrapper text tag` upper left; a drain-life lightning bolt
   below the footman that stays (chain lightning faded right after creation in an earlier run); the area-of-effect
   circle centred under the footman; a building-base splat upper right; a red, half-transparent, slowed Footman model
   turned 90 degrees (yaw π/2) from the blue one, raised and attacking, and a blue (player 2 colour) Footman model
   beside it; the potions and two trees further up and left. The minimap shows a revealed circle towards the top right
   and a revealed square towards the bottom left. `Wrapper float for another player` never appears. At 2 s
   `Wrapper float` rises and fades, and the warning sound plays (`Wrapper sound play`). At 4 s
   `Wrapper sound duration after play <n>` prints (record whether it differs from the start value), the sound stops,
   `Wrapper playOnce first call` prints and a knight's voice plays. If it is silent then but audible at 6 s
   (`Wrapper playOnce second call`), record first-play silence (spec §5.2) and stop: the fix is decided with the
   maintainer before release. At 8 s the footman voice plays from the centre (`Wrapper 3D sound`). At 10 s
   `Wrapper playFor and playOnce for another player` prints and nothing plays (playOnce for another player plays at
   volume 0 locally). At 12 s (`Wrapper presentation changed`): the tag jumps to the footman and reads
   `Wrapper tag moved`, the bolt moves above the footman (its `setColor` red showed no visible change on 3.0.0.24268;
   see README), the circle turns green and moves up, the splat fades out, the bottom-left reveal ends and a thunder clap
   flashes below the footman. At 14 s the circle disappears and a thunder clap flashes on the footman
   (`Wrapper image hidden`). At 16 s `Wrapper playOnce 3D` prints and a footman voice plays from the centre; if it is
   silent while the 8 s voice was audible, record it: `playOnce` may need default sound distances (spec §5.2), decided
   with the maintainer before release. At 20 s everything disappears and `Wrapper presentation cleanup passed` prints.
   If a sound, model or splat never appears or plays in any run, its path or name may not exist in this game version:
   substitute one from World Editor and record it. Record whether the bolt stays visible and moves at 12 s. Restore
   `presentation = false`.
8. Classic UI (v0.4.0): first run the gate map's `ui-init` probe (`../wrappers-gate`, `yue -e gate.lua ui-init`,
   instructions in its `PROBE-UI.md`) and record its answers in the results below and in README. Then set `ui = true`
   and run again; only the classic UI gate runs. A dialog titled `Wrapper dialog` appears with `Keyed (K)`, `Plain` and
   `Rebuild` (`Wrapper dialog shown: ...` prints). Press K: the dialog closes, `Wrapper dialog keyed by <your name>`
   prints and the dialog comes back half a second later. Click `Plain`: `Wrapper dialog plain by <your name>`. Click
   `Rebuild`: `Wrapper dialog rebuilt` prints and the dialog comes back with only `After clear` and `Destroy dialog`.
   Click `After clear`: `Wrapper dialog after clear by <your name>`. Click `Destroy dialog`:
   `Wrapper dialog destroyed from its own button` prints, the dialog never comes back, and no `[wrappers] ... failed`
   line prints. Times below count from that click. At once a multiboard titled `Wrapper multiboard` (yellow) appears top
   right with 3 × 3 cells: a yellow `Name` and `Kills` in row 1; `Footman` with its icon in row 2; `Row 3` in row 3;
   footman icons down column 3; a wider first column. `Wrapper multiboard Wrapper multiboard 3 3` prints. At 3 s it
   grows to 6 rows with `Row 6` in the last (`Wrapper multiboard rows 6`); at 6 s it shrinks to 2
   (`Wrapper multiboard rows 2`); at 9 s it minimizes to its title; at 12 s it expands, then disappears
   (`Wrapper multiboard hidden for another player`). At 15 s a leaderboard titled `Wrapper leaderboard` (yellow) appears
   with `Other 9` (blue value) above `You 5`; `Wrapper leaderboard items 2` prints. At 18 s `You (12)` moves to the top
   and the icons disappear. At 21 s `Other` is removed and the board shrinks to one row
   (`Wrapper leaderboard items 1 has other false`). At 24 s the leaderboard disappears, the quest button flashes and
   `Wrapper quests created: open the quest log (F9)` prints: the log lists `Wrapper quest` (required, footman icon, two
   items), `Wrapper optional quest` (optional) and the defeat condition `Wrapper defeat condition`. At 27 s the first
   item shows as completed (`Wrapper quest item completed true`); at 30 s the quest shows completed and the optional
   quest failed (`Wrapper quest completed true optional failed true`). At 33 s a timer dialog `Wrapper timer dialog`
   (yellow title, green time) counts down from about 1:00; at 36 s it counts faster (`speed 4`; record what it shows);
   at 39 s it shows about 0:10; at 42 s it disappears. At 45 s `Wrapper ui cleanup passed; quest item disposed true`
   prints and the quests leave the log. Restore `ui = false`.
9. Frames (v0.5.0): first run the gate map's `frame-init` probe (`../wrappers-gate`, `yue -e gate.lua frame-init`,
   instructions in its `PROBE-FRAME.md`) and record its answers in the results below and in README. If a template the
   gate uses did not create after loading the gate map's TOC, change the gate to one that did before continuing. Then
   set `frames = true` and run again; only the frames gate runs. `Wrapper frames shown: <name> children <n>` prints
   (record both). A panel appears in the centre with a yellow title `Wrapper frames`, a `Click me` button, an edit box,
   a slider, a check box and a `Close` button; a footman icon appears top left; `ERROR visible for another player` never
   appears. Hovering `Click me` shows `Wrapper tooltip`. Clicking it prints
   `Wrapper frame clicked by <your name> count
   1` (then 2, …); right after a click, pressing Enter opens the chat box
   (focus was released). Typing in the edit box and pressing Enter prints
   `Wrapper edit box enter by <your name> <text>`. Dragging the slider prints `Wrapper slider value <n>`. Ticking and
   unticking the check box print `Wrapper checkbox checked by <your name>` and `... unchecked ...`. At 5 s the footman
   icon jumps into the panel's top right (`Wrapper badge moved into the panel`); click `Close` only after that. Clicking
   `Close` removes the panel and the icon, prints `Wrapper frames closed; badge disposed true button disposed true`, and
   no `[wrappers] ... failed` line prints. Restore `frames = false`.
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
    `weather:enableFor` drawing only for that player; no desync.
12. Record results here and in CHANGELOG, including Warcraft/editor versions. Automated native doubles cannot replace
    this gate. Do not declare the release ready while this is pending. The spec's fallback (strong widget caches plus
    `forget()`) applies only if a run with `collected=true` prints `stale=false` or `identity=false`, or if a desync
    occurs. Then stop and apply it.
13. Port prerequisites (v0.7.0): in the gate map, `yue -e gate.lua port` (normal build only). Only the port gate runs; a
    footman stands at the centre with another one to its left, and a line of trees runs north–south to their right.
    Messages, one step per second:
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
14. Additions (v0.8.0): in the gate map, `yue -e gate.lua additions` (normal build only). Only the additions gate runs.
    Every line starts with `Wrapper additions` and is also written to
    `Documents\Warcraft III\CustomMapData\moonwell-wrappers-additions.pld`.
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
    - Rain, in the middle of the screen. It takes a second or two to start and to stop:
      - no rain until `rain 1: enabled for everyone NOW` (4 s), then rain;
      - after `rain 2: enabled for another player only NOW` (10 s) the rain stops;
      - after `rain 3: enabled for you only NOW` (16 s) it falls again;
      - after `rain 4: destroyed NOW` (22 s) it stops.
    - At 27 s, `art: a Thunder Clap appears NOW in the middle`: the effect plays at the centre.
    - From 30 s the game shows six input steps, one at a time; do each, then press Esc. After each Esc one line prints:
      1. tap Q once: `input 1: downs 1 with repeats 1 of which repeated 0 ups 1 meta 0`;
      2. hold Q for about two seconds: `input 2: downs 1 with repeats <many> of which repeated <one fewer> ups 1`;
      3. Shift with Q: `input 3: downs 1 … ups 1 meta 1`;
      4. a left click on the ground: `input 4: … clicks 1 (left at <x> <y>) releases 1`;
      5. moving the mouse for two seconds: `input 5: … moves <over 100>`, then `input: every listener removed`;
      6. Q and a click after the listeners are removed: every count is 0 (`input 6: downs 0 … moves 0`), then
         `gate done`.
    - No `[wrappers] ... failed` line at any point.
15. Automatic disposal (v0.9.0): in the gate map, `yue -e gate.lua dispose` (normal build only). Only the dispose gate
    runs, for about four seconds, and nothing needs watching: five units stand in a row, of which some die. Every line
    starts with `Wrapper dispose` and is also written to
    `Documents\Warcraft III\CustomMapData\moonwell-wrappers-dispose.pld`.
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

v0.5.0: `frame-init` probe run 2026-09-29 by the maintainer on Warcraft III Reforged 3.0.0.24268 (library `a565d2c`;
`../wrappers-gate/PROBE-FRAME-RESULTS.md`): the origin frame existed in `on_main` and an icon made there showed;
BlzGetFrameByName returned the created frame (identity); all nine templates tried (`ScriptDialogButton`,
`EscMenuBackdrop`, `EscMenuTitleTextTemplate`, `EscMenuLabelTextTemplate`, `EscMenuEditBoxTemplate`,
`EscMenuSliderTemplate`, `QuestCheckBox`, `QuestButtonBaseTemplate`, `BattleNetTextAreaTemplate`) created without a TOC,
and again after loading the gate map's TOC (which returned true); a missing TOC returned false; an unknown template
returned nil; destroying a parent removed it, its child and a frame re-parented onto it, and the child was no longer
found by name; after clicking a plain button Enter did not open the chat box, after a button that called
`releaseFocusFor` it did; a button destroyed itself in its own click event without a crash. The frames gate (step 9) and
its minified run (step 10) passed the same day, as the maintainer reported. Steps 2–8 were not re-run (their code is
unchanged since v0.4.0). Step 11 is deferred.

v0.5.1: Not re-run (maintainer's decision, 2026-09-30). The release changes LuaLS annotations (`Effect.attach` and
`Effect.flashOn` take a Unit), a comment, fixtures and documentation; runtime code is that of v0.5.0.

v0.6.0: run 2026-09-30 by the maintainer on Warcraft III Reforged 3.0.0.24268, normal builds from the gate map
(`yue -e gate.lua core`, `probes`, `presentation`, `ui`, `perf`). Steps 2–8 passed as described. The probes run was
repeated once after adding the delayed `exists()` check.

- `Wrapper exists after raw removal true false false`: the unit still reads `true` in that instant.
- `Wrapper unit exists after 0 s false` and `after 1 s false`.
- `Wrapper killed unit alive, exists false true`.
- `Wrapper error location war3map.lua:4055: … Unit is disposed`: bundle line 4055 is the gate's own `pcall` line in
  `gate_probes`.

Step 9 (frames) and step 10 (minified) were not re-run, by the maintainer's decision. Frames changed only by the
parentheses on raising returns and the shared `require`, which the unit tests and the sweep cover, and minified builds
run the same code. Performance against v0.5.1 is recorded in the CHANGELOG and in
`../wrappers-gate/PROBE-PERF-RESULTS.md`.

v0.7.0: run 2026-09-30 by the maintainer on Warcraft III Reforged 3.0.0.24268, `yue -e gate.lua port` (step 13), normal
build. Every step printed as described, with two corrections to the expectations, now written into step 13: `isAttack`
reads false for `damageTarget` (the native's value), and the footman with pathing off walked around the tree line, not
through it (`Wrapper pathing walker x 563.7461`). Collision size 31.0; step 3 gave 178.5714 (magic against heavy armor
doubles); the nested hit's outer `setAmount 0` took effect; prefixes of 16, 17 and 32 characters arrived whole. Steps
2–10 were not re-run: this release adds modules and two Unit methods and changes no existing code path.

v0.8.0: run 2026-10-01 by the maintainer on Warcraft III Reforged 3.0.0.24268, `yue -e gate.lua additions` (step 14),
normal build, one machine. Every line printed as described, read from the gate's file, with two corrections now written
into step 14: the Claws of Attack read `+12`, and the region line arrives a moment after the start, not with the first
lines. All 21 weather ids were created. The maintainer saw the rain start, stop, start and stop at the four lines, and
the Thunder Clap. The input steps read: one down and one up for a tap; one down against 60 with repeats (59 repeated)
for a held key; `meta 1` with Shift; one click `left at -109 133` with one release; 1041 mouse moves in step 5; and
nothing after the listeners were removed. Steps 2–10 and 13 were not re-run: the release adds modules and functions, and
its one change to existing code is a type check in front of four natives. Two probes came before the design
(`../wrappers-gate/PROBE-EXTRAS-RESULTS.md`).

v0.8.1: Not re-run (maintainer's decision, 2026-10-02). The release adds `moonwell-library.json` and changes tools and
documentation; no file under `src/` changed since v0.8.0.

v0.9.0: run 2026-10-02 by the maintainer on Warcraft III Reforged 3.0.0.24268, `yue -e gate.lua dispose` (step 15),
normal build, one machine. Every line printed as described, read from the gate's file. The exploded unit read
`disposed false exists true` in the instant of its death, like the removed one; the timer's sweep disposed the removed
unit after 0.25 s; the error named `war3map.lua:5417`, the gate's own line; the handle ids were 1048696 and 1048703;
a sweep over 200 more wrappers took 90.0 microseconds. Steps 2–10, 13 and 14 were not re-run: the release adds two
functions and changes `exists()` for a disposed wrapper only.

v0.9.1: run 2026-10-02 by the maintainer on Warcraft III Reforged 3.0.0.24268, the probe
`yue -e gate.lua probe-release` (six steps, `../wrappers-gate/PROBE-RELEASE.md`), before and after the fix. The
results are in `../wrappers-gate/PROBE-RELEASE-RESULTS.md` and in the changelog: with the fix the press after
Alt+Tab, after a click on another window and after the chat box reached `onKeyDown`, and the press one second of game
time after the menu did not. The numbered steps above were not re-run: the change is inside `wrappers.input`.

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
