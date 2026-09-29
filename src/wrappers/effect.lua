local Handle = require('wrappers.internal.handle')

---@class MoonwellWrappers.Effect
---@field handle effect? Read-only by convention; nil after destruction.
local Effect = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Effect, effect>
local registry = Handle.new(Effect, 'Effect')

---@param raw effect?
---@return MoonwellWrappers.Effect?
---@overload fun(raw: nil): nil
function Effect.fromHandle(raw) return registry.wrap(raw) end
---@param model string
---@param x number
---@param y number
---@return MoonwellWrappers.Effect
function Effect.create(model, x, y)
    return Handle.created(Effect.fromHandle(AddSpecialEffect(model, x, y)), 'Effect.create')
end
---@param model string
---@param target MoonwellWrappers.Widget
---@param attachmentPoint string
---@return MoonwellWrappers.Effect
function Effect.attach(model, target, attachmentPoint)
    local raw = Handle.unwrapWidget(target, 'Effect.attach')
    return Handle.created(Effect.fromHandle(AddSpecialEffectTarget(model, raw, attachmentPoint)), 'Effect.attach')
end
---Creates and destroys an effect at once, which plays its death animation. Returns nothing.
---@param model string
---@param x number
---@param y number
function Effect.flash(model, x, y)
    DestroyEffect(Handle.created(AddSpecialEffect(model, x, y), 'Effect.flash'))
end
---Attaches and destroys an effect at once, which plays its death animation. Returns nothing.
---@param model string
---@param target MoonwellWrappers.Widget
---@param attachmentPoint string
function Effect.flashOn(model, target, attachmentPoint)
    local raw = Handle.unwrapWidget(target, 'Effect.flashOn')
    DestroyEffect(Handle.created(AddSpecialEffectTarget(model, raw, attachmentPoint), 'Effect.flashOn'))
end
---@return effect
function Effect:getHandle() return registry.require(self, 'Effect.getHandle') end
---@return boolean
function Effect:isDisposed() return registry.isDisposed(self, 'Effect.isDisposed') end
---@param x number
---@param y number
---@param z number
function Effect:setPosition(x, y, z)
    BlzSetSpecialEffectPosition(registry.require(self, 'Effect.setPosition'), x, y, z)
end
---@param scale number
function Effect:setScale(scale) BlzSetSpecialEffectScale(registry.require(self, 'Effect.setScale'), scale) end
---@param r integer 0-255
---@param g integer 0-255
---@param b integer 0-255
function Effect:setColor(r, g, b) BlzSetSpecialEffectColor(registry.require(self, 'Effect.setColor'), r, g, b) end
---@param alpha integer 0-255
function Effect:setAlpha(alpha) BlzSetSpecialEffectAlpha(registry.require(self, 'Effect.setAlpha'), alpha) end
---@param player MoonwellWrappers.Player
function Effect:setPlayerColor(player)
    local raw = registry.require(self, 'Effect.setPlayerColor')
    BlzSetSpecialEffectColorByPlayer(raw, Handle.unwrap(player, 'Player', 'Effect.setPlayerColor'))
end
---@param scale number
function Effect:setTimeScale(scale)
    BlzSetSpecialEffectTimeScale(registry.require(self, 'Effect.setTimeScale'), scale)
end
---@param yaw number Radians.
---@param pitch number Radians.
---@param roll number Radians.
function Effect:setOrientation(yaw, pitch, roll)
    BlzSetSpecialEffectOrientation(registry.require(self, 'Effect.setOrientation'), yaw, pitch, roll)
end
---@param height number
function Effect:setHeight(height) BlzSetSpecialEffectHeight(registry.require(self, 'Effect.setHeight'), height) end
---@param z number
function Effect:setZ(z) BlzSetSpecialEffectZ(registry.require(self, 'Effect.setZ'), z) end
---@param animation animtype
function Effect:playAnimation(animation)
    BlzPlaySpecialEffect(registry.require(self, 'Effect.playAnimation'), animation)
end
function Effect:destroy()
    local raw = registry.dispose(self, 'Effect.destroy')
    if raw then DestroyEffect(raw) end
end

return Effect
