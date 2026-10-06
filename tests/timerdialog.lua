native('CreateTimer', function() return {} end)
native('CreateTimerDialog', function() return {} end)
native('GetLocalPlayer', function() return PLAYER_RAW end)
for _, name in ipairs({'PauseTimer', 'DestroyTimer', 'TimerDialogSetTitle', 'TimerDialogSetTitleColor',
    'TimerDialogSetTimeColor', 'TimerDialogSetSpeed', 'TimerDialogSetRealTimeRemaining', 'TimerDialogDisplay',
    'DestroyTimerDialog'}) do
    native(name, function() end)
end
local TimerDialog = require('wrappers.timerdialog')
local Timer = require('wrappers.timer')
local Player = require('wrappers.player')
eq(totalCalls(), 0)

local methods = {'getHandle', 'setTitle', 'setTitleColor', 'setTimeColor', 'setSpeed', 'setRealTimeRemaining',
    'setVisible', 'setVisibleFor'}

test('create shows the given timer with an optional title, hidden until setVisible', function()
    local timer = Timer.create()
    local dialog = TimerDialog.create(timer, 'Next wave')
    expectCall('CreateTimerDialog', timer.handle)
    expectCall('TimerDialogSetTitle', dialog.handle, 'Next wave')
    eq(callCount('TimerDialogDisplay'), 0)
    eq(TimerDialog.fromHandle(dialog.handle), dialog); eq(TimerDialog.fromHandle(nil), nil)
    eq(dialog:getHandle(), dialog.handle); eq(dialog:isDisposed(), false)
    local untitled = TimerDialog.create(timer)
    eq(callCount('TimerDialogSetTitle'), 1)
    resetCalls()
    failsAt(function() TimerDialog.create(dialog) end, 'TimerDialog.create: expected Timer wrapper')
    eq(totalCalls(), 0)
    dialog:destroy(); untitled:destroy(); timer:destroy()
end)

test('setters forward exact arguments', function()
    local timer = Timer.create()
    local dialog = TimerDialog.create(timer)
    checkSetters(dialog, {{'TimerDialogSetTitle', 'setTitle', 'T'},
        {'TimerDialogSetTitleColor', 'setTitleColor', 1, 2, 3, 4}, {'TimerDialogSetTimeColor', 'setTimeColor', 5, 6, 7, 8},
        {'TimerDialogSetSpeed', 'setSpeed', 2}, {'TimerDialogSetRealTimeRemaining', 'setRealTimeRemaining', 30},
        {'TimerDialogDisplay', 'setVisible', true}})
    dialog:setVisibleFor(Player.fromIndex(0)); expectCall('TimerDialogDisplay', dialog.handle, true)
    dialog:setVisibleFor(Player.fromHandle({})); expectCall('TimerDialogDisplay', dialog.handle, false)
    failsAt(function() dialog:setVisibleFor(timer) end, 'TimerDialog.setVisibleFor: expected Player wrapper')
    eq(dialog.isDisplayed, nil); eq(TimerDialog.show, nil)
    dialog:destroy(); timer:destroy()
end)

test('methods raise once the timer is disposed, but destroy still works', function()
    local timer = Timer.create()
    local dialog = TimerDialog.create(timer)
    timer:destroy()
    resetCalls()
    for _, method in ipairs(methods) do
        failsAt(function() dialog[method](dialog) end, 'TimerDialog.' .. method .. ': Timer is disposed')
    end
    eq(totalCalls(), 0); eq(dialog:isDisposed(), false)
    local raw = dialog.handle
    dialog:destroy(); dialog:destroy()
    expectCall('DestroyTimerDialog', raw); eq(callCount('DestroyTimerDialog'), 1)
    eq(callCount('DestroyTimer'), 0)
end)

test('destroy never destroys the timer and guards every method', function()
    local timer = Timer.create()
    local dialog = TimerDialog.create(timer)
    dialog:destroy()
    eq(callCount('DestroyTimer'), 0); eq(timer:isDisposed(), false)
    eq(dialog.handle, nil); eq(dialog:isDisposed(), true)
    checkDisposed(dialog, methods)
    timer:destroy()
end)

test('create fails clearly when the native returns nil', function()
    local timer = Timer.create()
    native('CreateTimerDialog', function() return nil end)
    failsAt(function() TimerDialog.create(timer, 'x') end, 'TimerDialog.create: native returned nil')
    eq(callCount('TimerDialogSetTitle'), 0)
    native('CreateTimerDialog', function() return {} end)
    timer:destroy()
end)

test('a destroyed timer is reported at the caller', function()
    local timer = Timer.create()
    local dialog = TimerDialog.create(timer)
    timer:destroy()
    failsAt(function() dialog:setTitle('x') end, 'TimerDialog.setTitle: Timer is disposed')
end)
