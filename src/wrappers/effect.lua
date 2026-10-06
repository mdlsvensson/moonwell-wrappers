local Handle = require('wrappers.internal.handle')
local Check = require('wrappers.internal.check')

---@class MoonwellWrappers.Effect
---@field handle effect? Read-only by convention; nil after destruction.
local Effect = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Effect, effect>
local registry = Handle.new(Effect, 'Effect')

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
    Check.requireInteger(index, 'index', 'Effect.abilityArt', 0, 1)
    local art = GetAbilityEffectById(abilityId, effectType, index - 1)
    if art == '' then return nil end
    return art
end
---A model that is not a string, such as a missing Effect.abilityArt, fails at the caller instead of drawing nothing.
---The same holds for attach, flash and flashOn.
---@param model string
---@param x number
---@param y number
---@return MoonwellWrappers.Effect
function Effect.create(model, x, y)
    Check.requireText(model, 'a model path', 'Effect.create')
    return (Handle.created(Effect.fromHandle(AddSpecialEffect(model, x, y)), 'Effect.create'))
end
---Takes a Unit in the editor: Warcraft draws no effect attached to an item or a destructable (v0.3.0 gate). The
---runtime still accepts any Widget, for custom models.
---@param model string
---@param target MoonwellWrappers.Unit
---@param attachmentPoint string
---@return MoonwellWrappers.Effect
function Effect.attach(model, target, attachmentPoint)
    Check.requireText(model, 'a model path', 'Effect.attach')
    local raw = Handle.unwrapWidget(target, 'Effect.attach')
    return (Handle.created(Effect.fromHandle(AddSpecialEffectTarget(model, raw, attachmentPoint)), 'Effect.attach'))
end
---Creates and destroys an effect at once, which plays its death animation. Returns nothing.
---@param model string
---@param x number
---@param y number
function Effect.flash(model, x, y)
    Check.requireText(model, 'a model path', 'Effect.flash')
    DestroyEffect(Handle.created(AddSpecialEffect(model, x, y), 'Effect.flash'))
end
---Attaches and destroys an effect at once, which plays its death animation. Returns nothing. Takes a Unit in the
---editor, like Effect.attach.
---@param model string
---@param target MoonwellWrappers.Unit
---@param attachmentPoint string
function Effect.flashOn(model, target, attachmentPoint)
    Check.requireText(model, 'a model path', 'Effect.flashOn')
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
---Tints the effect. With `a` it also sets the alpha, as setAlpha does.
---@param r integer 0-255
---@param g integer 0-255
---@param b integer 0-255
---@param a integer? 0-255; the alpha stays as it is when this is left out.
function Effect:setColor(r, g, b, a)
    local raw = registry.require(self, 'Effect.setColor')
    BlzSetSpecialEffectColor(raw, r, g, b)
    if a ~= nil then BlzSetSpecialEffectAlpha(raw, a) end
end
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
---The native takes radians; this converts.
---@param yaw number Degrees.
---@param pitch number Degrees.
---@param roll number Degrees.
function Effect:setOrientation(yaw, pitch, roll)
    local raw = registry.require(self, 'Effect.setOrientation')
    Check.requireFinite(yaw, 'yaw', 'Effect.setOrientation')
    Check.requireFinite(pitch, 'pitch', 'Effect.setOrientation')
    Check.requireFinite(roll, 'roll', 'Effect.setOrientation')
    BlzSetSpecialEffectOrientation(raw, math.rad(yaw), math.rad(pitch), math.rad(roll))
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
