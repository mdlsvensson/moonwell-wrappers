# Changelog

## Unreleased

- Annotated Lua wrappers for Player, Unit, Timer, Trigger, Group and Effect, consumed through Moonwell 0.5.0 libraries.
- Stable handle identity, explicit idempotent cleanup and disposed-object checks.
- Protected timer/trigger callbacks, stale-schedule suppression and dense group snapshots.
- Lua and Yue examples, native-boundary behavior tests, Lua 5.3 syntax checks and Moonwell/LuaLS integration tests.

### Release gate

The in-game gate **passed 2026-09-28**, confirmed by the maintainer on Warcraft III Reforged 3.0.0.24268 and World
Editor 3.00 (file version 3.0.0.24268): normal gameplay and cleanup, intentional timer/trigger errors followed by
continued ticks and cleanup, minified packed-map gameplay, and opening the packed map in World Editor. The probe
screenshot shows both intentional errors, later ticks, the death event and successful cleanup retained in F12.

First GitHub-tag consumption is **pending**. No v0.1.0 release has been published by this work.

Automated checks passed 2026-09-28 on Windows: 23 behavior tests with YueScript 0.34.2; Lua 5.3.6 syntax checks;
Moonwell 0.5.0 normal/minified builds and bundled execution; LuaLS 3.19.1 positive Lua/Yue fixtures and four expected
negative diagnostics. The all-six-wrapper gate example builds and has clean editor diagnostics. Integration passed with
explicit absolute/relative compiler paths and with Yue available only on PATH.
