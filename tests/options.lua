local Options = require('wrappers.internal.options')
local Player = require('wrappers.player')
eq(totalCalls(), 0)

local fields = {
    size = {'number', 10}, count = {'integer'}, flag = {'boolean', false}, name = {'string', 'x'},
    life = {'nonnegative', 2}, color = {'color', {255, 255, 255}}, player = {'Player'},
}

-- Stand-ins for public functions: `read` calls Options.read directly, `deep` through one local helper (depth 1).
local function read(options) return (Options.read(options, fields, 'Test.op')) end
local function helper(options) return (Options.read(options, fields, 'Test.op', 1)) end
local function deep(options) return (helper(options)) end

---Runs `fn`, which must fail, and returns the line its error points at and the line this function was called from.
---With the failing call written on the line of the `blamed` call, the two are equal exactly when the error points
---at the caller of the function under test.
local function blamed(fn)
    local ok, err = pcall(fn)
    assert(not ok, 'expected failure')
    return tonumber(tostring(err):match('^%./tests/options%.lua:(%d+): ')), debug.getinfo(2, 'l').currentline
end

test('defaults fill a fresh table and given values pass through', function()
    local owner = Player.fromIndex(0)
    local given = {size = 12, count = 3.0, player = owner, color = {1, 2, 3}}
    local o = read(given)
    eq(o.size, 12); eq(o.count, 3.0); eq(o.flag, false); eq(o.name, 'x'); eq(o.life, 2); eq(o.player, PLAYER_RAW)
    eq(o.color[1], 1); eq(o.color[2], 2); eq(o.color[3], 3); eq(o.color[4], 255)
    eq(given.player, owner); eq(given.color[4], nil); eq(given.flag, nil); eq(o == given, false)
    eq(o.color == given.color, false)
    local full = read({color = {1, 2, 3, 4}, flag = true, life = 0})
    eq(full.color[4], 4); eq(full.flag, true); eq(full.life, 0); eq(full.size, 10); eq(full.count, nil)
    local empty = read({})
    eq(empty.size, 10); eq(empty.flag, false); eq(empty.color[4], 255); eq(empty.player, nil)
end)

test('without options every read copies the defaults into a fresh table', function()
    local first, second = read(nil), read(nil)
    eq(first == second, false); eq(first.color == second.color, false)
    eq(first.size, 10); eq(first.flag, false); eq(first.name, 'x'); eq(first.life, 2)
    eq(first.count, nil); eq(first.player, nil)
    eq(first.color[1], 255); eq(first.color[2], 255); eq(first.color[3], 255); eq(first.color[4], 255)
    eq(fields.color[2][4], nil)
    -- What a caller does to its result reaches no later read.
    first.size, first.color[1], first.extra = 99, 0, true
    local third = read(nil)
    eq(third.size, 10); eq(third.color[1], 255); eq(third.extra, nil)
    eq(read({}).color[1], 255)
    eq(totalCalls(), 0)
end)

test('declared defaults are checked once, at the first read of a field table', function()
    local own = {size = {'number', 10}, tint = {'color', {1, 2, 3}}}
    eq(Options.read(nil, own, 'Test.op').size, 10)
    own.size[2] = 'big'
    eq(Options.read(nil, own, 'Test.op').size, 10)
    eq(Options.read({}, own, 'Test.op').size, 10)
    eq(Options.read({size = 4}, own, 'Test.op').tint[4], 255)
    local broken = {size = {'number', 'big'}}
    local function public() return (Options.read(nil, broken, 'Test.op')) end
    failsAt(function() public() end, "[wrappers] Test.op: 'size' expected a number")
end)

test('invalid options fail with the operation name before any native', function()
    failsAt(function() read('big') end, '[wrappers] Test.op: expected an options table')
    failsAt(function() read(5) end, 'Test.op: expected an options table')
    failsAt(function() read({colour = {1, 2, 3}}) end, "[wrappers] Test.op: unknown option 'colour'")
    failsAt(function() read({size = 'big'}) end, "[wrappers] Test.op: 'size' expected a number")
    failsAt(function() read({count = 1.5}) end, "Test.op: 'count' expected an integer")
    failsAt(function() read({flag = 1}) end, "Test.op: 'flag' expected a boolean")
    failsAt(function() read({name = 1}) end, "Test.op: 'name' expected a string")
    failsAt(function() read({life = -1}) end, "Test.op: 'life' expected a finite non-negative number")
    failsAt(function() read({life = 0 / 0}) end, "'life' expected a finite non-negative number")
    failsAt(function() read({life = math.huge}) end, "'life' expected a finite non-negative number")
    failsAt(function() read({color = {1, 2}}) end, "Test.op: 'color' expected {r, g, b, a?} integers")
    failsAt(function() read({color = {1, 2, 3, 4, 5}}) end, "'color' expected {r, g, b, a?} integers")
    failsAt(function() read({color = {1, 2, 3.5}}) end, "'color' expected {r, g, b, a?} integers")
    failsAt(function() read({color = 'red'}) end, "'color' expected {r, g, b, a?} integers")
    failsAt(function() read({player = {}}) end, '[wrappers] Test.op: expected Player wrapper')
    eq(totalCalls(), 0)
end)

test('a table with a metatable is not an options table', function()
    local owner = Player.fromIndex(0)
    resetCalls()
    failsAt(function() read(owner) end, '[wrappers] Test.op: expected an options table')
    failsAt(function() read(setmetatable({size = 1}, {})) end, 'Test.op: expected an options table')
    failsAt(function() deep(owner) end, 'Test.op: expected an options table')
    eq(totalCalls(), 0)
end)

test('an integer option stays inside the 32-bit range', function()
    eq(read({count = 5.0}).count, 5.0); eq(read({count = 2147483647}).count, 2147483647)
    eq(read({count = -2147483648}).count, -2147483648)
    failsAt(function() read({count = 2 ^ 31}) end, "Test.op: 'count' expected an integer")
    failsAt(function() read({count = 2 ^ 40}) end, "'count' expected an integer")
    failsAt(function() read({count = 1e300}) end, "'count' expected an integer")
    failsAt(function() read({count = -2147483649}) end, "'count' expected an integer")
    failsAt(function() read({count = math.huge}) end, "'count' expected an integer")
    failsAt(function() read({color = {1e300, 0, 0}}) end, "'color' expected {r, g, b, a?} integers")
    failsAt(function() read({color = {0, 0, 0, 2 ^ 31}}) end, "'color' expected {r, g, b, a?} integers")
end)

test('several errors report the same first one on every machine', function()
    failsAt(function() read({zeta = 1, alpha = 2}) end, "unknown option 'alpha'")
    failsAt(function() read({zeta = 1, size = 'a'}) end, "unknown option 'zeta'")
    failsAt(function() read({size = 'a', name = 1}) end, "'name' expected a string")
    failsAt(function() read({size = 'a', count = 1.5, flag = 1}) end, "'count' expected an integer")
end)

test('a key that is not a string is shown without an address', function()
    failsAt(function() read({[{}] = 1}) end, "Test.op: unknown option '<table>'")
    failsAt(function() read({[print] = 1}) end, "unknown option '<function>'")
    failsAt(function() read({'first'}) end, "unknown option '1'")
    failsAt(function() read({[true] = 1}) end, "unknown option 'true'")
    failsAt(function() read({[{}] = 1, [{}] = 2, zeta = 3}) end, "unknown option '<table>'")
    failsAt(function() read({[2] = 1, [{}] = 2}) end, "unknown option '2'")
end)

test('every error points at the caller of the public function, with and without a helper in between', function()
    local owner = Player.fromIndex(0)
    local wrong = {'big', owner, {bogus = 1}, {size = 'big'}, {color = {1}}, {player = {}}, {count = 2 ^ 31}}
    for _, options in ipairs(wrong) do
        local line, here = blamed(function() read(options) end)
        eq(line, here)
        line, here = blamed(function() deep(options) end)
        eq(line, here)
    end
end)
