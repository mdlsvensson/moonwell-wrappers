for _, name in ipairs({'DestroyTextTag', 'SetTextTagPermanent', 'SetTextTagText', 'SetTextTagPos',
    'SetTextTagPosUnit', 'SetTextTagColor', 'SetTextTagVelocity', 'SetTextTagVisibility', 'SetTextTagSuspended',
    'SetTextTagLifespan', 'SetTextTagFadepoint'}) do
    native(name, function() end)
end
native('CreateTextTag', function() return {} end)
native('GetLocalPlayer', function() return PLAYER_RAW end)
local TextTag = require('wrappers.texttag')
local Player = require('wrappers.player')
local Unit = require('wrappers.unit')
eq(totalCalls(), 0)

test('owned text tags are permanent and forward exact arguments', function()
    eq(TextTag.fromHandle(nil), nil)
    local tag = TextTag.create()
    expectCall('SetTextTagPermanent', tag.handle, true)
    eq(TextTag.fromHandle(tag.handle), tag); eq(tag:getHandle(), tag.handle); eq(tag:isDisposed(), false)
    checkSetters(tag, {{'SetTextTagColor', 'setColor', 1, 2, 3, 4}, {'SetTextTagPos', 'setPosition', 5, 6, 7},
        {'SetTextTagSuspended', 'setSuspended', true}, {'SetTextTagVisibility', 'setVisible', false}})
    tag:setText('hello', 10)
    expectCall('SetTextTagText', tag.handle, 'hello', 10 * 0.023 / 10)
    tag:setText('small', 7.5)
    expectCall('SetTextTagText', tag.handle, 'small', 7.5 * 0.023 / 10)
    failsAt(function() tag:setText('hello') end, 'TextTag.setText: expected a finite size')
    failsAt(function() tag:setText('hello', 'big') end, 'TextTag.setText: expected a finite size')
    eq(callCount('SetTextTagText'), 2); eq(TextTag.show, nil)
    local u = Unit.fromHandle({})
    tag:setPositionOnUnit(u, 16); expectCall('SetTextTagPosUnit', tag.handle, u.handle, 16)
    failsAt(function() tag:setPositionOnUnit(tag, 0) end, 'TextTag.setPositionOnUnit: expected Unit wrapper')
    eq(callCount('SetTextTagPosUnit'), 1)
    u:remove(); tag:destroy()
end)

test('setVisibleFor shows the tag only on that player machine', function()
    local tag = TextTag.create()
    tag:setVisibleFor(Player.fromIndex(0)); expectCall('SetTextTagVisibility', tag.handle, true)
    tag:setVisibleFor(Player.fromHandle({})); expectCall('SetTextTagVisibility', tag.handle, false)
    failsAt(function() tag:setVisibleFor(tag) end, 'TextTag.setVisibleFor: expected Player wrapper')
    eq(callCount('SetTextTagVisibility'), 2)
    tag:destroy()
end)

test('setVelocity takes the speed and angle of TextTag.float', function()
    local tag = TextTag.create()
    local xvel, yvel
    native('SetTextTagVelocity', function(_, x, y) xvel, yvel = x, y end)
    local function near(actual, expected)
        assert(math.abs(actual - expected) < 1e-9, 'expected about ' .. expected .. ', got ' .. tostring(actual))
    end
    tag:setVelocity(64, 0)
    near(xvel, 0.0355); near(yvel, 0)
    tag:setVelocity(64, 90)
    near(xvel, 0); near(yvel, 0.0355)
    failsAt(function() tag:setVelocity('fast', 0) end, 'TextTag.setVelocity: expected a finite speed')
    eq(callCount('SetTextTagVelocity'), 2)
    native('SetTextTagVelocity', function() end)
    tag:destroy()
end)

test('destroy is idempotent and guards every method', function()
    local tag = TextTag.create()
    local raw = tag.handle
    tag:destroy(); tag:destroy()
    expectCall('DestroyTextTag', raw); eq(callCount('DestroyTextTag'), 1); eq(tag.handle, nil)
    eq(tag:isDisposed(), true)
    checkDisposed(tag, {'getHandle', 'setText', 'setColor', 'setPosition', 'setPositionOnUnit', 'setVelocity',
        'setSuspended', 'setVisible', 'setVisibleFor'})
end)

test('create fails clearly when the native returns nil', function()
    native('CreateTextTag', function() return nil end)
    failsAt(function() TextTag.create() end, 'TextTag.create')
    eq(callCount('SetTextTagPermanent'), 0)
    native('CreateTextTag', function() return {} end)
end)

test('float shows a temporary tag with documented defaults and no wrapper', function()
    local raw = {}
    native('CreateTextTag', function() return raw end)
    eq(TextTag.float('+10', 1, 2), nil)
    local v = 64 * 0.071 / 128
    expectCall('SetTextTagText', raw, '+10', 10 * 0.023 / 10)
    expectCall('SetTextTagPos', raw, 1, 2, 0)
    expectCall('SetTextTagColor', raw, 255, 255, 255, 255)
    expectCall('SetTextTagVelocity', raw, v * math.cos(math.rad(90)), v * math.sin(math.rad(90)))
    expectCall('SetTextTagVisibility', raw, true)
    expectCall('SetTextTagPermanent', raw, false)
    expectCall('SetTextTagLifespan', raw, 2); expectCall('SetTextTagFadepoint', raw, 1)
    eq(callCount('GetLocalPlayer'), 0)
    native('CreateTextTag', function() return {} end)
end)

test('float options change size, color, motion, timing and audience', function()
    local raw = {}
    native('CreateTextTag', function() return raw end)
    TextTag.float('crit', 3, 4, {size = 14, heightOffset = 32, color = {255, 0, 0}, speed = 128, angle = 0,
        lifespan = 3, fadepoint = 2, player = Player.fromHandle({})})
    local v = 128 * 0.071 / 128
    expectCall('SetTextTagText', raw, 'crit', 14 * 0.023 / 10)
    expectCall('SetTextTagPos', raw, 3, 4, 32)
    expectCall('SetTextTagColor', raw, 255, 0, 0, 255)
    expectCall('SetTextTagVelocity', raw, v * math.cos(math.rad(0)), v * math.sin(math.rad(0)))
    expectCall('SetTextTagVisibility', raw, false)
    expectCall('SetTextTagLifespan', raw, 3); expectCall('SetTextTagFadepoint', raw, 2)
    TextTag.float('me', 0, 0, {player = Player.fromIndex(0), color = {0, 0, 255, 128}})
    expectCall('SetTextTagVisibility', raw, true); expectCall('SetTextTagColor', raw, 0, 0, 255, 128)
    native('CreateTextTag', function() return {} end)
end)

test('float makes the tag temporary before any native that can raise', function()
    local raw = {}
    native('CreateTextTag', function() return raw end)
    native('SetTextTagText', function() error('boom') end)
    fails(function() TextTag.float('x', 0, 0) end, 'boom')
    -- Restore the doubles before asserting, so a failed assertion cannot leak into later tests.
    native('SetTextTagText', function() end)
    native('CreateTextTag', function() return {} end)
    expectCall('SetTextTagPermanent', raw, false)
    expectCall('SetTextTagLifespan', raw, 2)
    expectCall('SetTextTagFadepoint', raw, 1)
end)

test('float does nothing without a free text tag and rejects bad options first', function()
    native('CreateTextTag', function() return nil end)
    eq(TextTag.float('x', 0, 0), nil)
    eq(totalCalls(), 1)
    native('CreateTextTag', function() return {} end)
    failsAt(function() TextTag.float('x', 0, 0, {colour = {1, 2, 3}}) end, "TextTag.float: unknown option 'colour'")
    failsAt(function() TextTag.float('x', 0, 0, {lifespan = -1}) end,
        "TextTag.float: 'lifespan' expected a finite non-negative number")
    failsAt(function() TextTag.float('x', 0, 0, {player = {}}) end, 'TextTag.float: expected Player wrapper')
    eq(callCount('CreateTextTag'), 1)
end)

test('option errors point at the caller', function()
    failsAt(function() TextTag.float('x', 0, 0, {size = 'big'}) end, "TextTag.float: 'size' expected a number")
    failsAt(function() TextTag.float('x', 0, 0, {bogus = 1}) end, "TextTag.float: unknown option 'bogus'")
    failsAt(function() TextTag.float('x', 0, 0, {color = {1}}) end,
        "TextTag.float: 'color' expected {r, g, b, a?} integers")
    failsAt(function() TextTag.float('x', 0, 0, {player = {}}) end, 'TextTag.float: expected Player wrapper')
end)
