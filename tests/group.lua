native('Rect', function() return {} end)
native('RemoveRect', function() end)
native('CreateGroup', function() return {} end)
native('DestroyGroup', function() end)
local Group = require('wrappers.group')
local Unit = require('wrappers.unit')
local Rect = require('wrappers.rect')
local Player = require('wrappers.player')

-- A native group double backed by an array; every enumeration native appends `initial`.
local function nativeGroup(initial)
    local members = {}
    native('GroupClear', function() members = {} end)
    native('BlzGroupGetSize', function() return #members end)
    native('BlzGroupUnitAt', function(_, index) return members[index + 1] end)
    native('GroupAddUnit', function(_, raw) members[#members + 1] = raw end)
    native('GroupRemoveUnit', function(_, raw)
        for i = #members, 1, -1 do if members[i] == raw then table.remove(members, i) end end
    end)
    local function enum() for _, raw in ipairs(initial) do members[#members + 1] = raw end end
    for _, name in ipairs({'GroupEnumUnitsInRange', 'GroupEnumUnitsInRect', 'GroupEnumUnitsOfPlayer',
        'GroupEnumUnitsSelected'}) do native(name, enum) end
    return function() return members end
end
eq(totalCalls(), 0)

test('group membership forwards native arguments without owning units', function()
    local g, u = Group.create(), Unit.fromHandle({})
    eq(Group.fromHandle(nil), nil); eq(Group.fromHandle(g.handle), g)
    for _, name in ipairs({'GroupAddUnit', 'GroupRemoveUnit', 'GroupClear'}) do native(name, function() end) end
    native('IsUnitInGroup', function() return true end)
    g:add(u); expectCall('GroupAddUnit', g.handle, u.handle)
    eq(g:contains(u), true); expectCall('IsUnitInGroup', u.handle, g.handle)
    g:remove(u); expectCall('GroupRemoveUnit', g.handle, u.handle)
    g:clear(); expectCall('GroupClear', g.handle)
    local raw = g:getHandle(); g:destroy(); g:destroy()
    expectCall('DestroyGroup', raw); eq(callCount('DestroyGroup'), 1)
    eq(callCount('RemoveUnit'), 0); eq(u:isDisposed(), false); eq(g.handle, nil)
    for _, method in ipairs({'getHandle', 'add', 'remove', 'contains', 'clear', 'enumInRange', 'getSize', 'getUnits'}) do
        fails(function() g[method](g) end, 'disposed')
    end
    u:remove()
    native('CreateGroup', function() return nil end); fails(Group.create, 'Group.create')
    native('CreateGroup', function() return {} end)
end)

test('range validation preserves group on failure and enumeration clears first', function()
    local g = Group.create()
    native('GroupEnumUnitsInRange', function() end)
    for _, radius in ipairs({-1, math.huge, 0/0, '1'}) do
        failsAt(function() g:enumInRange(0, 0, radius) end, 'Group.enumInRange: expected a finite non-negative radius')
    end
    eq(callCount('GroupClear'), 0)
    resetCalls(); g:enumInRange(10, 20, 0)
    eq(callName(1), 'GroupClear'); eq(callName(2), 'GroupEnumUnitsInRange')
    expectCall('GroupEnumUnitsInRange', g.handle, 10, 20, 0, nil)
    local u = Unit.fromHandle({}); u:remove()
    fails(function() g:add(u) end, 'disposed')
    fails(function() g:contains(g) end, 'Unit')
    fails(function() g:remove({}) end, 'Unit')
    eq(callCount('GroupAddUnit'), 0); eq(callCount('IsUnitInGroup'), 0); eq(callCount('GroupRemoveUnit'), 0)
    g:destroy()
end)

test('snapshots are dense independent arrays preserving wrapper identity', function()
    local a, b, g = {}, {}, Group.create()
    native('BlzGroupGetSize', function() return 3 end)
    native('BlzGroupUnitAt', function(_, index) return ({[0] = a, [2] = b})[index] end)
    eq(g:getSize(), 3); expectCall('BlzGroupGetSize', g.handle)
    local first, second = g:getUnits(), g:getUnits()
    assert(first ~= second); eq(#first, 2)
    eq(first[1], Unit.fromHandle(a)); eq(first[2], Unit.fromHandle(b))
    expectCall('BlzGroupUnitAt', g.handle, 2)
    g:clear(); eq(#first, 2)
    first[1]:remove(); eq(first[1]:isDisposed(), true); eq(second[1]:isDisposed(), true)
    first[2]:remove(); g:destroy()
end)

test('enumerations clear first and forward exact arguments', function()
    local g, r, p = Group.create(), Rect.create(0, 0, 1, 1), Player.fromIndex(0)
    nativeGroup({})
    resetCalls(); g:enumInRect(r)
    eq(callName(1), 'GroupClear'); expectCall('GroupEnumUnitsInRect', g.handle, r.handle, nil)
    resetCalls(); g:enumOfPlayer(p)
    eq(callName(1), 'GroupClear'); expectCall('GroupEnumUnitsOfPlayer', g.handle, PLAYER_RAW, nil)
    resetCalls(); g:enumSelected(p)
    eq(callName(1), 'GroupClear'); expectCall('GroupEnumUnitsSelected', g.handle, PLAYER_RAW, nil)
    resetCalls()
    fails(function() g:enumInRect(p) end, 'Group.enumInRect: expected Rect wrapper')
    fails(function() g:enumOfPlayer(r) end, 'Group.enumOfPlayer: expected Player wrapper')
    fails(function() g:enumInRange(0, 0, 10, 'filter') end, 'Group.enumInRange: expected a callback function')
    fails(function() g:enumSelected(p, 5) end, 'Group.enumSelected: expected a callback function')
    eq(totalCalls(), 0)
    g:destroy(); r:destroy()
end)

test('invalid filters blame the caller, not the library', function()
    local g, r, p = Group.create(), Rect.create(0, 0, 1, 1), Player.fromIndex(0)
    for _, call in ipairs({function() g:enumInRange(0, 0, 10, 'filter') end, function() g:enumInRect(r, 1) end,
        function() g:enumOfPlayer(p, true) end, function() g:enumSelected(p, {}) end, function() g:forEach(nil) end}) do
        local ok, err = pcall(call)
        eq(ok, false)
        assert(tostring(err):find('tests/group.lua:', 1, true), tostring(err))
        assert(tostring(err):find('expected a callback function', 1, true), tostring(err))
    end
    g:destroy(); r:destroy()
end)

test('filters run after native enumeration and remove rejected units', function()
    local a, b, c = {}, {}, {}
    local members = nativeGroup({a, b, c})
    local g, seen = Group.create(), {}
    resetCalls()
    g:enumInRange(0, 0, 500, function(unit) seen[#seen + 1] = unit; return unit.handle ~= b end)
    eq(callName(1), 'GroupClear'); eq(callName(2), 'GroupEnumUnitsInRange')
    expectCall('GroupEnumUnitsInRange', g.handle, 0, 0, 500, nil)
    eq(#seen, 3); eq(seen[1], Unit.fromHandle(a))
    eq(#members(), 2); eq(members()[1], a); eq(members()[2], c)
    expectCall('GroupRemoveUnit', g.handle, b)
    g:enumInRange(0, 0, 500)
    eq(#members(), 3)
    g:destroy()
end)

test('a failing filter clears the group and re-raises', function()
    local members = nativeGroup({{}, {}})
    local g = Group.create()
    fails(function() g:enumOfPlayer(Player.fromIndex(0), function() error('filter probe') end) end, 'filter probe')
    eq(#members(), 0); eq(#PRINTED, 0)
    -- The error object passes through unchanged.
    local thrown = {}
    local ok, caught = pcall(function() g:enumOfPlayer(Player.fromIndex(0), function() error(thrown) end) end)
    eq(ok, false); eq(caught, thrown); eq(#members(), 0)
    g:destroy()
end)

test('a filter keeps what it returns truthy for; nil entries of the native group are skipped', function()
    local a, b, c, d = {}, {}, {}, {}
    local members = nativeGroup({a, b, c, d})
    local g, seen = Group.create(), {}
    g:enumInRange(0, 0, 1, function(unit)
        seen[#seen + 1] = unit.handle
        if unit.handle == a then return nil end
        if unit.handle == c then return false end
        return 'kept'
    end)
    eq(#seen, 4); eq(seen[1], a); eq(seen[4], d)
    eq(#members(), 2); eq(members()[1], b); eq(members()[2], d)
    eq(callCount('GroupRemoveUnit'), 2)
    -- A hole in the native group: the handle removed is the rejected unit's, not its neighbour's.
    native('GroupClear', function() end)
    native('GroupEnumUnitsInRange', function() end)
    native('BlzGroupGetSize', function() return 3 end)
    native('BlzGroupUnitAt', function(_, index) return ({[0] = a, [2] = b})[index] end)
    native('GroupRemoveUnit', function() end)
    resetCalls()
    g:enumInRange(0, 0, 1, function(unit) return unit.handle ~= b end)
    eq(callCount('GroupRemoveUnit'), 1); expectCall('GroupRemoveUnit', g.handle, b)
    g:destroy()
end)

test('filters that change the group see a stable snapshot', function()
    nativeGroup({{}, {}})
    local g, extra, count = Group.create(), Unit.fromHandle({}), 0
    g:enumInRange(0, 0, 1, function() count = count + 1; g:add(extra); return true end)
    eq(count, 2)
    extra:remove(); g:destroy()
end)

test('forEach iterates a snapshot and first uses FirstOfGroup', function()
    local a, b = {}, {}
    nativeGroup({a, b})
    local g, seen = Group.create(), {}
    g:enumInRange(0, 0, 1)
    g:forEach(function(unit) seen[#seen + 1] = unit; g:clear() end)
    eq(#seen, 2); eq(seen[2], Unit.fromHandle(b))
    fails(function() g:forEach(nil) end, 'Group.forEach: expected a callback function')
    g:enumInRange(0, 0, 1)
    fails(function() g:forEach(function() error('each probe') end) end, 'each probe')
    native('FirstOfGroup', function() return a end)
    eq(g:first(), Unit.fromHandle(a)); expectCall('FirstOfGroup', g.handle)
    native('FirstOfGroup', function() return nil end)
    eq(g:first(), nil)
    g:destroy()
    checkDisposed(g, {'enumInRect', 'enumOfPlayer', 'enumSelected', 'forEach', 'first'})
end)

test('forEach keeps the snapshot wrapper when a callback removes a later unit', function()
    local a, b = {}, {}
    nativeGroup({a, b})
    local g, removed, second = Group.create(), nil, nil
    g:enumInRange(0, 0, 1)
    g:forEach(function(unit)
        if removed == nil then removed = assert(Unit.fromHandle(b)); removed:remove() else second = unit end
    end)
    eq(second, removed); eq(second:isDisposed(), true)
    g:destroy()
end)

test('filters keep the snapshot wrapper when a filter removes a later unit', function()
    local a, b = {}, {}
    local members = nativeGroup({a, b})
    local g, removed, second = Group.create(), nil, nil
    g:enumInRange(0, 0, 1, function(unit)
        if removed == nil then removed = assert(Unit.fromHandle(b)); removed:remove(); return true end
        second = unit
        return false
    end)
    eq(second, removed); eq(second:isDisposed(), true)
    expectCall('GroupRemoveUnit', g.handle, b)
    eq(#members(), 1); eq(members()[1], a)
    g:destroy()
end)
