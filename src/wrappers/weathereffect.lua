local Handle = require('wrappers.internal.handle')

---@class MoonwellWrappers.WeatherEffect
---@field handle weathereffect? Read-only by convention; nil after destruction.
local WeatherEffect = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.WeatherEffect, weathereffect>
local registry = Handle.new(WeatherEffect, 'WeatherEffect')

---@param raw weathereffect?
---@return MoonwellWrappers.WeatherEffect?
---@overload fun(raw: nil): nil
function WeatherEffect.fromHandle(raw) return registry.wrap(raw) end
---Creates a weather effect over the rect. It is not drawn until enable(true). The effect does not own the rect, which
---may be destroyed afterwards. An unknown id raises an error: Warcraft returns an invalid effect (handle id -1) rather
---than nil, which this removes first.
---@param rect MoonwellWrappers.Rect
---@param effectId integer For example FourCC('RAhr').
---@return MoonwellWrappers.WeatherEffect
function WeatherEffect.create(rect, effectId)
    local raw = AddWeatherEffect(Handle.unwrap(rect, 'Rect', 'WeatherEffect.create'), effectId)
    -- Only compared with -1, which every machine gets for the same unknown id; removing it was safe in game.
    if raw ~= nil and GetHandleId(raw) == -1 then
        RemoveWeatherEffect(raw)
        error('[wrappers] WeatherEffect.create: unknown weather effect id: ' .. tostring(effectId), 2)
    end
    return (Handle.created(WeatherEffect.fromHandle(raw), 'WeatherEffect.create'))
end
---@return weathereffect
function WeatherEffect:getHandle() return (registry.require(self, 'WeatherEffect.getHandle')) end
---@return boolean
function WeatherEffect:isDisposed() return (registry.isDisposed(self, 'WeatherEffect.isDisposed')) end
---@param flag boolean
function WeatherEffect:enable(flag) EnableWeatherEffect(registry.require(self, 'WeatherEffect.enable'), flag) end
---Draws the effect on that player's machine only; enable(flag) afterwards applies to everyone.
---@param player MoonwellWrappers.Player
function WeatherEffect:enableFor(player)
    local raw = registry.require(self, 'WeatherEffect.enableFor')
    EnableWeatherEffect(raw, Handle.unwrap(player, 'Player', 'WeatherEffect.enableFor') == GetLocalPlayer())
end
function WeatherEffect:destroy()
    local raw = registry.dispose(self, 'WeatherEffect.destroy')
    if raw then RemoveWeatherEffect(raw) end
end

return WeatherEffect
