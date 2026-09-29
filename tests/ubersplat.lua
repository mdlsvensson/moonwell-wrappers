for _, name in ipairs({'SetUbersplatRenderAlways', 'ShowUbersplat', 'FinishUbersplat', 'ResetUbersplat',
    'DestroyUbersplat'}) do
    native(name, function() end)
end
native('CreateUbersplat', function() return {} end)
native('GetLocalPlayer', function() return PLAYER_RAW end)
local Ubersplat = require('wrappers.ubersplat')
local Player = require('wrappers.player')
eq(totalCalls(), 0)

test('ubersplats use documented defaults and options and are always rendered', function()
    eq(Ubersplat.fromHandle(nil), nil)
    local splat = Ubersplat.create('HMED', 1, 2)
    expectCall('CreateUbersplat', 1, 2, 'HMED', 255, 255, 255, 255, false, false)
    expectCall('SetUbersplatRenderAlways', splat.handle, true)
    eq(Ubersplat.fromHandle(splat.handle), splat); eq(splat:getHandle(), splat.handle); eq(splat:isDisposed(), false)
    local tinted = Ubersplat.create('OLAR', 3, 4, {color = {10, 20, 30}, forcePaused = true, noBirthTime = true})
    expectCall('CreateUbersplat', 3, 4, 'OLAR', 10, 20, 30, 255, true, true)
    fails(function() Ubersplat.create('HMED', 0, 0, {colour = {1, 2, 3}}) end,
        "Ubersplat.create: unknown option 'colour'")
    eq(callCount('CreateUbersplat'), 2)
    splat:destroy(); tinted:destroy()
end)

test('ubersplat controls and local visibility forward exact arguments', function()
    local splat = Ubersplat.create('HMED', 0, 0)
    checkSetters(splat, {{'ShowUbersplat', 'show', false}, {'FinishUbersplat', 'finish'},
        {'ResetUbersplat', 'reset'}})
    splat:setVisibleFor(Player.fromIndex(0)); expectCall('ShowUbersplat', splat.handle, true)
    splat:setVisibleFor(Player.fromHandle({})); expectCall('ShowUbersplat', splat.handle, false)
    fails(function() splat:setVisibleFor(splat) end, 'Ubersplat.setVisibleFor: expected Player wrapper')
    splat:destroy()
end)

test('ubersplat destruction is idempotent and guards every method', function()
    local splat = Ubersplat.create('HMED', 0, 0)
    local raw = splat.handle
    splat:destroy(); splat:destroy()
    expectCall('DestroyUbersplat', raw); eq(callCount('DestroyUbersplat'), 1); eq(splat.handle, nil)
    eq(splat:isDisposed(), true)
    checkDisposed(splat, {'getHandle', 'show', 'setVisibleFor', 'finish', 'reset'})
    native('CreateUbersplat', function() return nil end)
    fails(function() Ubersplat.create('HMED', 0, 0) end, 'Ubersplat.create')
    eq(callCount('SetUbersplatRenderAlways'), 1)
    native('CreateUbersplat', function() return {} end)
end)
