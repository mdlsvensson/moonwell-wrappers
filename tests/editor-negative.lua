local Unit = require('wrappers.unit')
local PlayerWrapper = require('wrappers.player')
local Timer = require('wrappers.timer')
local Group = require('wrappers.group')
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
return true
