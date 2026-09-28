local Player = require('wrappers.player')
local Unit = require('wrappers.unit')
eq(totalCalls(), 0)

test('identity and nil conversion', function()
    local p = Player.fromIndex(0)
    expectCall('Player', 0)
    eq(Player.fromHandle(PLAYER_RAW), p)
    eq(Player.fromHandle(nil), nil)
    eq(Unit.fromHandle(nil), nil)
    local u = Unit.create(p, 1751543663, 10, 20, 270)
    expectCall('CreateUnit', PLAYER_RAW, 1751543663, 10, 20, 270)
    eq(Unit.fromHandle(u.handle), u)
    eq(u:getHandle(), u.handle)
    eq(u:isDisposed(), false)
    u:remove()
end)

test('player index boundaries and nil factory', function()
    for _, bad in ipairs({-1, 28, 0.5, math.huge, 0/0, '0', false}) do
        fails(function() Player.fromIndex(bad) end, 'Player.fromIndex')
    end
    eq(callCount('Player'), 0)
    Player.fromIndex(27)
    native('Player', function() return nil end)
    fails(function() Player.fromIndex(0) end, 'Player.fromIndex')
    native('Player', function() return PLAYER_RAW end)
    native('CreateUnit', function() return nil end)
    fails(function() Unit.create(Player.fromIndex(0), 1, 0, 0, 0) end, 'Unit.create')
    native('CreateUnit', function() return {} end)
end)

test('player state reads and writes use the native handle', function()
    local p = Player.fromIndex(0)
    local color, state = {}, {}
    for _, row in ipairs({{'GetPlayerId', 'getId', 4}, {'GetPlayerName', 'getName', 'Blue'},
        {'GetPlayerColor', 'getColor', color}}) do
        native(row[1], function() return row[3] end)
        eq(p[row[2]](p), row[3]); expectCall(row[1], PLAYER_RAW)
    end
    native('GetPlayerState', function() return 123 end)
    eq(p:getState(state), 123); expectCall('GetPlayerState', PLAYER_RAW, state)
    native('SetPlayerState', function() end)
    p:setState(state, 45); expectCall('SetPlayerState', PLAYER_RAW, state, 45)
    eq(p:isDisposed(), false)
    eq(p.destroy, nil)
end)

test('unit getters read current native state', function()
    local u = Unit.fromHandle({})
    local owner = {}
    native('GetOwningPlayer', function() return owner end)
    eq(u:getOwner(), Player.fromHandle(owner)); expectCall('GetOwningPlayer', u.handle)
    for _, row in ipairs({{'GetUnitTypeId', 'getTypeId', 1751543663}, {'GetUnitX', 'getX', 11},
        {'GetUnitY', 'getY', 22}, {'GetUnitFacing', 'getFacing', 90},
        {'GetWidgetLife', 'getLife', 250}, {'BlzGetUnitMaxHP', 'getMaxLife', 420}}) do
        local value = row[3]
        native(row[1], function() return value end)
        eq(u[row[2]](u), value); expectCall(row[1], u.handle)
        value = value + 1; eq(u[row[2]](u), value)
    end
    u:remove()
end)

test('unit mutations and order arguments', function()
    local u, target, p = Unit.fromHandle({}), Unit.fromHandle({}), Player.fromIndex(0)
    local color = {}
    for _, name in ipairs({'SetUnitOwner', 'SetUnitPosition', 'SetUnitFacing', 'SetWidgetLife', 'SetUnitColor'}) do
        native(name, function() end)
    end
    u:setOwner(p, false); expectCall('SetUnitOwner', u.handle, p.handle, false)
    u:setPosition(30, 40); expectCall('SetUnitPosition', u.handle, 30, 40)
    u:setFacing(180); expectCall('SetUnitFacing', u.handle, 180)
    u:setLife(70); expectCall('SetWidgetLife', u.handle, 70)
    u:setColor(color); expectCall('SetUnitColor', u.handle, color)
    native('IssueImmediateOrder', function() return false end)
    eq(u:issueOrder('stop'), false); expectCall('IssueImmediateOrder', u.handle, 'stop')
    native('IssuePointOrder', function() return true end)
    eq(u:issuePointOrder('move', 1, 2), true); expectCall('IssuePointOrder', u.handle, 'move', 1, 2)
    native('IssueTargetOrder', function() return false end)
    eq(u:issueTargetOrder('attack', target), false)
    expectCall('IssueTargetOrder', u.handle, 'attack', target.handle)
    u:kill(); expectCall('KillUnit', u.handle); eq(u:isDisposed(), false)
    u:remove(); target:remove()
end)

test('disposal is idempotent and guards all receiver operations', function()
    local u = Unit.fromHandle({})
    local raw = u.handle
    u:remove(); expectCall('RemoveUnit', raw)
    eq(u:isDisposed(), true); eq(u.handle, nil)
    u:remove(); eq(callCount('RemoveUnit'), 1)
    for _, name in ipairs({'getHandle', 'getTypeId', 'getOwner', 'setOwner', 'getX', 'getY', 'setPosition',
        'getFacing', 'setFacing', 'getLife', 'setLife', 'getMaxLife', 'setColor', 'kill',
        'issueOrder', 'issuePointOrder', 'issueTargetOrder'}) do
        fails(function() u[name](u) end, 'disposed')
    end
    eq(totalCalls(), 1)
    local new = Unit.fromHandle({})
    assert(new ~= u); new:remove()
end)

test('wrong classes and forged wrappers fail before native mutation', function()
    local u = Unit.fromHandle({})
    fails(function() Unit.create(u, 1, 0, 0, 0) end, 'Player')
    fails(function() u:setOwner({}, true) end, 'Player')
    fails(function() u:issueTargetOrder('attack', Player.fromIndex(0)) end, 'Unit')
    local forged = setmetatable({handle = {}}, getmetatable(u))
    fails(function() forged:setLife(10) end, 'Unit')
    u:remove()
    local live = Unit.fromHandle({})
    fails(function() live:issueTargetOrder('attack', u) end, 'disposed')
    eq(callCount('CreateUnit'), 0); eq(callCount('SetUnitOwner'), 0); eq(callCount('IssueTargetOrder'), 0)
    eq(callCount('SetWidgetLife'), 0)
    live:remove()
end)

test('disposal state precedes reentrant native cleanup and survives failure', function()
    local u = Unit.fromHandle({})
    native('RemoveUnit', function()
        eq(u:isDisposed(), true); eq(u.handle, nil); u:remove()
        error('native failed')
    end)
    fails(function() u:remove() end, 'native failed')
    u:remove(); eq(callCount('RemoveUnit'), 1)
    fails(function() u:getHandle() end, 'disposed')
    native('RemoveUnit', function() end)
end)
