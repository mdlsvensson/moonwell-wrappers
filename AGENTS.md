# Moonwell Wrappers: agent handoff

This is a separate optional Moonwell library, written in annotated Lua 5.3. Runtime modules live only in
`src/wrappers/`. Maps consume this repository with `dir = "src"`, through a local path or an immutable GitHub tag. The
remote is `mdlsvensson/moonwell-wrappers`; `v0.1.0` is tagged on commit `c1209f5` and `v0.2.0` on the commit that
records its gate. Tags must never be moved.

The approved design and implementation history live in the sibling Moonwell repository:

- `../moonwell/docs/superpowers/specs/2026-09-28-moonwell-wrappers-design.md`
- `../moonwell/docs/superpowers/plans/2026-09-28-moonwell-wrappers.md`
- `../moonwell/docs/superpowers/specs/2026-09-28-moonwell-wrappers-broad-design.md` and
  `../moonwell/docs/superpowers/plans/2026-09-28-moonwell-wrappers-broad.md` (v0.2.0)
- `../moonwell/docs/superpowers/specs/2026-09-29-moonwell-wrappers-presentation-design.md` and
  `../moonwell/docs/superpowers/plans/2026-09-29-moonwell-wrappers-presentation.md` (v0.3.0)

README documents the complete public API. CONTRIBUTING documents tool versions, checks and the manual release gate.
v0.2.0 adds broad gameplay coverage; v0.3.0 adds presentation (text tags, sounds, lightning, images, ubersplats, fog
modifiers), deeper effects and item/destructable enumeration. Classic UI and frames remain in Moonwell's backlog. Do not
add gameplay systems, implicit cleanup or a w3ts compatibility layer without a new design.

## Rules

- No Node.js, npm packages, `node:` or `npm:` specifiers. Deno tooling uses built-ins and `jsr:@std/*` only.
- Test-first changes; review each task and the final change. Commit on main; the maintainer pushes.
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
  pass a machine-local boolean to the same native on every machine. No getters for machine-local values.
- Options tables go through `internal/options.lua`: unknown keys and wrong types fail before any native.

## Verification

Run every command in CONTRIBUTING before committing. `deno task test` covers Warcraft boundary behavior with native
doubles; `check:lua` uses actual Lua 5.3.6 syntax; `test:integration` uses a fresh real Moonwell consumer and LuaLS.
Test outputs remain in ignored `.test-work/`; downloaded verification tools remain in ignored `.tools/`.

v0.1.0: the maintainer passed the in-game gate on 2026-09-28: normal gameplay/cleanup, intentional callback-error
recovery, minified gameplay and World Editor opening (Warcraft 3.0.0.24268, World Editor 3.00). First GitHub-tag
consumption passed the same day: a fresh map locked `v0.1.0` to `c1209f5`. The runnable gate is `examples/gate.yue`.
v0.2.0: the in-game gate passed on 2026-09-29, including the weak cache probe
(`collected=true stale=true identity=true`); the two-player desync run is deferred to Moonwell's pre-1.0 online checks
(LAN was removed from the game). Tag consumption passed the same day: a fresh map locked `v0.2.0` to `7baa81e`. Later
releases repeat the automated checks, the in-game gate and the tag consumption gate in CONTRIBUTING.
