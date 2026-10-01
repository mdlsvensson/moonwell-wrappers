local Handle = require('wrappers.internal.handle')

---@class MoonwellWrappers.Effect
---@field handle effect? Read-only by convention; nil after destruction.
local Effect = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Effect, effect>
local registry = Handle.new(Effect, 'Effect')

---A model that is not a string, such as a missing Effect.abilityArt, fails at the caller instead of drawing nothing.
---@param model unknown
---@param operation string
local function checkModel(model, operation)
    if type(model) ~= 'string' then error('[wrappers] ' .. operation .. ': expected a model path', 3) end
end

---@param raw effect?
---@return MoonwellWrappers.Effect?
---@overload fun(raw: nil): nil
function Effect.fromHandle(raw) return registry.wrap(raw) end
---The art an ability's data names for an effect type: a model path, or a lightning code for EFFECT_TYPE_LIGHTNING.
---Returns nil when the ability has none. Past the last entry of a list the game reads the last entry.
---@param abilityId integer
---@param effectType effecttype
---@param index integer? Which entry of a list, from 1. Default 1.
---@return string?
function Effect.abilityArt(abilityId, effectType, index)
    if index == nil then index = 1 end
    if type(index) ~= 'number' or index % 1 ~= 0 or index < 1 then
        error('[wrappers] Effect.abilityArt: expected a positive integer index', 2)
    end
    local art = GetAbilityEffectById(abilityId, effectType, index - 1)
    if art == '' then return nil end
    return art
end
---@param model string
---@param x number
---@param y number
---@return MoonwellWrappers.Effect
function Effect.create(model, x, y)
    checkModel(model, 'Effect.create')
    return (Handle.created(Effect.fromHandle(AddSpecialEffect(model, x, y)), 'Effect.create'))
end
---Takes a Unit in the editor: Warcraft draws no effect attached to an item or a destructable (v0.3.0 gate). The
---runtime still accepts any Widget, for custom models.
---@param model string
---@param target MoonwellWrappers.Unit
---@param attachmentPoint string
---@return MoonwellWrappers.Effect
function Effect.attach(model, target, attachmentPoint)
    checkModel(model, 'Effect.attach')
    local raw = Handle.unwrapWidget(target, 'Effect.attach')
    return (Handle.created(Effect.fromHandle(AddSpecialEffectTarget(model, raw, attachmentPoint)), 'Effect.attach'))
end
---Creates and destroys an effect at once, which plays its death animation. Returns nothing.
---@param model string
---@param x number
---@param y number
function Effect.flash(model, x, y)
    checkModel(model, 'Effect.flash')
    DestroyEffect(Handle.created(AddSpecialEffect(model, x, y), 'Effect.flash'))
end
---Attaches and destroys an effect at once, which plays its death animation. Returns nothing. Takes a Unit in the
---editor, like Effect.attach.
---@param model string
---@param target MoonwellWrappers.Unit
---@param attachmentPoint string
function Effect.flashOn(model, target, attachmentPoint)
    checkModel(model, 'Effect.flashOn')
    local raw = Handle.unwrapWidget(target, 'Effect.flashOn')
    DestroyEffect(Handle.created(AddSpecialEffectTarget(model, raw, attachmentPoint), 'Effect.flashOn'))
end
---@return effect
function Effect:getHandle() return (registry.require(self, 'Effect.getHandle')) end
---@return boolean
function Effect:isDisposed() return (registry.isDisposed(self, 'Effect.isDisposed')) end
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
