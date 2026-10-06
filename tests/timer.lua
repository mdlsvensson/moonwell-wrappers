local ticks = {}
native('CreateTimer', function() return {} end)
native('TimerStart', function(_, _, _, callback) ticks[#ticks + 1] = callback end)
native('PauseTimer', function() end)
native('DestroyTimer', function() end)
local Timer = require('wrappers.timer')
eq(totalCalls(), 0)

test('timer identity, factory and native mappings', function()
    eq(Timer.fromHandle(nil), nil)
    local t = Timer.create()
    eq(Timer.fromHandle(t.handle), t); eq(t:getHandle(), t.handle)
    local raw = t.handle
    for _, row in ipairs({{'TimerGetElapsed', 'getElapsed', 1}, {'TimerGetRemaining', 'getRemaining', 2},
        {'TimerGetTimeout', 'getTimeout', 3}}) do
        native(row[1], function() return row[3] end)
        eq(t[row[2]](t), row[3]); expectCall(row[1], raw)
    end
    native('ResumeTimer', function() end)
    t:pause(); expectCall('PauseTimer', raw)
    t:resume(); expectCall('ResumeTimer', raw)
    resetCalls(); t:destroy(); t:destroy()
    eq(callName(1), 'PauseTimer'); eq(callName(2), 'DestroyTimer'); eq(totalCalls(), 2)
    expectCall('DestroyTimer', raw); eq(t.handle, nil)
    for _, method in ipairs({'start', 'pause', 'resume', 'getHandle', 'getElapsed', 'getRemaining', 'getTimeout'}) do
        fails(function() t[method](t) end, 'disposed')
    end
    native('CreateTimer', function() return nil end)
    fails(Timer.create, 'Timer.create')
    native('CreateTimer', function() return {} end)
end)

-- In the game TimerStart replaces a timer's schedule, so one timer has one schedule at a time. A Timer therefore
-- gives every TimerStart the same function, and that function runs the callback of the latest start.
test('periodic callbacks receive self; a new start replaces the callback and reuses the one tick function', function()
    local t, hits = Timer.create(), 0
    t:start(1, true, function(self) eq(self, t); hits = hits + 1 end)
    local tick = ticks[#ticks]
    expectCall('TimerStart', t.handle, 1, true, tick)
    tick(); tick(); eq(hits, 2)
    t:pause(); t:resume(); tick(); eq(hits, 3)
    t:start(0, false, function(self) self:destroy() end)
    eq(#ticks, 2); eq(ticks[2], tick); expectCall('TimerStart', t.handle, 0, false, tick)
    tick(); eq(hits, 3); eq(t:isDisposed(), true)
    tick(); eq(callCount('DestroyTimer'), 1)
    -- Each Timer has a tick function of its own.
    local other = Timer.create()
    other:start(1, true, function() hits = hits + 100 end)
    eq(ticks[#ticks] ~= tick, true)
    tick(); eq(hits, 3)
    other:destroy()
end)

test('one shot retains timer and restart from callback survives', function()
    local t, hits = Timer.create(), 0
    t:start(1, false, function(self)
        hits = hits + 1
        self:start(2, true, function() hits = hits + 10 end)
    end)
    local tick = ticks[#ticks]
    tick(); eq(hits, 1)
    eq(t:isDisposed(), false)
    eq(ticks[#ticks], tick); expectCall('TimerStart', t.handle, 2, true, tick)
    tick(); tick(); eq(hits, 21)
    t:destroy()
    t = Timer.create()
    t:start(0, false, function() hits = hits + 1 end)
    -- A one-shot delivery releases its callback: an expiry with no start before it runs nothing.
    ticks[#ticks](); ticks[#ticks](); eq(hits, 22)
    eq(t:isDisposed(), false); t:destroy()
end)

test('invalid start cannot replace an existing schedule', function()
    local t, hits = Timer.create(), 0
    t:start(1, true, function() hits = hits + 1 end)
    local valid = ticks[#ticks]
    for _, value in ipairs({-1, math.huge, -math.huge, 0/0, '1', false}) do
        failsAt(function() t:start(value, true, function() end) end,
            'Timer.start: expected a finite non-negative timeout')
    end
    failsAt(function() t:start(1, true, nil) end, 'Timer.start: expected a callback function')
    eq(callCount('TimerStart'), 1); valid(); eq(hits, 1); t:destroy()
end)

test('callback errors are visible and later ticks run', function()
    local t, hits = Timer.create(), 0
    t:start(1, true, function()
        hits = hits + 1
        if hits == 1 then error('probe') end
        return 123
    end)
    ticks[#ticks](); ticks[#ticks]()
    eq(hits, 2); eq(#PRINTED, 1)
    assert(PRINTED[1]:find('[wrappers] Timer callback failed:', 1, true))
    assert(PRINTED[1]:find('probe', 1, true)); t:destroy()
end)

test('destroy invalidates callbacks before native reentry', function()
    local t, hits = Timer.create(), 0
    t:start(1, true, function() hits = hits + 1 end)
    native('PauseTimer', function() ticks[#ticks](); eq(t:isDisposed(), true); t:destroy() end)
    native('DestroyTimer', function() error('native failed') end)
    fails(function() t:destroy() end, 'native failed')
    eq(hits, 0); t:destroy(); eq(callCount('DestroyTimer'), 1)
    native('PauseTimer', function() end); native('DestroyTimer', function() end)
end)

test('fromEvent wraps the timer of the running event, and nil when it has none', function()
    local raw = {}
    native('GetExpiredTimer', function() return raw end)
    local found = Timer.fromEvent()
    eq(found, Timer.fromHandle(raw)); eq(found.handle, raw); eq(callCount('GetExpiredTimer'), 1)
    native('GetExpiredTimer', function() return nil end)
    eq(Timer.fromEvent(), nil)
end)
