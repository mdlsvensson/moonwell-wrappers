local Handle = require('wrappers.internal.handle')
local Options = require('wrappers.internal.options')
local Check = require('wrappers.internal.check')

---@class MoonwellWrappers.TextTag
---@field handle texttag? Read-only by convention; nil after destruction.
local TextTag = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.TextTag, texttag>
local registry = Handle.new(TextTag, 'TextTag')

---@class MoonwellWrappers.TextTagFloatOptions
---@field size number? Font size, as in World Editor; default 10.
---@field heightOffset number? Height above the ground; default 0.
---@field color integer[]? {r, g, b, a?}, each 0-255; default white, opaque.
---@field speed number? World Editor speed units; default 64.
---@field angle number? Direction of travel in degrees; default 90.
---@field lifespan number? Seconds until the game destroys the tag; default 2.
---@field fadepoint number? Seconds after which the tag fades; default 1.
---@field player MoonwellWrappers.Player? Show the tag to this player only; default everyone.

---@type MoonwellWrappers.OptionFields
local floatFields = {
    size = {'number', 10}, heightOffset = {'number', 0}, color = {'color', {255, 255, 255}},
    speed = {'number', 64}, angle = {'number', 90}, lifespan = {'nonnegative', 2}, fadepoint = {'nonnegative', 1},
    player = {'Player'},
}

---The TextTagSize2Height conversion, computed in Lua.
---@param size number
---@return number
local function height(size) return size * 0.023 / 10 end

---@param raw texttag?
---@return MoonwellWrappers.TextTag?
---@overload fun(raw: nil): nil
function TextTag.fromHandle(raw) return registry.wrap(raw) end
---Creates a permanent text tag: the game never destroys it, so the wrapper stays valid until destroy().
---@return MoonwellWrappers.TextTag
function TextTag.create()
    local raw = CreateTextTag()
    local tag = Handle.created(TextTag.fromHandle(raw), 'TextTag.create')
    SetTextTagPermanent(raw, true)
    return tag
end
---Shows floating text that the game destroys after its lifespan. Returns nothing, so no wrapper can go stale. Does
---nothing when the game has no free text tag.
---@param text string
---@param x number
---@param y number
---@param options MoonwellWrappers.TextTagFloatOptions?
function TextTag.float(text, x, y, options)
    local o = Options.read(options, floatFields, 'TextTag.float')
    local raw = CreateTextTag()
    if raw == nil then return end
    -- A new tag is permanent: make it temporary first, so an error below cannot leave an unreachable permanent tag.
    SetTextTagPermanent(raw, false)
    SetTextTagLifespan(raw, o.lifespan)
    SetTextTagFadepoint(raw, o.fadepoint)
    SetTextTagText(raw, text, height(o.size))
    SetTextTagPos(raw, x, y, o.heightOffset)
    SetTextTagColor(raw, o.color[1], o.color[2], o.color[3], o.color[4])
    local velocity, radians = o.speed * 0.071 / 128, math.rad(o.angle)
    SetTextTagVelocity(raw, velocity * math.cos(radians), velocity * math.sin(radians))
    SetTextTagVisibility(raw, o.player == nil or o.player == GetLocalPlayer())
end
---@return texttag
function TextTag:getHandle() return (registry.require(self, 'TextTag.getHandle')) end
---@return boolean
function TextTag:isDisposed() return (registry.isDisposed(self, 'TextTag.isDisposed')) end
---@param text string
---@param size number Font size, as in World Editor.
function TextTag:setText(text, size)
    local raw = registry.require(self, 'TextTag.setText')
    Check.requireFinite(size, 'size', 'TextTag.setText')
    SetTextTagText(raw, text, height(size))
end
---@param r integer 0-255
---@param g integer 0-255
---@param b integer 0-255
---@param a integer 0-255
function TextTag:setColor(r, g, b, a) SetTextTagColor(registry.require(self, 'TextTag.setColor'), r, g, b, a) end
---@param x number
---@param y number
---@param heightOffset number
function TextTag:setPosition(x, y, heightOffset)
    SetTextTagPos(registry.require(self, 'TextTag.setPosition'), x, y, heightOffset)
end
---Places the tag at the unit once; it does not follow the unit.
---@param unit MoonwellWrappers.Unit
---@param heightOffset number
function TextTag:setPositionOnUnit(unit, heightOffset)
    local raw = registry.require(self, 'TextTag.setPositionOnUnit')
    SetTextTagPosUnit(raw, Handle.unwrap(unit, 'Unit', 'TextTag.setPositionOnUnit'), heightOffset)
end
---@param xvel number Native units.
---@param yvel number Native units.
function TextTag:setVelocity(xvel, yvel) SetTextTagVelocity(registry.require(self, 'TextTag.setVelocity'), xvel, yvel) end
---@param flag boolean
function TextTag:setSuspended(flag) SetTextTagSuspended(registry.require(self, 'TextTag.setSuspended'), flag) end
---@param flag boolean
function TextTag:setVisible(flag) SetTextTagVisibility(registry.require(self, 'TextTag.setVisible'), flag) end
---Shows the tag on that player's machine only. Only local visuals differ.
---@param player MoonwellWrappers.Player
function TextTag:setVisibleFor(player)
    local raw = registry.require(self, 'TextTag.setVisibleFor')
    SetTextTagVisibility(raw, Handle.unwrap(player, 'Player', 'TextTag.setVisibleFor') == GetLocalPlayer())
end
function TextTag:destroy()
    local raw = registry.dispose(self, 'TextTag.destroy')
    if raw then DestroyTextTag(raw) end
end

return TextTag
