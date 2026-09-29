local Unit = require('wrappers.unit')
local PlayerWrapper = require('wrappers.player')
local Timer = require('wrappers.timer')
local Group = require('wrappers.group')
local Item = require('wrappers.item')
local Trigger = require('wrappers.trigger')
local Effect = require('wrappers.effect')
local TextTag = require('wrappers.texttag')
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
TextTag.create():setVisibleFor(unit) -- EXPECT param-type-mismatch
TextTag.float('x', 0, 0, {size = 'big'}) -- EXPECT assign-type-mismatch
return true
