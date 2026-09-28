native('CreateItem', function() return {} end)
native('RemoveItem', function() end)
local Handle = require('wrappers.internal.handle')
local Item = require('wrappers.item')
local Player = require('wrappers.player')
eq(totalCalls(), 0)

test('item identity, factory and widget family', function()
    eq(Item.fromHandle(nil), nil)
    local i = Item.create(1918989411, 10, 20)
    expectCall('CreateItem', 1918989411, 10, 20)
    eq(Item.fromHandle(i.handle), i); eq(i:getHandle(), i.handle); eq(i:isDisposed(), false)
    eq(Handle.unwrapWidget(i, 'Test.op'), i.handle)
    native('CreateItem', function() return nil end)
    fails(function() Item.create(1, 0, 0) end, 'Item.create')
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
    fails(function() i:getOwner() end, 'Item.getOwner')
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
    fails(function() i:setOwner(i, true) end, 'Item.setOwner: expected Player wrapper')
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
