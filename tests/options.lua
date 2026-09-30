local Options = require('wrappers.internal.options')
local Player = require('wrappers.player')
eq(totalCalls(), 0)

local fields = {
    size = {'number', 10}, count = {'integer'}, flag = {'boolean', false}, name = {'string', 'x'},
    life = {'nonnegative', 2}, color = {'color', {255, 255, 255}}, player = {'Player'},
}

test('defaults fill a fresh table and given values pass through', function()
    local owner = Player.fromIndex(0)
    local given = {size = 12, count = 3.0, player = owner, color = {1, 2, 3}}
    local o = Options.read(given, fields, 'Test.op')
    eq(o.size, 12); eq(o.count, 3.0); eq(o.flag, false); eq(o.name, 'x'); eq(o.life, 2); eq(o.player, PLAYER_RAW)
    eq(o.color[1], 1); eq(o.color[2], 2); eq(o.color[3], 3); eq(o.color[4], 255)
    eq(given.player, owner); eq(given.color[4], nil); eq(given.flag, nil); eq(o == given, false)
    local defaults = Options.read(nil, fields, 'Test.op')
    eq(defaults.count, nil); eq(defaults.player, nil); eq(defaults.color[1], 255); eq(defaults.color[4], 255)
    eq(Options.read(nil, fields, 'Test.op').color == defaults.color, false)
    eq(fields.color[2][4], nil)
    local full = Options.read({color = {1, 2, 3, 4}}, fields, 'Test.op')
    eq(full.color[4], 4)
end)

test('invalid options fail with the operation name before any native', function()
    fails(function() Options.read('big', fields, 'Test.op') end, 'Test.op: expected an options table')
    fails(function() Options.read({colour = {1, 2, 3}}, fields, 'Test.op') end, "Test.op: unknown option 'colour'")
    fails(function() Options.read({size = 'big'}, fields, 'Test.op') end, "Test.op: option 'size' expected a number")
    fails(function() Options.read({count = 1.5}, fields, 'Test.op') end, "option 'count' expected an integer")
    fails(function() Options.read({flag = 1}, fields, 'Test.op') end, "option 'flag' expected a boolean")
    fails(function() Options.read({name = 1}, fields, 'Test.op') end, "option 'name' expected a string")
    fails(function() Options.read({life = -1}, fields, 'Test.op') end,
        "option 'life' expected a finite non-negative number")
    fails(function() Options.read({life = 0 / 0}, fields, 'Test.op') end, 'finite non-negative')
    fails(function() Options.read({life = math.huge}, fields, 'Test.op') end, 'finite non-negative')
    fails(function() Options.read({color = {1, 2}}, fields, 'Test.op') end,
        "option 'color' expected {r, g, b, a?} integers")
    fails(function() Options.read({color = {1, 2, 3, 4, 5}}, fields, 'Test.op') end, "option 'color'")
    fails(function() Options.read({color = {1, 2, 3.5}}, fields, 'Test.op') end, "option 'color'")
    fails(function() Options.read({color = 'red'}, fields, 'Test.op') end, "option 'color'")
    fails(function() Options.read({player = {}}, fields, 'Test.op') end, 'Test.op: expected Player wrapper')
    eq(totalCalls(), 0)
end)

test('several errors report the first in sorted order', function()
    fails(function() Options.read({zeta = 1, alpha = 2}, fields, 'Test.op') end, "unknown option 'alpha'")
    fails(function() Options.read({size = 'a', name = 1}, fields, 'Test.op') end, "option 'name' expected a string")
end)
