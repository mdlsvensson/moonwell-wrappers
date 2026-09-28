local actions, conditions = {}, {}
local lastAction, lastBoolexpr, lastCondition
native('CreateTrigger', function() return {} end)
native('TriggerAddAction', function(_, callback)
    actions[#actions + 1] = callback; lastAction = {}; return lastAction
end)
native('Condition', function(fn) conditions[#conditions + 1] = fn; lastBoolexpr = {}; return lastBoolexpr end)
native('TriggerAddCondition', function() lastCondition = {}; return lastCondition end)
for _, name in ipairs({'DestroyTrigger', 'TriggerRemoveAction', 'TriggerClearActions', 'TriggerRemoveCondition',
    'TriggerClearConditions', 'DestroyCondition', 'CreateRegion', 'RemoveRegion', 'RemoveItem'}) do
    native(name, function() end)
end
native('CreateRegion', function() return {} end)
local Trigger = require('wrappers.trigger')
local Unit = require('wrappers.unit')
local Player = require('wrappers.player')
local Region = require('wrappers.region')
local Item = require('wrappers.item')
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

test('new registrations forward exact arguments', function()
    local t, u, p, g, item = Trigger.create(), Unit.fromHandle({}), Player.fromIndex(0), Region.create(),
        Item.fromHandle({})
    local event, state, op = {}, {}, {}
    for _, name in ipairs({'TriggerRegisterPlayerUnitEvent', 'TriggerRegisterPlayerEvent',
        'TriggerRegisterPlayerChatEvent', 'TriggerRegisterEnterRegion', 'TriggerRegisterLeaveRegion',
        'TriggerRegisterDeathEvent', 'TriggerRegisterUnitInRange', 'TriggerRegisterUnitStateEvent',
        'TriggerRegisterGameEvent', 'TriggerExecute'}) do native(name, function() end) end
    resetCalls()
    t:registerAnyUnitEvent(event)
    eq(callCount('TriggerRegisterPlayerUnitEvent'), bj_MAX_PLAYER_SLOTS); eq(callCount('Player'), bj_MAX_PLAYER_SLOTS)
    expectCall('Player', bj_MAX_PLAYER_SLOTS - 1)
    expectCall('TriggerRegisterPlayerUnitEvent', t.handle, PLAYER_RAW, event, nil)
    t:registerPlayerEvent(p, event); expectCall('TriggerRegisterPlayerEvent', t.handle, PLAYER_RAW, event)
    t:registerChatEvent(p, '-go', true); expectCall('TriggerRegisterPlayerChatEvent', t.handle, PLAYER_RAW, '-go', true)
    t:registerEnterRegion(g); expectCall('TriggerRegisterEnterRegion', t.handle, g.handle, nil)
    t:registerLeaveRegion(g); expectCall('TriggerRegisterLeaveRegion', t.handle, g.handle, nil)
    t:registerDeathEvent(item); expectCall('TriggerRegisterDeathEvent', t.handle, item.handle)
    t:registerDeathEvent(u); expectCall('TriggerRegisterDeathEvent', t.handle, u.handle)
    t:registerUnitInRange(u, 300); expectCall('TriggerRegisterUnitInRange', t.handle, u.handle, 300, nil)
    t:registerUnitStateEvent(u, state, op, 50)
    expectCall('TriggerRegisterUnitStateEvent', t.handle, u.handle, state, op, 50)
    t:registerGameEvent(event); expectCall('TriggerRegisterGameEvent', t.handle, event)
    native('TriggerEvaluate', function() return false end)
    eq(t:evaluate(), false); expectCall('TriggerEvaluate', t.handle)
    t:execute(); expectCall('TriggerExecute', t.handle)
    t:destroy(); g:destroy(); item:remove(); u:remove()
end)

test('new registrations validate before natives', function()
    local t, u, p, item = Trigger.create(), Unit.fromHandle({}), Player.fromIndex(0), Item.fromHandle({})
    resetCalls()
    fails(function() t:registerEnterRegion(u) end, 'Trigger.registerEnterRegion: expected Region wrapper')
    fails(function() t:registerLeaveRegion(p) end, 'Trigger.registerLeaveRegion: expected Region wrapper')
    fails(function() t:registerDeathEvent(p) end, 'Trigger.registerDeathEvent: expected Widget wrapper')
    fails(function() t:registerChatEvent(u, 'x', true) end, 'Trigger.registerChatEvent: expected Player wrapper')
    fails(function() t:registerPlayerEvent(u, {}) end, 'Trigger.registerPlayerEvent: expected Player wrapper')
    fails(function() t:registerUnitStateEvent(p, {}, {}, 1) end, 'Trigger.registerUnitStateEvent: expected Unit wrapper')
    for _, bad in ipairs({-1, math.huge, 0/0, '1'}) do
        fails(function() t:registerUnitInRange(u, bad) end, 'Trigger.registerUnitInRange')
    end
    fails(function() t:addCondition(nil) end, 'callback')
    item:remove()
    fails(function() t:registerDeathEvent(item) end, 'Trigger.registerDeathEvent: Item is disposed')
    eq(callCount('RemoveItem'), 1); eq(totalCalls(), 1)
    t:destroy(); u:remove()
end)

test('conditions own boolexprs and failures evaluate false', function()
    local t, pass = Trigger.create(), nil
    local token = t:addCondition(function(self) eq(self, t); return pass end)
    local boolexpr, nativeCondition, check = lastBoolexpr, lastCondition, conditions[#conditions]
    expectCall('TriggerAddCondition', t.handle, boolexpr)
    eq(check(), false)
    pass = 1; eq(check(), true)
    t:addCondition(function() error('condition probe') end)
    eq(conditions[#conditions](), false); eq(#PRINTED, 1)
    assert(PRINTED[1]:find('[wrappers] Trigger condition failed:', 1, true))
    assert(PRINTED[1]:find('condition probe', 1, true))
    t:removeCondition(token)
    expectCall('TriggerRemoveCondition', t.handle, nativeCondition); expectCall('DestroyCondition', boolexpr)
    eq(check(), false)
    t:removeCondition(token); eq(callCount('TriggerRemoveCondition'), 1); eq(callCount('DestroyCondition'), 1)
    native('Condition', function() return nil end)
    fails(function() t:addCondition(function() return true end) end, 'Trigger.addCondition')
    native('Condition', function(fn) conditions[#conditions + 1] = fn; lastBoolexpr = {}; return lastBoolexpr end)
    t:destroy()
end)

test('action tokens remove individual actions, even mid-firing', function()
    local t, hits, second = Trigger.create(), {}, nil
    t:addAction(function(self) hits[#hits + 1] = 'first'; self:removeAction(second) end)
    local runFirst = actions[#actions]
    second = t:addAction(function() hits[#hits + 1] = 'second' end)
    local runSecond, secondNative = actions[#actions], lastAction
    runFirst(); runSecond()
    eq(#hits, 1); eq(hits[1], 'first')
    expectCall('TriggerRemoveAction', t.handle, secondNative)
    t:removeAction(second); eq(callCount('TriggerRemoveAction'), 1)
    t:destroy()
end)

test('tokens are checked for kind and owner', function()
    local a, b = Trigger.create(), Trigger.create()
    local action, condition = a:addAction(function() end), a:addCondition(function() return true end)
    resetCalls()
    fails(function() b:removeAction(action) end, 'Trigger.removeAction: token belongs to another trigger')
    fails(function() a:removeAction(condition) end, 'Trigger.removeAction: expected TriggerAction token')
    fails(function() a:removeCondition(action) end, 'Trigger.removeCondition: expected TriggerCondition token')
    fails(function() a:removeAction({}) end, 'Trigger.removeAction: expected TriggerAction token')
    eq(totalCalls(), 0)
    a:destroy(); b:destroy()
end)

test('clear operations release callbacks and owned boolexprs', function()
    local t, hits = Trigger.create(), 0
    local action = t:addAction(function() hits = hits + 1 end)
    local runAction = actions[#actions]
    local kept = t:addCondition(function() return true end)
    local keptBoolexpr, keptCheck = lastBoolexpr, conditions[#conditions]
    local removed = t:addCondition(function() return true end)
    t:removeCondition(removed)
    resetCalls()
    t:clearConditions()
    eq(callName(1), 'TriggerClearConditions'); expectCall('TriggerClearConditions', t.handle)
    expectCall('DestroyCondition', keptBoolexpr); eq(callCount('DestroyCondition'), 1)
    eq(keptCheck(), false)
    t:removeCondition(kept); eq(callCount('TriggerRemoveCondition'), 0)
    t:clearActions(); expectCall('TriggerClearActions', t.handle)
    runAction(); eq(hits, 0)
    t:removeAction(action); eq(callCount('TriggerRemoveAction'), 0)
    t:destroy()
end)

test('destroy clears conditions, destroys boolexprs, then the trigger', function()
    local t = Trigger.create()
    local condition = t:addCondition(function() return true end)
    local boolexpr = lastBoolexpr
    t:addAction(function() end)
    local raw = t.handle
    resetCalls()
    t:destroy(); t:destroy()
    eq(callName(1), 'TriggerClearConditions'); eq(callName(2), 'DestroyCondition'); eq(callName(3), 'DestroyTrigger')
    eq(totalCalls(), 3)
    expectCall('TriggerClearConditions', raw); expectCall('DestroyCondition', boolexpr); expectCall('DestroyTrigger', raw)
    fails(function() t:removeCondition(condition) end, 'disposed')
    checkDisposed(t, {'registerAnyUnitEvent', 'registerPlayerEvent', 'registerChatEvent', 'registerEnterRegion',
        'registerLeaveRegion', 'registerDeathEvent', 'registerUnitInRange', 'registerUnitStateEvent',
        'registerGameEvent', 'addCondition', 'removeAction', 'removeCondition', 'clearActions', 'clearConditions',
        'evaluate', 'execute'})
end)
