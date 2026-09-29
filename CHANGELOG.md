# Changelog

## Unreleased

- New classic UI wrappers: Dialog, Multiboard, Leaderboard, Quest, DefeatCondition and TimerDialog, all owned by the map
  and destroyed explicitly.
- Dialog buttons take a callback that receives the clicking Player; the dialog owns one internal trigger. Buttons and
  quest items belong to their dialog or quest, which dispose them on `clear()`/`destroy()`.
- Multiboard rows and columns count from 1; cell methods (`setCell`, `setRow`, `setColumn`, `setAll`) obtain and release
  the native cell handles themselves. `setRowCount` changes the count one row at a time.
- Leaderboard items are keyed by player and resize the board.
- `setVisibleFor(Player)` on Multiboard and TimerDialog. No getters for display or minimized state.
- A TimerDialog raises once its Timer is destroyed, except for `destroy()`.

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
Warcraft III Reforged 3.0.0.24268 and World Editor 3.00, library code `dae9982`:

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
3.0.0.24268 and World Editor 3.00 (file version 3.0.0.24268), library commit `5417ce6`:

- **Normal and minified runs:** startup messages (hero level 4, ability level 2 with a 30-second cooldown, item charges
  3, filtered heroes 1), region entry, item pickup, unit and tree death events, both cleanups, the tree restore, and
  `Wrapper broad cleanup passed` at 30 seconds.
- **Weak cache probe:** `collected=true stale=true identity=true` and `Wrapper weak cache probe passed` (normal run).
- **Probe run:** all three intentional errors printed (timer, trigger, condition), then recovery.
- **World Editor:** opened the packed minified map.
- **Chat:** the first `-gate` printed `Wrapper chat once` and `Wrapper chat accepted`, so the self-removing action and
  condition both ran in game. That was the first run, on `830cf31`, which has the same library code. The second `-gate`
  was not observed.
- **Gate fix during the run:** it printed its startup messages while the map loaded, where they never reach the log;
  `5417ce6` starts it just after loading.

Deferred, not passed: the two-player no-desync run. Reforged's latest patch removed LAN, and online multiplayer and
desync checks wait until the last step before Moonwell 1.0 (Moonwell's backlog).

GitHub-tag consumption **passed 2026-09-29** with Moonwell 0.5.0: a fresh map configured with the README GitHub settings
ran check, build and `build --minify` with the gate example; `moonwell.lock` recorded tag `v0.2.0` at commit
`7baa81eb46d0e4dec6e18a976e55fb90d3858cfd`, and the fetched files matched the tag's `src/`. After removing only that
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
