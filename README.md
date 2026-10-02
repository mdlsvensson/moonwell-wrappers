# Moonwell Wrappers

Annotated Lua 5.3 library for Warcraft III. It provides Player, Unit, Item, Destructable, Rect, Region, Force, Timer,
Trigger, Group, Effect, TextTag, Sound, Lightning, Image, Ubersplat, FogModifier, Dialog, Multiboard, Leaderboard,
Quest, DefeatCondition, TimerDialog, Frame and WeatherEffect wrappers, Damage, Sync and Input modules, editor
completion, stable handle identity and explicit cleanup.

**Status:** `v0.9.0` (2026-10-02): `Unit.autoDispose` and `Unit.sweep` dispose the wrappers of units the game has
removed, and `exists()` answers `false` for a disposed wrapper. It builds on v0.8's input listeners, weather effects,
`Effect.abilityArt`, Trigger registrations and `fromEvent()` (and v0.8.1's `moonwell-library.json`, so a map no longer
writes `dir = "src"`), v0.7's damage events and sync, v0.6's refactor (errors point at the calling line; Moonwell 0.5.1
or later), v0.5's frames, v0.4's classic UI and v0.3's presentation wrappers. Its in-game gate passed on 3.0.0.24268.
Multiplayer desync checks are deferred until before Moonwell 1.0.

## Use a local checkout

Keep `moonwell-wrappers` next to your map project. In the map's `moonwell.local.pkl`:

```pkl
amends "moonwell.pkl"

libraries {
  ["wrappers"] {
    path = "../moonwell-wrappers"
  }
}
```

Run `moonwell check` in the map to sync the library and refresh the editor view. Restart `dev` after adding a local
library. There are no additional runtime dependencies or install scripts.

To use the published `v0.9.0` tag from GitHub, put this in the map's committed `moonwell.pkl`:

```pkl
libraries {
  ["wrappers"] {
    github = "mdlsvensson/moonwell-wrappers"
    tag = "v0.9.0"
  }
}
```

Commit the resulting `moonwell.lock`. A local `path` override preserves that entry. The configuration key is a cache
label; imports follow paths inside `src/`. For example, `src/wrappers/unit.lua` is `wrappers.unit`.

The library's `moonwell-library.json` tells Moonwell 0.6.0 or later that module names start at `src/`. With Moonwell
0.5, or a tag before `v0.8.1`, add `dir = "src"` to the entry. An entry that still has it keeps working.

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
- `fromEvent()` (Unit, Player, Item, Destructable, Timer and Region only): return the wrapper of the object the running
  event is about, or nil when it has none. It reads `GetTriggerUnit`, `GetTriggerPlayer`, `GetManipulatedItem`,
  `GetTriggerDestructable`, `GetExpiredTimer` and `GetTriggeringRegion`. Wrap any other event response with
  `fromHandle`, for example `Unit.fromHandle(GetKillingUnit())`.
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
arguments (`isDisposed()` and a widget's `exists()` answer instead). `unit:kill()` leaves its wrapper valid because death is not removal. Groups do not own their units, effects
do not own their targets, and fog modifiers do not own their rects. Garbage collection never destroys game objects.

Raw natives remain available through `getHandle()`, for example `SetUnitInvulnerable(unit:getHandle(), true)`. Destroy
wrapped resources through their wrappers: direct native destruction bypasses tracking. Never wrap a destroyed raw
handle. There is no generic native liveness or handle-type check. Do not modify wrapper metatables or fields.

## Widgets

A widget the game removes by itself (decay, a used powerup, removal by code that bypassed the wrapper) leaves a wrapper
that is not disposed: `exists()` tells you it is gone (its type id reads 0), while `isAlive()` on a unit uses the
`UnitAlive` native, which needs Moonwell 0.5.1 or later. `exists()` is also `false` for a disposed wrapper, so it is
the one question that never raises; `isAlive()` raises for a disposed wrapper, like every other method. Measured on
3.0.0.24268 (v0.6.0 gate): an item or destructable removed with the raw native reads `false` at once; a unit reads
`true` in the same instant as `RemoveUnit` and `false` from the next frame (a zero-second timer).

### Automatic disposal of removed units

A map can have the library dispose the wrappers of units the game has removed:

```yue
import "moonwell" as mw
import "wrappers.unit" as Unit

mw.on_main ->
  Unit.autoDispose!        -- every 0.25 seconds; Unit.autoDispose 1 for every second
```

- `Unit.autoDispose(interval?)` starts one game timer that runs `Unit.sweep()` every `interval` seconds (0.25 when left
  out) and returns a function that stops it. Nothing runs until a map calls it. Calling it again changes the interval
  of that one timer, and any of the returned functions stops it.
- `Unit.sweep()` checks once: it disposes the wrapper of every unit whose type id reads 0, with one native call per
  Unit wrapper still in use. Call it yourself to choose the moment, for example from your own scheduler.
- A swept wrapper is like one you called `remove()` on: `isDisposed()` is `true`, `exists()` is `false`, every other
  method raises `Unit is disposed` at your line, and the wrapper lets go of the handle.
- A corpse is still a unit: its wrapper stays valid until the corpse is gone. A hero waiting to be revived stays valid
  too.
- A removal is seen at the first sweep after the frame it happened in, so code that keeps a unit across time asks
  `unit\exists!` before it uses it.
- There is no "unit was removed" callback: wrappers are swept in no fixed order, so nothing may depend on it. Items and
  destructables are not swept.

Measured on 3.0.0.24268 (v0.9.0 gate): with the default interval a unit removed by raw code was disposed 0.25 seconds
later, and an exploded unit within a second; a corpse and a dead hero stayed valid; a sweep by hand in the same instant
as `RemoveUnit` did not see the removal; a sweep over 200 wrappers took 90 microseconds, about 0.45 per wrapper.

Unit, Item and Destructable are widgets (`MoonwellWrappers.Widget` in the editor). All three have `getLife()`,
`setLife(value)`, `getX()` and `getY()`. Parameters typed Widget accept any of them: `unit:issueTargetOrder`,
`unit:issueTargetOrderById`, `unit:damageTarget` and `trigger:registerDeathEvent`. `Effect.attach` and `Effect.flashOn`
take a Unit in the editor: Warcraft drew no effect attached to an item or a destructable in the v0.3.0 gate
(3.0.0.24268: a Claws of Attack item and a summer tree, standard effect models), so the editor flags an Item or a
Destructable there. At run time both still accept any widget, as the native does, for custom models that may draw; put
`---@diagnostic disable-next-line: param-type-mismatch` above such a call. Otherwise attach to a unit, or create the
effect at the object's position instead. There is no `Widget.fromHandle`: convert a raw widget with the class you know
it is, for example `Item.fromHandle(GetSoldItem())`.

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

Use Moonwell's normal YueScript + Lua extension setup and run the map's `moonwell check`. Moonwell supplies native
types and the library view. Wrapper classes are named `MoonwellWrappers.Unit`, etc., separate from native `unit`. These
are editor diagnostics, not a new Moonwell compile-time type checker.

LuaLS 3.19.1 conservatively treats `fromHandle` results as nullable, including for a known non-null input, and
`fromEvent` results are nullable too. Narrow the result with an `if`, or use `assert` when the handle is known to exist:

```lua
local triggered = Unit.fromEvent()
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

- `fromIndex(index)`, `fromEvent()`
- `getId()`, `getName()`, `getColor()`, `getState(playerstate)`, `setState(playerstate, integer)`
- `getGold()`, `setGold(n)`, `addGold(n)`, `getLumber()`, `setLumber(n)`, `addLumber(n)`
- `getAlliance(Player, alliancetype)`, `setAlliance(Player, alliancetype, flag)`, `isAlly(Player)`, `isEnemy(Player)`
- `getTechCount(techId, specificOnly)`, `setTechResearched(techId, level)`, `addTechResearched(techId, levels)`,
  `setTechMaxAllowed(techId, max)`, `setAbilityAvailable(abilityId, flag)`
- `getController()`, `getSlotState()`, `getRace()`, `getTeam()`, `getStartX()`, `getStartY()`, `isLocal()`

### `wrappers.unit`

- `create(Player, typeId, x, y, facing)`, `fromEvent()`
- `sweep()`, `autoDispose(interval?)`: see [Automatic disposal of removed units](#automatic-disposal-of-removed-units)
- `getTypeId()`, `getName()`, `getOwner()`, `setOwner(Player, changeColor)`
- `getX()`, `getY()`, `setPosition(x,y)`, `setX(x)`, `setY(y)`, `getFacing()`, `setFacing(degrees)`
- `getLife()`, `setLife(v)`, `getMaxLife()`, `setMaxLife(n)`, `getMana()`, `setMana(v)`, `getMaxMana()`,
  `setMaxMana(n)`, `getMoveSpeed()`, `setMoveSpeed(v)`
- `setColor(playercolor)`, `setScale(s)`, `setVertexColor(r,g,b,a)`, `setAnimation(name)`, `pause(flag)`, `isPaused()`,
  `setInvulnerable(flag)`, `isInvulnerable()`, `show(flag)`, `isHidden()`, `getCollisionSize()`, `setPathing(flag)`
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

- `create(typeId, x, y)`, `enumInRect(Rect, filter?)`, `fromEvent()`
- `getTypeId()`, `getName()`, `getLevel()`, `setPosition(x, y)`, `getCharges()`, `setCharges(n)`, `getOwner()`,
  `setOwner(Player, changeColor)`, `isOwned()`, `isPowerup()`, `isVisible()`, `setVisible(flag)`, `isInvulnerable()`,
  `setInvulnerable(flag)`, `setDroppable(flag)`, `setPawnable(flag)`, `exists()`, `remove()`

### `wrappers.destructable`

- `create(typeId, x, y, facing, scale, variation)`, `enumInRect(Rect, filter?)`, `fromEvent()`
- `getTypeId()`, `getName()`, `getMaxLife()`, `setMaxLife(v)`, `kill()`, `restore(life, birth)`, `isInvulnerable()`,
  `setInvulnerable(flag)`, `show(flag)`, `setAnimation(name)`, `queueAnimation(name)`, `exists()`, `remove()`

### `wrappers.rect`

- `create(minX, minY, maxX, maxY)`, `worldBounds()`
- `getMinX()`, `getMinY()`, `getMaxX()`, `getMaxY()`, `getCenterX()`, `getCenterY()`, `set(minX, minY, maxX, maxY)`,
  `moveTo(x, y)`, `destroy()`

### `wrappers.region`

- `create()`, `fromEvent()`
- `addRect(Rect)`, `clearRect(Rect)`, `addCell(x, y)`, `clearCell(x, y)`, `containsPoint(x, y)`, `containsUnit(Unit)`,
  `destroy()`

### `wrappers.force`

- `create()`
- `add(Player)`, `remove(Player)`, `contains(Player)`, `clear()`, `enumPlayers()`, `enumAllies(Player)`,
  `enumEnemies(Player)`, `getPlayers()`, `destroy()`

### `wrappers.timer`

- `create()`, `fromEvent()`
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
  `registerGameEvent(gameevent)`, `registerPlayerStateEvent(Player, playerstate, limitop, value)`,
  `registerPlayerAllianceChange(Player, alliancetype)`, `registerGameStateEvent(gamestate, limitop, value)`,
  `registerTimerExpireEvent(Timer)`
- `addAction(callback)` and `addCondition(predicate)` return tokens for `removeAction(token)` and
  `removeCondition(token)`
- `clearActions()`, `clearConditions()`, `destroy()`

Measured on 3.0.0.24268 (the v0.8.0 probes):

- `registerPlayerStateEvent` fires inside `SetPlayerState` (so inside `player:setGold`), at every change to a value that
  satisfies the comparison, not only when the limit is crossed. `Player.fromEvent()` is the player.
- `registerPlayerAllianceChange` fires inside `SetPlayerAlliance` when that player's setting of that kind toward any
  player really changes. The event names no player: `Player.fromEvent()` is nil. The generic
  `registerPlayerEvent(Player, EVENT_PLAYER_ALLIANCE_CHANGED)` fired only for `ALLIANCE_PASSIVE`.
- `registerGameStateEvent` with `GAME_STATE_TIME_OF_DAY` fires when the comparison becomes true, by a set or by the
  game's clock, and not again while it stays true.
- `registerTimerExpireEvent` fires at every expiry, before the timer's own callback, also when it is registered after
  the timer started. `Timer.fromEvent()` is the timer. The trigger does not own the timer.

### `wrappers.group`

- `create()`
- `add(Unit)`, `remove(Unit)`, `contains(Unit)`, `clear()`
- `enumInRange(x, y, radius, filter?)`, `enumInRect(Rect, filter?)`, `enumOfPlayer(Player, filter?)`,
  `enumSelected(Player, filter?)`
- `getSize()`, `getUnits()`, `forEach(callback)`, `first()`, `destroy()`

### `wrappers.effect`

- `create(model,x,y)`, `attach(model,Unit,attachmentPoint)`, `flash(model, x, y)`,
  `flashOn(model, Unit, attachmentPoint)`, `abilityArt(abilityId, effecttype, index?)`
- `setPosition(x,y,z)`, `setScale(scale)`, `setColor(r, g, b)`, `setAlpha(a)`, `setPlayerColor(Player)`,
  `setTimeScale(scale)`, `setOrientation(yaw, pitch, roll)`, `setHeight(height)`, `setZ(z)`, `playAnimation(animtype)`,
  `destroy()`

`Effect.abilityArt(abilityId, effecttype, index?)` returns the art an ability's data names: a model path, for the
constructors above or a missile's model, and for `EFFECT_TYPE_LIGHTNING` a lightning code for `Lightning.create`. It
returns nil when the ability has none. `index` picks an entry of a list, from 1; past the last entry the game reads the
last one, so the number of entries cannot be read. Abilities such as Blizzard keep their art on their buff and read nil.
The four constructors raise `expected a model path` for a model that is not a string, so a missing art fails at the line
that uses it; an empty string still gives an effect that draws nothing.

```yue
clap = Effect.abilityArt FourCC("AHtc"), EFFECT_TYPE_CASTER
Effect.flash clap, x, y if clap
```

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

### `wrappers.weathereffect`

- `create(Rect, effectId)`
- `enable(flag)`, `enableFor(Player)`, `destroy()`

A weather effect is not drawn until `enable(true)`. `enableFor(Player)` compares with the local player, as
`setVisibleFor` does: the effect exists on every machine and is drawn on that player's only; `enable(flag)` afterwards
applies to everyone. There is no getter for whether it is enabled. The effect reads its rect when it is created and does
not own it, so the rect may be destroyed at once. `create` raises `unknown weather effect id` for an id the game does
not know: Warcraft returns an invalid effect for one, not nil.

The game's weather ids, each created by the v0.8.0 gate on 3.0.0.24268:

| Ids                                                            | Weather                                                  |
| -------------------------------------------------------------- | -------------------------------------------------------- |
| `RAhr`, `RAlr`                                                 | Ashenvale rain, heavy and light                          |
| `RLhr`, `RLlr`                                                 | Lordaeron rain, heavy and light                          |
| `SNbs`, `SNhs`, `SNls`                                         | Northrend blizzard, and snow heavy and light             |
| `WOcw`, `WOlw`                                                 | Outland wind, heavy and light                            |
| `WNcw`                                                         | Wind, heavy                                              |
| `LRaa`, `LRma`                                                 | Rays of light, rays of moonlight                         |
| `MEds`                                                         | Dalaran shield                                           |
| `FDbh`, `FDbl`, `FDgh`, `FDgl`, `FDrh`, `FDrl`, `FDwh`, `FDwl` | Dungeon fog: blue, green, red and white, heavy and light |

```yue
import "wrappers.weathereffect" as WeatherEffect
import "wrappers.rect" as Rect

area = Rect.create -1024, -1024, 1024, 1024
rain = WeatherEffect.create area, FourCC "RAhr"
area\destroy!
rain\enable true
```

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

### `wrappers.damage`

- `onDamaging(callback)` (before armor) and `onDamaged(callback)` (after armor) return a token for `off(token)`
- the event: `source` (a Unit, or nil when the game gives none), `target`, `amount`, `isAttack`, `attackType`,
  `damageType`, `weaponType`
- DAMAGING events: `setAmount(n)`, `setAttackType(t)`, `setDamageType(t)`, `setWeaponType(t)`; DAMAGED events:
  `setAmount(n)`

Every listener of one hit gets the same event, so a change is visible to the listeners after it. Setters work only while
the hit's listeners run; afterwards (for example from a timer) they raise `the damage event is over`. Each phase has one
shared trigger, created by the first listener and disabled while the phase has none.

Measured by the v0.7.0 gate on 3.0.0.24268:

- `isAttack` is what `BlzGetEventIsAttack` reports: false for damage dealt with `unit:damageTarget`, even with its
  `attack` argument true.
- A type change before armor takes effect (magic against a footman's heavy armor doubled the hit); a type change after
  armor, with the raw native, changed nothing.
- When a listener deals damage itself, the nested hit gets its own event, and the outer event's setters still change the
  outer hit afterwards.

```yue
import "wrappers.damage" as Damage

Damage.onDamaging (event) ->
  if event.isAttack
    event\setAmount event.amount * 1.5
```

### `wrappers.sync`

- `send(prefix, data)` returns what `BlzSendSyncData` returns; `data` is at most 255 bytes
- `on(prefix, callback)` returns a token for `off(token)`; the callback gets `(Player, data)`

Call `send` for the local player only, inside a local-player branch; the listeners run on every machine, in the same
order, some frames later (about 0.09 s on one machine). The game cuts longer messages to 255 bytes and still reports
success, so `send` raises instead. Split longer data yourself. Prefixes of 16, 17 and 32 characters arrived whole in the
v0.7.0 gate, so the wrappers only require a non-empty prefix.

```yue
import "wrappers.sync" as Sync

Sync.on "load", (player, data) -> print player\getName!, data
Sync.send "load", code if Player.fromIndex(0)\isLocal!
```

### `wrappers.input`

- `onKeyDown(Player, key, callback, options?)`: the callback gets `(Player, meta, repeated)`; the option `repeats`
  (false) also passes the downs the game repeats while the key is held
- `onKeyUp(Player, key, callback)`: the callback gets `(Player, meta)`
- `onMouseDown(Player, callback)` and `onMouseUp(Player, callback)`: the callback gets `(Player, x, y, button)`
- `onMouseMove(Player, callback)`: the callback gets `(Player, x, y)`
- each returns a token for `off(token)`

Listeners are for one player's keyboard and mouse. The events are synced: a listener runs on every machine, in the same
order, some frames after the input, so it may change game state. Each player and key, and each player and kind of mouse
event, has one shared trigger, created by its first listener and disabled while it has none. The first key listener
also starts one game timer, which the module reads game time from.

Keys are the `OSKEY_` constants. A key listener runs whatever modifier keys are held. `meta` is the sum of
`METAKEY_SHIFT` (1), `METAKEY_CTRL` (2), `METAKEY_ALT` (4) and `METAKEY_WINKEYS` (8); compare it to ask for one
combination, for example `meta == METAKEY_CTRL + METAKEY_SHIFT`. `button` is `MOUSE_BUTTON_TYPE_LEFT`, `_MIDDLE` or
`_RIGHT`.

`onKeyDown` runs once per press. The game repeats the down while a key stays held; those are skipped unless `repeats` is
true, and `repeated` is true for them. The module tells a press from a repeat by remembering that the key is down until
its release arrives.

**A release can be lost.** The game sends no release for a key that is let go while the game takes no keyboard input:
another program in front (Alt+Tab, or a click on another window), the chat box open, or the menu open. Two things
follow:

- **`onKeyUp` does not run for that release,** and nothing in the game says so. A map that keeps its own "this key is
  held" state, for movement on W, A, S and D for example, sees the key as held until it is pressed and let go again.
  Make such a stuck key harmless, or give the player that way out.
- **`onKeyDown` would take the next press for a repeat.** So a down that comes more than two seconds of game time
  after the key's last down counts as a new press: no keyboard repeats that slowly. A press sooner than that after a
  lost release is still skipped, and so is one after the single-player menu, which pauses game time. The skipped
  press's own release then clears the state.

Measured on 3.0.0.24268 (the v0.8.0 probes):

- A held key repeats: the first repeat after half a second, then about 30 a second.
- The game matches the modifier keys exactly, which is why the module registers every combination: a raw
  `BlzTriggerRegisterPlayerKeyEvent` for no modifier does not fire while Shift is held.
- Shift is a key of its own (`OSKEY_LSHIFT`), with its bit already set in `meta` when it goes down.
- Typing in the chat box runs no key listener.
- Mouse points are world coordinates under the cursor. A click on the interface (the minimap) runs the listeners too.
- A quick click delivers its down and its up at the same moment.
- `onMouseMove` runs 150 to 190 times a second while the mouse moves, each a synced event. Add the listener only while
  it is needed, and remove it afterwards.

```yue
import "wrappers.input" as Input

cast = Input.onKeyDown player, OSKEY_Q, (player, meta) ->
  castFor player if meta == METAKEY_NONE

Input.onMouseDown player, (player, x, y, button) ->
  print player\getName!, "clicked at", x, y if button == MOUSE_BUTTON_TYPE_LEFT

Input.off cast
```

Player indices must be integers below `bj_MAX_PLAYER_SLOTS`, including neutral slots. Players have no destruction
method. `setPosition` uses SetUnitPosition, which respects pathing; `setX`/`setY` use SetUnitX/SetUnitY, which do not.
`setPathing(false)` does not let move orders cross trees: in the v0.7.0 gate a footman ordered across a tree line walked
around it. Inventory slots are zero-based integers below `getInventorySize()`. `getItemInSlot`, `removeItemFromSlot`,
`addItemById` and `group:first()` return nil when there is nothing. `group:first()` uses FirstOfGroup, which can also
return nil while the group still holds removed units, so do not loop `while group:first()`; use `forEach` or
`getUnits()`. Hero methods pass through to the natives, so Warcraft's behavior applies to non-heroes. `isLocal()` is
true only on that player's machine: never change synchronized game state inside a branch on it. `enumSelected` inherits
the native's synchronization behavior. `Rect.worldBounds()` allocates a new rect each call; destroy it. SetPlayerName is
deliberately outside the API.

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
its label and nothing else is affected. The labels are `Timer`, `Trigger`, `Dialog button`, `Frame event`,
`Damage listener`, `Sync listener` and `Input listener`, printed as `[wrappers] <label> callback failed: …`, and
`Trigger condition`, printed as `[wrappers] Trigger condition failed: …` (the condition then counts as false).

Timer callbacks receive their Timer; trigger actions and conditions receive their Trigger. Read event context using
ordinary natives, then convert handles with `fromHandle` as needed, or use `fromEvent()`. Registrations pass no native
filter; filter inside a condition or an action. Warcraft cannot unregister an event, so destroying the trigger is the
only way to remove one. `addAction` and `addCondition` return tokens; removing a token takes effect at once, even during
a firing, and removing it twice does nothing. A condition may remove its own token; the evaluation in progress still
counts its result. A token from another trigger raises an error. A condition's result counts as truthy or falsy; if it
raises, the error is printed with `[wrappers] Trigger condition failed:` and the condition counts as false. The trigger
owns each condition's boolexpr and destroys it on removal, on `clearConditions()` and on `destroy()`.

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
