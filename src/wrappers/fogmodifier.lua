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
---@param useSharedVision boolean? Default false.
---@param afterUnits boolean? Default false.
---@return MoonwellWrappers.FogModifier
function FogModifier.createRadius(player, state, x, y, radius, useSharedVision, afterUnits)
    local rawPlayer = Handle.unwrap(player, 'Player', 'FogModifier.createRadius')
    local raw = CreateFogModifierRadius(rawPlayer, state, x, y, radius, useSharedVision or false, afterUnits or false)
    return (Handle.created(FogModifier.fromHandle(raw), 'FogModifier.createRadius'))
end
---Creates a stopped modifier; call start(). The modifier does not own the rect.
---@param player MoonwellWrappers.Player
---@param state fogstate
---@param rect MoonwellWrappers.Rect
---@param useSharedVision boolean? Default false.
---@param afterUnits boolean? Default false.
---@return MoonwellWrappers.FogModifier
function FogModifier.createRect(player, state, rect, useSharedVision, afterUnits)
    local rawPlayer = Handle.unwrap(player, 'Player', 'FogModifier.createRect')
    local rawRect = Handle.unwrap(rect, 'Rect', 'FogModifier.createRect')
    local raw = CreateFogModifierRect(rawPlayer, state, rawRect, useSharedVision or false, afterUnits or false)
    return (Handle.created(FogModifier.fromHandle(raw), 'FogModifier.createRect'))
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
