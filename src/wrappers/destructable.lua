local Handle = require('wrappers.internal.handle')
local Widget = require('wrappers.internal.widget')

---@class MoonwellWrappers.Destructable: MoonwellWrappers.Widget
---@field handle destructable? Read-only by convention; nil after removal.
local Destructable = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Destructable, destructable>
local registry = Handle.new(Destructable, 'Destructable', {weak = true, widget = true})

---@param raw destructable?
---@return MoonwellWrappers.Destructable?
---@overload fun(raw: nil): nil
function Destructable.fromHandle(raw) return registry.wrap(raw) end
---@param typeId integer
---@param x number
---@param y number
---@param facing number
---@param scale number
---@param variation integer
---@return MoonwellWrappers.Destructable
function Destructable.create(typeId, x, y, facing, scale, variation)
    local raw = CreateDestructable(typeId, x, y, facing, scale, variation)
    return Handle.created(Destructable.fromHandle(raw), 'Destructable.create')
end
---@return destructable
function Destructable:getHandle() return registry.require(self, 'Destructable.getHandle') end
---@return boolean
function Destructable:isDisposed() return registry.isDisposed(self, 'Destructable.isDisposed') end
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

Widget.install(Destructable, registry)
return Destructable
