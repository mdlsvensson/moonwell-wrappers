local Handle = require('wrappers.internal.handle')

---@class MoonwellWrappers.DefeatCondition
---@field handle defeatcondition? Read-only by convention; nil after destruction.
local DefeatCondition = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.DefeatCondition, defeatcondition>
local registry = Handle.new(DefeatCondition, 'DefeatCondition')

---@param raw defeatcondition?
---@return MoonwellWrappers.DefeatCondition?
---@overload fun(raw: nil): nil
function DefeatCondition.fromHandle(raw) return registry.wrap(raw) end
---A defeat condition listed in the quest log.
---@param description string?
---@return MoonwellWrappers.DefeatCondition
function DefeatCondition.create(description)
    local raw = CreateDefeatCondition()
    local condition = Handle.created(DefeatCondition.fromHandle(raw), 'DefeatCondition.create')
    if description ~= nil then DefeatConditionSetDescription(raw, description) end
    return condition
end
---@return defeatcondition
function DefeatCondition:getHandle() return (registry.require(self, 'DefeatCondition.getHandle')) end
---@return boolean
function DefeatCondition:isDisposed() return (registry.isDisposed(self, 'DefeatCondition.isDisposed')) end
---@param text string
function DefeatCondition:setDescription(text)
    DefeatConditionSetDescription(registry.require(self, 'DefeatCondition.setDescription'), text)
end
function DefeatCondition:destroy()
    local raw = registry.dispose(self, 'DefeatCondition.destroy')
    if raw then DestroyDefeatCondition(raw) end
end

return DefeatCondition
