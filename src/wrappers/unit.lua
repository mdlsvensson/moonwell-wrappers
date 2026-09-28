local Handle = require('wrappers.internal.handle')
local Widget = require('wrappers.internal.widget')
local PlayerWrapper = require('wrappers.player')

---@class MoonwellWrappers.Unit: MoonwellWrappers.Widget
---@field handle unit? Read-only by convention; nil after removal.
local Unit = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Unit, unit>
local registry = Handle.new(Unit, 'Unit', {weak = true, widget = true})

---@param raw unit?
---@return MoonwellWrappers.Unit?
---@overload fun(raw: nil): nil
function Unit.fromHandle(raw) return registry.wrap(raw) end

---@param owner MoonwellWrappers.Player
---@param typeId integer
---@param x number
---@param y number
---@param facing number
---@return MoonwellWrappers.Unit
function Unit.create(owner, typeId, x, y, facing)
    local rawOwner = Handle.unwrap(owner, 'Player', 'Unit.create')
    return Handle.created(Unit.fromHandle(CreateUnit(rawOwner, typeId, x, y, facing)), 'Unit.create')
end
---@return unit
function Unit:getHandle() return registry.require(self, 'Unit.getHandle') end
---@return boolean
function Unit:isDisposed() return registry.isDisposed(self, 'Unit.isDisposed') end
---@return integer
function Unit:getTypeId() return GetUnitTypeId(registry.require(self, 'Unit.getTypeId')) end
---@return MoonwellWrappers.Player
function Unit:getOwner()
    return Handle.created(PlayerWrapper.fromHandle(GetOwningPlayer(registry.require(self, 'Unit.getOwner'))), 'Unit.getOwner')
end
---@param owner MoonwellWrappers.Player
---@param changeColor boolean
function Unit:setOwner(owner, changeColor)
    local raw = registry.require(self, 'Unit.setOwner')
    SetUnitOwner(raw, Handle.unwrap(owner, 'Player', 'Unit.setOwner'), changeColor)
end
---@return number
function Unit:getX() return GetUnitX(registry.require(self, 'Unit.getX')) end
---@return number
function Unit:getY() return GetUnitY(registry.require(self, 'Unit.getY')) end
---@param x number
---@param y number
function Unit:setPosition(x, y) SetUnitPosition(registry.require(self, 'Unit.setPosition'), x, y) end
---@return number
function Unit:getFacing() return GetUnitFacing(registry.require(self, 'Unit.getFacing')) end
---@param facing number
function Unit:setFacing(facing) SetUnitFacing(registry.require(self, 'Unit.setFacing'), facing) end
---@return number
function Unit:getLife() return GetWidgetLife(registry.require(self, 'Unit.getLife')) end
---@param value number
function Unit:setLife(value) SetWidgetLife(registry.require(self, 'Unit.setLife'), value) end
---@return integer
function Unit:getMaxLife() return BlzGetUnitMaxHP(registry.require(self, 'Unit.getMaxLife')) end
---@param color playercolor
function Unit:setColor(color) SetUnitColor(registry.require(self, 'Unit.setColor'), color) end
function Unit:kill() KillUnit(registry.require(self, 'Unit.kill')) end
function Unit:remove()
    local raw = registry.dispose(self, 'Unit.remove')
    if raw then RemoveUnit(raw) end
end
---@param order string
---@return boolean
function Unit:issueOrder(order) return IssueImmediateOrder(registry.require(self, 'Unit.issueOrder'), order) end
---@param order string
---@param x number
---@param y number
---@return boolean
function Unit:issuePointOrder(order, x, y)
    return IssuePointOrder(registry.require(self, 'Unit.issuePointOrder'), order, x, y)
end
---@param order string
---@param target MoonwellWrappers.Unit
---@return boolean
function Unit:issueTargetOrder(order, target)
    local raw = registry.require(self, 'Unit.issueTargetOrder')
    return IssueTargetOrder(raw, order, registry.require(target, 'Unit.issueTargetOrder'))
end

-- Unit defines all four shared methods itself (GetUnitX/GetUnitY keep v0.1.0's mapping); install is a no-op here.
Widget.install(Unit, registry)

return Unit
