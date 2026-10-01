local Handle = require('wrappers.internal.handle')

---@class MoonwellWrappers.Region
---@field handle region? Read-only by convention; nil after destruction.
local Region = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Region, region>
local registry = Handle.new(Region, 'Region')

---@param raw region?
---@return MoonwellWrappers.Region?
---@overload fun(raw: nil): nil
function Region.fromHandle(raw) return registry.wrap(raw) end
---The region the running event is about (GetTriggeringRegion), or nil when it has none.
---@return MoonwellWrappers.Region?
function Region.fromEvent() return registry.wrap(GetTriggeringRegion()) end
---@return MoonwellWrappers.Region
function Region.create() return (Handle.created(Region.fromHandle(CreateRegion()), 'Region.create')) end
---@return region
function Region:getHandle() return (registry.require(self, 'Region.getHandle')) end
---@return boolean
function Region:isDisposed() return (registry.isDisposed(self, 'Region.isDisposed')) end
---@param rect MoonwellWrappers.Rect
function Region:addRect(rect)
    local raw = registry.require(self, 'Region.addRect')
    RegionAddRect(raw, Handle.unwrap(rect, 'Rect', 'Region.addRect'))
end
---@param rect MoonwellWrappers.Rect
function Region:clearRect(rect)
    local raw = registry.require(self, 'Region.clearRect')
    RegionClearRect(raw, Handle.unwrap(rect, 'Rect', 'Region.clearRect'))
end
---@param x number
---@param y number
function Region:addCell(x, y) RegionAddCell(registry.require(self, 'Region.addCell'), x, y) end
---@param x number
---@param y number
function Region:clearCell(x, y) RegionClearCell(registry.require(self, 'Region.clearCell'), x, y) end
---@param x number
---@param y number
---@return boolean
function Region:containsPoint(x, y) return IsPointInRegion(registry.require(self, 'Region.containsPoint'), x, y) end
---@param unit MoonwellWrappers.Unit
---@return boolean
function Region:containsUnit(unit)
    local raw = registry.require(self, 'Region.containsUnit')
    return IsUnitInRegion(raw, Handle.unwrap(unit, 'Unit', 'Region.containsUnit'))
end
---A region does not own its rects.
function Region:destroy()
    local raw = registry.dispose(self, 'Region.destroy')
    if raw then RemoveRegion(raw) end
end

return Region
