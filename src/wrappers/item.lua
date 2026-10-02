local Handle = require('wrappers.internal.handle')
local Widget = require('wrappers.internal.widget')
local Callback = require('wrappers.internal.callback')
local PlayerWrapper = require('wrappers.player')

---@class MoonwellWrappers.Item: MoonwellWrappers.Widget
---@field handle item? Read-only by convention; nil after removal.
local Item = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Item, item>
local registry = Handle.new(Item, 'Item', {weak = true, widget = true})

---@param raw item?
---@return MoonwellWrappers.Item?
---@overload fun(raw: nil): nil
function Item.fromHandle(raw) return registry.wrap(raw) end
---The item the running event is about (GetManipulatedItem), or nil when it has none.
---@return MoonwellWrappers.Item?
function Item.fromEvent() return registry.wrap(GetManipulatedItem()) end
---@param typeId integer
---@param x number
---@param y number
---@return MoonwellWrappers.Item
function Item.create(typeId, x, y)
    return (Handle.created(Item.fromHandle(CreateItem(typeId, x, y)), 'Item.create'))
end
---@return item
function Item:getHandle() return (registry.require(self, 'Item.getHandle')) end
---@return boolean
function Item:isDisposed() return (registry.isDisposed(self, 'Item.isDisposed')) end
---True while the game still has the item; false once it was removed (a used powerup, used-up charges, or removal by
---code that bypassed this wrapper). False for a disposed wrapper, without raising.
---@return boolean
function Item:exists()
    local raw = registry.live(self, 'Item.exists')
    return raw ~= nil and GetItemTypeId(raw) ~= 0
end
---@return integer
function Item:getTypeId() return GetItemTypeId(registry.require(self, 'Item.getTypeId')) end
---@return string
function Item:getName() return GetItemName(registry.require(self, 'Item.getName')) end
---@return integer
function Item:getLevel() return GetItemLevel(registry.require(self, 'Item.getLevel')) end
---@param x number
---@param y number
function Item:setPosition(x, y) SetItemPosition(registry.require(self, 'Item.setPosition'), x, y) end
---@return integer
function Item:getCharges() return GetItemCharges(registry.require(self, 'Item.getCharges')) end
---@param charges integer
function Item:setCharges(charges) SetItemCharges(registry.require(self, 'Item.setCharges'), charges) end
---@return MoonwellWrappers.Player
function Item:getOwner()
    local owner = GetItemPlayer(registry.require(self, 'Item.getOwner'))
    return (Handle.created(PlayerWrapper.fromHandle(owner), 'Item.getOwner'))
end
---@param owner MoonwellWrappers.Player
---@param changeColor boolean
function Item:setOwner(owner, changeColor)
    local raw = registry.require(self, 'Item.setOwner')
    SetItemPlayer(raw, Handle.unwrap(owner, 'Player', 'Item.setOwner'), changeColor)
end
---@return boolean
function Item:isOwned() return IsItemOwned(registry.require(self, 'Item.isOwned')) end
---@return boolean
function Item:isPowerup() return IsItemPowerup(registry.require(self, 'Item.isPowerup')) end
---@return boolean
function Item:isVisible() return IsItemVisible(registry.require(self, 'Item.isVisible')) end
---@param visible boolean
function Item:setVisible(visible) SetItemVisible(registry.require(self, 'Item.setVisible'), visible) end
---@return boolean
function Item:isInvulnerable() return IsItemInvulnerable(registry.require(self, 'Item.isInvulnerable')) end
---@param flag boolean
function Item:setInvulnerable(flag) SetItemInvulnerable(registry.require(self, 'Item.setInvulnerable'), flag) end
---@param flag boolean
function Item:setDroppable(flag) SetItemDroppable(registry.require(self, 'Item.setDroppable'), flag) end
---@param flag boolean
function Item:setPawnable(flag) SetItemPawnable(registry.require(self, 'Item.setPawnable'), flag) end
function Item:remove()
    local raw = registry.dispose(self, 'Item.remove')
    if raw then RemoveItem(raw) end
end

---Returns a new array of the items in the rect. `filter` runs afterwards, as ordinary Lua, and keeps the items for
---which it returns truthy; its errors propagate.
---@param rect MoonwellWrappers.Rect
---@param filter (fun(item: MoonwellWrappers.Item): any)?
---@return MoonwellWrappers.Item[]
function Item.enumInRect(rect, filter)
    local rawRect = Handle.unwrap(rect, 'Rect', 'Item.enumInRect')
    Callback.optional(filter, 'Item.enumInRect')
    local raws = {}
    -- Warcraft accepts a null filter; the generated JASS signature cannot express that.
    ---@diagnostic disable-next-line: param-type-mismatch
    EnumItemsInRect(rawRect, nil, function() raws[#raws + 1] = GetEnumItem() end)
    local items = {}
    for index, raw in ipairs(raws) do items[index] = assert(Item.fromHandle(raw)) end
    if filter == nil then return items end
    local kept = {}
    for _, item in ipairs(items) do
        if filter(item) then kept[#kept + 1] = item end
    end
    return kept
end

Widget.install(Item, registry)
return Item
