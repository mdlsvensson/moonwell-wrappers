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
