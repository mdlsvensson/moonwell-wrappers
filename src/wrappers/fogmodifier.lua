local Handle = require('wrappers.internal.handle')

---@class MoonwellWrappers.FogModifier
---@field handle fogmodifier? Read-only by convention; nil after destruction.
local FogModifier = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.FogModifier, fogmodifier>
local registry = Handle.new(FogModifier, 'FogModifier')

---@param raw fogmodifier?
---@return MoonwellWrappers.FogModifier?
---@overload fun(raw: nil): nil
function FogModifier.fromHandle(raw) return registry.wrap(raw) end
---Creates a stopped modifier; call start().
---@param player MoonwellWrappers.Player
---@param state fogstate
---@param x number
---@param y number
---@param radius number
---@param useSharedVision boolean
---@param afterUnits boolean
---@return MoonwellWrappers.FogModifier
function FogModifier.radius(player, state, x, y, radius, useSharedVision, afterUnits)
    local rawPlayer = Handle.unwrap(player, 'Player', 'FogModifier.radius')
    local raw = CreateFogModifierRadius(rawPlayer, state, x, y, radius, useSharedVision, afterUnits)
    return (Handle.created(FogModifier.fromHandle(raw), 'FogModifier.radius'))
end
---Creates a stopped modifier; call start(). The modifier does not own the rect.
---@param player MoonwellWrappers.Player
---@param state fogstate
---@param rect MoonwellWrappers.Rect
---@param useSharedVision boolean
---@param afterUnits boolean
---@return MoonwellWrappers.FogModifier
function FogModifier.rect(player, state, rect, useSharedVision, afterUnits)
    local rawPlayer = Handle.unwrap(player, 'Player', 'FogModifier.rect')
    local rawRect = Handle.unwrap(rect, 'Rect', 'FogModifier.rect')
    local raw = CreateFogModifierRect(rawPlayer, state, rawRect, useSharedVision, afterUnits)
    return (Handle.created(FogModifier.fromHandle(raw), 'FogModifier.rect'))
end
---@return fogmodifier
function FogModifier:getHandle() return (registry.require(self, 'FogModifier.getHandle')) end
---@return boolean
function FogModifier:isDisposed() return (registry.isDisposed(self, 'FogModifier.isDisposed')) end
function FogModifier:start() FogModifierStart(registry.require(self, 'FogModifier.start')) end
function FogModifier:stop() FogModifierStop(registry.require(self, 'FogModifier.stop')) end
function FogModifier:destroy()
    local raw = registry.dispose(self, 'FogModifier.destroy')
    if raw then DestroyFogModifier(raw) end
end

return FogModifier
