native('Rect', function() return {} end)
native('GetWorldBounds', function() return {} end)
native('RemoveRect', function() end)
local Rect = require('wrappers.rect')
eq(totalCalls(), 0)

test('rect factories, bounds, changes and destruction', function()
    local r = Rect.create(-10, -20, 30, 40)
    expectCall('Rect', -10, -20, 30, 40)
    eq(Rect.fromHandle(nil), nil); eq(Rect.fromHandle(r.handle), r); eq(r:getHandle(), r.handle)
    local world = Rect.createWorldBounds()
    expectCall('GetWorldBounds'); assert(world ~= r)
    checkGetters(r, {{'GetRectMinX', 'getMinX', -10}, {'GetRectMinY', 'getMinY', -20},
        {'GetRectMaxX', 'getMaxX', 30}, {'GetRectMaxY', 'getMaxY', 40},
        {'GetRectCenterX', 'getCenterX', 10}, {'GetRectCenterY', 'getCenterY', 10}})
    checkSetters(r, {{'SetRect', 'set', 0, 0, 5, 5}, {'MoveRectTo', 'moveTo', 7, 8}})
    local raw = r.handle
    r:destroy(); r:destroy()
    expectCall('RemoveRect', raw); eq(callCount('RemoveRect'), 1); eq(r.handle, nil); eq(r:isDisposed(), true)
    checkDisposed(r, {'getHandle', 'getMinX', 'getMinY', 'getMaxX', 'getMaxY', 'getCenterX', 'getCenterY', 'set',
        'moveTo'})
    world:destroy()
end)

test('rect factories fail on nil natives', function()
    native('Rect', function() return nil end)
    failsAt(function() Rect.create(0, 0, 1, 1) end, 'Rect.create: native returned nil')
    native('GetWorldBounds', function() return nil end)
    failsAt(function() Rect.createWorldBounds() end, 'Rect.createWorldBounds: native returned nil')
    native('Rect', function() return {} end)
    native('GetWorldBounds', function() return {} end)
end)
