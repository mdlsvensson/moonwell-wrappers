local Handle = require('wrappers.internal.handle')
local Callback = require('wrappers.internal.callback')
local Unit = require('wrappers.unit')

---@class MoonwellWrappers.Group
---@field handle group? Read-only by convention; nil after destruction.
local Group = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Group, group>
local registry = Handle.new(Group, 'Group')

---@param raw group?
---@return MoonwellWrappers.Group?
---@overload fun(raw: nil): nil
function Group.fromHandle(raw) return registry.wrap(raw) end
---@return MoonwellWrappers.Group
function Group.create() return Handle.created(Group.fromHandle(CreateGroup()), 'Group.create') end
---@return group
function Group:getHandle() return registry.require(self, 'Group.getHandle') end
---@return boolean
function Group:isDisposed() return registry.isDisposed(self, 'Group.isDisposed') end
---@param unit MoonwellWrappers.Unit
function Group:add(unit)
    local raw = registry.require(self, 'Group.add')
    GroupAddUnit(raw, Handle.unwrap(unit, 'Unit', 'Group.add'))
end
---@param unit MoonwellWrappers.Unit
function Group:remove(unit)
    local raw = registry.require(self, 'Group.remove')
    GroupRemoveUnit(raw, Handle.unwrap(unit, 'Unit', 'Group.remove'))
end
---@param unit MoonwellWrappers.Unit
---@return boolean
function Group:contains(unit)
    local raw = registry.require(self, 'Group.contains')
    return IsUnitInGroup(Handle.unwrap(unit, 'Unit', 'Group.contains'), raw)
end
function Group:clear() GroupClear(registry.require(self, 'Group.clear')) end
---@param x number
---@param y number
---@param radius number
function Group:enumInRange(x, y, radius)
    local raw = registry.require(self, 'Group.enumInRange')
    Callback.nonnegative(radius, 'Group.enumInRange')
    GroupClear(raw)
    -- Warcraft accepts a null filter; the generated JASS signature cannot express that.
    ---@diagnostic disable-next-line: param-type-mismatch
    GroupEnumUnitsInRange(raw, x, y, radius, nil)
end
---@return integer
function Group:getSize() return BlzGroupGetSize(registry.require(self, 'Group.getSize')) end
---@return MoonwellWrappers.Unit[]
function Group:getUnits()
    local raw = registry.require(self, 'Group.getUnits')
    local result = {}
    for index = 0, BlzGroupGetSize(raw) - 1 do
        local unit = Unit.fromHandle(BlzGroupUnitAt(raw, index))
        if unit then result[#result + 1] = unit end
    end
    return result
end
function Group:destroy()
    local raw = registry.dispose(self, 'Group.destroy')
    if raw then DestroyGroup(raw) end
end

return Group
