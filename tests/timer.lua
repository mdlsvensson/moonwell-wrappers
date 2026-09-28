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

test('periodic callbacks receive self and old schedules cannot fire', function()
    local t, hits = Timer.create(), 0
    t:start(1, true, function(self) eq(self, t); hits = hits + 1 end)
    local first = ticks[#ticks]
    expectCall('TimerStart', t.handle, 1, true, first)
    first(); first(); eq(hits, 2)
    t:pause(); t:resume(); first(); eq(hits, 3)
    t:start(0, false, function(self) self:destroy() end)
    first(); eq(hits, 3)
    ticks[#ticks](); eq(t:isDisposed(), true)
    ticks[#ticks](); eq(callCount('DestroyTimer'), 1)
end)

test('one shot retains timer and restart from callback survives', function()
    local t, hits = Timer.create(), 0
    t:start(1, false, function(self)
        hits = hits + 1
        self:start(2, true, function() hits = hits + 10 end)
    end)
    local first = ticks[#ticks]
    first(); first(); eq(hits, 1)
    eq(t:isDisposed(), false)
    ticks[#ticks](); ticks[#ticks](); eq(hits, 21)
    t:destroy()
    t = Timer.create()
    t:start(0, false, function() hits = hits + 1 end)
    ticks[#ticks](); ticks[#ticks](); eq(hits, 22)
    eq(t:isDisposed(), false); t:destroy()
end)

test('invalid start cannot replace an existing schedule', function()
    local t, hits = Timer.create(), 0
    t:start(1, true, function() hits = hits + 1 end)
    local valid = ticks[#ticks]
    for _, value in ipairs({-1, math.huge, -math.huge, 0/0, '1', false}) do
        fails(function() t:start(value, true, function() end) end, 'Timer.start')
    end
    fails(function() t:start(1, true, nil) end, 'callback')
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
