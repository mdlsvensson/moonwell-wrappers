PLAYER_STATE_RESOURCE_GOLD, PLAYER_STATE_RESOURCE_LUMBER = {}, {}
local Player = require('wrappers.player')
eq(totalCalls(), 0)

test('resources read, set and add through player state', function()
    local p, gold, lumber = Player.fromIndex(0), 100, 50
    native('GetPlayerState', function(_, state)
        if state == PLAYER_STATE_RESOURCE_GOLD then return gold end
        return lumber
    end)
    native('SetPlayerState', function(_, state, value)
        if state == PLAYER_STATE_RESOURCE_GOLD then gold = value else lumber = value end
    end)
    eq(p:getGold(), 100); expectCall('GetPlayerState', PLAYER_RAW, PLAYER_STATE_RESOURCE_GOLD)
    eq(p:getLumber(), 50); expectCall('GetPlayerState', PLAYER_RAW, PLAYER_STATE_RESOURCE_LUMBER)
    p:setGold(10); expectCall('SetPlayerState', PLAYER_RAW, PLAYER_STATE_RESOURCE_GOLD, 10)
    p:setLumber(20); expectCall('SetPlayerState', PLAYER_RAW, PLAYER_STATE_RESOURCE_LUMBER, 20)
    p:addGold(5); eq(gold, 15)
    p:addLumber(-5); eq(lumber, 15); expectCall('SetPlayerState', PLAYER_RAW, PLAYER_STATE_RESOURCE_LUMBER, 15)
    -- A wrong amount is refused at the caller, before any native; an integral float is an integer.
    resetCalls()
    for _, bad in ipairs({1.5, 2 ^ 31, -2 ^ 31 - 1, 0/0, math.huge, '5', false, {}}) do
        failsAt(function() p:addGold(bad) end, 'Player.addGold: expected an integer amount')
        failsAt(function() p:addLumber(bad) end, 'Player.addLumber: expected an integer amount')
    end
    failsAt(function() p:addGold() end, 'Player.addGold: expected an integer amount')
    failsAt(function() p:addLumber() end, 'Player.addLumber: expected an integer amount')
    eq(totalCalls(), 0); eq(gold, 15); eq(lumber, 15)
    p:addGold(5.0); eq(gold, 20)
    -- The edges of the 32-bit range are amounts.
    p:addGold(2 ^ 31 - 1); p:addGold(-2 ^ 31); eq(gold, 19)
end)

test('alliances take player wrappers', function()
    local p, other, setting = Player.fromIndex(0), Player.fromHandle({}), {}
    native('GetPlayerAlliance', function() return true end)
    eq(p:getAlliance(other, setting), true); expectCall('GetPlayerAlliance', PLAYER_RAW, other.handle, setting)
    native('SetPlayerAlliance', function() end)
    p:setAlliance(other, setting, false); expectCall('SetPlayerAlliance', PLAYER_RAW, other.handle, setting, false)
    native('IsPlayerAlly', function() return false end)
    eq(p:isAlly(other), false); expectCall('IsPlayerAlly', PLAYER_RAW, other.handle)
    native('IsPlayerEnemy', function() return true end)
    eq(p:isEnemy(other), true); expectCall('IsPlayerEnemy', PLAYER_RAW, other.handle)
    failsAt(function() p:isAlly({}) end, 'Player.isAlly: expected Player wrapper')
    failsAt(function() p:setAlliance({}, setting, true) end, 'Player.setAlliance: expected Player wrapper')
    eq(callCount('IsPlayerAlly'), 1); eq(callCount('SetPlayerAlliance'), 1)
end)

test('tech, slot and start location', function()
    local p, controller, slot, race = Player.fromIndex(0), {}, {}, {}
    checkGetters(p, {{'GetPlayerTechCount', 'getTechCount', 2, 1382118509, true},
        {'GetPlayerController', 'getController', controller}, {'GetPlayerSlotState', 'getSlotState', slot},
        {'GetPlayerRace', 'getRace', race}, {'GetPlayerTeam', 'getTeam', 1},
        {'GetPlayerStartLocationX', 'getStartX', -512}, {'GetPlayerStartLocationY', 'getStartY', 256}})
    checkSetters(p, {{'SetPlayerTechResearched', 'setTechResearched', 1382118509, 2},
        {'AddPlayerTechResearched', 'addTechResearched', 1382118509, 1},
        {'SetPlayerTechMaxAllowed', 'setTechMaxAllowed', 1382118509, 3},
        {'SetPlayerAbilityAvailable', 'setAbilityAvailable', 1097361000, false}})
end)

test('isLocal compares with the local player without a local factory', function()
    local p, other = Player.fromIndex(0), Player.fromHandle({})
    native('GetLocalPlayer', function() return PLAYER_RAW end)
    eq(p:isLocal(), true); eq(other:isLocal(), false); eq(callCount('GetLocalPlayer'), 2)
    eq(rawget(Player, 'local'), nil)
end)

test('fromEvent wraps the player of the running event, and nil when it has none', function()
    local raw = {}
    native('GetTriggerPlayer', function() return raw end)
    local found = Player.fromEvent()
    eq(found, Player.fromHandle(raw)); eq(found.handle, raw); eq(callCount('GetTriggerPlayer'), 1)
    native('GetTriggerPlayer', function() return nil end)
    eq(Player.fromEvent(), nil)
end)
