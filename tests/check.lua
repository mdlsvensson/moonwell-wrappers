local Check = require('wrappers.internal.check')
local Callback = require('wrappers.internal.callback')
eq(totalCalls(), 0)

local NAN = 0 / 0

-- Stand-ins for public functions: each calls one raising form directly, as a module does.
local Public = {}
function Public.finite(value) return (Check.requireFinite(value, 'amount', 'Test.op')) end
function Public.positive(value) return (Check.requirePositive(value, 'interval', 'Test.op')) end
function Public.nonNegative(value) return (Check.requireNonNegative(value, 'timeout', 'Test.op')) end
function Public.integer(value, min, max) return (Check.requireInteger(value, 'count', 'Test.op', nil, min, max)) end
function Public.text(value) return (Check.requireText(value, 'a model path', 'Test.op')) end
function Public.callback(value) Callback.check(value, 'Test.op') end
function Public.optional(value) Callback.optional(value, 'Test.op') end

-- The same checks behind one local helper, which passes depth 1.
local Deep = {}
local function count(value) return (Check.requireInteger(value, 'count', 'Test.op', 1, 0)) end
function Deep.integer(value) return (count(value)) end
local function callback(value) Callback.check(value, 'Test.op', 1) end
function Deep.callback(value) callback(value) end
local function optional(value) Callback.optional(value, 'Test.op', 1) end
function Deep.optional(value) optional(value) end

---Runs `fn`, which must fail, and returns the line its error points at and the line this function was called from.
---With the failing call written on the line of the `blamed` call, the two are equal exactly when the error points
---at the caller of the function under test: one level less gives the line of that function, one more gives none.
local function blamed(fn)
    local ok, err = pcall(fn)
    assert(not ok, 'expected failure')
    return tonumber(tostring(err):match('^%./tests/check%.lua:(%d+): ')), debug.getinfo(2, 'l').currentline
end

---The message of the error `fn` raises, without its position.
local function message(fn)
    local ok, err = pcall(fn)
    assert(not ok, 'expected failure')
    return (tostring(err):gsub('^.-: ', '', 1))
end

test('finite, positive and nonNegative accept only finite numbers', function()
    eq(Check.finite(0), true); eq(Check.finite(-1.5), true); eq(Check.finite(1e300), true)
    eq(Check.finite(math.huge), false); eq(Check.finite(-math.huge), false); eq(Check.finite('1'), false)
    eq(Check.finite(nil), false); eq(Check.finite({}), false)
    eq(Check.positive(0.5), true); eq(Check.positive(1e-300), true); eq(Check.positive(0), false)
    eq(Check.positive(-1), false); eq(Check.positive(math.huge), false); eq(Check.positive('1'), false)
    eq(Check.nonNegative(0), true); eq(Check.nonNegative(2), true); eq(Check.nonNegative(-0.1), false)
    eq(Check.nonNegative(math.huge), false); eq(Check.nonNegative(nil), false)
    -- Lua 5.4, which runs the suites, refuses NaN. Warcraft's Lua cannot: there NaN equals itself.
    eq(Check.finite(NAN), false); eq(Check.positive(NAN), false); eq(Check.nonNegative(NAN), false)
end)

test('integer is a whole number inside the 32-bit range, of either number subtype', function()
    eq(Check.integer(0), true); eq(Check.integer(-7), true); eq(Check.integer(5.0), true); eq(Check.integer(-0.0), true)
    eq(Check.integer(2147483647), true); eq(Check.integer(2147483647.0), true); eq(Check.integer(-2147483648), true)
    eq(Check.integer(2147483648), false); eq(Check.integer(2 ^ 31), false); eq(Check.integer(-2147483649), false)
    eq(Check.integer(1e300), false); eq(Check.integer(2 ^ 40), false)
    eq(Check.integer(1.5), false); eq(Check.integer(-0.5), false)
    eq(Check.integer(math.huge), false); eq(Check.integer(-math.huge), false); eq(Check.integer(NAN), false)
    eq(Check.integer('5'), false); eq(Check.integer(nil), false); eq(Check.integer(true), false)
end)

test('text is a string, and show never prints an address', function()
    eq(Check.text(''), true); eq(Check.text('x'), true); eq(Check.text(1), false); eq(Check.text(nil), false)
    eq(Check.show('name'), 'name'); eq(Check.show(12), '12'); eq(Check.show(1.5), '1.5'); eq(Check.show(true), 'true')
    eq(Check.show({}), '<table>'); eq(Check.show(print), '<function>'); eq(Check.show(nil), '<nil>')
    eq(Check.show(coroutine.create(function() end)), '<thread>')
end)

test('the raising forms return their value', function()
    eq(Public.finite(-2.5), -2.5); eq(Public.positive(0.25), 0.25); eq(Public.nonNegative(0), 0)
    eq(Public.integer(5.0), 5.0); eq(math.type(Public.integer(5.0)), 'float')
    eq(Public.integer(3, 1, 3), 3); eq(Public.integer(1, 1, 3), 1); eq(Public.integer(-2147483648), -2147483648)
    eq(Public.text(''), ''); eq(Deep.integer(0), 0)
end)

test('the raising forms name the argument and the operation, at the caller', function()
    failsAt(function() Public.finite(math.huge) end, '[wrappers] Test.op: expected a finite amount')
    failsAt(function() Public.finite('1') end, '[wrappers] Test.op: expected a finite amount')
    failsAt(function() Public.finite(NAN) end, 'expected a finite amount')
    failsAt(function() Public.positive(0) end, '[wrappers] Test.op: expected a finite positive interval')
    failsAt(function() Public.nonNegative(-1) end, '[wrappers] Test.op: expected a finite non-negative timeout')
    failsAt(function() Public.nonNegative(math.huge) end, 'expected a finite non-negative timeout')
    failsAt(function() Public.text(nil) end, '[wrappers] Test.op: expected a model path')
    failsAt(function() Public.text(5) end, '[wrappers] Test.op: expected a model path')
end)

test('requireInteger words its bounds and always keeps the 32-bit range', function()
    eq(message(function() Public.integer(1.5) end), '[wrappers] Test.op: expected an integer count')
    eq(message(function() Public.integer(-1, 0) end), '[wrappers] Test.op: expected an integer count of at least 0')
    eq(message(function() Public.integer(4, 1, 3) end), '[wrappers] Test.op: expected an integer count from 1 to 3')
    eq(message(function() Public.integer(0, 1, 3) end), '[wrappers] Test.op: expected an integer count from 1 to 3')
    eq(message(function() Public.integer(9, nil, 8) end), '[wrappers] Test.op: expected an integer count of at most 8')
    failsAt(function() Public.integer(2 ^ 31) end, 'expected an integer count')
    failsAt(function() Public.integer(2 ^ 31, 0) end, 'expected an integer count of at least 0')
    failsAt(function() Public.integer(1e300, 0, 1e301) end, 'expected an integer count')
    failsAt(function() Public.integer(-2147483649) end, 'expected an integer count')
    failsAt(function() Public.integer('3') end, 'expected an integer count')
    failsAt(function() Public.integer({}, 0) end, 'expected an integer count of at least 0')
    failsAt(function() Public.integer(nil, 1, 3) end, 'expected an integer count from 1 to 3')
end)

test('a raising form blames the caller of the public function, and depth counts helper frames', function()
    local line, here
    for _, name in ipairs({'finite', 'positive', 'nonNegative', 'integer', 'text'}) do
        line, here = blamed(function() Public[name]({}) end)
        eq(line, here)
    end
    line, here = blamed(function() Deep.integer(-1) end)
    eq(line, here)
    eq(message(function() Deep.integer(-1) end), '[wrappers] Test.op: expected an integer count of at least 0')
end)

test('Callback.check and Callback.optional keep their message and take a depth', function()
    Public.callback(print); Public.optional(print); Public.optional(nil)
    Deep.callback(print); Deep.optional(print); Deep.optional(nil)
    failsAt(function() Public.callback(1) end, '[wrappers] Test.op: expected a callback function')
    failsAt(function() Public.callback(nil) end, '[wrappers] Test.op: expected a callback function')
    failsAt(function() Public.optional(1) end, '[wrappers] Test.op: expected a callback function')
    eq(message(function() Deep.callback(1) end), '[wrappers] Test.op: expected a callback function')
    eq(message(function() Deep.optional(1) end), '[wrappers] Test.op: expected a callback function')
    local line, here
    for _, call in ipairs({Public.callback, Public.optional, Deep.callback, Deep.optional}) do
        line, here = blamed(function() call(1) end)
        eq(line, here)
    end
end)
