local Handle = require('wrappers.internal.handle')
local Widget = require('wrappers.internal.widget')
local Callback = require('wrappers.internal.callback')

---@class MoonwellWrappers.Destructable: MoonwellWrappers.Widget
---@field handle destructable? Read-only by convention; nil after removal.
local Destructable = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Destructable, destructable>
local registry = Handle.new(Destructable, 'Destructable', {weak = true, widget = true})

---@param raw destructable?
---@return MoonwellWrappers.Destructable?
---@overload fun(raw: nil): nil
function Destructable.fromHandle(raw) return registry.wrap(raw) end
---The destructable the running event is about (GetTriggerDestructable), or nil when it has none.
---@return MoonwellWrappers.Destructable?
function Destructable.fromEvent() return registry.wrap(GetTriggerDestructable()) end
---@param typeId integer
---@param x number
---@param y number
---@param facing number
---@param scale number
---@param variation integer
---@return MoonwellWrappers.Destructable
function Destructable.create(typeId, x, y, facing, scale, variation)
    local raw = CreateDestructable(typeId, x, y, facing, scale, variation)
    return (Handle.created(Destructable.fromHandle(raw), 'Destructable.create'))
end
---@return destructable
function Destructable:getHandle() return (registry.require(self, 'Destructable.getHandle')) end
---@return boolean
function Destructable:isDisposed() return (registry.isDisposed(self, 'Destructable.isDisposed')) end
---True while the game still has the destructable, dead or alive; false once it was removed by code that bypassed this
---wrapper. A disposed wrapper raises, like every method.
---@return boolean
function Destructable:exists() return GetDestructableTypeId(registry.require(self, 'Destructable.exists')) ~= 0 end
---@return integer
function Destructable:getTypeId() return GetDestructableTypeId(registry.require(self, 'Destructable.getTypeId')) end
---@return string
function Destructable:getName() return GetDestructableName(registry.require(self, 'Destructable.getName')) end
---@return number
function Destructable:getMaxLife() return GetDestructableMaxLife(registry.require(self, 'Destructable.getMaxLife')) end
---@param value number
function Destructable:setMaxLife(value)
    SetDestructableMaxLife(registry.require(self, 'Destructable.setMaxLife'), value)
end
function Destructable:kill() KillDestructable(registry.require(self, 'Destructable.kill')) end
---@param life number
---@param birth boolean
function Destructable:restore(life, birth)
    DestructableRestoreLife(registry.require(self, 'Destructable.restore'), life, birth)
end
---@return boolean
function Destructable:isInvulnerable()
    return IsDestructableInvulnerable(registry.require(self, 'Destructable.isInvulnerable'))
end
---@param flag boolean
function Destructable:setInvulnerable(flag)
    SetDestructableInvulnerable(registry.require(self, 'Destructable.setInvulnerable'), flag)
end
---@param visible boolean
function Destructable:show(visible) ShowDestructable(registry.require(self, 'Destructable.show'), visible) end
---@param animation string
function Destructable:setAnimation(animation)
    SetDestructableAnimation(registry.require(self, 'Destructable.setAnimation'), animation)
end
---@param animation string
function Destructable:queueAnimation(animation)
    QueueDestructableAnimation(registry.require(self, 'Destructable.queueAnimation'), animation)
end
function Destructable:remove()
    local raw = registry.dispose(self, 'Destructable.remove')
    if raw then RemoveDestructable(raw) end
end

---Returns a new array of the destructables in the rect. `filter` runs afterwards, as ordinary Lua, and keeps the
---destructables for which it returns truthy; its errors propagate.
---@param rect MoonwellWrappers.Rect
---@param filter (fun(destructable: MoonwellWrappers.Destructable): any)?
---@return MoonwellWrappers.Destructable[]
function Destructable.enumInRect(rect, filter)
    local rawRect = Handle.unwrap(rect, 'Rect', 'Destructable.enumInRect')
    Callback.optional(filter, 'Destructable.enumInRect')
    local raws = {}
    -- Warcraft accepts a null filter; the generated JASS signature cannot express that.
    ---@diagnostic disable-next-line: param-type-mismatch
    EnumDestructablesInRect(rawRect, nil, function() raws[#raws + 1] = GetEnumDestructable() end)
    local destructables = {}
    for index, raw in ipairs(raws) do destructables[index] = assert(Destructable.fromHandle(raw)) end
    if filter == nil then return destructables end
    local kept = {}
    for _, destructable in ipairs(destructables) do
        if filter(destructable) then kept[#kept + 1] = destructable end
    end
    return kept
end

Widget.install(Destructable, registry)
return Destructable
