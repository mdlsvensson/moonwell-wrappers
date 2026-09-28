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
---@param target MoonwellWrappers.Unit
---@param attachmentPoint string
---@return MoonwellWrappers.Effect
function Effect.attach(model, target, attachmentPoint)
    local raw = Handle.unwrap(target, 'Unit', 'Effect.attach')
    return Handle.created(Effect.fromHandle(AddSpecialEffectTarget(model, raw, attachmentPoint)), 'Effect.attach')
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
function Effect:destroy()
    local raw = registry.dispose(self, 'Effect.destroy')
    if raw then DestroyEffect(raw) end
end

return Effect
