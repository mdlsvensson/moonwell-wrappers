UNIT_TYPE_HERO, UNIT_TYPE_DEAD, UNIT_STATE_MANA = {}, {}, {}
native('RemoveItem', function() end)
local Player = require('wrappers.player')
local Unit = require('wrappers.unit')
local Item = require('wrappers.item')
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
    for _, bad in ipairs({-1, 28, 0.5, 2 ^ 31, math.huge, 0/0, '0', false}) do
        failsAt(function() Player.fromIndex(bad) end, 'Player.fromIndex: expected an integer player slot from 0 to 27')
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
    u:setPlayerColor(color); expectCall('SetUnitColor', u.handle, color)
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
        'getFacing', 'setFacing', 'getLife', 'setLife', 'getMaxLife', 'setPlayerColor', 'kill',
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

test('hero methods forward exact arguments', function()
    local u = Unit.fromHandle({})
    native('IsUnitType', function(_, kind) return kind == UNIT_TYPE_HERO end)
    eq(u:isHero(), true); expectCall('IsUnitType', u.handle, UNIT_TYPE_HERO)
    checkGetters(u, {{'GetHeroProperName', 'getHeroName', 'Arthas'}, {'GetHeroLevel', 'getLevel', 3},
        {'GetHeroXP', 'getXP', 200}, {'GetHeroSkillPoints', 'getSkillPoints', 1},
        {'GetHeroStr', 'getStr', 17, true}, {'GetHeroAgi', 'getAgi', 18, false}, {'GetHeroInt', 'getInt', 19, true},
        {'UnitModifySkillPoints', 'modifySkillPoints', true, -1}, {'ReviveHero', 'revive', false, 1, 2, true}})
    checkSetters(u, {{'SetHeroLevel', 'setLevel', 4, true}, {'SetHeroXP', 'setXP', 300, false},
        {'AddHeroXP', 'addXP', 50, true}, {'SetHeroStr', 'setStr', 20, false}, {'SetHeroAgi', 'setAgi', 21, true},
        {'SetHeroInt', 'setInt', 22, false}, {'SelectHeroSkill', 'selectSkill', 1097361000}})
    u:remove()
end)

test('ability methods forward exact arguments', function()
    local u = Unit.fromHandle({})
    checkGetters(u, {{'UnitAddAbility', 'addAbility', true, 1097361000},
        {'UnitRemoveAbility', 'removeAbility', false, 1097361000},
        {'GetUnitAbilityLevel', 'getAbilityLevel', 2, 1097361000},
        {'SetUnitAbilityLevel', 'setAbilityLevel', 3, 1097361000, 3},
        {'BlzGetUnitAbilityCooldownRemaining', 'getCooldownRemaining', 1.5, 1097361000}})
    checkSetters(u, {{'BlzUnitHideAbility', 'setAbilityHidden', 1097361000, true},
        {'BlzUnitDisableAbility', 'setAbilityDisabled', 1097361000, true, false},
        {'BlzStartUnitAbilityCooldown', 'startCooldown', 1097361000, 5},
        {'BlzEndUnitAbilityCooldown', 'endCooldown', 1097361000}})
    native('UnitMakeAbilityPermanent', function() return true end)
    eq(u:setAbilityPermanent(1097361000, true), true)
    expectCall('UnitMakeAbilityPermanent', u.handle, true, 1097361000)
    native('UnitMakeAbilityPermanent', function() return false end)
    eq(u:setAbilityPermanent(1097361000, false), false)
    expectCall('UnitMakeAbilityPermanent', u.handle, false, 1097361000)
    u:remove()
end)

test('inventory validates slots and wraps items', function()
    local u, rawItem = Unit.fromHandle({}), {}
    native('UnitInventorySize', function() return 6 end)
    native('UnitItemInSlot', function(_, slot) if slot == 2 then return rawItem end end)
    eq(u:getInventorySize(), 6); expectCall('UnitInventorySize', u.handle)
    local item = u:getItemInSlot(2)
    eq(item, Item.fromHandle(rawItem)); expectCall('UnitItemInSlot', u.handle, 2)
    eq(u:getItemInSlot(0), nil)
    for _, bad in ipairs({-1, 6, 1.5, 2 ^ 31, 0/0, math.huge, '1'}) do
        failsAt(function() u:getItemInSlot(bad) end, 'Unit.getItemInSlot: expected an inventory slot index')
        failsAt(function() u:removeItemFromSlot(bad) end, 'Unit.removeItemFromSlot: expected an inventory slot index')
        failsAt(function() u:dropItemToSlot(item, bad) end, 'Unit.dropItemToSlot: expected an inventory slot index')
    end
    -- A slot that is no integer is refused without asking the game for the inventory's size.
    local asked = callCount('UnitInventorySize')
    failsAt(function() u:getItemInSlot('1') end, 'Unit.getItemInSlot: expected an inventory slot index')
    failsAt(function() u:getItemInSlot(2 ^ 31) end, 'Unit.getItemInSlot: expected an inventory slot index')
    eq(callCount('UnitInventorySize'), asked)
    eq(callCount('UnitItemInSlot'), 2); eq(callCount('UnitRemoveItemFromSlot'), 0); eq(callCount('UnitDropItemSlot'), 0)
    native('UnitRemoveItemFromSlot', function() return rawItem end)
    eq(u:removeItemFromSlot(2), item); expectCall('UnitRemoveItemFromSlot', u.handle, 2)
    native('UnitAddItemById', function() return nil end)
    eq(u:addItemById(1), nil); expectCall('UnitAddItemById', u.handle, 1)
    for _, row in ipairs({{'UnitAddItem', 'addItem', true}, {'UnitHasItem', 'hasItem', false},
        {'UnitUseItem', 'useItem', true}}) do
        native(row[1], function() return row[3] end)
        eq(u[row[2]](u, item), row[3]); expectCall(row[1], u.handle, rawItem)
    end
    native('UnitRemoveItem', function() end)
    u:removeItem(item); expectCall('UnitRemoveItem', u.handle, rawItem)
    native('UnitDropItemPoint', function() return true end)
    eq(u:dropItemAt(item, 3, 4), true); expectCall('UnitDropItemPoint', u.handle, rawItem, 3, 4)
    native('UnitDropItemSlot', function() return true end)
    eq(u:dropItemToSlot(item, 5), true); expectCall('UnitDropItemSlot', u.handle, rawItem, 5)
    fails(function() u:addItem(u) end, 'Unit.addItem: expected Item wrapper')
    item:remove()
    fails(function() u:hasItem(item) end, 'Unit.hasItem: Item is disposed')
    eq(callCount('UnitAddItem'), 1); eq(callCount('UnitHasItem'), 1)
    u:remove()
end)

test('state and presentation methods', function()
    local u, kind, p = Unit.fromHandle({}), {}, Player.fromIndex(0)
    native('GetUnitState', function() return 40 end)
    eq(u:getMana(), 40); expectCall('GetUnitState', u.handle, UNIT_STATE_MANA)
    native('SetUnitState', function() end)
    u:setMana(10); expectCall('SetUnitState', u.handle, UNIT_STATE_MANA, 10)
    checkGetters(u, {{'BlzGetUnitMaxMana', 'getMaxMana', 100}, {'GetUnitMoveSpeed', 'getMoveSpeed', 270},
        {'IsUnitPaused', 'isPaused', false}, {'BlzIsUnitInvulnerable', 'isInvulnerable', true},
        {'GetUnitName', 'getName', 'Footman'},
        {'GetUnitCurrentOrder', 'getCurrentOrder', 851983}, {'IsUnitType', 'isType', true, kind},
        {'BlzGetUnitCollisionSize', 'getCollisionSize', 16}})
    checkSetters(u, {{'BlzSetUnitMaxMana', 'setMaxMana', 150}, {'BlzSetUnitMaxHP', 'setMaxLife', 500},
        {'SetUnitMoveSpeed', 'setMoveSpeed', 300}, {'SetUnitX', 'setX', 5}, {'SetUnitY', 'setY', 6},
        {'SetUnitVertexColor', 'setColor', 255, 128, 0, 200}, {'SetUnitAnimation', 'setAnimation', 'attack'},
        {'PauseUnit', 'setPaused', true}, {'SetUnitInvulnerable', 'setInvulnerable', false},
        {'ShowUnit', 'setVisible', false},
        {'UnitApplyTimedLife', 'applyTimedLife', 1112045413, 5}, {'SetUnitPathing', 'setPathing', false}})
    -- isVisible is the opposite of IsUnitHidden.
    native('IsUnitHidden', function() return false end)
    eq(u:isVisible(), true); expectCall('IsUnitHidden', u.handle)
    native('IsUnitHidden', function() return true end)
    eq(u:isVisible(), false)
    for _, old in ipairs({'show', 'isHidden', 'pause', 'setVertexColor', 'hideAbility', 'disableAbility',
        'makeAbilityPermanent'}) do
        eq(Unit[old], nil)
    end
    native('SetUnitScale', function() end)
    u:setScale(1.5); expectCall('SetUnitScale', u.handle, 1.5, 1.5, 1.5)
    native('IsUnitAlly', function() return true end)
    eq(u:isAlly(p), true); expectCall('IsUnitAlly', u.handle, PLAYER_RAW)
    native('IsUnitEnemy', function() return false end)
    eq(u:isEnemy(p), false); expectCall('IsUnitEnemy', u.handle, PLAYER_RAW)
    fails(function() u:isAlly(u) end, 'Unit.isAlly: expected Player wrapper')
    u:remove()
end)

test('isAlive asks UnitAlive; exists asks for a type id', function()
    local u, alive, typeId = Unit.fromHandle({}), true, 1
    native('UnitAlive', function(raw) eq(raw, u.handle); return alive end)
    native('GetUnitTypeId', function() return typeId end)
    eq(u:isAlive(), true); eq(u:exists(), true)
    alive = false; eq(u:isAlive(), false); eq(u:exists(), true)
    typeId = 0; eq(u:exists(), false)
    typeId = 1
    u:remove()
    local asked = callCount('GetUnitTypeId')
    eq(u:exists(), false); eq(callCount('GetUnitTypeId'), asked)
    failsAt(function() Unit.exists({}) end, 'Unit.exists: expected Unit wrapper')
end)

test('sweep disposes the wrappers of removed units and leaves living units and corpses', function()
    collectgarbage(); collectgarbage()
    local types = {}
    native('GetUnitTypeId', function(raw) return types[raw] end)
    local living, corpse, gone = Unit.fromHandle({}), Unit.fromHandle({}), Unit.fromHandle({})
    local goneRaw = gone.handle
    types[living.handle], types[corpse.handle], types[goneRaw] = 1751543663, 1751543663, 0
    resetCalls()
    eq(select('#', Unit.sweep()), 0)
    eq(callCount('GetUnitTypeId'), 3); eq(totalCalls(), 3)
    eq(living:isDisposed(), false); eq(corpse:isDisposed(), false)
    eq(gone:isDisposed(), true); eq(gone.handle, nil); eq(gone:exists(), false)
    failsAt(function() gone:getX() end, 'Unit.getX: Unit is disposed')
    gone:remove(); eq(callCount('RemoveUnit'), 0)
    local again = Unit.fromHandle(goneRaw)
    assert(again ~= gone); eq(again:isDisposed(), false)
    types[goneRaw] = 1751543663
    Unit.sweep()
    eq(again:isDisposed(), false); eq(living:isDisposed(), false)
    again:remove(); living:remove(); corpse:remove()
end)

test('autoDispose sweeps on one repeating timer; starting again changes the interval; stop is idempotent', function()
    local timers, started, types = {}, nil, {}
    native('CreateTimer', function() timers[#timers + 1] = {}; return timers[#timers] end)
    native('TimerStart', function(timer, interval, periodic, callback)
        started = {timer = timer, interval = interval, periodic = periodic, callback = callback}
    end)
    native('PauseTimer', function() end)
    native('DestroyTimer', function() end)
    native('GetUnitTypeId', function(raw) return types[raw] end)
    local stop = Unit.autoDispose()
    eq(#timers, 1); eq(started.timer, timers[1]); eq(started.interval, 0.25); eq(started.periodic, true)
    -- The sweep is written once: the timer runs Unit.sweep itself.
    eq(started.callback, Unit.sweep)
    local gone, living = Unit.fromHandle({}), Unit.fromHandle({})
    types[gone.handle], types[living.handle] = 0, 1751543663
    started.callback()
    eq(gone:isDisposed(), true); eq(living:isDisposed(), false)
    local stopAgain = Unit.autoDispose(1)
    eq(#timers, 1); eq(started.timer, timers[1]); eq(started.interval, 1); eq(started.periodic, true)
    eq(callCount('DestroyTimer'), 0)
    stop()
    eq(callName(totalCalls() - 1), 'PauseTimer'); expectCall('PauseTimer', timers[1])
    eq(callName(totalCalls()), 'DestroyTimer'); expectCall('DestroyTimer', timers[1])
    stop(); stopAgain()
    eq(callCount('PauseTimer'), 1); eq(callCount('DestroyTimer'), 1)
    local last = Unit.autoDispose(0.5)
    eq(#timers, 2); eq(started.timer, timers[2]); eq(started.interval, 0.5)
    last(); expectCall('DestroyTimer', timers[2])
    living:remove()
end)

test('autoDispose rejects a bad interval and a missing timer at the caller, before any native', function()
    native('CreateTimer', function() return {} end)
    native('TimerStart', function() end)
    for _, bad in ipairs({0, -1, 0/0, math.huge, '1', false, {}}) do
        failsAt(function() Unit.autoDispose(bad) end, 'Unit.autoDispose: expected a finite positive interval')
    end
    eq(totalCalls(), 0)
    native('CreateTimer', function() return nil end)
    failsAt(function() Unit.autoDispose() end, 'Unit.autoDispose: native returned nil')
    eq(callCount('TimerStart'), 0)
end)

test('orders and damage accept any widget target', function()
    local u, target, item = Unit.fromHandle({}), Unit.fromHandle({}), Item.fromHandle({})
    local attack, damage, weapon = {}, {}, {}
    native('UnitDamageTarget', function() return true end)
    eq(u:damageTarget(item, 50, true, false, attack, damage, weapon), true)
    expectCall('UnitDamageTarget', u.handle, item.handle, 50, true, false, attack, damage, weapon)
    native('IssueTargetOrder', function() return true end)
    eq(u:issueTargetOrder('smart', item), true); expectCall('IssueTargetOrder', u.handle, 'smart', item.handle)
    checkGetters(u, {{'IssueImmediateOrderById', 'issueOrderById', true, 851972},
        {'IssuePointOrderById', 'issuePointOrderById', false, 851986, 1, 2}})
    native('IssueTargetOrderById', function() return true end)
    eq(u:issueTargetOrderById(851983, target), true)
    expectCall('IssueTargetOrderById', u.handle, 851983, target.handle)
    fails(function() u:damageTarget(Player.fromIndex(0), 1, true, false, attack, damage, weapon) end,
        'Unit.damageTarget: expected Widget wrapper')
    fails(function() u:issueTargetOrderById(1, Player.fromIndex(0)) end,
        'Unit.issueTargetOrderById: expected Widget wrapper')
    eq(callCount('UnitDamageTarget'), 1); eq(callCount('IssueTargetOrderById'), 1)
    item:remove(); target:remove(); u:remove()
end)

test('new unit methods reject a removed receiver', function()
    local u = Unit.fromHandle({})
    u:remove()
    checkDisposed(u, {'isHero', 'getHeroName', 'getLevel', 'setLevel', 'getXP', 'setXP', 'addXP', 'getStr', 'setStr',
        'getAgi', 'setAgi', 'getInt', 'setInt', 'getSkillPoints', 'modifySkillPoints', 'selectSkill', 'revive',
        'addAbility', 'removeAbility', 'getAbilityLevel', 'setAbilityLevel', 'setAbilityPermanent',
        'setAbilityHidden', 'setAbilityDisabled', 'startCooldown', 'endCooldown', 'getCooldownRemaining',
        'getInventorySize', 'getItemInSlot',
        'addItem', 'addItemById', 'removeItem', 'removeItemFromSlot', 'hasItem', 'dropItemAt', 'dropItemToSlot',
        'useItem', 'getMana', 'setMana', 'getMaxMana', 'setMaxMana', 'setMaxLife', 'getMoveSpeed', 'setMoveSpeed',
        'setX', 'setY', 'setScale', 'setColor', 'setAnimation', 'setPaused', 'isPaused', 'setInvulnerable',
        'isInvulnerable', 'setVisible', 'isVisible', 'isType', 'isAlly', 'isEnemy', 'getName', 'getCurrentOrder',
        'isAlive',
        'damageTarget', 'applyTimedLife', 'issueOrderById', 'issuePointOrderById', 'issueTargetOrderById'})
end)

test('errors point at the caller: disposed receiver, arguments, factories and slots', function()
    native('UnitInventorySize', function() return 6 end)
    local p = Player.fromIndex(0)
    local u = Unit.create(p, 1751543663, 0, 0, 0)
    local gone = Unit.create(p, 1751543663, 0, 0, 0)
    gone:remove()
    failsAt(function() gone:getX() end, 'Unit.getX: Unit is disposed')
    failsAt(function() Unit.create({}, 1, 0, 0, 0) end, 'Unit.create: expected Player wrapper')
    failsAt(function() u:issueTargetOrder('smart', {}) end, 'Unit.issueTargetOrder: expected Widget wrapper')
    failsAt(function() u:issueTargetOrder('smart', gone) end, 'Unit.issueTargetOrder: Unit is disposed')
    failsAt(function() u:getItemInSlot(99) end, 'Unit.getItemInSlot: expected an inventory slot index')
    native('CreateUnit', function() return nil end)
    failsAt(function() Unit.create(p, 1, 0, 0, 0) end, 'Unit.create: native returned nil')
    native('CreateUnit', function() return {} end)
end)

test('fromEvent wraps the unit of the running event, and nil when it has none', function()
    local raw = {}
    native('GetTriggerUnit', function() return raw end)
    local found = Unit.fromEvent()
    eq(found, Unit.fromHandle(raw)); eq(found.handle, raw); eq(callCount('GetTriggerUnit'), 1)
    native('GetTriggerUnit', function() return nil end)
    eq(Unit.fromEvent(), nil)
end)
