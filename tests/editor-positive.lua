local Unit = require('wrappers.unit')
local PlayerWrapper = require('wrappers.player')
local Timer = require('wrappers.timer')
local Trigger = require('wrappers.trigger')
local Group = require('wrappers.group')
local Effect = require('wrappers.effect')

local unit = Unit.create(PlayerWrapper.fromIndex(0), 1751543663, 0, 0, 270)
unit:setPosition(1, 2)
unit:setLife(unit:getMaxLife())
local group = Group.create()
group:add(unit)
for _, member in ipairs(group:getUnits()) do member:setLife(100) end
local effect = Effect.attach('model.mdx', unit, 'origin')
effect:setScale(0.5)
local timer = Timer.create()
timer:start(1, false, function(self) self:pause(); self:destroy(); return 1 end)
local trigger = Trigger.create()
trigger:registerUnitEvent(unit, EVENT_UNIT_DEATH)
trigger:addAction(function(self) self:disable(); return 2 end)
---@type unit?
local maybeRaw = unit.handle
local maybe = Unit.fromHandle(maybeRaw)
if maybe then maybe:setLife(50) end
---@type nil
local absent = Unit.fromHandle(nil)
assert(absent == nil)
---@type MoonwellWrappers.Unit
local definite = assert(Unit.fromHandle(unit:getHandle()))
definite:kill()
effect:destroy()
group:destroy()
trigger:destroy()
unit:remove()
return true
