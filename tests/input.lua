EVENT_PLAYER_MOUSE_DOWN, EVENT_PLAYER_MOUSE_UP, EVENT_PLAYER_MOUSE_MOVE = {}, {}, {}
local actions, numbers, nextNumber, event = {}, {}, 0, {}
native('CreateTrigger', function() return {registrations = {}, enabled = true} end)
native('BlzTriggerRegisterPlayerKeyEvent', function(trigger, player, key, meta, down)
    trigger.player, trigger.key = player, key
    trigger.registrations[#trigger.registrations + 1] = meta .. (down and ' down' or ' up')
    return {}
end)
native('TriggerRegisterPlayerEvent', function(trigger, player, kind)
    trigger.player, trigger.kind = player, kind
    return {}
end)
native('TriggerAddAction', function(trigger, callback)
    actions[#actions + 1] = {trigger = trigger, callback = callback}
    return {}
end)
native('EnableTrigger', function(trigger) trigger.enabled = true end)
native('DisableTrigger', function(trigger) trigger.enabled = false end)
native('GetPlayerId', function(raw) return numbers[raw] end)
native('GetHandleId', function(raw) return numbers[raw] end)
native('GetTriggerPlayer', function() return event.player end)
native('BlzGetTriggerPlayerIsKeyDown', function() return event.down end)
native('BlzGetTriggerPlayerMetaKey', function() return event.meta end)
native('BlzGetTriggerPlayerMouseX', function() return event.x end)
native('BlzGetTriggerPlayerMouseY', function() return event.y end)
native('BlzGetTriggerPlayerMouseButton', function() return event.button end)
-- Game time, as the module's clock timer reports it; a test moves it by hand.
local gameTime, clocks = 0, {}
native('CreateTimer', function() clocks[#clocks + 1] = {}; return clocks[#clocks] end)
native('TimerStart', function() end)
native('TimerGetElapsed', function(timer) eq(timer, clocks[1]); return gameTime end)
local Input = require('wrappers.input')
local Player = require('wrappers.player')
eq(totalCalls(), 0)

-- The module keeps one trigger per player and key for good, so every test uses players and keys of its own.
local function numbered()
    nextNumber = nextNumber + 1
    local raw = {}
    numbers[raw] = nextNumber
    return raw
end
local function newPlayer() return Player.fromHandle(numbered()) end
local function triggerOf(who, what)
    for _, action in ipairs(actions) do
        local trigger = action.trigger
        local matches = trigger.key == what or trigger.kind == what
        if trigger.player == who.handle and matches then return trigger, action end
    end
end
-- Simulates a synced input event: runs the action of the trigger registered for it, if that trigger is enabled.
local function deliver(who, what, data)
    data.player = who.handle
    event = data
    local trigger, action = triggerOf(who, what)
    if trigger and trigger.enabled then action.callback() end
end
local function press(who, key, meta) deliver(who, key, {down = true, meta = meta or 0}) end
local function release(who, key, meta) deliver(who, key, {down = false, meta = meta or 0}) end

test('the game clock is one timer, started by the first key listener and by no mouse listener', function()
    local who, q, w = newPlayer(), numbered(), numbered()
    local mouse = {Input.onMouseDown(who, function() end), Input.onMouseUp(who, function() end),
        Input.onMouseMove(who, function() end)}
    eq(callCount('CreateTimer'), 0); eq(callCount('TimerStart'), 0)
    native('CreateTimer', function() return nil end)
    failsAt(function() Input.onKeyDown(who, q, function() end) end, 'Input.onKeyDown: native returned nil')
    failsAt(function() Input.onKeyUp(who, q, function() end) end, 'Input.onKeyUp: native returned nil')
    eq(callCount('CreateTrigger'), 3); eq(callCount('TimerStart'), 0)
    native('CreateTimer', function() clocks[#clocks + 1] = {}; return clocks[#clocks] end)
    local starts = {}
    native('TimerStart', function(timer, timeout, periodic, callback)
        starts[#starts + 1] = {timer, timeout, periodic, type(callback)}
    end)
    local up = Input.onKeyUp(who, q, function() end)
    -- One long run, not a repeating one: the elapsed time must never start over.
    eq(#clocks, 1); eq(#starts, 1)
    eq(starts[1][1], clocks[1]); eq(starts[1][2], 1000000); eq(starts[1][3], false); eq(starts[1][4], 'function')
    local down, other = Input.onKeyDown(who, q, function() end), Input.onKeyDown(who, w, function() end)
    eq(#clocks, 1); eq(#starts, 1)
    native('TimerStart', function() end)
    for _, token in ipairs({up, down, other, mouse[1], mouse[2], mouse[3]}) do Input.off(token) end
    eq(callCount('PauseTimer'), 0); eq(callCount('DestroyTimer'), 0)
end)

test('one trigger per player and key, registered for all 16 modifier values, down and up', function()
    local who, other, q, w = newPlayer(), newPlayer(), numbered(), numbered()
    local down = Input.onKeyDown(who, q, function() end)
    eq(callCount('CreateTrigger'), 1); eq(callCount('BlzTriggerRegisterPlayerKeyEvent'), 32)
    local trigger = triggerOf(who, q)
    eq(trigger.player, who.handle); eq(trigger.key, q)
    local expected = {}
    for meta = 0, 15 do
        expected[#expected + 1] = meta .. ' down'
        expected[#expected + 1] = meta .. ' up'
    end
    eq(table.concat(trigger.registrations, ','), table.concat(expected, ','))
    local up = Input.onKeyUp(who, q, function() end)
    eq(callCount('CreateTrigger'), 1); eq(callCount('BlzTriggerRegisterPlayerKeyEvent'), 32)
    local second = Input.onKeyDown(who, w, function() end)
    local third = Input.onKeyUp(other, q, function() end)
    eq(callCount('CreateTrigger'), 3); eq(callCount('BlzTriggerRegisterPlayerKeyEvent'), 96)
    Input.off(down)
    eq(trigger.enabled, true)
    Input.off(up)
    eq(trigger.enabled, false); eq(triggerOf(who, w).enabled, true); eq(triggerOf(other, q).enabled, true)
    local again = Input.onKeyUp(who, q, function() end)
    eq(callCount('CreateTrigger'), 3); eq(trigger.enabled, true)
    Input.off(again); Input.off(second); Input.off(third)
    eq(callCount('DestroyTrigger'), 0)
end)

test('onKeyDown runs once per press with the modifiers, and onKeyUp at the release', function()
    local who, q, log = newPlayer(), numbered(), {}
    local function note(name)
        return function(player, meta, repeated, extra)
            eq(player, who); eq(extra, nil)
            log[#log + 1] = name .. ' ' .. meta .. ' ' .. tostring(repeated)
        end
    end
    local down, up = Input.onKeyDown(who, q, note('down')), Input.onKeyUp(who, q, note('up'))
    press(who, q, 3); press(who, q, 3); press(who, q, 1); release(who, q, 1)
    press(who, q); release(who, q)
    eq(table.concat(log, ', '), 'down 3 false, up 1 nil, down 0 false, up 0 nil')
    eq(#PRINTED, 0)
    Input.off(down); Input.off(up)
end)

test('the option repeats passes the repeated downs and says which they are', function()
    local who, q, log = newPlayer(), numbered(), {}
    local every = Input.onKeyDown(who, q, function(_, _, repeated) log[#log + 1] = 'every ' .. tostring(repeated) end,
        {repeats = true})
    local once = Input.onKeyDown(who, q, function(_, _, repeated) log[#log + 1] = 'once ' .. tostring(repeated) end,
        {repeats = false})
    press(who, q); press(who, q); press(who, q); release(who, q); press(who, q)
    eq(table.concat(log, ', '), 'every false, once false, every true, every true, every false, once false')
    Input.off(every); Input.off(once)
end)

test('a down more than two seconds of game time after the last is a new press: its release was lost', function()
    local who, q, w, log = newPlayer(), numbered(), numbered(), {}
    local function note(name) return function(_, _, repeated) log[#log + 1] = name .. ' ' .. tostring(repeated) end end
    local tokens = {Input.onKeyDown(who, q, note('once')), Input.onKeyDown(who, q, note('every'), {repeats = true}),
        Input.onKeyDown(who, w, note('w'))}
    local function at(time, key) gameTime = time; press(who, key) end
    at(100, q)
    -- The first repeat, and one exactly two seconds after it: both are repeats.
    at(100.5, q); at(102.5, q)
    eq(table.concat(log, ', '), 'once false, every false, every true, every true')
    -- The window starts at the last down, not at the first: 2.25 seconds after it this is a new press.
    log = {}
    at(104.75, q); at(104.78125, q)
    eq(table.concat(log, ', '), 'once false, every false, every true')
    -- Each key has a time of its own: W's first down, long after Q's, and Q's repeat right after it.
    log = {}
    at(106.5, w); at(106.5, q); at(109, w)
    eq(table.concat(log, ', '), 'w false, every true, w false')
    -- A release still ends the press at once.
    log = {}
    release(who, q); at(109, q); at(109, q)
    eq(table.concat(log, ', '), 'once false, every false, every true')
    for _, token in ipairs(tokens) do Input.off(token) end
    gameTime = 0
end)

test('what is held is kept per player and key, and forgotten when the last listener of a key is removed', function()
    local who, other, q, w, log = newPlayer(), newPlayer(), numbered(), numbered(), {}
    local function note(name) return function() log[#log + 1] = name end end
    local tokens = {Input.onKeyDown(who, q, note('q')), Input.onKeyDown(who, w, note('w')),
        Input.onKeyDown(other, q, note('other q'))}
    press(who, q); press(who, w); press(other, q); press(who, q); press(who, w); press(other, q)
    eq(table.concat(log, ', '), 'q, w, other q')
    -- An up listener alone keeps the key's state: the trigger stays enabled.
    local up = Input.onKeyUp(who, q, function() end)
    Input.off(tokens[1])
    tokens[1] = Input.onKeyDown(who, q, note('q'))
    press(who, q)
    eq(#log, 3)
    -- With no listener left the release is never seen, so the next listener starts over.
    Input.off(tokens[1]); Input.off(up)
    release(who, q)
    tokens[1] = Input.onKeyDown(who, q, note('q again'))
    press(who, q); press(who, q)
    eq(table.concat(log, ', '), 'q, w, other q, q again')
    for _, token in ipairs(tokens) do Input.off(token) end
end)

test('mouse listeners get the point and the button, and a move the point alone', function()
    local who, other, left, log = newPlayer(), newPlayer(), {}, {}
    local function note(name)
        return function(player, x, y, ...)
            eq(player, who)
            log[#log + 1] = name .. ' ' .. x .. ' ' .. y .. ' ' .. select('#', ...) .. ' ' .. tostring(... == left)
        end
    end
    local down, up = Input.onMouseDown(who, note('down')), Input.onMouseUp(who, note('up'))
    local move = Input.onMouseMove(who, note('move'))
    eq(callCount('CreateTrigger'), 3); eq(callCount('TriggerRegisterPlayerEvent'), 3)
    eq(callCount('BlzTriggerRegisterPlayerKeyEvent'), 0)
    for _, kind in ipairs({EVENT_PLAYER_MOUSE_DOWN, EVENT_PLAYER_MOUSE_UP, EVENT_PLAYER_MOUSE_MOVE}) do
        eq(triggerOf(who, kind).player, who.handle)
    end
    local also = Input.onMouseDown(who, function() log[#log + 1] = 'also' end)
    local far = Input.onMouseDown(other, function() log[#log + 1] = 'other' end)
    eq(callCount('CreateTrigger'), 4)
    deliver(who, EVENT_PLAYER_MOUSE_DOWN, {x = 1, y = 2, button = left})
    deliver(who, EVENT_PLAYER_MOUSE_UP, {x = 3, y = 4, button = left})
    deliver(who, EVENT_PLAYER_MOUSE_MOVE, {x = 5, y = 6, button = left})
    eq(table.concat(log, ', '), 'down 1 2 1 true, also, up 3 4 1 true, move 5 6 0 false')
    Input.off(move)
    eq(triggerOf(who, EVENT_PLAYER_MOUSE_MOVE).enabled, false)
    eq(triggerOf(who, EVENT_PLAYER_MOUSE_DOWN).enabled, true)
    deliver(who, EVENT_PLAYER_MOUSE_MOVE, {x = 7, y = 8})
    eq(#log, 4)
    Input.off(down); Input.off(up); Input.off(also); Input.off(far)
end)

test('a listener added during a firing waits; a failing one is printed and the next still runs', function()
    local who, q, log, late = newPlayer(), numbered(), {}, nil
    local first
    first = Input.onKeyDown(who, q, function()
        log[#log + 1] = 'first'
        if not late then late = Input.onKeyDown(who, q, function() log[#log + 1] = 'late' end) end
    end)
    local broken = Input.onKeyDown(who, q, function() error('intentional input probe') end)
    local last = Input.onKeyDown(who, q, function()
        log[#log + 1] = 'last'
        Input.off(first)
    end)
    press(who, q)
    eq(table.concat(log, ','), 'first,last'); eq(#PRINTED, 1)
    assert(PRINTED[1]:find('[wrappers] Input listener callback failed:', 1, true), PRINTED[1])
    assert(PRINTED[1]:find('intentional input probe', 1, true), PRINTED[1])
    Input.off(broken)
    release(who, q); press(who, q)
    eq(table.concat(log, ','), 'first,last,last,late')
    Input.off(first); Input.off(last); Input.off(late)
end)

test('arguments are checked at the caller, before any native', function()
    local who, q = newPlayer(), numbered()
    resetCalls()
    local function nothing() end
    failsAt(function() Input.onKeyDown({}, q, nothing) end, 'Input.onKeyDown: expected Player wrapper')
    failsAt(function() Input.onKeyDown(who, nil, nothing) end, 'Input.onKeyDown: expected a key, such as OSKEY_Q')
    failsAt(function() Input.onKeyDown(who, q, 'cast') end, 'Input.onKeyDown: expected a callback function')
    failsAt(function() Input.onKeyDown(who, q, nothing, true) end, 'Input.onKeyDown: expected an options table')
    failsAt(function() Input.onKeyDown(who, q, nothing, {repeat_ = true}) end,
        "Input.onKeyDown: unknown option 'repeat_'")
    failsAt(function() Input.onKeyDown(who, q, nothing, {repeats = 1}) end,
        "Input.onKeyDown: 'repeats' expected a boolean")
    failsAt(function() Input.onKeyUp({}, q, nothing) end, 'Input.onKeyUp: expected Player wrapper')
    failsAt(function() Input.onKeyUp(who, nil, nothing) end, 'Input.onKeyUp: expected a key, such as OSKEY_Q')
    failsAt(function() Input.onKeyUp(who, q, nil) end, 'Input.onKeyUp: expected a callback function')
    for _, name in ipairs({'onMouseDown', 'onMouseUp', 'onMouseMove'}) do
        failsAt(function() Input[name]({}, nothing) end, 'Input.' .. name .. ': expected Player wrapper')
        failsAt(function() Input[name](who, nil) end, 'Input.' .. name .. ': expected a callback function')
    end
    failsAt(function() Input.off({}) end, 'Input.off: expected InputListener token')
    failsAt(function() Input.off(nil) end, 'Input.off: expected InputListener token')
    eq(totalCalls(), 0)
    local token = Input.onMouseMove(who, nothing)
    Input.off(token); Input.off(token)
    native('CreateTrigger', function() return nil end)
    failsAt(function() Input.onKeyDown(who, q, nothing) end, 'Input.onKeyDown: native returned nil')
    failsAt(function() Input.onMouseDown(who, nothing) end, 'Input.onMouseDown: native returned nil')
    native('CreateTrigger', function() return {registrations = {}, enabled = true} end)
end)
