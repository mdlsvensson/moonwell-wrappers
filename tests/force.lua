local enumerated, current = {}, nil
native('CreateForce', function() return {} end)
native('DestroyForce', function() end)
native('ForForce', function(_, callback)
    for _, raw in ipairs(enumerated) do current = raw; callback() end
end)
native('GetEnumPlayer', function() return current end)
local Force = require('wrappers.force')
local Player = require('wrappers.player')
eq(totalCalls(), 0)

test('force membership and enumerations clear first', function()
    local f, p = Force.create(), Player.fromIndex(0)
    eq(Force.fromHandle(nil), nil); eq(Force.fromHandle(f.handle), f)
    for _, name in ipairs({'ForceAddPlayer', 'ForceRemovePlayer', 'ForceClear', 'ForceEnumPlayers',
        'ForceEnumAllies', 'ForceEnumEnemies'}) do native(name, function() end) end
    native('IsPlayerInForce', function() return true end)
    f:add(p); expectCall('ForceAddPlayer', f.handle, PLAYER_RAW)
    eq(f:contains(p), true); expectCall('IsPlayerInForce', PLAYER_RAW, f.handle)
    f:remove(p); expectCall('ForceRemovePlayer', f.handle, PLAYER_RAW)
    f:clear(); expectCall('ForceClear', f.handle)
    resetCalls(); f:enumPlayers()
    eq(callName(1), 'ForceClear'); expectCall('ForceEnumPlayers', f.handle, nil)
    resetCalls(); f:enumAllies(p)
    eq(callName(1), 'ForceClear'); expectCall('ForceEnumAllies', f.handle, PLAYER_RAW, nil)
    resetCalls(); f:enumEnemies(p)
    eq(callName(1), 'ForceClear'); expectCall('ForceEnumEnemies', f.handle, PLAYER_RAW, nil)
    resetCalls()
    fails(function() f:enumAllies(f) end, 'Force.enumAllies: expected Player wrapper')
    fails(function() f:add({}) end, 'Force.add: expected Player wrapper')
    eq(totalCalls(), 0)
    f:destroy()
    native('CreateForce', function() return nil end); fails(Force.create, 'Force.create')
    native('CreateForce', function() return {} end)
end)

test('player snapshots are dense and independent', function()
    local f, a, b = Force.create(), {}, {}
    enumerated = {a, b}
    local first = f:getPlayers()
    eq(callCount('ForForce'), 1)
    eq(#first, 2); eq(first[1], Player.fromHandle(a)); eq(first[2], Player.fromHandle(b))
    enumerated = {}
    eq(#f:getPlayers(), 0); eq(#first, 2)
    local raw = f.handle
    f:destroy(); f:destroy()
    expectCall('DestroyForce', raw); eq(callCount('DestroyForce'), 1); eq(f.handle, nil)
    checkDisposed(f, {'getHandle', 'add', 'remove', 'contains', 'clear', 'enumPlayers', 'enumAllies',
        'enumEnemies', 'getPlayers'})
end)
