EVENT_PLAYER_UNIT_DAMAGING, EVENT_PLAYER_UNIT_DAMAGED = {}, {}
ATTACK_NORMAL, ATTACK_CHAOS, DAMAGE_NORMAL, DAMAGE_UNIVERSAL, WEAPON_NONE, WEAPON_METAL = {}, {}, {}, {}, {}, {}
local actions = {}
native('CreateTrigger', function() return {events = {}, enabled = true} end)
native('TriggerRegisterPlayerUnitEvent', function(trigger, _, event) trigger.events[#trigger.events + 1] = event end)
native('TriggerAddAction', function(trigger, callback)
    actions[#actions + 1] = {trigger = trigger, callback = callback}
    return {}
end)
native('EnableTrigger', function(trigger) trigger.enabled = true end)
native('DisableTrigger', function(trigger) trigger.enabled = false end)
local hit = {}
native('GetEventDamageSource', function() return hit.source end)
native('BlzGetEventDamageTarget', function() return hit.target end)
native('GetEventDamage', function() return hit.amount end)
native('BlzGetEventIsAttack', function() return hit.isAttack end)
native('BlzGetEventAttackType', function() return hit.attackType end)
native('BlzGetEventDamageType', function() return hit.damageType end)
native('BlzGetEventWeaponType', function() return hit.weaponType end)
native('BlzSetEventDamage', function(amount) hit.amount = amount end)
native('BlzSetEventAttackType', function(value) hit.attackType = value end)
native('BlzSetEventDamageType', function(value) hit.damageType = value end)
native('BlzSetEventWeaponType', function(value) hit.weaponType = value end)
local Damage = require('wrappers.damage')
local Unit = require('wrappers.unit')
eq(totalCalls(), 0)

local SOURCE, TARGET = {}, {}
-- Simulates one hit: sets the event data, then runs the action of every enabled trigger registered for `event`.
-- `options.amount` replaces the default 10; `options.noSource` makes the game give no source. Returns the hit, whose
-- fields the setter doubles change.
local function fire(event, options)
    options = options or {}
    hit = {source = SOURCE, target = TARGET, amount = options.amount or 10, isAttack = true,
        attackType = ATTACK_NORMAL, damageType = DAMAGE_NORMAL, weaponType = WEAPON_NONE}
    if options.noSource then hit.source = nil end
    local current = hit
    for _, action in ipairs(actions) do
        if action.trigger.enabled and action.trigger.events[1] == event then action.callback() end
    end
    return current
end

test('the first listener of a phase creates its trigger; an empty phase is disabled, never destroyed', function()
    local first = Damage.onDamaging(function() end)
    eq(callCount('CreateTrigger'), 1); eq(callCount('TriggerAddAction'), 1)
    eq(callCount('TriggerRegisterPlayerUnitEvent'), 28)
    expectCall('TriggerRegisterPlayerUnitEvent', actions[1].trigger, PLAYER_RAW, EVENT_PLAYER_UNIT_DAMAGING, nil)
    local second = Damage.onDamaging(function() end)
    eq(callCount('CreateTrigger'), 1)
    local after = Damage.onDamaged(function() end)
    eq(callCount('CreateTrigger'), 2)
    expectCall('TriggerRegisterPlayerUnitEvent', actions[2].trigger, PLAYER_RAW, EVENT_PLAYER_UNIT_DAMAGED, nil)
    first(); eq(callCount('DisableTrigger'), 0)
    second(); eq(callCount('DisableTrigger'), 1); eq(actions[1].trigger.enabled, false)
    after(); eq(actions[2].trigger.enabled, false)
    local again = Damage.onDamaging(function() end)
    eq(callCount('CreateTrigger'), 2); eq(callCount('EnableTrigger'), 1); eq(actions[1].trigger.enabled, true)
    again()
    eq(callCount('DestroyTrigger'), 0)
end)

test('listeners share one event with the hit data, in the order added', function()
    local seen = {}
    local a = Damage.onDamaging(function(event) seen[#seen + 1] = {'a', event} end)
    local b = Damage.onDamaging(function(event) seen[#seen + 1] = {'b', event} end)
    local other = Damage.onDamaged(function() seen[#seen + 1] = {'damaged'} end)
    fire(EVENT_PLAYER_UNIT_DAMAGING)
    eq(#seen, 2); eq(seen[1][1], 'a'); eq(seen[2][1], 'b'); eq(seen[1][2], seen[2][2])
    local event = seen[1][2]
    eq(event.source, Unit.fromHandle(SOURCE)); eq(event.target, Unit.fromHandle(TARGET))
    eq(event.amount, 10); eq(event.isAttack, true)
    eq(event.attackType, ATTACK_NORMAL); eq(event.damageType, DAMAGE_NORMAL); eq(event.weaponType, WEAPON_NONE)
    fire(EVENT_PLAYER_UNIT_DAMAGED)
    eq(#seen, 3); eq(seen[3][1], 'damaged')
    fire(EVENT_PLAYER_UNIT_DAMAGING)
    eq(seen[4][2] ~= event, true)
    eq(#PRINTED, 0)
    a(); b(); other()
end)

test('a hit with no source gives a nil source', function()
    local seen
    local cancel = Damage.onDamaged(function(event) seen = event end)
    fire(EVENT_PLAYER_UNIT_DAMAGED, {noSource = true})
    eq(seen.source, nil); eq(seen.target, Unit.fromHandle(TARGET))
    cancel()
end)

test('a listener added during a firing waits; one removed during a firing is skipped', function()
    local log, late, second = {}, nil, nil
    local first = Damage.onDamaging(function()
        log[#log + 1] = 'first'
        if not late then late = Damage.onDamaging(function() log[#log + 1] = 'late' end) end
        second()
    end)
    second = Damage.onDamaging(function() log[#log + 1] = 'second' end)
    fire(EVENT_PLAYER_UNIT_DAMAGING)
    eq(table.concat(log, ','), 'first')
    fire(EVENT_PLAYER_UNIT_DAMAGING)
    eq(table.concat(log, ','), 'first,first,late')
    first(); late(); second()
end)

test('a failing listener is printed and the next one still runs', function()
    local count = 0
    local a = Damage.onDamaging(function() error('intentional damage probe') end)
    local b = Damage.onDamaging(function() count = count + 1 end)
    fire(EVENT_PLAYER_UNIT_DAMAGING)
    eq(count, 1); eq(#PRINTED, 1)
    assert(PRINTED[1]:find('[wrappers] Damage listener callback failed:', 1, true), PRINTED[1])
    assert(PRINTED[1]:find('intentional damage probe', 1, true), PRINTED[1])
    a(); b()
end)

test('module functions check their arguments at the caller', function()
    failsAt(function() Damage.onDamaging(nil) end, 'Damage.onDamaging: expected a callback function')
    failsAt(function() Damage.onDamaged('x') end, 'Damage.onDamaged: expected a callback function')
    eq(Damage.off, nil)
    eq(callCount('CreateTrigger'), 0)
end)

test('a registration returns one cancel function: it works once, at once, and never again', function()
    local log, cancelSelf = {}, nil
    local results = table.pack(Damage.onDamaged(function() log[#log + 1] = 'a' end))
    eq(results.n, 1); eq(type(results[1]), 'function')
    local cancelA = results[1]
    local cancelB = Damage.onDamaged(function() log[#log + 1] = 'b' end)
    cancelSelf = Damage.onDamaged(function() log[#log + 1] = 'self'; cancelSelf() end)
    resetCalls()
    eq(select('#', cancelA()), 0)
    cancelA(); cancelA()
    fire(EVENT_PLAYER_UNIT_DAMAGED); fire(EVENT_PLAYER_UNIT_DAMAGED)
    eq(table.concat(log, ','), 'b,self,b')
    -- A phase with a listener left stays enabled, however often an old cancel function is called.
    eq(callCount('DisableTrigger'), 0)
    cancelB()
    eq(callCount('DisableTrigger'), 1)
    local quiet = totalCalls()
    fire(EVENT_PLAYER_UNIT_DAMAGED)
    eq(#log, 3); eq(totalCalls(), quiet)
    -- Nor does an old cancel function disable a phase that has a listener again.
    local again = Damage.onDamaged(function() log[#log + 1] = 'again' end)
    eq(callCount('EnableTrigger'), 1)
    cancelB(); cancelA(); cancelSelf()
    eq(callCount('DisableTrigger'), 1)
    fire(EVENT_PLAYER_UNIT_DAMAGED)
    eq(table.concat(log, ','), 'b,self,b,again'); eq(#PRINTED, 0)
    again()
    eq(callCount('DisableTrigger'), 2)
end)

test('setAmount changes the hit and the shared event', function()
    local seen
    local a = Damage.onDamaging(function(event) event:setAmount(event.amount * 2) end)
    local b = Damage.onDamaging(function(event) seen = event.amount end)
    local result = fire(EVENT_PLAYER_UNIT_DAMAGING)
    eq(seen, 20); eq(result.amount, 20); expectCall('BlzSetEventDamage', 20)
    a(); b()
    local c = Damage.onDamaged(function(event) event:setAmount(3); seen = event end)
    result = fire(EVENT_PLAYER_UNIT_DAMAGED)
    eq(result.amount, 3); eq(seen.amount, 3)
    eq(#PRINTED, 0)
    c()
end)

test('a DAMAGING event changes the types; a DAMAGED event has no type setters', function()
    local seen
    local a = Damage.onDamaging(function(event)
        event:setAttackType(ATTACK_CHAOS); event:setDamageType(DAMAGE_UNIVERSAL); event:setWeaponType(WEAPON_METAL)
        seen = event
    end)
    local result = fire(EVENT_PLAYER_UNIT_DAMAGING)
    eq(result.attackType, ATTACK_CHAOS); eq(result.damageType, DAMAGE_UNIVERSAL); eq(result.weaponType, WEAPON_METAL)
    eq(seen.attackType, ATTACK_CHAOS); eq(seen.damageType, DAMAGE_UNIVERSAL); eq(seen.weaponType, WEAPON_METAL)
    a()
    local b = Damage.onDamaged(function(event) seen = event end)
    fire(EVENT_PLAYER_UNIT_DAMAGED)
    eq(seen.setAttackType, nil); eq(seen.setDamageType, nil); eq(seen.setWeaponType, nil)
    eq(#PRINTED, 0)
    b()
end)

test('setters check their arguments at the caller', function()
    local ran = false
    local cancel = Damage.onDamaging(function(event)
        failsAt(function() event:setAmount('1') end, 'DamagingEvent.setAmount: expected a finite amount')
        failsAt(function() event:setAmount(0 / 0) end, 'DamagingEvent.setAmount: expected a finite amount')
        failsAt(function() event:setAmount(math.huge) end, 'DamagingEvent.setAmount: expected a finite amount')
        failsAt(function() event:setAmount(-math.huge) end, 'DamagingEvent.setAmount: expected a finite amount')
        failsAt(function() event:setAttackType(nil) end, 'DamagingEvent.setAttackType: expected an attack type')
        failsAt(function() event:setDamageType(nil) end, 'DamagingEvent.setDamageType: expected a damage type')
        failsAt(function() event:setWeaponType(nil) end, 'DamagingEvent.setWeaponType: expected a weapon type')
        event:setAmount(-5)
        ran = true
    end)
    fire(EVENT_PLAYER_UNIT_DAMAGING)
    eq(#PRINTED, 0); eq(ran, true)
    eq(callCount('BlzSetEventDamage'), 1); expectCall('BlzSetEventDamage', -5)
    eq(callCount('BlzSetEventAttackType') + callCount('BlzSetEventDamageType') + callCount('BlzSetEventWeaponType'), 0)
    cancel()
end)

test('setters raise once the firing is over', function()
    local damaging, damaged
    local a = Damage.onDamaging(function(event) damaging = event end)
    local b = Damage.onDamaged(function(event) damaged = event end)
    fire(EVENT_PLAYER_UNIT_DAMAGING); fire(EVENT_PLAYER_UNIT_DAMAGED)
    a(); b()
    resetCalls()
    failsAt(function() damaging:setAmount(1) end, 'DamagingEvent.setAmount: the damage event is over')
    failsAt(function() damaging:setAttackType(ATTACK_CHAOS) end, 'DamagingEvent.setAttackType: the damage event is over')
    failsAt(function() damaging:setDamageType(DAMAGE_UNIVERSAL) end,
        'DamagingEvent.setDamageType: the damage event is over')
    failsAt(function() damaging:setWeaponType(WEAPON_METAL) end, 'DamagingEvent.setWeaponType: the damage event is over')
    failsAt(function() damaged:setAmount(1) end, 'DamagedEvent.setAmount: the damage event is over')
    eq(totalCalls(), 0)
end)

test('a nested hit gets its own event and the outer one stays live', function()
    local outer, inner, depth = nil, nil, 0
    local cancel = Damage.onDamaging(function(event)
        depth = depth + 1
        if depth == 1 then
            outer = event
            local saved = hit
            fire(EVENT_PLAYER_UNIT_DAMAGING, {amount = 1})
            hit = saved
            event:setAmount(7)
        else
            inner = event
        end
    end)
    local result = fire(EVENT_PLAYER_UNIT_DAMAGING)
    eq(#PRINTED, 0)
    eq(outer ~= inner, true); eq(inner.amount, 1); eq(outer.amount, 7); eq(result.amount, 7)
    failsAt(function() inner:setAmount(2) end, 'DamagingEvent.setAmount: the damage event is over')
    cancel()
end)
