native('CreateDestructable', function() return {} end)
native('RemoveDestructable', function() end)
local Handle = require('wrappers.internal.handle')
local Destructable = require('wrappers.destructable')
eq(totalCalls(), 0)

test('destructable identity, factory and widget family', function()
    eq(Destructable.fromHandle(nil), nil)
    local d = Destructable.create(1280601204, 10, 20, 270, 1.2, 3)
    expectCall('CreateDestructable', 1280601204, 10, 20, 270, 1.2, 3)
    eq(Destructable.fromHandle(d.handle), d); eq(d:getHandle(), d.handle)
    eq(Handle.unwrapWidget(d, 'Test.op'), d.handle)
    native('CreateDestructable', function() return nil end)
    fails(function() Destructable.create(1, 0, 0, 0, 1, 0) end, 'Destructable.create')
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
        {'ShowDestructable', 'show', false}, {'SetDestructableAnimation', 'setAnimation', 'death'},
        {'QueueDestructableAnimation', 'queueAnimation', 'stand'}, {'SetWidgetLife', 'setLife', 10}})
    eq(d:isDisposed(), false)
    d:remove()
end)

test('destructable removal is idempotent and guards every method', function()
    local d = Destructable.fromHandle({})
    local raw = d.handle
    d:remove(); d:remove()
    expectCall('RemoveDestructable', raw); eq(callCount('RemoveDestructable'), 1); eq(d.handle, nil)
    checkDisposed(d, {'getHandle', 'getTypeId', 'getName', 'getMaxLife', 'setMaxLife', 'kill', 'restore',
        'isInvulnerable', 'setInvulnerable', 'show', 'setAnimation', 'queueAnimation', 'getLife', 'setLife',
        'getX', 'getY'})
end)
