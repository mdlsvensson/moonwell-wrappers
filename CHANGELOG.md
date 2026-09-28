# Changelog

## Unreleased

- Annotated Lua wrappers for Player, Unit, Timer, Trigger, Group and Effect, consumed through Moonwell 0.5.0 libraries.
- Stable handle identity, explicit idempotent cleanup and disposed-object checks.
- Protected timer/trigger callbacks, stale-schedule suppression and dense group snapshots.
- Lua and Yue examples, native-boundary behavior tests, Lua 5.3 syntax checks and Moonwell/LuaLS integration tests.

### Release gate

In-game and first GitHub-tag consumption gates are **pending**. No v0.1.0 release has been published by this work.

Automated checks passed 2026-09-28 on Windows: 23 behavior tests with YueScript 0.34.2; Lua 5.3.6 syntax checks;
Moonwell 0.5.0 normal/minified builds and bundled execution; LuaLS 3.19.1 positive Lua/Yue fixtures and four expected
negative diagnostics. The all-six-wrapper gate example builds and has clean editor diagnostics. Integration passed with
explicit absolute/relative compiler paths and with Yue available only on PATH.
