local Handle = require('wrappers.internal.handle')

---@class MoonwellWrappers.Rect
---@field handle rect? Read-only by convention; nil after destruction.
local RectWrapper = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Rect, rect>
local registry = Handle.new(RectWrapper, 'Rect')

---@param raw rect?
---@return MoonwellWrappers.Rect?
---@overload fun(raw: nil): nil
function RectWrapper.fromHandle(raw) return registry.wrap(raw) end
---@param minX number
---@param minY number
---@param maxX number
---@param maxY number
---@return MoonwellWrappers.Rect
function RectWrapper.create(minX, minY, maxX, maxY)
    return (Handle.created(RectWrapper.fromHandle(Rect(minX, minY, maxX, maxY)), 'Rect.create'))
end
---GetWorldBounds allocates a new rect on every call: the result is owned; destroy it.
---@return MoonwellWrappers.Rect
function RectWrapper.createWorldBounds()
    return (Handle.created(RectWrapper.fromHandle(GetWorldBounds()), 'Rect.createWorldBounds'))
end
---@return rect
function RectWrapper:getHandle() return (registry.require(self, 'Rect.getHandle')) end
---@return boolean
function RectWrapper:isDisposed() return (registry.isDisposed(self, 'Rect.isDisposed')) end
---@return number
function RectWrapper:getMinX() return GetRectMinX(registry.require(self, 'Rect.getMinX')) end
---@return number
function RectWrapper:getMinY() return GetRectMinY(registry.require(self, 'Rect.getMinY')) end
---@return number
function RectWrapper:getMaxX() return GetRectMaxX(registry.require(self, 'Rect.getMaxX')) end
---@return number
function RectWrapper:getMaxY() return GetRectMaxY(registry.require(self, 'Rect.getMaxY')) end
---@return number
function RectWrapper:getCenterX() return GetRectCenterX(registry.require(self, 'Rect.getCenterX')) end
---@return number
function RectWrapper:getCenterY() return GetRectCenterY(registry.require(self, 'Rect.getCenterY')) end
---@param minX number
---@param minY number
---@param maxX number
---@param maxY number
function RectWrapper:set(minX, minY, maxX, maxY) SetRect(registry.require(self, 'Rect.set'), minX, minY, maxX, maxY) end
---@param x number
---@param y number
function RectWrapper:moveTo(x, y) MoveRectTo(registry.require(self, 'Rect.moveTo'), x, y) end
function RectWrapper:destroy()
    local raw = registry.dispose(self, 'Rect.destroy')
    if raw then RemoveRect(raw) end
end

return RectWrapper
