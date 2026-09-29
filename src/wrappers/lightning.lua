local Handle = require('wrappers.internal.handle')

---@class MoonwellWrappers.Lightning
---@field handle lightning? Read-only by convention; nil after destruction.
local Lightning = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Lightning, lightning>
local registry = Handle.new(Lightning, 'Lightning')

---@param raw lightning?
---@return MoonwellWrappers.Lightning?
---@overload fun(raw: nil): nil
function Lightning.fromHandle(raw) return registry.wrap(raw) end
---@param code string Lightning type, such as "CLPB".
---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@param checkVisibility boolean? Default false.
---@return MoonwellWrappers.Lightning
function Lightning.create(code, x1, y1, z1, x2, y2, z2, checkVisibility)
    local raw = AddLightningEx(code, checkVisibility or false, x1, y1, z1, x2, y2, z2)
    return Handle.created(Lightning.fromHandle(raw), 'Lightning.create')
end
---@return lightning
function Lightning:getHandle() return registry.require(self, 'Lightning.getHandle') end
---@return boolean
function Lightning:isDisposed() return registry.isDisposed(self, 'Lightning.isDisposed') end
---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@param checkVisibility boolean? Default false.
---@return boolean
function Lightning:move(x1, y1, z1, x2, y2, z2, checkVisibility)
    local raw = registry.require(self, 'Lightning.move')
    return MoveLightningEx(raw, checkVisibility or false, x1, y1, z1, x2, y2, z2)
end
---@param r number 0-1
---@param g number 0-1
---@param b number 0-1
---@param a number 0-1
---@return boolean
function Lightning:setColor(r, g, b, a) return SetLightningColor(registry.require(self, 'Lightning.setColor'), r, g, b, a) end
function Lightning:destroy()
    local raw = registry.dispose(self, 'Lightning.destroy')
    if raw then DestroyLightning(raw) end
end

return Lightning
