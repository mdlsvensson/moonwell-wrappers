local Handle = require('wrappers.internal.handle')
local Callback = require('wrappers.internal.callback')
local Check = require('wrappers.internal.check')
local Unit = require('wrappers.unit')

---@class MoonwellWrappers.Group
---@field handle group? Read-only by convention; nil after destruction.
local Group = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Group, group>
local registry = Handle.new(Group, 'Group')

---Wrappers of the members in native order, skipping nil entries. Every unit is wrapped before any callback runs, so a
---unit removed mid-iteration keeps its disposed wrapper. `raws`, when given, receives the raw handle at each index.
---@param raw group
---@param raws (unit|false)[]?
---@return MoonwellWrappers.Unit[]
local function snapshot(raw, raws)
    local result, count = {}, 0
    for index = 0, BlzGroupGetSize(raw) - 1 do
        local unit = BlzGroupUnitAt(raw, index)
        local wrapper = Unit.fromHandle(unit)
        if wrapper then
            count = count + 1
            result[count] = wrapper
            if raws then raws[count] = unit end
        end
    end
    return result
end

---Runs the filter over every unit of a snapshot and puts false in `raws` at the index of each unit it keeps, so that
---`raws` is left with the handles to remove. A file-level function, so that a filtered enumeration makes no closure.
---@param units MoonwellWrappers.Unit[]
---@param raws (unit|false)[]
---@param filter fun(unit: MoonwellWrappers.Unit): any
local function sift(units, raws, filter)
    for index = 1, #units do
        if filter(units[index]) then raws[index] = false end
    end
end

---Runs the filter over a snapshot, then removes rejected units. If the filter raises, the group is cleared and the
---error re-raised, so a half-filtered group never escapes.
---@param raw group
---@param filter (fun(unit: MoonwellWrappers.Unit): any)?
local function applyFilter(raw, filter)
    if filter == nil then return end
    ---@type (unit|false)[]
    local raws = {}
    local units = snapshot(raw, raws)
    local ok, message = pcall(sift, units, raws, filter)
    if not ok then
        GroupClear(raw)
        error(message, 0)
    end
    for index = 1, #units do
        local rejected = raws[index]
        if rejected then GroupRemoveUnit(raw, rejected) end
    end
end

---@param raw group?
---@return MoonwellWrappers.Group?
---@overload fun(raw: nil): nil
function Group.fromHandle(raw) return registry.wrap(raw) end
---@return MoonwellWrappers.Group
function Group.create() return (Handle.created(Group.fromHandle(CreateGroup()), 'Group.create')) end
---@return group
function Group:getHandle() return (registry.require(self, 'Group.getHandle')) end
---@return boolean
function Group:isDisposed() return (registry.isDisposed(self, 'Group.isDisposed')) end
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
    Check.requireNonNegative(radius, 'radius', 'Group.enumInRange')
    Callback.optional(filter, 'Group.enumInRange')
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
    Callback.optional(filter, 'Group.enumInRect')
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
    Callback.optional(filter, 'Group.enumOfPlayer')
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
    Callback.optional(filter, 'Group.enumSelected')
    GroupClear(raw)
    -- Warcraft accepts a null filter; the generated JASS signature cannot express that.
    ---@diagnostic disable-next-line: param-type-mismatch
    GroupEnumUnitsSelected(raw, rawPlayer, nil)
    applyFilter(raw, filter)
end
---@return integer
function Group:getSize() return BlzGroupGetSize(registry.require(self, 'Group.getSize')) end
---@return MoonwellWrappers.Unit[]
function Group:getUnits() return snapshot(registry.require(self, 'Group.getUnits')) end
---Iterates a getUnits() snapshot; errors propagate to the caller.
---@param callback fun(unit: MoonwellWrappers.Unit): ...
function Group:forEach(callback)
    local raw = registry.require(self, 'Group.forEach')
    Callback.check(callback, 'Group.forEach')
    for _, unit in ipairs(snapshot(raw)) do callback(unit) end
end
---@return MoonwellWrappers.Unit?
function Group:first() return Unit.fromHandle(FirstOfGroup(registry.require(self, 'Group.first'))) end
function Group:destroy()
    local raw = registry.dispose(self, 'Group.destroy')
    if raw then DestroyGroup(raw) end
end

return Group
