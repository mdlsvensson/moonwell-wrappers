local Handle = require('wrappers.internal.handle')
local Callback = require('wrappers.internal.callback')
local Unit = require('wrappers.unit')

---@class MoonwellWrappers.Group
---@field handle group? Read-only by convention; nil after destruction.
local Group = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Group, group>
local registry = Handle.new(Group, 'Group')

---Raw member handles in native order, skipping nil entries.
---@param raw group
---@return unit[]
local function members(raw)
    local result = {}
    for index = 0, BlzGroupGetSize(raw) - 1 do
        local unit = BlzGroupUnitAt(raw, index)
        if unit then result[#result + 1] = unit end
    end
    return result
end

---@param filter unknown
---@param operation string
local function checkFilter(filter, operation)
    if filter ~= nil then Callback.check(filter, operation) end
end

---Runs the filter over a snapshot, then removes rejected units. If the filter raises, the group is cleared and the
---error re-raised, so a half-filtered group never escapes.
---@param raw group
---@param filter (fun(unit: MoonwellWrappers.Unit): any)?
local function applyFilter(raw, filter)
    if filter == nil then return end
    local rejected = {}
    local ok, message = pcall(function()
        for _, unit in ipairs(members(raw)) do
            if not filter(assert(Unit.fromHandle(unit))) then rejected[#rejected + 1] = unit end
        end
    end)
    if not ok then
        GroupClear(raw)
        error(message, 0)
    end
    for _, unit in ipairs(rejected) do GroupRemoveUnit(raw, unit) end
end

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
---Clears the group, then adds the units within radius; `filter` keeps units for which it returns truthy.
---@param x number
---@param y number
---@param radius number
---@param filter (fun(unit: MoonwellWrappers.Unit): any)?
function Group:enumInRange(x, y, radius, filter)
    local raw = registry.require(self, 'Group.enumInRange')
    Callback.nonnegative(radius, 'Group.enumInRange')
    checkFilter(filter, 'Group.enumInRange')
    GroupClear(raw)
    -- Warcraft accepts a null filter; the generated JASS signature cannot express that.
    ---@diagnostic disable-next-line: param-type-mismatch
    GroupEnumUnitsInRange(raw, x, y, radius, nil)
    applyFilter(raw, filter)
end
---@param rect MoonwellWrappers.Rect
---@param filter (fun(unit: MoonwellWrappers.Unit): any)?
function Group:enumInRect(rect, filter)
    local raw = registry.require(self, 'Group.enumInRect')
    local rawRect = Handle.unwrap(rect, 'Rect', 'Group.enumInRect')
    checkFilter(filter, 'Group.enumInRect')
    GroupClear(raw)
    -- Warcraft accepts a null filter; the generated JASS signature cannot express that.
    ---@diagnostic disable-next-line: param-type-mismatch
    GroupEnumUnitsInRect(raw, rawRect, nil)
    applyFilter(raw, filter)
end
---@param player MoonwellWrappers.Player
---@param filter (fun(unit: MoonwellWrappers.Unit): any)?
function Group:enumOfPlayer(player, filter)
    local raw = registry.require(self, 'Group.enumOfPlayer')
    local rawPlayer = Handle.unwrap(player, 'Player', 'Group.enumOfPlayer')
    checkFilter(filter, 'Group.enumOfPlayer')
    GroupClear(raw)
    -- Warcraft accepts a null filter; the generated JASS signature cannot express that.
    ---@diagnostic disable-next-line: param-type-mismatch
    GroupEnumUnitsOfPlayer(raw, rawPlayer, nil)
    applyFilter(raw, filter)
end
---Inherits the native's synchronization behavior for selections.
---@param player MoonwellWrappers.Player
---@param filter (fun(unit: MoonwellWrappers.Unit): any)?
function Group:enumSelected(player, filter)
    local raw = registry.require(self, 'Group.enumSelected')
    local rawPlayer = Handle.unwrap(player, 'Player', 'Group.enumSelected')
    checkFilter(filter, 'Group.enumSelected')
    GroupClear(raw)
    -- Warcraft accepts a null filter; the generated JASS signature cannot express that.
    ---@diagnostic disable-next-line: param-type-mismatch
    GroupEnumUnitsSelected(raw, rawPlayer, nil)
    applyFilter(raw, filter)
end
---@return integer
function Group:getSize() return BlzGroupGetSize(registry.require(self, 'Group.getSize')) end
---@return MoonwellWrappers.Unit[]
function Group:getUnits()
    local result = {}
    for _, unit in ipairs(members(registry.require(self, 'Group.getUnits'))) do
        result[#result + 1] = assert(Unit.fromHandle(unit))
    end
    return result
end
---Iterates a snapshot; errors propagate to the caller.
---@param callback fun(unit: MoonwellWrappers.Unit): ...
function Group:forEach(callback)
    local raw = registry.require(self, 'Group.forEach')
    Callback.check(callback, 'Group.forEach')
    for _, unit in ipairs(members(raw)) do callback(assert(Unit.fromHandle(unit))) end
end
---@return MoonwellWrappers.Unit?
function Group:first() return Unit.fromHandle(FirstOfGroup(registry.require(self, 'Group.first'))) end
function Group:destroy()
    local raw = registry.dispose(self, 'Group.destroy')
    if raw then DestroyGroup(raw) end
end

return Group
