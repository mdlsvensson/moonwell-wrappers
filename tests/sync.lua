bj_MAX_PLAYERS = 24
local actions = {}
native('CreateTrigger', function() return {prefixes = {}, enabled = true} end)
native('BlzTriggerRegisterPlayerSyncEvent', function(trigger, _, prefix)
    trigger.prefixes[#trigger.prefixes + 1] = prefix
    return {}
end)
native('TriggerAddAction', function(trigger, callback)
    actions[#actions + 1] = {trigger = trigger, callback = callback}
    return {}
end)
native('EnableTrigger', function(trigger) trigger.enabled = true end)
native('DisableTrigger', function(trigger) trigger.enabled = false end)
native('BlzSendSyncData', function() return true end)
local message = {}
native('GetTriggerPlayer', function() return message.player end)
native('BlzGetTriggerSyncData', function() return message.data end)
local Sync = require('wrappers.sync')
local Player = require('wrappers.player')
eq(totalCalls(), 0)

-- Simulates a synced message arriving: runs the action of every enabled trigger registered for `prefix`.
local function deliver(prefix, data, who)
    message = {player = who or PLAYER_RAW, data = data}
    for _, action in ipairs(actions) do
        if action.trigger.enabled and action.trigger.prefixes[1] == prefix then action.callback() end
    end
end

test('one trigger per prefix, registered for every player, disabled when empty', function()
    local a = Sync.on('load', function() end)
    eq(callCount('CreateTrigger'), 1); eq(callCount('BlzTriggerRegisterPlayerSyncEvent'), 24)
    expectCall('BlzTriggerRegisterPlayerSyncEvent', actions[1].trigger, PLAYER_RAW, 'load', false)
    local b = Sync.on('load', function() end)
    local c = Sync.on('save', function() end)
    eq(callCount('CreateTrigger'), 2)
    a(); b()
    eq(actions[1].trigger.enabled, false); eq(actions[2].trigger.enabled, true)
    local again = Sync.on('load', function() end)
    eq(callCount('CreateTrigger'), 2); eq(actions[1].trigger.enabled, true)
    again(); c()
    eq(callCount('DestroyTrigger'), 0)
end)

test('listeners get the player and the data, in order', function()
    local seen = {}
    local a = Sync.on('load', function(player, data) seen[#seen + 1] = {'a', player, data} end)
    local b = Sync.on('load', function(player, data) seen[#seen + 1] = {'b', player, data} end)
    local other = Sync.on('save', function() seen[#seen + 1] = {'save'} end)
    local sender = {}
    deliver('load', 'hello', sender)
    eq(#seen, 2); eq(seen[1][1], 'a'); eq(seen[2][1], 'b')
    eq(seen[1][2], Player.fromHandle(sender)); eq(seen[1][3], 'hello'); eq(seen[2][3], 'hello')
    eq(#PRINTED, 0)
    a(); b(); other()
end)

test('a listener added during a firing waits; a failing one is printed and the next still runs', function()
    local log, late = {}, nil
    local first = Sync.on('load', function()
        log[#log + 1] = 'first'
        if not late then late = Sync.on('load', function() log[#log + 1] = 'late' end) end
    end)
    local broken = Sync.on('load', function() error('intentional sync probe') end)
    deliver('load', 'x')
    eq(table.concat(log, ','), 'first'); eq(#PRINTED, 1)
    assert(PRINTED[1]:find('[wrappers] Sync listener callback failed:', 1, true), PRINTED[1])
    broken()
    deliver('load', 'x')
    eq(table.concat(log, ','), 'first,first,late')
    first(); late()
end)

test('send checks the prefix and the 255-byte limit', function()
    local longest = string.rep('a', 255)
    eq(Sync.send('load', longest), true); expectCall('BlzSendSyncData', 'load', longest)
    eq(Sync.send('load', ''), true)
    failsAt(function() Sync.send('load', string.rep('a', 256)) end,
        'Sync.send: data is 256 bytes, over the 255-byte limit')
    failsAt(function() Sync.send('load', string.rep('\u{e9}', 128)) end,
        'Sync.send: data is 256 bytes, over the 255-byte limit')
    failsAt(function() Sync.send('load', 5) end, 'Sync.send: expected a data string')
    failsAt(function() Sync.send('', 'x') end, 'Sync.send: expected a non-empty prefix string')
    failsAt(function() Sync.send(nil, 'x') end, 'Sync.send: expected a non-empty prefix string')
    eq(callCount('BlzSendSyncData'), 2)
    native('BlzSendSyncData', function() return false end)
    eq(Sync.send('load', 'x'), false)
end)

test('on checks its arguments at the caller', function()
    failsAt(function() Sync.on('', function() end) end, 'Sync.on: expected a non-empty prefix string')
    failsAt(function() Sync.on(7, function() end) end, 'Sync.on: expected a non-empty prefix string')
    failsAt(function() Sync.on('load', nil) end, 'Sync.on: expected a callback function')
    eq(Sync.off, nil)
end)

test('a registration returns one cancel function: it works once, at once, and never again', function()
    local log, cancelSelf = {}, nil
    local results = table.pack(Sync.on('once', function() log[#log + 1] = 'a' end))
    eq(results.n, 1); eq(type(results[1]), 'function')
    local cancelA = results[1]
    local cancelB = Sync.on('once', function() log[#log + 1] = 'b' end)
    cancelSelf = Sync.on('once', function() log[#log + 1] = 'self'; cancelSelf() end)
    resetCalls()
    eq(select('#', cancelA()), 0)
    cancelA(); cancelA()
    deliver('once', 'x'); deliver('once', 'x')
    eq(table.concat(log, ','), 'b,self,b')
    eq(callCount('DisableTrigger'), 0)
    cancelB()
    eq(callCount('DisableTrigger'), 1)
    deliver('once', 'x')
    eq(#log, 3)
    -- Nor does an old cancel function disable a prefix that has a listener again.
    local again = Sync.on('once', function() log[#log + 1] = 'again' end)
    eq(callCount('EnableTrigger'), 1)
    cancelB(); cancelA(); cancelSelf()
    eq(callCount('DisableTrigger'), 1)
    deliver('once', 'x')
    eq(table.concat(log, ','), 'b,self,b,again'); eq(#PRINTED, 0)
    again()
    eq(callCount('DisableTrigger'), 2)
end)
