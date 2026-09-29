# Contributing

Use handwritten annotated Lua 5.3, test-first changes and explicit native boundaries. Keep runtime modules under
`src/wrappers/`; tests/tools/examples must stay outside `src/`. No Node.js or npm dependencies. Expected gameplay misuse
raises contextual Lua errors. Review each task and the final change. Work on main; the maintainer pushes.

## Tools

- Deno 2.x.
- YueScript 0.34.2, installed by Moonwell setup (or set `MOONWELL_YUE` to its executable).
- Pkl 0.32.1, on PATH (or set `MOONWELL_PKL` to its executable).
- A sibling Moonwell checkout at 0.5.0 (or `MOONWELL_REPO` pointing to that checkout).
- LuaLS 3.19.1 (or `MOONWELL_LUALS` pointing to the Lua extension's `server/bin/lua-language-server.exe`).
- Lua 5.3.6 `luac` (or `MOONWELL_LUAC` pointing to it).

No tool is installed globally by the tests. Environment overrides are paths to executables, except MOONWELL_REPO.
Integration creates a fresh ignored `.test-work/integration-*/consumer`; reports and a latest-run pointer are retained
there. It uses the real CLI, Pkl schema, generated editor files and bundler. All tests run from this repository root.

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
deno task check
deno task lint
deno fmt --check
deno task test
deno task check:lua
deno task test:integration
```

Tests use real wrappers and stand-ins for unavailable Warcraft natives, checking arguments, return values and callback
lifecycle. Integration checks both Lua and compiled Yue with LuaLS, requires intentional negative diagnostics at exact
locations, builds normal/minified maps, excludes unused modules and executes a real bundle with native stand-ins.

The line-local LuaLS suppressions on native calls that pass a null boolexpr filter document a mismatch in Moonwell's
generated JASS signatures; each carries the same comment. Do not suppress diagnostics broadly. fromHandle is
conservatively nullable in LuaLS 3.19.1; narrow it or assert it. Factories validate and return a non-null wrapper.

## In-game release gate (maintainer)

Use Warcraft III Reforged 3.0.0.24268 and World Editor 3.00, recording actual versions if different.

1. Create a disposable Moonwell map and configure this checkout with the local path example in README. Copy
   `examples/gate.yue` to its `src/main.yue`; run check and test. The gate starts just after the map loads (times below
   count from there). Play each run until `Wrapper weak cache probe` prints (about 50 seconds); the presentation run
   (step 7) never prints it and ends at about 20 seconds with `Wrapper presentation cleanup passed`. Then read the whole
   message log (F12); opening it pauses a single-player game.
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
   never runs (no `ERROR condition probe action ran`). Restore `probes = false`.
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
8. Build with `--minify` and play the packed map; repeat steps 2–5 and 7. Open the packed map in World Editor.
9. Two-player run: deferred. Reforged's latest patch removed LAN, and online multiplayer and desync checks are the last
   step before Moonwell 1.0 (Moonwell's backlog). Then: host an online game of the minified map for two players and play
   past the weak cache probe (about a minute). Neither machine may desync. Each machine prints its own probe line, from
   its own Lua collector; record both. The same online check covers v0.3.0's local visibility: setVisibleFor, playFor
   and the player options of TextTag.float and Sound.playOnce show or play only for that player, with no desync. It also
   covers `playFor` followed by `destroy()` (the other machines never started that sound) and whether `getDuration()`
   agrees across machines.
10. Record results here and in CHANGELOG, including Warcraft/editor versions. Automated native doubles cannot replace
    this gate. Do not declare the release ready while this is pending. The spec's fallback (strong widget caches plus
    `forget()`) applies only if a run with `collected=true` prints `stale=false` or `identity=false`, or if a desync
    occurs. Then stop and apply it.

v0.1.0: Passed 2026-09-28, confirmed by the maintainer on Warcraft III Reforged 3.0.0.24268 and World Editor 3.00 (file
version 3.0.0.24268). Normal gameplay/cleanup, callback-error recovery, minified packed-map gameplay and World Editor
opening all passed. The probe screenshot confirms both intentional errors followed by ticks, death and cleanup in F12.
The disposable gate used three-second ticks, death at nine seconds and cleanup at fifteen seconds, with camera and
selection adjustments for visibility. Library code was commit `3b923d5` throughout.

v0.2.0: Passed 2026-09-29, confirmed by the maintainer's message-log screenshots on Warcraft III Reforged 3.0.0.24268
and World Editor 3.00 (file version 3.0.0.24268). Steps 2, 3, 5 (`collected=true stale=true identity=true`), 6 and 7
(the minified run, now step 8) passed with library `5417ce6`. Gate copies added one camera line. Step 4: the first
`-gate` printed `Wrapper chat once` and `Wrapper chat accepted` on `830cf31` (same library code); the second `-gate` was
not observed. Step 8 (the two-player run, now step 9) is deferred.

v0.3.0: Passed 2026-09-29, confirmed by the maintainer's message-log screenshots and observations on Warcraft III
Reforged 3.0.0.24268 and World Editor 3.00, library code `dae9982` (unchanged since), run from a disposable map with one
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
`moonwell.lock` recorded commit `7baa81eb46d0e4dec6e18a976e55fb90d3858cfd`, the fetched files matched the tag's `src/`,
and the lock stayed unchanged after removing the map's `.moonwell/` and checking again.

v0.3.0: Passed 2026-09-29 for `v0.3.0` with Moonwell 0.5.0: check, normal and minified builds of the gate example;
`moonwell.lock` recorded commit `1277875b936fdb60a0b4c64283d5244b73d6c858`, the fetched files matched the tag's `src/`,
and the lock stayed unchanged after removing the map's `.moonwell/` and checking again.

v0.3.1: Passed 2026-09-29 for `v0.3.1` with Moonwell at `92f8f40` (0.5.0 plus `UnitAlive` in its natives list): check,
normal and minified builds of the gate example; `moonwell.lock` recorded commit
`94d650febc2564bcd62d45f2a4f60613ad347e00`, the fetched files matched the tag's `src/` (plus Moonwell's
`.moonwell-library.json`), and the lock stayed unchanged after removing the map's `.moonwell/` and checking again.
