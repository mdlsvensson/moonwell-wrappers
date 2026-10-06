native('CreateItem', function() return {} end)
native('RemoveItem', function() end)
local Handle = require('wrappers.internal.handle')
local Item = require('wrappers.item')
local Player = require('wrappers.player')
local Rect = require('wrappers.rect')
eq(totalCalls(), 0)

test('item identity, factory and widget family', function()
    eq(Item.fromHandle(nil), nil)
    local i = Item.create(1918989411, 10, 20)
    expectCall('CreateItem', 1918989411, 10, 20)
    eq(Item.fromHandle(i.handle), i); eq(i:getHandle(), i.handle); eq(i:isDisposed(), false)
    eq(Handle.unwrapWidget(i, 'Test.op'), i.handle)
    native('CreateItem', function() return nil end)
    failsAt(function() Item.create(1, 0, 0) end, 'Item.create')
    native('CreateItem', function() return {} end)
    i:remove()
end)

test('item getters read current native state', function()
    local i, owner = Item.fromHandle({}), {}
    checkGetters(i, {{'GetItemTypeId', 'getTypeId', 1918989411}, {'GetItemName', 'getName', 'Claws'},
        {'GetItemLevel', 'getLevel', 2}, {'GetItemCharges', 'getCharges', 3}, {'IsItemOwned', 'isOwned', true},
        {'IsItemPowerup', 'isPowerup', false}, {'IsItemVisible', 'isVisible', true},
        {'IsItemInvulnerable', 'isInvulnerable', false}, {'GetWidgetLife', 'getLife', 75},
        {'GetWidgetX', 'getX', 5}, {'GetWidgetY', 'getY', 6}})
    native('GetItemPlayer', function() return owner end)
    eq(i:getOwner(), Player.fromHandle(owner)); expectCall('GetItemPlayer', i.handle)
    native('GetItemPlayer', function() return nil end)
    failsAt(function() i:getOwner() end, 'Item.getOwner')
    i:remove()
end)

test('item mutations forward exact arguments', function()
    local i, p = Item.fromHandle({}), Player.fromIndex(0)
    checkSetters(i, {{'SetItemPosition', 'setPosition', 1, 2}, {'SetItemCharges', 'setCharges', 4},
        {'SetItemVisible', 'setVisible', false}, {'SetItemInvulnerable', 'setInvulnerable', true},
        {'SetItemDroppable', 'setDroppable', false}, {'SetItemPawnable', 'setPawnable', true},
        {'SetWidgetLife', 'setLife', 30}})
    native('SetItemPlayer', function() end)
    i:setOwner(p, true); expectCall('SetItemPlayer', i.handle, PLAYER_RAW, true)
    failsAt(function() i:setOwner(i, true) end, 'Item.setOwner: expected Player wrapper')
    eq(callCount('SetItemPlayer'), 1)
    i:remove()
end)

test('item removal is idempotent and guards every method', function()
    local i = Item.fromHandle({})
    local raw = i.handle
    i:remove(); i:remove()
    expectCall('RemoveItem', raw); eq(callCount('RemoveItem'), 1); eq(i.handle, nil); eq(i:isDisposed(), true)
    checkDisposed(i, {'getHandle', 'getTypeId', 'getName', 'getLevel', 'setPosition', 'getCharges', 'setCharges',
        'getOwner', 'setOwner', 'isOwned', 'isPowerup', 'isVisible', 'setVisible', 'isInvulnerable',
        'setInvulnerable', 'setDroppable', 'setPawnable', 'getLife', 'setLife', 'getX', 'getY'})
end)

local enumerated, current, inNative, seenRect, seenFilter = {}, nil, false, nil, 'unset'
native('GetEnumItem', function() return current end)
native('EnumItemsInRect', function(rect, filter, callback)
    seenRect, seenFilter, inNative = rect, filter, true
    for _, raw in ipairs(enumerated) do current = raw; callback() end
    current, inNative = nil, false
end)

test('enumInRect returns a snapshot of the enumerated items', function()
    local area, a, b = Rect.fromHandle({}), {}, {}
    enumerated = {a, b}
    local all = Item.enumInRect(area)
    eq(#all, 2); eq(all[1], Item.fromHandle(a)); eq(all[2], Item.fromHandle(b))
    eq(seenRect, area.handle); eq(seenFilter, nil); eq(callCount('EnumItemsInRect'), 1)
    enumerated = {}
    eq(#Item.enumInRect(area), 0); eq(#all, 2)
end)

test('enumInRect filters after the native returns, as ordinary Lua', function()
    local area, a, b = Rect.fromHandle({}), {}, {}
    enumerated = {a, b}
    local seen = {}
    local kept = Item.enumInRect(area, function(item)
        assert(not inNative, 'filter ran inside the native enumeration')
        seen[#seen + 1] = item
        return item.handle == b
    end)
    eq(#seen, 2); eq(#kept, 1); eq(kept[1], Item.fromHandle(b))
    failsAt(function() Item.enumInRect(area, function() error('boom') end) end, 'boom')
end)

test('enumInRect wraps every item before the filter runs: one the filter removes stays disposed', function()
    local area, a, b = Rect.fromHandle({}), {}, {}
    enumerated = {a, b}
    local states = {}
    local kept = Item.enumInRect(area, function(item)
        if item.handle == a then Item.fromHandle(b):remove() end
        states[#states + 1] = item:isDisposed()
        return true
    end)
    eq(#states, 2); eq(states[1], false); eq(states[2], true)
    eq(#kept, 2); eq(kept[2]:isDisposed(), true); eq(callCount('RemoveItem'), 1)
    Item.fromHandle(a):remove()
end)

test('the shared widget methods are the class own and blame their caller', function()
    for _, method in ipairs({'getLife', 'setLife', 'getX', 'getY'}) do
        eq(type(rawget(Item, method)), 'function')
        failsAt(function() Item[method]({}) end, 'Item.' .. method .. ': expected Item wrapper')
    end
end)

test('enumInRect validates its rect and filter before the native', function()
    failsAt(function() Item.enumInRect({}) end, 'Item.enumInRect: expected Rect wrapper')
    failsAt(function() Item.enumInRect(Rect.fromHandle({}), 'all') end, 'Item.enumInRect: expected a callback function')
    eq(callCount('EnumItemsInRect'), 0)
end)

test('exists asks for a type id', function()
    local typeId = 1
    native('GetItemTypeId', function() return typeId end)
    local wrapper = Item.fromHandle({})
    eq(wrapper:exists(), true)
    typeId = 0; eq(wrapper:exists(), false)
end)

test('exists is false for a disposed wrapper, without a native call', function()
    native('GetItemTypeId', function() return 1 end)
    local wrapper = Item.fromHandle({})
    wrapper:remove()
    eq(wrapper:exists(), false); eq(callCount('GetItemTypeId'), 0)
    failsAt(function() Item.exists({}) end, 'Item.exists: expected Item wrapper')
end)

test('fromEvent wraps the item of the running event, and nil when it has none', function()
    local raw = {}
    native('GetManipulatedItem', function() return raw end)
    local found = Item.fromEvent()
    eq(found, Item.fromHandle(raw)); eq(found.handle, raw); eq(callCount('GetManipulatedItem'), 1)
    native('GetManipulatedItem', function() return nil end)
    eq(Item.fromEvent(), nil)
end)
