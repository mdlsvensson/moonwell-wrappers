# Moonwell Wrappers

Annotated Lua 5.3 library for Warcraft III. It provides Player, Unit, Item, Destructable, Rect, Region, Force, Timer,
Trigger, Group and Effect wrappers, editor completion, stable handle identity and explicit cleanup.

**Status:** `v0.1.0` released 2026-09-28. `v0.2.0` (broad coverage) is on main; its in-game gate is pending, so use
`v0.1.0` from GitHub until it is tagged. UI and presentation types (dialogs, multiboards, sounds, text tags) are not
wrapped yet.

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

To use the published `v0.1.0` tag from GitHub, put this in the map's committed `moonwell.pkl`:

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
the same Lua table while any reference to that wrapper exists.

Unit, Item and Destructable use a weak cache: the game removes these on its own (decay, used powerups, dead trees), so a
wrapper nothing references may be collected, and a later `fromHandle` returns a fresh wrapper. Keep a reference (a
variable, table key or closure) wherever identity matters. Timer, Trigger, Group, Effect, Rect, Region and Force stay
cached until you destroy them; Player wrappers stay cached for the game session.

Use `unit/item/destructable:remove()` and `timer/trigger/group/effect/rect/region/force:destroy()`. Repeated cleanup is
harmless; other methods reject disposed receivers and disposed wrapper arguments. `unit:kill()` leaves its wrapper valid
because death is not removal. Groups do not own their units, and effects do not own their targets. Garbage collection
never destroys game objects.

Raw natives remain available through `getHandle()`, for example `SetUnitInvulnerable(unit:getHandle(), true)`. Destroy
wrapped resources through their wrappers: direct native destruction bypasses tracking. Never wrap a destroyed raw
handle. There is no generic native liveness or handle-type check. Do not modify wrapper metatables or fields.

## Widgets

Unit, Item and Destructable are widgets (`MoonwellWrappers.Widget` in the editor). All three have `getLife()`,
`setLife(value)`, `getX()` and `getY()`. Parameters typed Widget accept any of them: `unit:issueTargetOrder`,
`unit:issueTargetOrderById`, `unit:damageTarget` and `trigger:registerDeathEvent`. There is no `Widget.fromHandle`:
convert a raw widget with the class you know it is, for example `Item.fromHandle(GetManipulatedItem())`.

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

Factories and `getOwner()` already return non-null wrappers. `getItemInSlot`, `removeItemFromSlot`, `addItemById` and
`group:first()` are also nullable, like `fromHandle`. LuaLS reports an unchecked use when the result is held in a local,
so narrow the local before calling methods on it:

```lua
local item = unit:getItemInSlot(0)
if item then item:setCharges(1) end
```

Callback parameters are typed; implicit YueScript return values are allowed and ignored.

## API reference

All wrapper parameters below require wrappers, not raw handles. Warcraft enums and integer rawcodes pass through. Player
indices are zero-based; durations are seconds; facing uses native degrees. Native pathing and synchronization rules
apply. Calls made only for a local player do not become synchronized by using wrappers.

| Module                  | Factories and methods beyond the common handle methods                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `wrappers.player`       | `fromIndex(index)`; `getId()`, `getName()`, `getColor()`, `getState(playerstate)`, `setState(playerstate, integer)`; `getGold()`, `setGold(n)`, `addGold(n)`, `getLumber()`, `setLumber(n)`, `addLumber(n)`; `getAlliance(Player, alliancetype)`, `setAlliance(Player, alliancetype, flag)`, `isAlly(Player)`, `isEnemy(Player)`; `getTechCount(techId, specificOnly)`, `setTechResearched(techId, level)`, `addTechResearched(techId, levels)`, `setTechMaxAllowed(techId, max)`, `setAbilityAvailable(abilityId, flag)`; `getController()`, `getSlotState()`, `getRace()`, `getTeam()`, `getStartX()`, `getStartY()`, `isLocal()`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `wrappers.unit`         | `create(Player, typeId, x, y, facing)`; `getTypeId()`, `getName()`, `getOwner()`, `setOwner(Player, changeColor)`; `getX()`, `getY()`, `setPosition(x,y)`, `setX(x)`, `setY(y)`, `getFacing()`, `setFacing(degrees)`; `getLife()`, `setLife(v)`, `getMaxLife()`, `setMaxLife(n)`, `getMana()`, `setMana(v)`, `getMaxMana()`, `setMaxMana(n)`, `getMoveSpeed()`, `setMoveSpeed(v)`; `setColor(playercolor)`, `setScale(s)`, `setVertexColor(r,g,b,a)`, `setAnimation(name)`, `pause(flag)`, `isPaused()`, `setInvulnerable(flag)`, `isInvulnerable()`, `show(flag)`, `isHidden()`; `isType(unittype)`, `isAlly(Player)`, `isEnemy(Player)`, `isAlive()`, `getCurrentOrder()`; `kill()`, `remove()`, `applyTimedLife(buffId, seconds)`, `damageTarget(Widget, amount, attack, ranged, attacktype, damagetype, weapontype)`; hero: `isHero()`, `getHeroName()`, `getLevel()`, `setLevel(level, showEffect)`, `getXP()`, `setXP(xp, showEffect)`, `addXP(xp, showEffect)`, `getStr/getAgi/getInt(includeBonuses)`, `setStr/setAgi/setInt(value, permanent)`, `getSkillPoints()`, `modifySkillPoints(delta)`, `selectSkill(abilityId)`, `revive(x, y, showEffect)`; abilities: `addAbility(id)`, `removeAbility(id)`, `getAbilityLevel(id)`, `setAbilityLevel(id, level)`, `makeAbilityPermanent(id, permanent)`, `hideAbility(id, hidden)`, `disableAbility(id, disabled, hideUI)`, `startCooldown(id, seconds)`, `endCooldown(id)`, `getCooldownRemaining(id)`; inventory: `getInventorySize()`, `getItemInSlot(slot)`, `addItem(Item)`, `addItemById(typeId)`, `removeItem(Item)`, `removeItemFromSlot(slot)`, `hasItem(Item)`, `dropItemAt(Item, x, y)`, `dropItemToSlot(Item, slot)`, `useItem(Item)`; orders (return boolean): `issueOrder(order)`, `issuePointOrder(order, x, y)`, `issueTargetOrder(order, Widget)`, `issueOrderById(id)`, `issuePointOrderById(id, x, y)`, `issueTargetOrderById(id, Widget)` |
| `wrappers.item`         | `create(typeId, x, y)`; `getTypeId()`, `getName()`, `getLevel()`, `setPosition(x, y)`, `getCharges()`, `setCharges(n)`, `getOwner()`, `setOwner(Player, changeColor)`, `isOwned()`, `isPowerup()`, `isVisible()`, `setVisible(flag)`, `isInvulnerable()`, `setInvulnerable(flag)`, `setDroppable(flag)`, `setPawnable(flag)`, `remove()`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `wrappers.destructable` | `create(typeId, x, y, facing, scale, variation)`; `getTypeId()`, `getName()`, `getMaxLife()`, `setMaxLife(v)`, `kill()`, `restore(life, birth)`, `isInvulnerable()`, `setInvulnerable(flag)`, `show(flag)`, `setAnimation(name)`, `queueAnimation(name)`, `remove()`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `wrappers.rect`         | `create(minX, minY, maxX, maxY)`, `worldBounds()`; `getMinX()`, `getMinY()`, `getMaxX()`, `getMaxY()`, `getCenterX()`, `getCenterY()`, `set(minX, minY, maxX, maxY)`, `moveTo(x, y)`, `destroy()`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `wrappers.region`       | `create()`; `addRect(Rect)`, `clearRect(Rect)`, `addCell(x, y)`, `clearCell(x, y)`, `containsPoint(x, y)`, `containsUnit(Unit)`, `destroy()`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `wrappers.force`        | `create()`; `add(Player)`, `remove(Player)`, `contains(Player)`, `clear()`, `enumPlayers()`, `enumAllies(Player)`, `enumEnemies(Player)`, `getPlayers()`, `destroy()`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `wrappers.timer`        | `create()`; `start(timeout, periodic, callback)`, `pause()`, `resume()`, `getElapsed()`, `getRemaining()`, `getTimeout()`, `destroy()`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `wrappers.trigger`      | `create()`; `enable()`, `disable()`, `isEnabled()`, `evaluate()` (returns boolean), `execute()`; `registerUnitEvent(Unit, unitevent)`, `registerPlayerUnitEvent(Player, playerunitevent)`, `registerAnyUnitEvent(playerunitevent)`, `registerPlayerEvent(Player, playerevent)`, `registerChatEvent(Player, text, exactMatch)`, `registerEnterRegion(Region)`, `registerLeaveRegion(Region)`, `registerDeathEvent(Widget)`, `registerUnitInRange(Unit, range)`, `registerUnitStateEvent(Unit, unitstate, limitop, value)`, `registerTimerEvent(timeout, periodic)`, `registerGameEvent(gameevent)`; `addAction(callback)` and `addCondition(predicate)` return tokens for `removeAction(token)` and `removeCondition(token)`; `clearActions()`, `clearConditions()`, `destroy()`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `wrappers.group`        | `create()`; `add(Unit)`, `remove(Unit)`, `contains(Unit)`, `clear()`; `enumInRange(x, y, radius, filter?)`, `enumInRect(Rect, filter?)`, `enumOfPlayer(Player, filter?)`, `enumSelected(Player, filter?)`; `getSize()`, `getUnits()`, `forEach(callback)`, `first()`, `destroy()`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `wrappers.effect`       | `create(model,x,y)`, `attach(model,Unit,attachmentPoint)`; `setPosition(x,y,z)`, `setScale(scale)`, `destroy()`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |

Player indices must be integers below `bj_MAX_PLAYER_SLOTS`, including neutral slots. Players have no destruction
method. `setPosition` uses SetUnitPosition, which respects pathing; `setX`/`setY` use SetUnitX/SetUnitY, which do not.
Inventory slots are zero-based integers below `getInventorySize()`. `getItemInSlot`, `removeItemFromSlot`, `addItemById`
and `group:first()` return nil when there is nothing. Hero methods pass through to the natives, so Warcraft's behavior
applies to non-heroes. `isLocal()` is true only on that player's machine: never change synchronized game state inside a
branch on it. `enumSelected` inherits the native's synchronization behavior. `Rect.worldBounds()` allocates a new rect
each call; destroy it. SetPlayerName is deliberately outside the API.

Some methods that act also pass the native's result through. `trigger:evaluate()` returns the conditions' boolean
result. On Unit, `damageTarget`, `modifySkillPoints`, `revive`, `addAbility`, `removeAbility`, `makeAbilityPermanent`,
`addItem`, `dropItemAt`, `dropItemToSlot` and `useItem` return a boolean, and `setAbilityLevel` returns an integer.

Every group enumeration clears the group first and passes no native filter. The optional `filter` then runs over a
snapshot and removes the units for which it returns falsy; "of type" is a filter such as `(u) -> u\getTypeId! == id`. If
the filter raises, the group is cleared and the error propagates. Negative, infinite and NaN radii fail before clearing.
`getUnits()` returns a dense one-based array, skips nil native entries and preserves native order without promising
sorting. Later group changes do not alter the array. `forEach` iterates the same kind of snapshot; its errors propagate.
`Force.getPlayers()` is a snapshot in the same way. `unit:remove()` still disposes that wrapper in every snapshot.

## Callbacks

Timer callbacks receive their Timer; trigger actions and conditions receive their Trigger. Read event context using
ordinary natives, then convert handles with `fromHandle` as needed. Registrations pass no native filter; filter inside a
condition or an action. Warcraft cannot unregister an event, so destroying the trigger is the only way to remove one.
`addAction` and `addCondition` return tokens; removing a token takes effect at once, even during a firing, and removing
it twice does nothing. A token from another trigger raises an error. A condition's result counts as truthy or falsy; if
it raises, the error is printed with `[wrappers] Trigger condition failed:` and the condition counts as false. The
trigger owns each condition's boolexpr and destroys it on removal, on `clearConditions()` and on `destroy()`.

`start` replaces the timer's old schedule. Timeouts must be finite and nonnegative. One-shot timers remain allocated
after firing: restart them or explicitly destroy them. A callback can restart or destroy its own timer. Stale callbacks
from replaced schedules or destroyed wrappers do nothing.

Callbacks must be synchronous: do not yield or call TriggerSleepAction. Use timers for delayed work. A callback error is
caught and printed with `[wrappers] Timer/Trigger callback failed:`; periodic ticks and future actions continue. Errors
do not automatically destroy resources. During the 2026-09-28 gate on Warcraft 3.0.0.24268, F12 retained these errors
and the subsequent tick and cleanup messages.

See [CONTRIBUTING.md](CONTRIBUTING.md) for checks and the in-game release gate.
