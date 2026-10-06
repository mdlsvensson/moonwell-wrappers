local Cells = require('wrappers.internal.cells')
eq(totalCalls(), 0)

---A callback that appends `name` to `log`.
local function mark(log, name) return function() log[#log + 1] = name end end

test('add appends in place and returns the cell and its cancel function', function()
    local list = Cells.new()
    eq(Cells.count(list), 0); eq(#list.items, 0); eq(list.cancelled, nil)
    local items = list.items
    local first = function() end
    local cell, cancel = Cells.add(list, first)
    eq(cell.callback, first); eq(type(cancel), 'function')
    local second = Cells.add(list, function() end)
    eq(Cells.count(list), 2); eq(list.items, items); eq(items[1], cell); eq(items[2], second)
    -- A module keeps fields of its own on a cell.
    cell.native = 'action'
    eq(items[1].native, 'action')
end)

test('cancel drops the callback, copies the list without the cell, then tells cancelled once', function()
    local told = {}
    local list
    list = Cells.new(function(cell)
        told[#told + 1] = {cell = cell, count = Cells.count(list), callback = cell.callback}
    end)
    local a, cancelA = Cells.add(list, function() end)
    local b, cancelB = Cells.add(list, function() end)
    local c = Cells.add(list, function() end)
    local before = list.items
    cancelB()
    eq(b.callback, nil); eq(Cells.count(list), 2); eq(list.items[1], a); eq(list.items[2], c)
    -- The array a firing would be walking is left as it was.
    eq(list.items == before, false); eq(#before, 3); eq(before[2], b)
    eq(#told, 1); eq(told[1].cell, b); eq(told[1].count, 2); eq(told[1].callback, nil)
    cancelB(); cancelB()
    eq(#told, 1); eq(Cells.count(list), 2)
    cancelA()
    eq(#told, 2); eq(told[2].cell, a); eq(told[2].count, 1); eq(list.items[1], c)
end)

test('a list made without cancelled still cancels', function()
    local list = Cells.new()
    local cell, cancel = Cells.add(list, function() end)
    cancel(); cancel()
    eq(cell.callback, nil); eq(Cells.count(list), 0)
end)

test('clear drops every callback without telling cancelled, and cancel functions do nothing afterwards', function()
    local told = 0
    local list = Cells.new(function() told = told + 1 end)
    local a, cancelA = Cells.add(list, function() end)
    local b, cancelB = Cells.add(list, function() end)
    local before = list.items
    Cells.clear(list)
    eq(a.callback, nil); eq(b.callback, nil); eq(Cells.count(list), 0); eq(told, 0)
    eq(list.items == before, false); eq(#before, 2)
    cancelA(); cancelB(); cancelA()
    eq(told, 0); eq(Cells.count(list), 0)
    Cells.clear(list)
    -- The list is still usable: an owner may clear and go on.
    local log = {}
    local _, cancelC = Cells.add(list, mark(log, 'c'))
    Cells.call(list, 'Test')
    eq(table.concat(log, ','), 'c'); eq(Cells.count(list), 1)
    cancelC()
    eq(told, 1)
    eq(totalCalls(), 0)
end)

test('call runs the live callbacks in the order added, with its arguments', function()
    local list, log = Cells.new(), {}
    Cells.add(list, function(x, y, z) log[#log + 1] = 'a' .. tostring(x) .. tostring(y) .. tostring(z) end)
    local _, cancel = Cells.add(list, mark(log, 'b'))
    Cells.add(list, function(x, y) log[#log + 1] = 'c' .. tostring(x) .. tostring(y) end)
    Cells.call(list, 'Test', 1, nil, 3)
    eq(table.concat(log, ','), 'a1nil3,b,c1nil')
    cancel()
    log = {}
    Cells.call(list, 'Test', 7)
    eq(table.concat(log, ','), 'a7nilnil,c7nil')
    Cells.call(Cells.new(), 'Test')
    eq(#PRINTED, 0)
end)

test('a callback added during a call waits for the next one', function()
    local list, log = Cells.new(), {}
    Cells.add(list, function()
        log[#log + 1] = 'a'
        if #log == 1 then Cells.add(list, mark(log, 'late')) end
    end)
    Cells.add(list, mark(log, 'b'))
    Cells.call(list, 'Test')
    eq(table.concat(log, ','), 'a,b'); eq(Cells.count(list), 3)
    Cells.call(list, 'Test')
    eq(table.concat(log, ','), 'a,b,a,b,late')
end)

test('a callback cancelled during a call is skipped at once, itself or another', function()
    local list, log = Cells.new(), {}
    local cancelSelf, cancelLast
    local _
    _, cancelSelf = Cells.add(list, function()
        log[#log + 1] = 'self'
        cancelSelf()
        cancelLast()
    end)
    Cells.add(list, mark(log, 'kept'))
    _, cancelLast = Cells.add(list, mark(log, 'last'))
    Cells.call(list, 'Test')
    eq(table.concat(log, ','), 'self,kept'); eq(Cells.count(list), 1)
    Cells.call(list, 'Test')
    eq(table.concat(log, ','), 'self,kept,kept')
    -- Cancelled and added in the same call: the old array is not appended to.
    local other, seen = Cells.new(), {}
    local cancelFirst
    _, cancelFirst = Cells.add(other, function()
        seen[#seen + 1] = 'first'
        cancelFirst()
        Cells.add(other, mark(seen, 'new'))
    end)
    Cells.add(other, mark(seen, 'second'))
    Cells.call(other, 'Test')
    eq(table.concat(seen, ','), 'first,second')
    Cells.call(other, 'Test')
    eq(table.concat(seen, ','), 'first,second,second,new')
end)

test('clear during a call stops the callbacks after it', function()
    local list, log = Cells.new(), {}
    Cells.add(list, function()
        log[#log + 1] = 'a'
        Cells.clear(list)
    end)
    Cells.add(list, mark(log, 'b'))
    Cells.call(list, 'Test')
    eq(table.concat(log, ','), 'a'); eq(Cells.count(list), 0)
    Cells.call(list, 'Test')
    eq(table.concat(log, ','), 'a')
end)

test('an error in one callback is printed with the label and the next one runs', function()
    local list, log = Cells.new(), {}
    Cells.add(list, function() error('boom', 0) end)
    Cells.add(list, mark(log, 'next'))
    Cells.call(list, 'Damage listener')
    eq(table.concat(log, ','), 'next')
    eq(#PRINTED, 1); eq(PRINTED[1], '[wrappers] Damage listener callback failed: boom')
end)

test('a caller that needs results walks items itself and skips cancelled cells', function()
    local list = Cells.new()
    local cancelSecond
    local _
    Cells.add(list, function()
        cancelSecond()
        return 1
    end)
    _, cancelSecond = Cells.add(list, function() return 2 end)
    Cells.add(list, function() return 3 end)
    local items, sum = list.items, 0
    for index = 1, #items do
        local callback = items[index].callback
        if callback then sum = sum + callback() end
    end
    eq(sum, 4); eq(Cells.count(list), 2)
end)
