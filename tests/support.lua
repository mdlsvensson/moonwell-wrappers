local calls, implementations, tests, failed = {}, {}, 0, 0
local realPrint = print
PRINTED = {}
print = function(message) PRINTED[#PRINTED + 1] = tostring(message) end

function eq(actual, expected)
    assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end

function fails(fn, fragment)
    local ok, err = pcall(fn)
    assert(not ok, 'expected failure')
    assert(tostring(err):find(fragment, 1, true), tostring(err))
end

---Like fails, and the error must point at the line where `fn` is written: wrapper errors blame their caller. `fn`
---runs in a coroutine of its own, so no frame above it can stand in for it. Write `fn` on one line, and call the
---wrapper as a statement: `return wrapper(...)` is a tail call and hides the position.
function failsAt(fn, fragment)
    local ok, err = coroutine.resume(coroutine.create(fn))
    assert(not ok, 'expected failure')
    local message = tostring(err)
    assert(message:find(fragment, 1, true), message)
    local info = debug.getinfo(fn, 'S')
    local at = info.short_src .. ':' .. info.linedefined .. ': '
    assert(message:sub(1, #at) == at, 'expected the error at ' .. at .. 'got: ' .. message)
end

function native(name, implementation)
    implementations[name] = implementation
    _G[name] = function(...)
        calls[#calls + 1] = {name = name, args = table.pack(...)}
        return implementations[name](...)
    end
end

function resetCalls() calls = {}; PRINTED = {} end
function callCount(name)
    local n = 0
    for _, call in ipairs(calls) do if call.name == name then n = n + 1 end end
    return n
end
function totalCalls() return #calls end
function expectCall(name, ...)
    local expected = table.pack(...)
    for i = #calls, 1, -1 do
        if calls[i].name == name then
            eq(calls[i].args.n, expected.n)
            for j = 1, expected.n do eq(calls[i].args[j], expected[j]) end
            return
        end
    end
    error('no call to ' .. name)
end
function callName(index) return calls[index].name end

function test(name, fn)
    tests = tests + 1
    resetCalls()
    local ok, err = pcall(fn)
    if not ok then failed = failed + 1; realPrint('FAIL ' .. name .. ': ' .. tostring(err)) end
end
function finish()
    assert(failed == 0, tostring(failed) .. '/' .. tests .. ' tests failed')
    realPrint('SUITE PASSED: ' .. tests .. ' tests')
end

bj_MAX_PLAYER_SLOTS = 28
PLAYER_RAW = {}
native('Player', function() return PLAYER_RAW end)
native('CreateUnit', function() return {} end)
native('RemoveUnit', function() end)
native('KillUnit', function() end)

-- Rows: {nativeName, methodName, returnValue, methodArgs...}; the native receives the handle then the same args.
function checkGetters(wrapper, rows)
    for _, row in ipairs(rows) do
        local value = row[3]
        native(row[1], function() return value end)
        eq(wrapper[row[2]](wrapper, table.unpack(row, 4)), value)
        expectCall(row[1], wrapper.handle, table.unpack(row, 4))
    end
end
-- Rows: {nativeName, methodName, methodArgs...}. A row with boolean arguments runs again with each one flipped, so a
-- wrapper that ignores a flag (passes a constant) fails whichever value the row uses.
function checkSetters(wrapper, rows)
    for _, row in ipairs(rows) do
        native(row[1], function() end)
        local variants, flipped, hasBoolean = {table.pack(table.unpack(row, 3))}, table.pack(table.unpack(row, 3)), false
        for index = 1, flipped.n do
            if type(flipped[index]) == 'boolean' then flipped[index], hasBoolean = not flipped[index], true end
        end
        if hasBoolean then variants[2] = flipped end
        for _, args in ipairs(variants) do
            wrapper[row[2]](wrapper, table.unpack(args, 1, args.n))
            expectCall(row[1], wrapper.handle, table.unpack(args, 1, args.n))
        end
    end
end
function checkDisposed(wrapper, methods)
    local before = totalCalls()
    for _, name in ipairs(methods) do failsAt(function() wrapper[name](wrapper) end, 'disposed') end
    eq(totalCalls(), before)
end
