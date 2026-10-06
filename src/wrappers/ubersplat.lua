local Handle = require('wrappers.internal.handle')
local Options = require('wrappers.internal.options')

---@class MoonwellWrappers.Ubersplat
---@field handle ubersplat? Read-only by convention; nil after destruction.
local Ubersplat = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Ubersplat, ubersplat>
local registry = Handle.new(Ubersplat, 'Ubersplat')

---@class MoonwellWrappers.UbersplatOptions
---@field color integer[]? {r, g, b, a?}, each 0-255; default white, opaque.
---@field forcePaused boolean? Default false.
---@field noBirthTime boolean? Default false.

---@type MoonwellWrappers.OptionFields
local createFields = {
    color = {'color', {255, 255, 255}}, forcePaused = {'boolean', false}, noBirthTime = {'boolean', false},
}

---@param raw ubersplat?
---@return MoonwellWrappers.Ubersplat?
---@overload fun(raw: nil): nil
function Ubersplat.fromHandle(raw) return registry.wrap(raw) end
---Creates an always-rendered splat.
---@param name string Splat name from Splats\UberSplatData.slk, such as "HMED".
---@param x number
---@param y number
---@param options MoonwellWrappers.UbersplatOptions?
---@return MoonwellWrappers.Ubersplat
function Ubersplat.create(name, x, y, options)
    local o = Options.read(options, createFields, 'Ubersplat.create')
    local c = o.color
    local raw = CreateUbersplat(x, y, name, c[1], c[2], c[3], c[4], o.forcePaused, o.noBirthTime)
    local splat = Handle.created(Ubersplat.fromHandle(raw), 'Ubersplat.create')
    SetUbersplatRenderAlways(raw, true)
    return splat
end
---@return ubersplat
function Ubersplat:getHandle() return (registry.require(self, 'Ubersplat.getHandle')) end
---@return boolean
function Ubersplat:isDisposed() return (registry.isDisposed(self, 'Ubersplat.isDisposed')) end
---@param flag boolean
function Ubersplat:setVisible(flag) ShowUbersplat(registry.require(self, 'Ubersplat.setVisible'), flag) end
---Shows the splat on that player's machine only. Only local visuals differ.
---@param player MoonwellWrappers.Player
function Ubersplat:setVisibleFor(player)
    local raw = registry.require(self, 'Ubersplat.setVisibleFor')
    ShowUbersplat(raw, Handle.unwrap(player, 'Player', 'Ubersplat.setVisibleFor') == GetLocalPlayer())
end
function Ubersplat:finish() FinishUbersplat(registry.require(self, 'Ubersplat.finish')) end
function Ubersplat:reset() ResetUbersplat(registry.require(self, 'Ubersplat.reset')) end
function Ubersplat:destroy()
    local raw = registry.dispose(self, 'Ubersplat.destroy')
    if raw then DestroyUbersplat(raw) end
end

return Ubersplat
