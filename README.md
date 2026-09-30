# Moonwell Wrappers

Annotated Lua 5.3 library for Warcraft III. It provides Player, Unit, Item, Destructable, Rect, Region, Force, Timer,
Trigger, Group, Effect, TextTag, Sound, Lightning, Image, Ubersplat, FogModifier, Dialog, Multiboard, Leaderboard,
Quest, DefeatCondition, TimerDialog and Frame wrappers, editor completion, stable handle identity and explicit cleanup.

**Status:** `v0.6.0` (2026-09-30): the refactor after the review. Errors point at the calling line, methods and group
enumeration are cheaper, `isAlive()` uses `UnitAlive` (Moonwell 0.5.1 or later), and `exists()` is new. It builds on
v0.5's frames, v0.4's classic UI and v0.3's presentation wrappers. Its in-game gate passed on 3.0.0.24268. Multiplayer
desync checks are deferred until before Moonwell 1.0.

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

To use the published `v0.6.0` tag from GitHub, put this in the map's committed `moonwell.pkl`:

```pkl
libraries {
  ["wrappers"] {
    github = "mdlsvensson/moonwell-wrappers"
    tag = "v0.6.0"
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

Factories return non-null wrappers or raise an error if the native returns nil. Wrapper errors point at the line that
called the wrapper. Rewrapping the same live handle returns the same Lua table while any reference to that wrapper
exists.

Unit, Item and Destructable use a weak cache: the game removes these on its own (decay, used powerups, dead trees), so a
wrapper nothing references may be collected, and a later `fromHandle` returns a fresh wrapper. Keep a reference (a
variable, table key or closure) wherever identity matters. Do not key weak tables (`__mode = 'k'`) by Unit, Item or
Destructable wrappers for game data: each client's collector drops those entries at its own time, so game logic that
reads such a table can desync. Timer, Trigger, Group, Effect, Rect, Region, Force and the presentation, classic UI and
frame classes stay cached until you destroy them (game frames for the session); Player wrappers stay cached for the game
session.

Use `unit/item/destructable:remove()` and `timer/trigger/group/effect/rect/region/force:destroy()`, and `destroy()` on
the presentation classes. Repeated cleanup is harmless; other methods reject disposed receivers and disposed wrapper
arguments. `unit:kill()` leaves its wrapper valid because death is not removal. Groups do not own their units, effects
do not own their targets, and fog modifiers do not own their rects. Garbage collection never destroys game objects.

Raw natives remain available through `getHandle()`, for example `SetUnitInvulnerable(unit:getHandle(), true)`. Destroy
wrapped resources through their wrappers: direct native destruction bypasses tracking. Never wrap a destroyed raw
handle. There is no generic native liveness or handle-type check. Do not modify wrapper metatables or fields.

## Widgets

A widget the game removes by itself (decay, a used powerup, removal by code that bypassed the wrapper) leaves a wrapper
that is not disposed: `exists()` tells you it is gone (its type id reads 0), while `isAlive()` on a unit uses the
`UnitAlive` native, which needs Moonwell 0.5.1 or later. Both raise for a disposed wrapper, like every method. Measured
on 3.0.0.24268 (v0.6.0 gate): an item or destructable removed with the raw native reads `false` at once; a unit reads
`true` in the same instant as `RemoveUnit` and `false` from the next frame (a zero-second timer).

Unit, Item and Destructable are widgets (`MoonwellWrappers.Widget` in the editor). All three have `getLife()`,
`setLife(value)`, `getX()` and `getY()`. Parameters typed Widget accept any of them: `unit:issueTargetOrder`,
`unit:issueTargetOrderById`, `unit:damageTarget` and `trigger:registerDeathEvent`. `Effect.attach` and `Effect.flashOn`
take a Unit in the editor: Warcraft drew no effect attached to an item or a destructable in the v0.3.0 gate
(3.0.0.24268: a Claws of Attack item and a summer tree, standard effect models), so the editor flags an Item or a
Destructable there. At run time both still accept any widget, as the native does, for custom models that may draw; put
`---@diagnostic disable-next-line: param-type-mismatch` above such a call. Otherwise attach to a unit, or create the
effect at the object's position instead. There is no `Widget.fromHandle`: convert a raw widget with the class you know
it is, for example `Item.fromHandle(GetManipulatedItem())`.

## Presentation

TextTag, Sound, Lightning, Image, Ubersplat and FogModifier wrappers exist only for objects the map owns: the game never
ends them on its own, so `destroy()` is their only cleanup. `TextTag.create()` makes a permanent tag, and a Sound
wrapper is never released when it finishes. One-shot presentation uses helpers that return nothing, so no wrapper can go
stale:

- `TextTag.float(text, x, y, options?)`: floating text that the game removes after its lifespan. Options: `size` (10),
  `heightOffset` (0), `color` (`{r, g, b, a?}`, white), `speed` (64) and `angle` (degrees, 90), `lifespan` (2),
  `fadepoint` (1) and `player` (show to one player only). It does nothing when the game has no free text tag.
- `Sound.playOnce(path, options?)`: plays a sound once and releases it. Options: `volume` (0–127, 127); `x`, `y` and `z`
  (given `x` and `y`, the sound is 3D at that point; giving only one of them raises an error; `z` defaults to 0);
  `player` (hear it on one player's machine only; the others play it at volume 0).
- `Effect.flash(model, x, y)` and `Effect.flashOn(model, Unit, attachmentPoint)`: create and destroy an effect at once,
  which plays its death animation.

`Sound.create(path, options?)` takes `looping`, `is3D` and `stopWhenOutOfRange` (false), `fadeIn` and `fadeOut` (10) and
`eax` (`"DefaultEAXON"`). `Ubersplat.create(name, x, y, options?)` takes a splat name from `Splats\UberSplatData.slk`
and the options `color` (white), `forcePaused` and `noBirthTime` (false); the splat is always rendered. Options tables
reject unknown keys and wrong types.

`setVisibleFor(Player)` (TextTag, Image, Ubersplat) and `sound:playFor(Player)` compare with the local player, so only
local visuals and audio differ; the objects exist on every machine. `show(flag)` afterwards applies to everyone.
Lightning has no local visibility. Do not wrap with `fromHandle` a text tag that has a lifespan or a sound released with
`KillSoundWhenDone` (for example one made by GUI or BJ code): the game ends those on its own, and text tag ids are
reused, so the wrapper would go stale. There is no `sound:isPlaying()`, and Effect has no position getters: those
natives answer differently on each machine.

Some lightning types fade by themselves right after creation, as their spells do: in the v0.3.0 gate Chain Lightning
(`CLPB`) vanished within a moment, while Drain Life (`DRAL`) stayed until destroyed; a later probe found the same fading
for Healing Wave (`HWPB`) and Spirit Link (`SPLK`). Pick a lasting type for a `Lightning` you keep. `lightning:setColor`
stores the colour (the game reads it back), but on 3.0.0.24268 the Drain Life bolt showed no visible change for green,
red or an alpha of 0.2; do not rely on it for visuals. Lightning heights are absolute, not relative to the ground: on
uneven terrain add the ground height (for example `GetLocationZ`), or the bolt can run under it.

`sound:play()` on a sound that is still playing cuts it off, and nothing plays (probe on 3.0.0.24268): let it finish, or
use another Sound or `Sound.playOnce`. `splat:finish()` fades the splat out while the wrapper stays valid (destroy it as
usual); `splat:reset()` did not bring a finished splat back.

Value ranges are the natives': colors are integers 0–255, except `lightning:setColor`, which takes numbers 0–1. Sound
volume is 0–127 and `getDuration()` is in milliseconds; it can be 0 until the file is loaded, so do not drive
synchronized game logic from it. Text tag `size` is World Editor's font size; `setVelocity` takes native units. Effect
orientation is in radians. `Image.create(path, width, height, x, y, imageType)` centres the image on `x, y` and makes it
visible; image types are 1 selection, 2 indicator, 3 occlusion mask and 4 ubersplat. A path the game cannot load raises
`[wrappers] Image.create: invalid image path`: Warcraft returns an invalid image (handle id -1), not nil, and the
wrapper destroys it first. `image:setPosition` also centres, so it fails on an image wrapped with `fromHandle`, whose
size is unknown. Fog modifiers start stopped.

`Item.enumInRect(Rect, filter?)` and `Destructable.enumInRect(Rect, filter?)` return a new dense array of what the
native enumerates. The filter runs afterwards as ordinary Lua and keeps the objects for which it returns truthy; its
errors propagate.

## Classic UI

Dialog, Multiboard, Leaderboard, Quest, DefeatCondition and TimerDialog wrap objects the map owns and destroys, like the
presentation classes. Show them from a timer or trigger once the map has started, as the gate does with a zero-second
timer: in a probe on 3.0.0.24268, a dialog and a multiboard shown directly in `on_main` never appeared. Creating a
quest, leaderboard or multiboard in `on_main` worked, and each showed correctly later. (w3ts reports that creating them
while the map script loads can crash the game; create game objects inside Moonwell's hooks, never at module top level.)

**Dialogs.** `dialog:addButton(text, callback)` or `dialog:addButton(text, options?, callback?)` returns a DialogButton.
The callback receives the Player who clicked, runs behind the same error boundary as trigger actions, and may hide,
clear or destroy its own dialog. Options: `hotkey` (one letter or digit), `quit` (the button quits the game for the
clicking player) and `scoreScreen` (with `quit`, show the score screen first). Warcraft hides a dialog when a button is
clicked. Buttons belong to their dialog: `dialog:clear()` and `dialog:destroy()` dispose them, and a disposed button's
callback never runs. Buttons have no `destroy()` and no `fromHandle`; `button:getDialog()` returns the dialog.
`show(Player)` and `hide(Player)` act for one player with the same call on every machine.

**Multiboards.** Rows and columns count from 1. `setCell(row, column, options)`, `setRow(row, options)`,
`setColumn(column, options)` and `setAll(options)` take `value`, `color` (`{r, g, b, a?}`), `icon`, `width` (a fraction
of the screen width) and `showValue` with `showIcon` (always together); at least one option is required. A cell outside
the board raises an error. The wrapper obtains and releases the native cell handles itself, so none can leak. A new
multiboard's cells show a default icon (an eye) and no text until they are styled, so start with, for example,
`setAll({showValue = true, showIcon = false})`. `setRowCount` changes the count one row at a time, a safeguard: w3ts
reports that bigger steps are unsafe, though a direct change from 0 to 5 rows worked in our probe.
`Multiboard.suppressDisplay(flag)` hides or allows every multiboard. There is no `isMinimized()`: each player minimizes
a multiboard on their own machine.

**Leaderboards.** Items are keyed by player, one per player. `addItem(Player, label, value)` and `removeItem(Player)`
resize the board to fit (a leaderboard starts with no rows); the item setters take the player. `assign(Player)` makes
the leaderboard the one that player sees; then call `show(true)`.

**Quests.** `Quest.create(options?)` takes `title`, `description`, `icon`, `required` (true) and `discovered` (true).
`quest:addItem(description)` returns a QuestItem, which belongs to its quest as a button belongs to its dialog:
`quest:destroy()` disposes it. `Quest.flashButton()` flashes the quest button; `Quest.refresh()` updates an open quest
log. `DefeatCondition.create(description?)` lists a defeat condition in the quest log.

**Timer dialogs.** `TimerDialog.create(Timer, title?)` makes a hidden countdown of that timer; call `show(true)`. It
does not own the timer: destroy the timer dialog first. Once the timer is destroyed, every method except `destroy()`
raises `Timer is disposed`.

`setVisibleFor(Player)` on Multiboard and TimerDialog compares with the local player, as for the presentation classes.
There are no getters for whether a multiboard, leaderboard or timer dialog is displayed or minimized: they answer
differently on each machine.

## Frames

`wrappers.frame` wraps the `BlzFrame` API. Create, destroy and re-parent frames on every machine in the same order,
never inside a branch on the local player: frame handles and the wrapper's create contexts must agree across machines.
Screen coordinates run 0–0.8 wide and 0–0.6 high, from the bottom left.

There are three kinds of frame:

- **Owned** frames come from `Frame.create(template, parent, options?)` (option `priority`),
  `Frame.createSimple(template, parent)` and `Frame.createByType(frameType, parent, options?)` (options `name`,
  `inherits`). `frame:destroy()` destroys the frame and everything under it; the wrappers of its owned descendants and
  template parts are disposed at once and their callbacks never run again.
- **Template parts** are the frames a template creates inside a frame: `frame:findChild(name)` finds one by name (the
  wrapper passes each owned frame its own create context, so names never clash), and `frame:getChild(index)` by
  zero-based index. A part belongs to the owned frame it was found through and cannot be destroyed or re-parented.
- **Borrowed** frames are the game's: `Frame.origin(ORIGIN_FRAME_GAME_UI)`, `Frame.byName(name, context?)`,
  `Frame.fromHandle(raw)`. They can be parents but never be destroyed through a wrapper, and can only be re-parented
  under another borrowed frame, so destroying one of your frames never silently destroys a game frame.

`frame:setParent(parent)` moves an owned frame, and it is then destroyed with its new parent. A frame cannot be moved
into its own subtree.

Events go to callbacks: `frame:on(FRAMEEVENT_CONTROL_CLICK, function(player, event) ... end)` returns a token for
`frame:off(token)`. The callback receives the Player who caused the event and `event` with `type`, `frame`, `text` (edit
boxes) and `value` (sliders, check boxes, popup menus, the mouse wheel): the event's synced data. Callbacks run behind
the same error boundary as trigger actions and may destroy their own frame. After a click, a button keeps the keyboard
focus and hotkeys stop working; call `frame:releaseFocusFor(player)` in the click callback.

There are no getters for text, values, visibility, enabled state, alpha or size: they answer differently on each machine
(typed text, dragged sliders, local visibility). Read synced values in event callbacks. `setVisibleFor(Player)` compares
with the local player, as for the presentation classes. Colors (`setTextColor`, `setVertexColor`) are integers 0–255.

The game's own templates need no TOC file: in a probe on 3.0.0.24268, `ScriptDialogButton`, `EscMenuBackdrop`,
`EscMenuTitleTextTemplate`, `EscMenuLabelTextTemplate`, `EscMenuEditBoxTemplate`, `EscMenuSliderTemplate`,
`QuestCheckBox`, `QuestButtonBaseTemplate` and `BattleNetTextAreaTemplate` all created without one. An unknown template
name makes the factory raise `native returned nil`. The same probe found origin frames available in `on_main`, that
destroying a frame removes its children (including one re-parented onto it), that a clicked button keeps the keyboard
focus until `releaseFocusFor`, and that a button can destroy itself in its own click callback.

Your own templates come from `.fdf` files listed in a `.toc` file. Put both under `assets/`, for example
`assets/war3mapImported/templates.toc` (imported as `war3mapImported\templates.toc`), with one FDF path per line and an
empty last line:

```text
war3mapImported\MyFrames.fdf
```

Then load it in a hook, before creating frames: `Frame.loadTOC("war3mapImported\\templates.toc")`. It raises when the
game cannot load the file. `Frame.hideOrigin(flag)` hides the game's own UI and `Frame.enableAutoPosition(flag)` turns
its automatic layout off or on, for everyone.

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

## Units and conventions

The wrappers keep each native's conventions, so they differ between classes:

| What       | Convention                         | Where                                                                    |
| ---------- | ---------------------------------- | ------------------------------------------------------------------------ |
| Colours    | 0–255 per channel                  | units, effects, text tags, images, ubersplats, classic UI, frames        |
| Colours    | 0–1 per channel                    | `lightning:setColor` (`SetLightningColor`)                               |
| Angles     | degrees                            | unit facing, `Destructable.create`'s facing, `TextTag.float`'s `angle`   |
| Angles     | radians                            | `effect:setOrientation` (`BlzSetSpecialEffectOrientation`)               |
| Visibility | `show(flag)` / `isHidden()`        | units (`ShowUnit`, `IsUnitHidden`); destructables have `show(flag)` only |
| Visibility | `setVisible(flag)` / `isVisible()` | items (`SetItemVisible`, `IsItemVisible`)                                |
| Time       | seconds                            | timers, timed life, cooldowns, text tag lifespan and fade point          |
| Time       | milliseconds                       | `sound:getDuration()` (`GetSoundDuration`)                               |

## API reference

All wrapper parameters below require wrappers, not raw handles. Warcraft enums and integer rawcodes pass through. Player
indices are zero-based; durations are seconds; facing uses native degrees. Native pathing and synchronization rules
apply. Calls made only for a local player do not become synchronized by using wrappers.

Each module lists its factories and methods beyond the common handle methods (`fromHandle`, `getHandle`, `isDisposed`,
and `destroy` or `remove`).

### `wrappers.player`

- `fromIndex(index)`
- `getId()`, `getName()`, `getColor()`, `getState(playerstate)`, `setState(playerstate, integer)`
- `getGold()`, `setGold(n)`, `addGold(n)`, `getLumber()`, `setLumber(n)`, `addLumber(n)`
- `getAlliance(Player, alliancetype)`, `setAlliance(Player, alliancetype, flag)`, `isAlly(Player)`, `isEnemy(Player)`
- `getTechCount(techId, specificOnly)`, `setTechResearched(techId, level)`, `addTechResearched(techId, levels)`,
  `setTechMaxAllowed(techId, max)`, `setAbilityAvailable(abilityId, flag)`
- `getController()`, `getSlotState()`, `getRace()`, `getTeam()`, `getStartX()`, `getStartY()`, `isLocal()`

### `wrappers.unit`

- `create(Player, typeId, x, y, facing)`
- `getTypeId()`, `getName()`, `getOwner()`, `setOwner(Player, changeColor)`
- `getX()`, `getY()`, `setPosition(x,y)`, `setX(x)`, `setY(y)`, `getFacing()`, `setFacing(degrees)`
- `getLife()`, `setLife(v)`, `getMaxLife()`, `setMaxLife(n)`, `getMana()`, `setMana(v)`, `getMaxMana()`,
  `setMaxMana(n)`, `getMoveSpeed()`, `setMoveSpeed(v)`
- `setColor(playercolor)`, `setScale(s)`, `setVertexColor(r,g,b,a)`, `setAnimation(name)`, `pause(flag)`, `isPaused()`,
  `setInvulnerable(flag)`, `isInvulnerable()`, `show(flag)`, `isHidden()`
- `isType(unittype)`, `isAlly(Player)`, `isEnemy(Player)`, `isAlive()`, `exists()`, `getCurrentOrder()`
- `kill()`, `remove()`, `applyTimedLife(buffId, seconds)`,
  `damageTarget(Widget, amount, attack, ranged, attacktype, damagetype, weapontype)`
- hero: `isHero()`, `getHeroName()`, `getLevel()`, `setLevel(level, showEffect)`, `getXP()`, `setXP(xp, showEffect)`,
  `addXP(xp, showEffect)`, `getStr/getAgi/getInt(includeBonuses)`, `setStr/setAgi/setInt(value, permanent)`,
  `getSkillPoints()`, `modifySkillPoints(delta)`, `selectSkill(abilityId)`, `revive(x, y, showEffect)`
- abilities: `addAbility(id)`, `removeAbility(id)`, `getAbilityLevel(id)`, `setAbilityLevel(id, level)`,
  `makeAbilityPermanent(id, permanent)`, `hideAbility(id, hidden)`, `disableAbility(id, disabled, hideUI)`,
  `startCooldown(id, seconds)`, `endCooldown(id)`, `getCooldownRemaining(id)`
- inventory: `getInventorySize()`, `getItemInSlot(slot)`, `addItem(Item)`, `addItemById(typeId)`, `removeItem(Item)`,
  `removeItemFromSlot(slot)`, `hasItem(Item)`, `dropItemAt(Item, x, y)`, `dropItemToSlot(Item, slot)`, `useItem(Item)`
- orders (return boolean): `issueOrder(order)`, `issuePointOrder(order, x, y)`, `issueTargetOrder(order, Widget)`,
  `issueOrderById(id)`, `issuePointOrderById(id, x, y)`, `issueTargetOrderById(id, Widget)`

### `wrappers.item`

- `create(typeId, x, y)`, `enumInRect(Rect, filter?)`
- `getTypeId()`, `getName()`, `getLevel()`, `setPosition(x, y)`, `getCharges()`, `setCharges(n)`, `getOwner()`,
  `setOwner(Player, changeColor)`, `isOwned()`, `isPowerup()`, `isVisible()`, `setVisible(flag)`, `isInvulnerable()`,
  `setInvulnerable(flag)`, `setDroppable(flag)`, `setPawnable(flag)`, `exists()`, `remove()`

### `wrappers.destructable`

- `create(typeId, x, y, facing, scale, variation)`, `enumInRect(Rect, filter?)`
- `getTypeId()`, `getName()`, `getMaxLife()`, `setMaxLife(v)`, `kill()`, `restore(life, birth)`, `isInvulnerable()`,
  `setInvulnerable(flag)`, `show(flag)`, `setAnimation(name)`, `queueAnimation(name)`, `exists()`, `remove()`

### `wrappers.rect`

- `create(minX, minY, maxX, maxY)`, `worldBounds()`
- `getMinX()`, `getMinY()`, `getMaxX()`, `getMaxY()`, `getCenterX()`, `getCenterY()`, `set(minX, minY, maxX, maxY)`,
  `moveTo(x, y)`, `destroy()`

### `wrappers.region`

- `create()`
- `addRect(Rect)`, `clearRect(Rect)`, `addCell(x, y)`, `clearCell(x, y)`, `containsPoint(x, y)`, `containsUnit(Unit)`,
  `destroy()`

### `wrappers.force`

- `create()`
- `add(Player)`, `remove(Player)`, `contains(Player)`, `clear()`, `enumPlayers()`, `enumAllies(Player)`,
  `enumEnemies(Player)`, `getPlayers()`, `destroy()`

### `wrappers.timer`

- `create()`
- `start(timeout, periodic, callback)`, `pause()`, `resume()`, `getElapsed()`, `getRemaining()`, `getTimeout()`,
  `destroy()`

### `wrappers.trigger`

- `create()`
- `enable()`, `disable()`, `isEnabled()`, `evaluate()` (returns boolean), `execute()`
- `registerUnitEvent(Unit, unitevent)`, `registerPlayerUnitEvent(Player, playerunitevent)`,
  `registerAnyUnitEvent(playerunitevent)`, `registerPlayerEvent(Player, playerevent)`,
  `registerChatEvent(Player, text, exactMatch)`, `registerEnterRegion(Region)`, `registerLeaveRegion(Region)`,
  `registerDeathEvent(Widget)`, `registerUnitInRange(Unit, range)`,
  `registerUnitStateEvent(Unit, unitstate, limitop, value)`, `registerTimerEvent(timeout, periodic)`,
  `registerGameEvent(gameevent)`
- `addAction(callback)` and `addCondition(predicate)` return tokens for `removeAction(token)` and
  `removeCondition(token)`
- `clearActions()`, `clearConditions()`, `destroy()`

### `wrappers.group`

- `create()`
- `add(Unit)`, `remove(Unit)`, `contains(Unit)`, `clear()`
- `enumInRange(x, y, radius, filter?)`, `enumInRect(Rect, filter?)`, `enumOfPlayer(Player, filter?)`,
  `enumSelected(Player, filter?)`
- `getSize()`, `getUnits()`, `forEach(callback)`, `first()`, `destroy()`

### `wrappers.effect`

- `create(model,x,y)`, `attach(model,Unit,attachmentPoint)`, `flash(model, x, y)`,
  `flashOn(model, Unit, attachmentPoint)`
- `setPosition(x,y,z)`, `setScale(scale)`, `setColor(r, g, b)`, `setAlpha(a)`, `setPlayerColor(Player)`,
  `setTimeScale(scale)`, `setOrientation(yaw, pitch, roll)`, `setHeight(height)`, `setZ(z)`, `playAnimation(animtype)`,
  `destroy()`

### `wrappers.texttag`

- `create()`, `float(text, x, y, options?)`
- `setText(text, size)`, `setColor(r, g, b, a)`, `setPosition(x, y, heightOffset)`,
  `setPositionOnUnit(Unit, heightOffset)`, `setVelocity(xvel, yvel)`, `setSuspended(flag)`, `show(flag)`,
  `setVisibleFor(Player)`, `destroy()`

### `wrappers.sound`

- `create(path, options?)`, `playOnce(path, options?)`
- `play()`, `playFor(Player)`, `stop(fadeOut?)`, `setVolume(volume)`, `setPitch(pitch)`, `setChannel(channel)`,
  `setPosition(x, y, z)`, `attachToUnit(Unit)`, `setDistances(min, max)`, `setDistanceCutoff(cutoff)`, `getDuration()`,
  `destroy()`

### `wrappers.lightning`

- `create(code, x1, y1, z1, x2, y2, z2, checkVisibility?)`
- `move(x1, y1, z1, x2, y2, z2, checkVisibility?)` and `setColor(r, g, b, a)` (both return boolean), `destroy()`

### `wrappers.image`

- `create(path, width, height, x, y, imageType)`
- `setPosition(x, y, z?)`, `show(flag)`, `setVisibleFor(Player)`, `setColor(r, g, b, a)`,
  `setConstantHeight(flag, height)`, `setAboveWater(flag, useWaterAlpha)`, `setType(imageType)`, `destroy()`

### `wrappers.ubersplat`

- `create(name, x, y, options?)`
- `show(flag)`, `setVisibleFor(Player)`, `finish()`, `reset()`, `destroy()`

### `wrappers.fogmodifier`

- `radius(Player, fogstate, x, y, radius, useSharedVision, afterUnits)`,
  `rect(Player, fogstate, Rect, useSharedVision, afterUnits)`
- `start()`, `stop()`, `destroy()`

### `wrappers.dialog`

- `create()`
- `setMessage(text)`, `addButton(text, options?, callback?)` (returns a DialogButton), `show(Player)`, `hide(Player)`,
  `clear()`, `destroy()`. DialogButton: `getDialog()`

### `wrappers.multiboard`

- `create(rows, columns, title?)`, `suppressDisplay(flag)`
- `setRowCount(count)`, `setColumnCount(count)`, `getRowCount()`, `getColumnCount()`, `setTitle(text)`, `getTitle()`,
  `setTitleColor(r, g, b, a)`, `setCell(row, column, options)`, `setRow(row, options)`, `setColumn(column, options)`,
  `setAll(options)`, `show(flag)`, `setVisibleFor(Player)`, `minimize(flag)`, `destroy()`

### `wrappers.leaderboard`

- `create(label?)`
- `setLabel(text)`, `setLabelColor(r, g, b, a)`, `setValueColor(r, g, b, a)`, `setStyle(options?)`,
  `addItem(Player, label, value)`, `removeItem(Player)`, `setItemValue(Player, value)`, `setItemLabel(Player, label)`,
  `setItemLabelColor(Player, r, g, b, a)`, `setItemValueColor(Player, r, g, b, a)`, `setItemStyle(Player, options?)`,
  `hasItem(Player)`, `getItemCount()`, `sortByValue(ascending)`, `sortByLabel(ascending)`, `sortByPlayer(ascending)`,
  `assign(Player)`, `show(flag)`, `destroy()`

### `wrappers.quest`

- `create(options?)`, `flashButton()`, `refresh()`
- `setTitle(text)`, `setDescription(text)`, `setIcon(path)`, `setRequired(flag)`/`isRequired()`,
  `setCompleted(flag)`/`isCompleted()`, `setFailed(flag)`/`isFailed()`, `setDiscovered(flag)`/`isDiscovered()`,
  `setEnabled(flag)`/`isEnabled()`, `addItem(description)` (returns a QuestItem), `destroy()`. QuestItem:
  `setDescription(text)`, `setCompleted(flag)`, `isCompleted()`, `getQuest()`

### `wrappers.defeatcondition`

- `create(description?)`
- `setDescription(text)`, `destroy()`

### `wrappers.timerdialog`

- `create(Timer, title?)`
- `setTitle(text)`, `setTitleColor(r, g, b, a)`, `setTimeColor(r, g, b, a)`, `setSpeed(factor)`,
  `setRealTimeRemaining(seconds)`, `show(flag)`, `setVisibleFor(Player)`, `destroy()`

### `wrappers.frame`

- `create(template, parent, options?)`, `createSimple(template, parent)`, `createByType(frameType, parent, options?)`,
  `origin(originType, index?)`, `byName(name, context?)`, `loadTOC(path)`, `hideOrigin(flag)`,
  `enableAutoPosition(flag)`
- `getName()`, `getParent()`, `getChildrenCount()`, `getChild(index)`, `findChild(name)`, `setParent(Frame)`,
  `setPoint(point, Frame, relativePoint, x, y)`, `setAbsPoint(point, x, y)`, `setAllPoints(Frame)`, `clearPoints()`,
  `setSize(width, height)`, `setScale(scale)`, `setLevel(level)`, `setText(text)`, `addText(text)`,
  `setTextColor(r, g, b, a)`, `setVertexColor(r, g, b, a)`, `setFont(path, height, flags?)`,
  `setTextAlignment(vertical, horizontal)`, `setTextSizeLimit(size)`, `setTexture(path, flag?, blend?)`,
  `setModel(path, cameraIndex?)`, `setSpriteAnimate(primaryProp, flags)`, `setAutoScroll(flag)`, `setValue(value)`,
  `setMinMaxValue(min, max)`, `setStepSize(step)`, `setAlpha(alpha)`, `setEnabled(flag)`, `setTooltip(Frame)`,
  `show(flag)`, `setVisibleFor(Player)`, `releaseFocusFor(Player)`, `on(eventType, callback)`, `off(token)`, `destroy()`

Player indices must be integers below `bj_MAX_PLAYER_SLOTS`, including neutral slots. Players have no destruction
method. `setPosition` uses SetUnitPosition, which respects pathing; `setX`/`setY` use SetUnitX/SetUnitY, which do not.
Inventory slots are zero-based integers below `getInventorySize()`. `getItemInSlot`, `removeItemFromSlot`, `addItemById`
and `group:first()` return nil when there is nothing. `group:first()` uses FirstOfGroup, which can also return nil while
the group still holds removed units, so do not loop `while group:first()`; use `forEach` or `getUnits()`. Hero methods
pass through to the natives, so Warcraft's behavior applies to non-heroes. `isLocal()` is true only on that player's
machine: never change synchronized game state inside a branch on it. `enumSelected` inherits the native's
synchronization behavior. `Rect.worldBounds()` allocates a new rect each call; destroy it. SetPlayerName is deliberately
outside the API.

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

There are two kinds of callback. Callbacks that run immediately let their errors propagate to your code: the filters of
`enumInRange`, `enumInRect`, `enumOfPlayer` and `enumSelected`, `Group:forEach`, and the `Item.enumInRect` and
`Destructable.enumInRect` filters. Event callbacks run later, from the game, behind a boundary: an error is printed with
its label and nothing else is affected. The labels are `Timer`, `Trigger`, `Dialog button` and `Frame event`, printed as
`[wrappers] <label> callback failed: …`, and `Trigger condition`, printed as `[wrappers] Trigger condition failed: …`
(the condition then counts as false).

Timer callbacks receive their Timer; trigger actions and conditions receive their Trigger. Read event context using
ordinary natives, then convert handles with `fromHandle` as needed. Registrations pass no native filter; filter inside a
condition or an action. Warcraft cannot unregister an event, so destroying the trigger is the only way to remove one.
`addAction` and `addCondition` return tokens; removing a token takes effect at once, even during a firing, and removing
it twice does nothing. A condition may remove its own token; the evaluation in progress still counts its result. A token
from another trigger raises an error. A condition's result counts as truthy or falsy; if it raises, the error is printed
with `[wrappers] Trigger condition failed:` and the condition counts as false. The trigger owns each condition's
boolexpr and destroys it on removal, on `clearConditions()` and on `destroy()`.

`start` replaces the timer's old schedule. Timeouts must be finite and nonnegative. One-shot timers remain allocated
after firing: restart them or explicitly destroy them. A callback can restart or destroy its own timer. Stale callbacks
from replaced schedules or destroyed wrappers do nothing.

Callbacks must be synchronous: do not yield or call TriggerSleepAction. Use timers for delayed work. A callback error is
caught and printed with `[wrappers] Timer/Trigger callback failed:`; periodic ticks and future actions continue. Errors
do not automatically destroy resources. During the 2026-09-28 gate on Warcraft 3.0.0.24268, F12 retained these errors
and the subsequent tick and cleanup messages.

## Reported native caveats

Other libraries document these Warcraft behaviours (w3ts 3.0.2 doc comments and WCSharp 3.3.9; compared in Moonwell's
`docs/superpowers/research/`). They are **not tested by our gates**; they are listed because ignoring them can cause a
desync, a crash or wrong game logic.

- `getName()` on Unit, Item and Destructable returns the text in each player's game language. Display it, but do not
  compare or branch on it in synchronized logic.
- `GetHandleId` is prone to desyncs in Lua, where handle ids depend on each machine's garbage collection. Key tables by
  the wrapper or the handle instead; the wrappers expose no id.
- `group:enumOfPlayer` includes units with Locust; the other enumerations skip them.
- `timer:getRemaining()` can be wrong after the timer was paused and resumed.
- `unit:getX()` and `getY()` of a unit loaded into a transport return its position before loading.
- `unit:setX` and `setY` do not interrupt orders (`setPosition` does), and a unit with movement speed 0 moves while its
  model stays. `unit:setFacing` turns at the unit's turn rate; `BlzSetUnitFacingEx(unit:getHandle(), angle)` turns it at
  once.
- `unit:setInvulnerable` relies on the `Avul` ability; a map whose object data removes it crashes the game.
- `unit:addXP` with a negative amount lowers experience but never the level.
- An order issued to a unit inside its own attack event can lock its AI; issue it from a zero-second timer instead.
- `destructable:restore(life, birth)`: 0, or more than the maximum, restores full life; less than 0.5 gives 0.5.
- Image types draw in a fixed order, selection over occlusion mask over indicator over ubersplat, and images of one type
  in creation order. Only selection images draw above water.

See [CONTRIBUTING.md](CONTRIBUTING.md) for checks and the in-game release gate.
