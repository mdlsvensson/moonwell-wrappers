# Changelog

## Unreleased (0.2.0)

- New wrappers: Item, Destructable, Rect, Region and Force.
- Unit: hero, ability, inventory, mana, movement, presentation and by-id order methods, `isAlive()` and `damageTarget`.
  `issueTargetOrder` accepts any widget (Unit, Item, Destructable).
- Player: gold and lumber, alliances, tech, slot state, start location and `isLocal()`.
- Trigger: any-player unit, player, chat, region, death, range, unit-state and game events; predicate conditions;
  `addAction` returns a token; `removeAction`, `removeCondition`, `clearActions`, `clearConditions`, `evaluate`,
  `execute`.
- Group: `enumInRect`, `enumOfPlayer`, `enumSelected`, an optional Lua filter on every enumeration, `forEach`, `first`.
- **Changed:** Unit, Item and Destructable wrappers use a weak cache. A wrapper nothing references may be collected, and
  a later `fromHandle` returns a fresh one; identity is unchanged while any reference exists.
- Trigger and Effect no longer import Unit or Player: wrapper arguments convert through the loaded classes.

### Release gate

Automated checks passed 2026-09-28 on Windows: 66 behavior tests in 13 suites with YueScript 0.34.2; Lua 5.3.6 syntax
checks (30 files); Moonwell normal/minified builds, unused-module exclusion, a Trigger-only bundle and bundled
execution; LuaLS 3.19.1 positive Lua/Yue fixtures and eight expected negative diagnostics; the gate example builds with
clean editor diagnostics.

Pending: the in-game gate (including the weak cache probe and a two-player LAN run) and tag consumption.

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
