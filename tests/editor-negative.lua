local Unit = require('wrappers.unit')
local PlayerWrapper = require('wrappers.player')
local Timer = require('wrappers.timer')
local Group = require('wrappers.group')
local Item = require('wrappers.item')
local Destructable = require('wrappers.destructable')
local Trigger = require('wrappers.trigger')
local Effect = require('wrappers.effect')
local TextTag = require('wrappers.texttag')
local Dialog = require('wrappers.dialog')
local Multiboard = require('wrappers.multiboard')
local Frame = require('wrappers.frame')
local unit = Unit.create(PlayerWrapper.fromIndex(0), 1751543663, 0, 0, 0)
Group.create():add(Timer.create()) -- EXPECT param-type-mismatch
unit:nonexistentMethod() -- EXPECT undefined-field
Timer.create():start(1, false, function(self)
    Group.create():add(self) -- EXPECT param-type-mismatch
end)
---@type unit?
local maybeRaw = unit.handle
local maybe = Unit.fromHandle(maybeRaw)
if maybe then
    ---@type MoonwellWrappers.Timer
    local wrong = maybe -- EXPECT assign-type-mismatch
    wrong:destroy()
end
local trigger = Trigger.create()
trigger:registerDeathEvent(Timer.create()) -- EXPECT param-type-mismatch
trigger:removeAction(trigger:addCondition(function() return true end)) -- EXPECT param-type-mismatch
Item.create(1, 0, 0):nonexistentMethod() -- EXPECT undefined-field
-- LuaLS 3.19.1 reports need-check-nil on a nullable local, not on a chained call result.
local slotItem = unit:getItemInSlot(0)
slotItem:setCharges(1) -- EXPECT need-check-nil
Effect.attach('model.mdx', Timer.create(), 'origin') -- EXPECT param-type-mismatch
-- Warcraft draws no effect attached to an item or a destructable (v0.3.0 gate), so the editor flags them.
Effect.attach('model.mdx', Item.create(1, 0, 0), 'origin') -- EXPECT param-type-mismatch
Effect.flashOn('model.mdx', Destructable.create(1, 0, 0, 0, 1, 0), 'origin') -- EXPECT param-type-mismatch
TextTag.create():setVisibleFor(unit) -- EXPECT param-type-mismatch
TextTag.float('x', 0, 0, {size = 'big'}) -- EXPECT assign-type-mismatch
Dialog.create():addButton('x', nil, function(player) Group.create():add(player) end) -- EXPECT param-type-mismatch
Multiboard.create(1, 1):setVisibleFor(unit) -- EXPECT param-type-mismatch
Frame.create('EscMenuBackdrop', unit) -- EXPECT param-type-mismatch
Frame.origin(ORIGIN_FRAME_GAME_UI):on(FRAMEEVENT_CONTROL_CLICK, function(player) Group.create():add(player) end) -- EXPECT param-type-mismatch
local Damage = require('wrappers.damage')
local Sync = require('wrappers.sync')
Damage.onDamaged(function(event) event:setDamageType(DAMAGE_TYPE_UNIVERSAL) end) -- EXPECT undefined-field
Sync.on('load', function(player) Group.create():add(player) end) -- EXPECT param-type-mismatch
Damage.off(Sync.on('load', function() end)) -- EXPECT param-type-mismatch
local Input = require('wrappers.input')
local WeatherEffect = require('wrappers.weathereffect')
local owner = PlayerWrapper.fromIndex(0)
Input.onKeyDown(owner, OSKEY_Q, function(player) Group.create():add(player) end) -- EXPECT param-type-mismatch
Input.onMouseDown(unit, function() end) -- EXPECT param-type-mismatch
Input.off(Sync.on('load', function() end)) -- EXPECT param-type-mismatch
WeatherEffect.create(unit, 1380018290) -- EXPECT param-type-mismatch
Effect.flash(Effect.abilityArt(1095267427, EFFECT_TYPE_CASTER), 0, 0) -- EXPECT param-type-mismatch
trigger:registerTimerExpireEvent(unit) -- EXPECT param-type-mismatch
Unit.autoDispose('fast') -- EXPECT param-type-mismatch
local eventUnit = Unit.fromEvent()
eventUnit:kill() -- EXPECT need-check-nil
return true
