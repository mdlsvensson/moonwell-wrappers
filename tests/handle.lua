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

---Runs `fn`, which must fail, and returns the line its error points at and the line this function was called from.
---With the failing call written on the line of the `blamed` call, the two are equal exactly when the error points
---at the caller of the function under test.
local function blamed(fn)
    local ok, err = pcall(fn)
    assert(not ok, 'expected failure')
    return tonumber(tostring(err):match('^%./tests/handle%.lua:(%d+): ')), debug.getinfo(2, 'l').currentline
end

---The index and value of the upvalue `name` of `fn`. The cache and the widget family are private to handle.lua, and
---what these tests pin (how often the cache is read, which class is tried first) shows nowhere else.
local function upvalue(fn, name)
    local index = 1
    while true do
        local found, value = debug.getupvalue(fn, index)
        assert(found, 'no upvalue named ' .. name)
        if found == name then return index, value end
        index = index + 1
    end
end

test('wrap reads its cache once for a handle that has its wrapper', function()
    local fakes = Handle.new({}, 'FakeCached')
    local raw = {}
    local first = fakes.wrap(raw)
    local index, cache = upvalue(fakes.wrap, 'byHandle')
    local reads = 0
    debug.setupvalue(fakes.wrap, index, setmetatable({}, {
        __index = function(_, key) reads = reads + 1; return cache[key] end,
        __newindex = function(_, key, value) cache[key] = value end,
    }))
    eq(fakes.wrap(raw), first); eq(reads, 1)
    eq(fakes.wrap(nil), nil); eq(reads, 1)
    local otherRaw = {}
    local other = fakes.wrap(otherRaw)
    eq(reads, 2); eq(other.handle, otherRaw); eq(fakes.wrap(otherRaw), other); eq(reads, 3)
end)

test('unwrapWidget tries Unit first whatever the load order', function()
    -- unit.lua requires item.lua before it makes its own registry, so Item's registry is the older one.
    local _, names = upvalue(Handle.unwrapWidget, 'widgetNames')
    local _, tables = upvalue(Handle.unwrapWidget, 'widgetMembers')
    eq(names[1], 'Unit'); eq(names[2], 'Item'); eq(names[3], 'Destructable'); eq(#tables, #names)
    local u, i, d = Unit.fromHandle({}), Item.fromHandle({}), Destructable.fromHandle({})
    eq(tables[1][u], u.handle); eq(tables[2][i], i.handle); eq(tables[3][d], d.handle)
    eq(Handle.unwrapWidget(u, 'Test.op'), u.handle); eq(Handle.unwrapWidget(i, 'Test.op'), i.handle)
    eq(Handle.unwrapWidget(d, 'Test.op'), d.handle)
    i:remove(); d:remove()
    fails(function() Handle.unwrapWidget(i, 'Test.op') end, '[wrappers] Test.op: Item is disposed')
    fails(function() Handle.unwrapWidget(d, 'Test.op') end, '[wrappers] Test.op: Destructable is disposed')
    u:remove()
end)

test('unwrap, unwrapWidget and created blame the caller of the public function', function()
    local Public = {}
    function Public.unwrap(value) return (Handle.unwrap(value, 'Unit', 'Test.op')) end
    function Public.widget(value) return (Handle.unwrapWidget(value, 'Test.op')) end
    function Public.created(value) return (Handle.created(value, 'Test.op')) end
    local function helper(value) return (Handle.unwrap(value, 'Unit', 'Test.op', 1)) end
    function Public.deep(value) return (helper(value)) end
    -- unwrapWidget has no depth parameter: a third argument changes nothing.
    function Public.extra(value) return (Handle.unwrapWidget(value, 'Test.op', 1)) end
    local gone = Unit.fromHandle({})
    gone:remove()
    for _, name in ipairs({'unwrap', 'widget', 'deep', 'extra'}) do
        local line, here = blamed(function() Public[name]({}) end)
        eq(line, here)
        line, here = blamed(function() Public[name](gone) end)
        eq(line, here)
    end
    local line, here = blamed(function() Public.created(nil) end)
    eq(line, here)
    failsAt(function() Public.unwrap({}) end, '[wrappers] Test.op: expected Unit wrapper')
    failsAt(function() Public.widget(gone) end, '[wrappers] Test.op: Unit is disposed')
    failsAt(function() Public.extra(nil) end, '[wrappers] Test.op: expected Widget wrapper')
    failsAt(function() Public.created(nil) end, '[wrappers] Test.op: native returned nil')
end)

test('dispose and sweep leave a wrapper in the same state', function()
    local fakes = Handle.new({}, 'FakeRelease')
    local disposed, swept = fakes.wrap({}), fakes.wrap({})
    local disposedRaw, sweptRaw = disposed.handle, swept.handle
    eq(fakes.dispose(disposed, 'Test.op'), disposedRaw)
    fakes.sweep(function(raw) return raw == sweptRaw end)
    for _, pair in ipairs({{disposed, disposedRaw}, {swept, sweptRaw}}) do
        local value, raw = pair[1], pair[2]
        eq(value.handle, nil); eq(fakes.isDisposed(value, 'Test.op'), true); eq(fakes.live(value, 'Test.op'), nil)
        eq(fakes.dispose(value, 'Test.op'), nil)
        fails(function() fakes.require(value, 'Test.op') end, '[wrappers] Test.op: FakeRelease is disposed')
        fails(function() Handle.unwrap(value, 'FakeRelease', 'Test.op') end, 'Test.op: FakeRelease is disposed')
        local again = fakes.wrap(raw)
        eq(again == value, false); eq(again.handle, raw); eq(fakes.isDisposed(again, 'Test.op'), false)
    end
end)
