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

The two line-local LuaLS suppressions for null boolexpr filters document a mismatch in Moonwell's generated JASS
signatures. Do not suppress diagnostics broadly. fromHandle is conservatively nullable in LuaLS 3.19.1; narrow it or
assert it. Factories validate and return a non-null wrapper.

## In-game release gate (maintainer)

Use Warcraft III Reforged 3.0.0.24268 and World Editor 3.00, recording actual versions if different.

1. Create a disposable Moonwell map and configure this checkout with the local path example in README. Copy
   `examples/gate.yue` to its `src/main.yue`; run check and test.
2. Confirm the unit appears, moves, changes life and color (disable ally color mode with Alt+A if needed), and the
   attached effect appears. The group contains the unit; identity and group assertions must not report errors.
3. Confirm timer and trigger tick messages. The death event prints at timer tick 3. At tick 5, owned resources are
   removed/destroyed; the timer destroys itself, no later ticks print, and double cleanup reports success.
4. Set `probes = true` and run again. Both intentional errors print, and both callbacks continue on later ticks,
   reaching cleanup. Restore `probes = false` afterwards. Print output is not retained in the F12 log.
5. Build with `--minify` and play the packed map; repeat the observations. Open the packed map in World Editor.
6. Record results here and in CHANGELOG, including Warcraft/editor versions. Automated native doubles cannot replace
   this gate. Do not declare the release ready while this is pending.

## First publication and tag gate (maintainer)

After all automated checks and the in-game gate pass, create/push `mdlsvensson/moonwell-wrappers`, then publish an
immutable `v0.1.0` tag on the verified commit. This library is not a JSR or Pkl package. Change the Unreleased changelog
heading to the released version/date and record the gate evidence before tagging.

In a fresh Moonwell map, use the README GitHub configuration, run check/build, and inspect/commit moonwell.lock. Confirm
it records the tagged commit. Remove only that disposable map's `.moonwell/` cache and repeat check; the lock must stay
unchanged. Record the result and only then mark first-tag consumption verified. Do not retag a moved release.
