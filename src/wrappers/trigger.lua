local Handle = require('wrappers.internal.handle')
local Callback = require('wrappers.internal.callback')
local Unit = require('wrappers.unit')
local PlayerWrapper = require('wrappers.player')

---@class MoonwellWrappers.Trigger
---@field handle trigger? Read-only by convention; nil after destruction.
local Trigger = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Trigger, trigger>
local registry = Handle.new(Trigger, 'Trigger')
---@type table<MoonwellWrappers.Trigger, {callback: (fun(trigger: MoonwellWrappers.Trigger): ...)?}[]>
local actions = {}

---@param raw trigger?
---@return MoonwellWrappers.Trigger?
---@overload fun(raw: nil): nil
function Trigger.fromHandle(raw) return registry.wrap(raw) end
---@return MoonwellWrappers.Trigger
function Trigger.create() return Handle.created(Trigger.fromHandle(CreateTrigger()), 'Trigger.create') end
---@return trigger
function Trigger:getHandle() return registry.require(self, 'Trigger.getHandle') end
---@return boolean
function Trigger:isDisposed() return registry.isDisposed(self, 'Trigger.isDisposed') end
function Trigger:enable() EnableTrigger(registry.require(self, 'Trigger.enable')) end
function Trigger:disable() DisableTrigger(registry.require(self, 'Trigger.disable')) end
---@return boolean
function Trigger:isEnabled() return IsTriggerEnabled(registry.require(self, 'Trigger.isEnabled')) end

---@param unit MoonwellWrappers.Unit
---@param event unitevent
function Trigger:registerUnitEvent(unit, event)
    local raw = registry.require(self, 'Trigger.registerUnitEvent')
    TriggerRegisterUnitEvent(raw, Unit.getHandle(unit), event)
end
---@param player MoonwellWrappers.Player
---@param event playerunitevent
function Trigger:registerPlayerUnitEvent(player, event)
    local raw = registry.require(self, 'Trigger.registerPlayerUnitEvent')
    -- Warcraft accepts a null filter; the generated JASS signature cannot express that.
    ---@diagnostic disable-next-line: param-type-mismatch
    TriggerRegisterPlayerUnitEvent(raw, PlayerWrapper.getHandle(player), event, nil)
end
---@param timeout number
---@param periodic boolean
function Trigger:registerTimerEvent(timeout, periodic)
    local raw = registry.require(self, 'Trigger.registerTimerEvent')
    Callback.nonnegative(timeout, 'Trigger.registerTimerEvent')
    TriggerRegisterTimerEvent(raw, timeout, periodic)
end
---@param callback fun(trigger: MoonwellWrappers.Trigger): ...
function Trigger:addAction(callback)
    local raw = registry.require(self, 'Trigger.addAction')
    Callback.check(callback, 'Trigger.addAction')
    local cell = {callback = callback}
    local list = actions[self] or {}
    list[#list + 1] = cell
    actions[self] = list
    TriggerAddAction(raw, function()
        if cell.callback then Callback.call('Trigger', cell.callback, self) end
    end)
end
function Trigger:destroy()
    local raw = registry.dispose(self, 'Trigger.destroy')
    if not raw then return end
    for _, cell in ipairs(actions[self] or {}) do cell.callback = nil end
    actions[self] = nil
    DestroyTrigger(raw)
end

return Trigger
