local Handle = require('wrappers.internal.handle')
local Check = require('wrappers.internal.check')

---@class MoonwellWrappers.Lightning
---@field handle lightning? Read-only by convention; nil after destruction.
local Lightning = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Lightning, lightning>
local registry = Handle.new(Lightning, 'Lightning')

---@param raw lightning?
---@return MoonwellWrappers.Lightning?
---@overload fun(raw: nil): nil
function Lightning.fromHandle(raw) return registry.wrap(raw) end
---A code that is not a string, such as a missing Effect.abilityArt, fails at the caller instead of drawing nothing.
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
    Check.requireText(code, 'a lightning code', 'Lightning.create')
    local raw = AddLightningEx(code, checkVisibility or false, x1, y1, z1, x2, y2, z2)
    return (Handle.created(Lightning.fromHandle(raw), 'Lightning.create'))
end
---@return lightning
function Lightning:getHandle() return (registry.require(self, 'Lightning.getHandle')) end
---@return boolean
function Lightning:isDisposed() return (registry.isDisposed(self, 'Lightning.isDisposed')) end
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
---The native takes 0 to 1 per channel; this divides by 255.
---@param r integer 0-255
---@param g integer 0-255
---@param b integer 0-255
---@param a integer 0-255
---@return boolean
function Lightning:setColor(r, g, b, a)
    local raw = registry.require(self, 'Lightning.setColor')
    Check.requireInteger(r, 'red', 'Lightning.setColor', 0, 0, 255)
    Check.requireInteger(g, 'green', 'Lightning.setColor', 0, 0, 255)
    Check.requireInteger(b, 'blue', 'Lightning.setColor', 0, 0, 255)
    Check.requireInteger(a, 'alpha', 'Lightning.setColor', 0, 0, 255)
    return SetLightningColor(raw, r / 255, g / 255, b / 255, a / 255)
end
function Lightning:destroy()
    local raw = registry.dispose(self, 'Lightning.destroy')
    if raw then DestroyLightning(raw) end
end

return Lightning
