# Moonwell Wrappers

An optional annotated Lua 5.3 library for Warcraft III maps built with Moonwell 0.5.0 or later. It provides Player,
Unit, Timer, Trigger, Group and Effect wrappers, editor completion, stable handle identity and explicit cleanup.

**Status:** implemented locally, unreleased. The in-game gate passed; first GitHub-tag consumption remains pending.
Broader handle coverage and w3ts API compatibility are outside this first release.

## Use a local checkout

Keep `moonwell-wrappers` next to your map project. In the map's `moonwell.local.pkl`:

```pkl
amends "moonwell.pkl"

libraries {
  ["wrappers"] {
    path = "../moonwell-wrappers"
    dir = "src"
  }
}
```

Run `deno task check` in the map to sync the library and refresh the editor view. Restart `dev` after adding a local
library. There are no additional runtime dependencies or install scripts.

After the repository and `v0.1.0` tag are published, use this in the map's committed `moonwell.pkl`:

```pkl
libraries {
  ["wrappers"] {
    github = "mdlsvensson/moonwell-wrappers"
    tag = "v0.1.0"
    dir = "src"
  }
}
```

Commit the resulting `moonwell.lock`. A local `path` override preserves that entry. The configuration key is a cache
label; imports follow paths inside `src/`. For example, `src/wrappers/unit.lua` is `wrappers.unit`.

## YueScript

```yue
import "moonwell" as mw
import "moonwell.macros" as {:$FourCC}
import "wrappers.player" as Player
import "wrappers.unit" as Unit
import "wrappers.timer" as Timer

mw.on_main ->
  footman = Unit.create Player.fromIndex(0), $FourCC("hfoo"), 0, 0, 270
  footman\setLife 250
  lifetime = Timer.create!
  lifetime\start 5, false, (self) ->
    footman\remove!
    self\destroy!
```

## Lua

```lua
local mw = require('moonwell')
local PlayerWrapper = require('wrappers.player')
local Unit = require('wrappers.unit')

mw.on_main(function()
    local footman = Unit.create(PlayerWrapper.fromIndex(0), FourCC('hfoo'), 0, 0, 270)
    footman:setPosition(100, 200)
    footman:remove()
end)
```

Factories use dot calls; instance methods use `:` in Lua and `\` in YueScript. Each module exports its class table;
there is no umbrella import and no new global. Only required modules and their dependencies enter a map's bundle.
Mutating methods return no value unless the reference below says otherwise. Getters always query current native state.

## Handles and cleanup

Each class has:

- `fromHandle(raw)`: return the cached wrapper, or nil when passed nil. Never creates a game object.
- `getHandle()`: return a live native handle, or error after disposal.
- `isDisposed()`: return whether wrapper cleanup has occurred.
- `.handle`: native handle while live; nil after disposal. Treat this field as read-only.

Factories return non-null wrappers or raise an error if the native returns nil. Rewrapping the same live handle returns
the same Lua table. Caches retain wrappers until cleanup; even wrappers produced by group snapshots need their native
lifetime managed. Player wrappers stay cached for the game session.

Use `unit:remove()` and `timer/trigger/group/effect:destroy()`. Repeated cleanup is harmless; other methods reject
disposed receivers and disposed wrapper arguments. `unit:kill()` leaves its wrapper valid because death is not removal.
Groups do not own their units, and effects do not own their targets. Garbage collection never destroys game objects.

Raw natives remain available through `getHandle()`, for example `SetUnitInvulnerable(unit:getHandle(), true)`. Destroy
wrapped resources through their wrappers: direct native destruction bypasses tracking. Never wrap a destroyed raw
handle. There is no generic native liveness or handle-type check. Do not modify wrapper metatables or fields.

## Editor types

Use Moonwell's normal YueScript + Lua extension setup and run the map's `deno task check`. Moonwell supplies native
types and the library view. Wrapper classes are named `MoonwellWrappers.Unit`, etc., separate from native `unit`. These
are editor diagnostics, not a new Moonwell compile-time type checker.

LuaLS 3.19.1 conservatively treats `fromHandle` results as nullable, including for a known non-null input. Narrow the
result with an `if`, or use `assert` when the handle is known to exist:

```lua
local triggered = Unit.fromHandle(GetTriggerUnit())
if triggered then triggered:setLife(100) end
local known = assert(Unit.fromHandle(existingUnit:getHandle()))
```

Factories and `getOwner()` already return non-null wrappers. Callback parameters are typed; implicit YueScript return
values are allowed and ignored.

## API reference

All wrapper parameters below require wrappers, not raw handles. Warcraft enums and integer rawcodes pass through. Player
indices are zero-based; durations are seconds; facing uses native degrees. Native pathing and synchronization rules
apply. Calls made only for a local player do not become synchronized by using wrappers.

| Module             | Factories and methods beyond the common handle methods                                                                                                                                                                                                                                                                                                                               |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `wrappers.player`  | `fromIndex(index)`; `getId()`, `getName()`, `getColor()`, `getState(playerstate)`, `setState(playerstate, integer)`                                                                                                                                                                                                                                                                  |
| `wrappers.unit`    | `create(Player, typeId, x, y, facing)`; `getTypeId()`, `getOwner()`, `setOwner(Player, changeColor)`; `getX()`, `getY()`, `setPosition(x,y)`; `getFacing()`, `setFacing(degrees)`; `getLife()`, `setLife(value)`, `getMaxLife()`; `setColor(playercolor)`, `kill()`, `remove()`; `issueOrder(string)`, `issuePointOrder(string,x,y)`, `issueTargetOrder(string,Unit)` return boolean |
| `wrappers.timer`   | `create()`; `start(timeout, periodic, callback)`, `pause()`, `resume()`, `getElapsed()`, `getRemaining()`, `getTimeout()`, `destroy()`                                                                                                                                                                                                                                               |
| `wrappers.trigger` | `create()`; `enable()`, `disable()`, `isEnabled()`; `registerUnitEvent(Unit,unitevent)`, `registerPlayerUnitEvent(Player,playerunitevent)`, `registerTimerEvent(timeout,periodic)`, `addAction(callback)`, `destroy()`                                                                                                                                                               |
| `wrappers.group`   | `create()`; `add(Unit)`, `remove(Unit)`, `contains(Unit)`, `clear()`; `enumInRange(x,y,radius)`, `getSize()`, `getUnits()`, `destroy()`                                                                                                                                                                                                                                              |
| `wrappers.effect`  | `create(model,x,y)`, `attach(model,Unit,attachmentPoint)`; `setPosition(x,y,z)`, `setScale(scale)`, `destroy()`                                                                                                                                                                                                                                                                      |

Player indices must be integers below `bj_MAX_PLAYER_SLOTS`, including neutral slots. Players have no destruction
method. `setPosition` uses SetUnitPosition, including its pathing behavior. Unit target orders currently accept units
only; use raw natives for item/destructable targets. SetPlayerName is deliberately outside the initial API.

`enumInRange` clears the group before enumerating without a native filter. Negative, infinite and NaN radii fail before
clearing. `getUnits()` returns a dense one-based array, skips nil native entries and preserves native order without
promising sorting. Later group changes do not alter the array. Removing a unit still disposes its wrapper in any
snapshots. Filter snapshots using ordinary Lua/Yue loops.

## Callbacks

Timer callbacks receive their Timer; trigger actions receive their Trigger. Read event context using ordinary natives,
then convert handles with `fromHandle` as needed. Trigger registrations have no native filter argument in this release;
filter inside your action. Individual action/registration removal and trigger conditions are deferred.

`start` replaces the timer's old schedule. Timeouts must be finite and nonnegative. One-shot timers remain allocated
after firing: restart them or explicitly destroy them. A callback can restart or destroy its own timer. Stale callbacks
from replaced schedules or destroyed wrappers do nothing.

Callbacks must be synchronous: do not yield or call TriggerSleepAction. Use timers for delayed work. A callback error is
caught and printed with `[wrappers] Timer/Trigger callback failed:`; periodic ticks and future actions continue. Errors
do not automatically destroy resources. During the 2026-09-28 gate on Warcraft 3.0.0.24268, F12 retained these errors
and the subsequent tick and cleanup messages.

See [CONTRIBUTING.md](CONTRIBUTING.md) for checks and the in-game release gate.
