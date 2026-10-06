native('CreateDestructable', function() return {} end)
native('RemoveDestructable', function() end)
local Handle = require('wrappers.internal.handle')
local Destructable = require('wrappers.destructable')
local Rect = require('wrappers.rect')
eq(totalCalls(), 0)

test('destructable identity, factory and widget family', function()
    eq(Destructable.fromHandle(nil), nil)
    local d = Destructable.create(1280601204, 10, 20, 270, 1.2, 3)
    expectCall('CreateDestructable', 1280601204, 10, 20, 270, 1.2, 3)
    eq(Destructable.fromHandle(d.handle), d); eq(d:getHandle(), d.handle)
    eq(Handle.unwrapWidget(d, 'Test.op'), d.handle)
    native('CreateDestructable', function() return nil end)
    failsAt(function() Destructable.create(1, 0, 0, 0, 1, 0) end, 'Destructable.create')
    native('CreateDestructable', function() return {} end)
    d:remove()
end)

test('destructable natives receive exact arguments', function()
    local d = Destructable.fromHandle({})
    checkGetters(d, {{'GetDestructableTypeId', 'getTypeId', 1280601204}, {'GetDestructableName', 'getName', 'Tree'},
        {'GetDestructableMaxLife', 'getMaxLife', 50}, {'IsDestructableInvulnerable', 'isInvulnerable', false},
        {'GetWidgetLife', 'getLife', 40}, {'GetWidgetX', 'getX', 1}, {'GetWidgetY', 'getY', 2}})
    checkSetters(d, {{'SetDestructableMaxLife', 'setMaxLife', 500}, {'KillDestructable', 'kill'},
        {'DestructableRestoreLife', 'restore', 100, true}, {'SetDestructableInvulnerable', 'setInvulnerable', true},
        {'ShowDestructable', 'setVisible', false}, {'SetDestructableAnimation', 'setAnimation', 'death'},
        {'QueueDestructableAnimation', 'queueAnimation', 'stand'}, {'SetWidgetLife', 'setLife', 10}})
    eq(d:isDisposed(), false)
    d:remove()
end)

test('destructable removal is idempotent and guards every method', function()
    local d = Destructable.fromHandle({})
    local raw = d.handle
    d:remove(); d:remove()
    expectCall('RemoveDestructable', raw); eq(callCount('RemoveDestructable'), 1); eq(d.handle, nil)
    eq(d:isDisposed(), true)
    checkDisposed(d, {'getHandle', 'getTypeId', 'getName', 'getMaxLife', 'setMaxLife', 'kill', 'restore',
        'isInvulnerable', 'setInvulnerable', 'setVisible', 'setAnimation', 'queueAnimation', 'getLife', 'setLife',
        'getX', 'getY'})
end)

local enumerated, current, inNative, seenRect, seenFilter = {}, nil, false, nil, 'unset'
native('GetEnumDestructable', function() return current end)
native('EnumDestructablesInRect', function(rect, filter, callback)
    seenRect, seenFilter, inNative = rect, filter, true
    for _, raw in ipairs(enumerated) do current = raw; callback() end
    current, inNative = nil, false
end)

test('enumInRect returns a snapshot of the enumerated destructables', function()
    local area, a, b = Rect.fromHandle({}), {}, {}
    enumerated = {a, b}
    local all = Destructable.enumInRect(area)
    eq(#all, 2); eq(all[1], Destructable.fromHandle(a)); eq(all[2], Destructable.fromHandle(b))
    eq(seenRect, area.handle); eq(seenFilter, nil); eq(callCount('EnumDestructablesInRect'), 1)
end)

test('enumInRect filters after the native returns, as ordinary Lua', function()
    local area, a, b = Rect.fromHandle({}), {}, {}
    enumerated = {a, b}
    local kept = Destructable.enumInRect(area, function(tree)
        assert(not inNative, 'filter ran inside the native enumeration')
        return tree.handle == a
    end)
    eq(#kept, 1); eq(kept[1], Destructable.fromHandle(a))
    failsAt(function() Destructable.enumInRect(area, function() error('boom') end) end, 'boom')
end)

test('enumInRect wraps every destructable before the filter runs: one the filter removes stays disposed', function()
    local area, a, b = Rect.fromHandle({}), {}, {}
    enumerated = {a, b}
    local states = {}
    local kept = Destructable.enumInRect(area, function(tree)
        if tree.handle == a then Destructable.fromHandle(b):remove() end
        states[#states + 1] = tree:isDisposed()
        return true
    end)
    eq(#states, 2); eq(states[1], false); eq(states[2], true)
    eq(#kept, 2); eq(kept[2]:isDisposed(), true); eq(callCount('RemoveDestructable'), 1)
    Destructable.fromHandle(a):remove()
end)

test('the shared widget methods are the class own and blame their caller', function()
    for _, method in ipairs({'getLife', 'setLife', 'getX', 'getY'}) do
        eq(type(rawget(Destructable, method)), 'function')
        failsAt(function() Destructable[method]({}) end, 'Destructable.' .. method .. ': expected Destructable wrapper')
    end
    eq(Destructable.show, nil)
end)

test('enumInRect validates its rect and filter before the native', function()
    failsAt(function() Destructable.enumInRect({}) end, 'Destructable.enumInRect: expected Rect wrapper')
    failsAt(function() Destructable.enumInRect(Rect.fromHandle({}), 1) end,
        'Destructable.enumInRect: expected a callback function')
    eq(callCount('EnumDestructablesInRect'), 0)
end)

test('exists asks for a type id', function()
    local typeId = 1
    native('GetDestructableTypeId', function() return typeId end)
    local wrapper = Destructable.fromHandle({})
    eq(wrapper:exists(), true)
    typeId = 0; eq(wrapper:exists(), false)
end)

test('exists is false for a disposed wrapper, without a native call', function()
    native('GetDestructableTypeId', function() return 1 end)
    local wrapper = Destructable.fromHandle({})
    wrapper:remove()
    eq(wrapper:exists(), false); eq(callCount('GetDestructableTypeId'), 0)
    failsAt(function() Destructable.exists({}) end, 'Destructable.exists: expected Destructable wrapper')
end)

test('fromEvent wraps the destructable of the running event, and nil when it has none', function()
    local raw = {}
    native('GetTriggerDestructable', function() return raw end)
    local found = Destructable.fromEvent()
    eq(found, Destructable.fromHandle(raw)); eq(found.handle, raw); eq(callCount('GetTriggerDestructable'), 1)
    native('GetTriggerDestructable', function() return nil end)
    eq(Destructable.fromEvent(), nil)
end)
