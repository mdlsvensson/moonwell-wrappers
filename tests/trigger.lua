local actions = {}
native('CreateTrigger', function() return {} end)
native('TriggerAddAction', function(_, callback) actions[#actions + 1] = callback; return {} end)
native('DestroyTrigger', function() end)
local Trigger = require('wrappers.trigger')
local Unit = require('wrappers.unit')
local Player = require('wrappers.player')
eq(totalCalls(), 0)

test('trigger identity and exact native registrations', function()
    local t, u, p, event = Trigger.create(), Unit.fromHandle({}), Player.fromIndex(0), {}
    eq(Trigger.fromHandle(nil), nil); eq(Trigger.fromHandle(t.handle), t)
    for _, name in ipairs({'EnableTrigger', 'DisableTrigger', 'TriggerRegisterUnitEvent',
        'TriggerRegisterPlayerUnitEvent', 'TriggerRegisterTimerEvent'}) do native(name, function() end) end
    native('IsTriggerEnabled', function() return false end)
    t:enable(); expectCall('EnableTrigger', t.handle)
    t:disable(); expectCall('DisableTrigger', t.handle)
    eq(t:isEnabled(), false); expectCall('IsTriggerEnabled', t.handle)
    t:registerUnitEvent(u, event); expectCall('TriggerRegisterUnitEvent', t.handle, u.handle, event)
    t:registerPlayerUnitEvent(p, event)
    expectCall('TriggerRegisterPlayerUnitEvent', t.handle, p.handle, event, nil)
    t:registerTimerEvent(0, false); expectCall('TriggerRegisterTimerEvent', t.handle, 0, false)
    local raw = t:getHandle()
    t:destroy(); t:destroy(); expectCall('DestroyTrigger', raw); eq(callCount('DestroyTrigger'), 1)
    eq(t.handle, nil); eq(t:isDisposed(), true)
    for _, method in ipairs({'getHandle', 'enable', 'disable', 'isEnabled', 'registerUnitEvent',
        'registerPlayerUnitEvent', 'registerTimerEvent', 'addAction'}) do
        fails(function() t[method](t) end, 'disposed')
    end
    u:remove()
    native('CreateTrigger', function() return nil end); fails(Trigger.create, 'Trigger.create')
    native('CreateTrigger', function() return {} end)
end)

test('trigger validates arguments before registrations', function()
    local t, u = Trigger.create(), Unit.fromHandle({})
    fails(function() t:registerUnitEvent(t, {}) end, 'Unit')
    fails(function() t:registerPlayerUnitEvent(u, {}) end, 'Player')
    u:remove(); fails(function() t:registerUnitEvent(u, {}) end, 'disposed')
    for _, bad in ipairs({-1, math.huge, 0/0, '1'}) do
        fails(function() t:registerTimerEvent(bad, true) end, 'Trigger.registerTimerEvent')
    end
    fails(function() t:addAction(nil) end, 'callback')
    eq(callCount('TriggerRegisterUnitEvent'), 0); eq(callCount('TriggerRegisterPlayerUnitEvent'), 0)
    eq(callCount('TriggerRegisterTimerEvent'), 0); eq(callCount('TriggerAddAction'), 0)
    t:destroy()
end)

test('action failures are visible and later actions still run', function()
    local t, hits = Trigger.create(), 0
    t:addAction(function(self) eq(self, t); error('trigger probe') end)
    local first = actions[#actions]
    t:addAction(function(self) eq(self, t); hits = hits + 1; return 1 end)
    local second = actions[#actions]
    first(); second(); first(); second(); eq(hits, 2); eq(#PRINTED, 2)
    assert(PRINTED[1]:find('[wrappers] Trigger callback failed:', 1, true))
    t:destroy(); first(); second(); eq(hits, 2); eq(#PRINTED, 2)
end)

test('self destruction suppresses other retained actions', function()
    local t, hits = Trigger.create(), 0
    t:addAction(function(self) self:destroy() end)
    local first = actions[#actions]
    t:addAction(function() hits = hits + 1 end)
    local second = actions[#actions]
    native('DestroyTrigger', function() first(); second(); t:destroy(); error('native failed') end)
    first(); second(); eq(hits, 0); eq(t:isDisposed(), true); eq(callCount('DestroyTrigger'), 1)
    assert(PRINTED[1]:find('native failed', 1, true))
    native('DestroyTrigger', function() end)
end)
