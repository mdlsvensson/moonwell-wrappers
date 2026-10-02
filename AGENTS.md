# Moonwell Wrappers: agent handoff

This is a separate optional Moonwell library, written in annotated Lua 5.3. Runtime modules live only in
`src/wrappers/`. Maps consume this repository through a local path or an immutable GitHub tag; `moonwell-library.json`
at the root names `src` as the module folder (since `v0.8.1`; a map on an older tag, or on Moonwell 0.5, writes
`dir = "src"`). The remote is `mdlsvensson/moonwell-wrappers`; `v0.1.0` is tagged on commit `c1209f5`; `v0.2.0`,
`v0.3.0`, `v0.3.1`, `v0.4.0`, `v0.5.0`, `v0.5.1`, `v0.6.0`, `v0.7.0`, `v0.8.0`, `v0.8.1`, `v0.9.0` and `v0.9.1` on the
commits that record their gates. Tags must never be moved.

The approved design and implementation history live in the sibling Moonwell repository:

- `../moonwell/docs/superpowers/specs/2026-09-28-moonwell-wrappers-design.md`
- `../moonwell/docs/superpowers/plans/2026-09-28-moonwell-wrappers.md`
- `../moonwell/docs/superpowers/specs/2026-09-28-moonwell-wrappers-broad-design.md` and
  `../moonwell/docs/superpowers/plans/2026-09-28-moonwell-wrappers-broad.md` (v0.2.0)
- `../moonwell/docs/superpowers/specs/2026-09-29-moonwell-wrappers-presentation-design.md` and
  `../moonwell/docs/superpowers/plans/2026-09-29-moonwell-wrappers-presentation.md` (v0.3.0)
- `../moonwell/docs/superpowers/specs/2026-09-29-moonwell-wrappers-classic-ui-design.md` and
  `../moonwell/docs/superpowers/plans/2026-09-29-moonwell-wrappers-classic-ui.md` (v0.4.0)
- `../moonwell/docs/superpowers/specs/2026-09-29-moonwell-wrappers-frames-design.md` and
  `../moonwell/docs/superpowers/plans/2026-09-29-moonwell-wrappers-frames.md` (v0.5.0)

README documents the complete public API. CONTRIBUTING documents tool versions, checks and the manual release gate.
v0.2.0 adds broad gameplay coverage; v0.3.0 adds presentation (text tags, sounds, lightning, images, ubersplats, fog
modifiers), deeper effects and item/destructable enumeration; v0.4.0 adds classic UI (dialogs, multiboards,
leaderboards, quests, defeat conditions, timer dialogs). v0.5.0 adds frames. v0.7.0 adds damage events and sync, for the
wc3-lib port, on a shared internal listener list (`internal/listeners.lua`). v0.8.0 adds input listeners, weather
effects, art from ability data, four Trigger registrations and `fromEvent()`. v0.9.0 adds the opt-in disposal of
removed units' wrappers. Do not add gameplay systems, further implicit cleanup or a w3ts compatibility layer without a
new design.

## Rules

- No Node.js and no Deno. The tools are Lua under `tools/`, run with `yue -e`, on `tools/lib.lua` (the same file as
  moonwell-systems', plus the `MOONWELL_PKL` override); they must pass the Lua 5.3.6 syntax check like the library.
- Test-first changes; review each task and the final change. Commit on main; push once the checks pass.
- Every public API carries LuaLS annotations. LuaLS 3.19.1 returns a conservative nullable type for fromHandle; use a
  check/assert, not a non-null cast that hides the real runtime contract.
- Cache identity by raw native handle. Unit, Item and Destructable caches are weak-valued; all others are strong.
  Cleanup invalidates wrappers/callbacks before native destruction and is idempotent. Never destroy game objects through
  garbage collection, and never iterate a table keyed by tables when the loop calls natives.
- Warcraft lacks normal filesystem/package/debug Lua libraries. Modules must use literal requires and perform no
  game-object creation when imported. Native calls run only when a user invokes a method.
- Line-local nil-filter diagnostic exceptions, each with the standard comment, compensate for generated JASS type
  limitations. Do not add broad diagnostic suppression.
- A module imports another public module only to return its wrappers. Convert wrapper arguments with `Handle.unwrap` or
  `Handle.unwrapWidget`.
- Presentation wrappers exist only for objects the map owns and destroys. Anything the game can end on its own (text
  tags with a lifespan, sounds released when done) goes through a helper that returns nothing. Local visibility helpers
  pass a machine-local boolean to the same native on every machine; the one exception is `sound:playFor`, which calls
  `StartSound` only on that player's machine (spec §4). No getters for machine-local values.
- Every wrapper error points at the line that called the public function. Raise at level 3 from registry, Handle and
  checker helpers (4 in `Options.read`), pass `depth` when a local helper sits in between, and never tail-call a raising
  helper from a public function: write `return (helper(...))`, since a tail call drops the position. `tests/blame.lua`
  sweeps every class; use `failsAt` in new tests of error paths.
- Options tables go through `internal/options.lua`: unknown keys and wrong types fail before any native.
- Children that die with their parent (dialog buttons, quest items) are wrappers owned by the parent: its `clear()` or
  `destroy()` disposes them, and they have no `destroy()` or `fromHandle`. Native handles that must be released
  (multiboard items) never become wrappers: get and release them in the same call.
- Frames: one registry for every frame; a private kind per wrapper (owned, template part, borrowed). Only owned frames
  are destroyed, and their destroy disposes the owned subtree and its parts. Never let a borrowed frame end up under an
  owned one.

## Verification

Run every command in CONTRIBUTING before committing. `yue -e tools/test.lua` covers Warcraft boundary behavior with
native doubles, one process per suite; `tools/check.lua` uses actual Lua 5.3.6 syntax; `tools/integration.lua` uses
a fresh real Moonwell consumer and LuaLS, and
checks `src/wrappers` against Moonwell's native declarations with planted mistakes in `tests/natives-negative.lua` (no
manual LuaLS run is needed). LuaLS paths must not contain `--`: 3.19.1 mangles them, so keep its work in `.test-work/`.
Test outputs remain in ignored `.test-work/`; downloaded verification tools remain in ignored `.tools/`.

v0.1.0: the maintainer passed the in-game gate on 2026-09-28: normal gameplay/cleanup, intentional callback-error
recovery, minified gameplay and World Editor opening (Warcraft 3.0.0.24268, World Editor 3.00). First GitHub-tag
consumption passed the same day: a fresh map locked `v0.1.0` to `c1209f5`. The runnable gate is `examples/gate.yue`.
v0.2.0: the in-game gate passed on 2026-09-29, including the weak cache probe
(`collected=true stale=true identity=true`); the two-player desync run is deferred to Moonwell's pre-1.0 online checks
(LAN was removed from the game). Tag consumption passed the same day: a fresh map locked `v0.2.0` to `7baa81e`. v0.3.0:
the in-game gate passed on 2026-09-29, normal and minified (CONTRIBUTING records it). It found game behaviour now in the
README: Chain Lightning fades by itself, `lightning:setColor` shows no visible change, and effects attached to items and
destructables are not drawn. The disposable gate map lived in `../wrappers-gate` (`yue -e gate.lua <run>`, one command
per run, generated from `examples/gate.yue`); recreate it the same way for later releases. Tag consumption passed the
same day: a fresh map locked `v0.3.0` to `1277875`. v0.3.1 (2026-09-29): documentation from the w3ts and WCSharp
comparisons and an in-game probe (Moonwell's `docs/superpowers/research/`), `Image.create`'s wrong-path error, and
flipped-boolean setter checks; the in-game gate was not re-run by the maintainer's decision (CONTRIBUTING). Tag
consumption passed the same day: a fresh map locked `v0.3.1` to `94d650f`. The probe map is
`../wrappers-gate/src/probe.yue` (`yue -e gate.lua probe`). The README's "Reported native caveats" are other libraries'
claims: move one into the measured notes only after a gate or probe confirms it. Later releases repeat the automated
checks, the in-game gate and the tag consumption gate in CONTRIBUTING. v0.4.0: the gate map has a `ui-init` probe
(`../wrappers-gate/src/probe_ui.yue`, `yue -e gate.lua ui-init`, results in `PROBE-UI-RESULTS.md`) and the runs `ui` and
`ui-min`; the probe and the classic UI gate passed on 2026-09-29, normal and minified (CONTRIBUTING records it). Tag
consumption passed the same day: a fresh map locked `v0.4.0` to `7e8ef13`. v0.5.0: the gate map has a `frame-init` probe
(`../wrappers-gate/src/probe_frame.yue`, `yue -e gate.lua frame-init`) and the runs `frames` and `frames-min`; the frames
gate loads `war3mapImported\wrappers-gate.toc` from the gate map's assets (the probe found the game's templates need no
TOC; results in `PROBE-FRAME-RESULTS.md`). The probe and the frames gate passed on 2026-09-29, normal and minified
(CONTRIBUTING records it). Tag consumption passed the same day: a fresh map locked `v0.5.0` to `b91ffd4`. v0.5.1
(2026-09-30): `Effect.attach` and `Effect.flashOn` take a Unit in the editor; runtime unchanged, so the in-game gate was
not re-run. Tag consumption passed the same day with Moonwell 0.5.1: a fresh map locked `v0.5.1` to `af9961e`. v0.6.0
(2026-09-30): the refactor after the review (Moonwell's `docs/superpowers/research/2026-09-30-wrappers-review.md`, spec
and plan `2026-09-30-moonwell-wrappers-refactor`).

- Errors point at the caller; `tests/blame.lua` sweeps every class.
- A one-lookup `require`, and one-table enumeration.
- `isAlive` through `UnitAlive`, and `exists()`. A removed unit reads `false` only from the next frame.
- Sorted options errors, and the per-module README API reference.

The in-game gate passed for `core`, `probes`, `presentation`, `ui` and `perf`. Frames and the minified runs were not
re-run. The performance probe is `../wrappers-gate/src/probe_perf.yue` (`yue -e gate.lua perf`). Tag consumption passed
the same day: a fresh map locked `v0.6.0` to `933b580`.

v0.7.0 (2026-09-30): the port prerequisites (Moonwell spec and plan `2026-09-30-moonwell-wrappers-port-prerequisites`).
`wrappers.damage` and `wrappers.sync` share `internal/listeners.lua`: one trigger per key, disabled while empty and
never destroyed. Damage events are live only while their listeners run (a weak set), and DAMAGED events have no type
setters. `Sync.send` checks 255 bytes. The gate map's `port` run (`yue -e gate.lua port`, CONTRIBUTING step 13) passed;
it found that `isAttack` is false for `damageTarget` and that `setPathing(false)` does not make orders cross trees. Tag
consumption passed the same day: a fresh map locked `v0.7.0` to `e9c2880`.

v0.8.0 (2026-10-01): the additions the port did not need (Moonwell spec and plan
`2026-10-01-moonwell-wrappers-additions`; probes `../wrappers-gate/PROBE-EXTRAS-RESULTS.md`).

- `wrappers.input` is the third user of `internal/listeners.lua`. Its listener keys are strings: `k<id>:<code>`, from
  the player id and the key code, for a key (one trigger, registered for all 16 modifier values, down and up, because
  the game matches modifiers exactly), and `d`, `u`, `m` plus the player id for mouse down, up and move. The held state
  that tells a press from a repeat lives per key and changes only in the synced events and in `Input.off`.
- `wrappers.weathereffect`: an unknown id gives a handle with id -1, which `create` removes and raises for, like
  `Image.create`. Weather handles are used again by the game after removal.
- `Effect.abilityArt` reads `GetAbilityEffectById` (index from 1 in the wrapper, 0 in the native; `""` becomes nil). The
  four Effect constructors check that the model is a string: the release's one change to existing behavior.
- `fromEvent()` is `fromHandle` of one native per class. Other event responses stay `fromHandle(GetKillingUnit())`; a
  `wrappers.event` module was rejected because it would bundle every widget class.
- The gate map's `additions` run (`yue -e gate.lua additions`, CONTRIBUTING step 14) writes its lines to
  `CustomMapData\moonwell-wrappers-additions.pld`. `.test-work/dry_gate_additions.lua` runs the compiled gate on stub
  natives; run it before handing a gate run to the maintainer. The run passed on 2026-10-01: all 21 weather ids of the
  README were created, and a held key gave one down against 60 with repeats. Tag consumption passed the same day: a
  fresh map locked `v0.8.0` to `d823b1b`.

Tools in Lua (2026-10-02, Moonwell's Plan 5f, `../moonwell/docs/superpowers/plans/2026-10-02-moonwell-go-siblings.md`):
Moonwell 0.8.0 is a Go program, `moonwell`, and its Deno CLI is gone, so `tools/test.ts`, `run.ts`, `check-lua.ts` and
`integration.ts` became `tools/test.lua`, `lib.lua`, `check.lua` and `integration.lua`, and `deno.json` and `deno.lock`
went. No library code changed. The numbers are the same as with the Deno tools: 34 suites (218
tests), 27 expected negative diagnostics, 4 planted native mistakes.

- Integration runs `moonwell init --link` with the Moonwell checkout as its working directory: the Go program finds the
  checkout by walking up from there. `MOONWELL` must name an executable; `go run` cannot stand in, because it would run
  in the checkout instead of the consumer.
- The program and the checkout must agree in major and minor version, because the consumer links to the checkout's Pkl
  schema.
- `luac` now checks `tools/` too. The gate map's runner is `yue -e gate.lua <run>` in `../wrappers-gate`.

v0.8.1 (2026-10-02): `moonwell-library.json` with `{ "dir": "src" }` (Moonwell's backlog item, a short design in chat).
Moonwell 0.6.0 or later reads it from a tag's download and from a local `path`, so a map leaves `dir` out; a `dir` in
the map's manifest still wins. Integration's consumer names the library by `path` alone, so every run exercises the
file. `src/` is that of v0.8.0, and the in-game gate was not re-run.
Tag consumption passed the same day: a fresh map whose entry has no `dir` locked `v0.8.1` to `c8e434b`.

v0.9.0 (2026-10-02): automatic disposal of Unit wrappers by polling (Moonwell's backlog item; a short design in chat,
after the maintainer chose polling over the undefend order).

- `registry.sweep(gone)` in `internal/handle.lua` walks the cache and disposes what the predicate names; it calls no
  native itself. `Unit.sweep()` passes "type id reads 0". `Unit.autoDispose(interval?)` runs it on one raw game timer
  (not `wrappers.timer`, so Unit bundles nothing more) and returns the one stop function.
- The sweep walks a weak table, so its order differs between machines, and so does the set of wrappers it meets (each
  machine's collector drops unused ones at its own time). That is harmless only while nothing observes it: the sweep
  returns nothing and has no callback. A "unit was removed" listener would need an ordered list beside the cache.
- `registry.live(value, operation)` gives the handle, or nil for a disposed wrapper; `exists()` on the three widget
  classes uses it and no longer raises for a disposed wrapper.
- Items and destructables are not swept. The undefend order (exact timing, needs a custom ability in every map) is
  left as a possible second source.
- The gate map's `dispose` run (`yue -e gate.lua dispose`, CONTRIBUTING step 15) passed on 2026-10-02;
  `.test-work/dry_gate_dispose.lua` runs the compiled gate on stub natives. Measured: a sweep in the instant of a
  removal sees nothing; the default timer disposed a removed unit after 0.25 s; 0.45 microseconds per wrapper; the
  removed unit's handle id was not used again two seconds later.

Tag consumption for v0.9.0 passed the same day: a fresh map locked `v0.9.0` to `7347705`.

v0.9.1 (2026-10-02): the lost key release (Moonwell's backlog item; a probe, then a short design in chat).

- Measured (`../wrappers-gate/PROBE-RELEASE-RESULTS.md`): the game sends no release for a key let go while it takes no
  keyboard input (Alt+Tab, a click on another window, the chat box, the menu). `onKeyUp` cannot know; `onKeyDown` took
  the next press for a repeat.
- The rule in `input.lua`: `held[id]` is the game time of the key's last down, and a down later than `REPEAT_WINDOW`
  (2 seconds) after it is a new press. Game time is `TimerGetElapsed` of one raw timer on a run of 1,000,000 seconds,
  created with the first key listener (`keySource`) and never destroyed. It must be game time, not `os.clock`: every
  machine has to decide alike.
- What stays: a press within the window after a lost release is skipped. In single player, game time stands still in
  the menu and runs slower in the background (8.7 s counted as 3.2 s), so the window is longer there in real time.
- A local that is set before its readers can run is declared `---@type timer` without a value: LuaLS flags
  `timer?` passed to a native, and the wrappers use no `--[[@as]]` casts.
- `.test-work/dry_probe_release.lua` runs the compiled probe on stub natives. It caught an import named `Player`
  hiding the native `Player` before the maintainer ran the probe: name such an import `PlayerWrapper` in raw code.

Tag consumption for v0.9.1 passed the same day: a fresh map locked `v0.9.1` to `24b1511`.
