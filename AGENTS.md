# Moonwell Wrappers: agent handoff

This is a separate optional Moonwell library, written in annotated Lua 5.3. Runtime modules live only in
`src/wrappers/`. Maps consume this repository with `dir = "src"`, through a local path or an immutable GitHub tag. The
intended remote is `mdlsvensson/moonwell-wrappers`; it has not been created/published by this implementation.

The approved design and implementation history live in the sibling Moonwell repository:

- `../moonwell/docs/superpowers/specs/2026-09-28-moonwell-wrappers-design.md`
- `../moonwell/docs/superpowers/plans/2026-09-28-moonwell-wrappers.md`

README documents the complete public API. CONTRIBUTING documents tool versions, checks and the manual release gate.
Broader wrapper coverage is deferred in Moonwell's backlog. Do not add gameplay systems, implicit cleanup or a w3ts
compatibility layer without a new design.

## Rules

- No Node.js, npm packages, `node:` or `npm:` specifiers. Deno tooling uses built-ins and `jsr:@std/*` only.
- Test-first changes; review each task and the final change. Commit on main; the maintainer pushes.
- Every public API carries LuaLS annotations. LuaLS 3.19.1 returns a conservative nullable type for fromHandle; use a
  check/assert, not a non-null cast that hides the real runtime contract.
- Cache identity by raw native handle. Cleanup invalidates wrappers/callbacks before native destruction and is
  idempotent. Never destroy game objects through garbage collection.
- Warcraft lacks normal filesystem/package/debug Lua libraries. Modules must use literal requires and perform no
  game-object creation when imported. Native calls run only when a user invokes a method.
- Existing two line-local nil-filter diagnostic exceptions compensate for generated JASS type limitations. Do not add
  broad diagnostic suppression.

## Verification

Run every command in CONTRIBUTING before committing. `deno task test` covers Warcraft boundary behavior with native
doubles; `check:lua` uses actual Lua 5.3.6 syntax; `test:integration` uses a fresh real Moonwell consumer and LuaLS.
Test outputs remain in ignored `.test-work/`; downloaded verification tools remain in ignored `.tools/`.

The maintainer passed the in-game gate on 2026-09-28: normal gameplay/cleanup, intentional callback-error recovery,
minified gameplay and World Editor opening (Warcraft 3.0.0.24268, World Editor 3.00). First GitHub-tag consumption
remains pending. The runnable gate is `examples/gate.yue`. Do not describe this library as released until those checks
pass and the maintainer publishes it.
