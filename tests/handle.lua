native('CreateTimer', function() return {} end)
native('RemoveItem', function() end)
native('RemoveDestructable', function() end)
local Handle = require('wrappers.internal.handle')
local Widget = require('wrappers.internal.widget')
local Unit = require('wrappers.unit')
local Item = require('wrappers.item')
local Destructable = require('wrappers.destructable')
local Timer = require('wrappers.timer')
eq(totalCalls(), 0)

test('unwrap converts loaded classes and names the operation', function()
    local u = Unit.fromHandle({})
    eq(Handle.unwrap(u, 'Unit', 'Test.op'), u.handle)
    fails(function() Handle.unwrap({}, 'Unit', 'Test.op') end, '[wrappers] Test.op: expected Unit wrapper')
    fails(function() Handle.unwrap(u, 'Nope', 'Test.op') end, '[wrappers] Test.op: expected Nope wrapper')
    u:remove()
    fails(function() Handle.unwrap(u, 'Unit', 'Test.op') end, '[wrappers] Test.op: Unit is disposed')
end)

test('unwrapWidget accepts every widget class and rejects others', function()
    local Fake = {}
    local fakes = Handle.new(Fake, 'FakeWidget', {widget = true})
    local u, f = Unit.fromHandle({}), fakes.wrap({})
    eq(Handle.unwrapWidget(u, 'Test.op'), u.handle)
    eq(Handle.unwrapWidget(f, 'Test.op'), f.handle)
    fails(function() Handle.unwrapWidget(Timer.create(), 'Test.op') end, '[wrappers] Test.op: expected Widget wrapper')
    fails(function() Handle.unwrapWidget({}, 'Test.op') end, 'expected Widget wrapper')
    u:remove()
    fails(function() Handle.unwrapWidget(u, 'Test.op') end, '[wrappers] Test.op: Unit is disposed')
end)

test('duplicate registry names are rejected', function()
    fails(function() Handle.new({}, 'Unit') end, 'duplicate registry: Unit')
end)

test('widget install copies shared methods without replacing class methods', function()
    local Fake = {}
    function Fake:getX() return 'own' end
    local fakes = Handle.new(Fake, 'FakeInstall', {widget = true})
    Widget.install(Fake, fakes)
    local f = fakes.wrap({})
    eq(f:getX(), 'own')
    native('GetWidgetY', function() return 9 end)
    eq(f:getY(), 9); expectCall('GetWidgetY', f.handle)
    native('GetWidgetLife', function() return 5 end)
    eq(f:getLife(), 5); expectCall('GetWidgetLife', f.handle)
    native('SetWidgetLife', function() end)
    f:setLife(3); expectCall('SetWidgetLife', f.handle, 3)
    fakes.dispose(f, 'Test.dispose')
    fails(function() f:getY() end, '[wrappers] FakeInstall.getY: FakeInstall is disposed')
end)

test('live gives the handle, nil once disposed, and raises for a stranger at the public caller', function()
    local Fake = {}
    local fakes = Handle.new(Fake, 'FakeLive')
    function Fake:read() return (fakes.live(self, 'FakeLive.read')) end
    local f = fakes.wrap({})
    eq(f:read(), f.handle)
    fakes.dispose(f, 'Test.dispose')
    eq(f:read(), nil)
    failsAt(function() Fake.read({}) end, '[wrappers] FakeLive.read: expected FakeLive wrapper')
end)

test('sweep disposes the wrappers whose handle the predicate names, and no others', function()
    local Fake = {}
    local fakes = Handle.new(Fake, 'FakeSweep', {weak = true})
    local kept, gone = fakes.wrap({}), fakes.wrap({})
    local goneRaw, asked = gone.handle, {}
    fakes.sweep(function(raw) asked[raw] = true; return raw == goneRaw end)
    eq(asked[kept.handle], true); eq(asked[goneRaw], true)
    eq(fakes.isDisposed(kept, 'Test.op'), false); eq(fakes.isDisposed(gone, 'Test.op'), true)
    eq(gone.handle, nil)
    fails(function() fakes.require(gone, 'Test.op') end, '[wrappers] Test.op: FakeSweep is disposed')
    local again = fakes.wrap(goneRaw)
    assert(again ~= gone); eq(fakes.isDisposed(again, 'Test.op'), false)
    asked = {}
    fakes.sweep(function(raw) asked[raw] = true; return false end)
    eq(asked[kept.handle], true); eq(asked[goneRaw], true)
    eq(fakes.isDisposed(again, 'Test.op'), false)
end)

-- Wrap inside a helper so no register of the test body keeps the wrapper alive.
local function wrapAndMark(fromHandle, raw, probe, kind)
    probe[fromHandle(raw)] = kind
end

test('weak caches release unreferenced wrappers; strong caches keep them', function()
    local rawUnit, rawItem, rawDestructable, rawTimer = {}, {}, {}, {}
    local held = Unit.fromHandle({})
    local heldItem, heldDestructable = Item.fromHandle({}), Destructable.fromHandle({})
    collectgarbage(); collectgarbage()
    eq(Unit.fromHandle(held.handle), held)
    eq(Item.fromHandle(heldItem.handle), heldItem)
    eq(Destructable.fromHandle(heldDestructable.handle), heldDestructable)
    local probe = setmetatable({}, {__mode = 'k'})
    wrapAndMark(Unit.fromHandle, rawUnit, probe, 'unit')
    wrapAndMark(Item.fromHandle, rawItem, probe, 'item')
    wrapAndMark(Destructable.fromHandle, rawDestructable, probe, 'destructable')
    wrapAndMark(Timer.fromHandle, rawTimer, probe, 'timer')
    collectgarbage(); collectgarbage()
    local left = {}
    for _, kind in pairs(probe) do left[kind] = true end
    eq(left.unit, nil); eq(left.item, nil); eq(left.destructable, nil); eq(left.timer, true)
    local fresh = Unit.fromHandle(rawUnit)
    eq(fresh:isDisposed(), false); eq(fresh.handle, rawUnit)
    local freshItem, freshDestructable = Item.fromHandle(rawItem), Destructable.fromHandle(rawDestructable)
    eq(freshItem:isDisposed(), false); eq(freshItem.handle, rawItem)
    eq(freshDestructable:isDisposed(), false); eq(freshDestructable.handle, rawDestructable)
    fresh:remove(); held:remove()
    freshItem:remove(); heldItem:remove(); freshDestructable:remove(); heldDestructable:remove()
end)
