ORIGIN_FRAME_GAME_UI = {}
local ORIGIN = {}
native('BlzGetOriginFrame', function() return ORIGIN end)
native('BlzCreateFrameByType', function(_, _, parent) return {parent = parent} end)
native('BlzDestroyFrame', function() end)
local actions = {}
native('CreateTrigger', function() return {events = {}} end)
native('TriggerAddAction', function(trigger, callback)
    actions[#actions + 1] = {trigger = trigger, callback = callback}
    return {}
end)
native('DestroyTrigger', function(trigger) trigger.destroyed = true end)
native('BlzTriggerRegisterFrameEvent', function(trigger, raw, eventType)
    trigger.events[#trigger.events + 1] = {raw = raw, type = eventType}
end)
local current = {}
native('BlzGetTriggerFrameEvent', function() return current.type end)
native('BlzGetTriggerFrameText', function() return current.text end)
native('BlzGetTriggerFrameValue', function() return current.value end)
native('GetTriggerPlayer', function() return current.player end)
local Frame = require('wrappers.frame')
local Player = require('wrappers.player')
eq(totalCalls(), 0)

-- Simulates Warcraft firing a frame event: runs the action of every trigger registered for that frame and event type
-- (a destroyed trigger only when `evenIfDestroyed` is set).
local function fire(raw, eventType, text, value, who, evenIfDestroyed)
    current = {type = eventType, text = text or '', value = value or 0, player = who or PLAYER_RAW}
    for _, action in ipairs(actions) do
        if evenIfDestroyed or not action.trigger.destroyed then
            for _, registration in ipairs(action.trigger.events) do
                if registration.raw == raw and registration.type == eventType then
                    action.callback()
                    break
                end
            end
        end
    end
end

test('on makes one internal trigger per frame and registers each event type once', function()
    local ui = Frame.origin(ORIGIN_FRAME_GAME_UI)
    local button = Frame.createByType('BUTTON', ui)
    button:on('click', function() end); button:on('click', function() end); button:on('enter', function() end)
    eq(callCount('CreateTrigger'), 1); eq(callCount('TriggerAddAction'), 1)
    eq(callCount('BlzTriggerRegisterFrameEvent'), 2)
    expectCall('BlzTriggerRegisterFrameEvent', actions[#actions].trigger, button.handle, 'enter')
    local quiet = Frame.createByType('TEXT', ui)
    quiet:destroy(); eq(callCount('DestroyTrigger'), 0)
    button:destroy(); eq(callCount('DestroyTrigger'), 1)
end)

test('callbacks run in order with the player and the event data', function()
    local box = Frame.createByType('EDITBOX', Frame.origin(ORIGIN_FRAME_GAME_UI))
    local seen = {}
    box:on('enter', function(player, event) seen[#seen + 1] = {'first', player, event} end)
    box:on('enter', function(player, event) seen[#seen + 1] = {'second', player, event} end)
    box:on('click', function() seen[#seen + 1] = {'click'} end)
    local other = {}
    fire(box.handle, 'enter', 'hello', 2.5, other)
    eq(#seen, 2); eq(seen[1][1], 'first'); eq(seen[2][1], 'second')
    eq(seen[1][2], Player.fromHandle(other))
    local event = seen[1][3]
    eq(event.type, 'enter'); eq(event.frame, box); eq(event.text, 'hello'); eq(event.value, 2.5)
    -- One event table per firing: every callback of the firing gets the same one, and the next firing a new one.
    eq(seen[2][3], event)
    fire(box.handle, 'mouse')
    eq(#seen, 2)
    fire(box.handle, 'enter', 'again', 1)
    eq(#seen, 4); eq(seen[3][3] ~= event, true); eq(seen[3][3].text, 'again'); eq(event.text, 'hello')
    box:destroy()
end)

test('a failing callback is printed and the next one still runs', function()
    local button = Frame.createByType('BUTTON', Frame.origin(ORIGIN_FRAME_GAME_UI))
    local count = 0
    button:on('click', function() error('intentional frame probe') end)
    button:on('click', function() count = count + 1 end)
    fire(button.handle, 'click'); fire(button.handle, 'click')
    eq(count, 2); eq(#PRINTED, 2)
    assert(PRINTED[1]:find('[wrappers] Frame event callback failed:', 1, true), PRINTED[1])
    assert(PRINTED[1]:find('intentional frame probe', 1, true), PRINTED[1])
    button:destroy()
end)

test('a cancel function removes its callback at once; callbacks added during a firing wait for the next', function()
    local ui = Frame.origin(ORIGIN_FRAME_GAME_UI)
    local button = Frame.createByType('BUTTON', ui)
    local log = {}
    local second, added
    button:on('click', function() log[#log + 1] = 'first'; second() end)
    second = button:on('click', function() log[#log + 1] = 'second' end)
    button:on('click', function()
        log[#log + 1] = 'third'
        if not added then added = button:on('click', function() log[#log + 1] = 'late' end) end
    end)
    fire(button.handle, 'click')
    eq(table.concat(log, ','), 'first,third')
    log = {}
    fire(button.handle, 'click')
    eq(table.concat(log, ','), 'first,third,late')
    second()
    eq(select('#', added()), 0)
    log = {}
    fire(button.handle, 'click')
    eq(table.concat(log, ','), 'first,third')
    eq(Frame.off, nil)
    button:destroy()
end)

test('a registration returns one cancel function; an emptied event type costs one native per firing', function()
    local ui = Frame.origin(ORIGIN_FRAME_GAME_UI)
    local button, count = Frame.createByType('BUTTON', ui), 0
    local results = table.pack(button:on('click', function() count = count + 1 end))
    eq(results.n, 1); eq(type(results[1]), 'function')
    local entered = button:on('enter', function() count = count + 10 end)
    results[1](); results[1]()
    resetCalls()
    fire(button.handle, 'click')
    eq(count, 0); eq(totalCalls(), 1); eq(callName(1), 'BlzGetTriggerFrameEvent')
    fire(button.handle, 'enter')
    eq(count, 10)
    -- The event type stays registered with the game: a new callback for it registers nothing.
    resetCalls()
    local again = button:on('click', function() count = count + 100 end)
    eq(totalCalls(), 0)
    results[1]()
    fire(button.handle, 'click')
    eq(count, 110)
    -- After the frame is destroyed a cancel function does nothing and calls no native.
    button:destroy()
    resetCalls()
    again(); entered(); results[1]()
    eq(totalCalls(), 0)
end)

test('a part first reached as borrowed loses its callbacks and its trigger with its owner', function()
    local ui = Frame.origin(ORIGIN_FRAME_GAME_UI)
    local panel = Frame.createByType('BACKDROP', ui)
    local partRaw = {parent = panel.handle}
    native('BlzFrameGetChild', function(_, index) if index == 0 then return partRaw end end)
    local part, count = Frame.fromHandle(partRaw), 0
    local cancel = part:on('click', function() count = count + 1 end)
    fire(partRaw, 'click'); eq(count, 1)
    eq(panel:getChild(0), part)
    fire(partRaw, 'click'); eq(count, 2)
    resetCalls()
    panel:destroy()
    eq(part:isDisposed(), true); eq(callCount('DestroyTrigger'), 1); eq(callCount('BlzDestroyFrame'), 1)
    fire(partRaw, 'click', nil, nil, nil, true); eq(count, 2)
    cancel()
    eq(callCount('DestroyTrigger'), 1)
end)

test('destroy clears the callbacks and triggers of the whole subtree', function()
    local ui = Frame.origin(ORIGIN_FRAME_GAME_UI)
    local panel = Frame.createByType('BACKDROP', ui)
    local button = Frame.createByType('BUTTON', panel)
    local count = 0
    panel:on('enter', function() count = count + 1 end)
    button:on('click', function() count = count + 1 end)
    local panelRaw, buttonRaw = panel.handle, button.handle
    resetCalls()
    panel:destroy()
    eq(callCount('DestroyTrigger'), 2); eq(callCount('BlzDestroyFrame'), 1)
    fire(panelRaw, 'enter', nil, nil, nil, true); fire(buttonRaw, 'click', nil, nil, nil, true)
    eq(count, 0)
end)

test('a callback may destroy its own frame or an ancestor', function()
    local ui = Frame.origin(ORIGIN_FRAME_GAME_UI)
    local panel = Frame.createByType('BACKDROP', ui)
    local close = Frame.createByType('BUTTON', panel)
    local after = {}
    close:on('click', function() panel:destroy(); after[#after + 1] = 'closed' end)
    close:on('click', function() after[#after + 1] = 'ERROR later callback ran' end)
    fire(close.handle, 'click')
    eq(table.concat(after, ','), 'closed'); eq(panel:isDisposed(), true); eq(close:isDisposed(), true)
    local solo = Frame.createByType('BUTTON', ui)
    solo:on('click', function() solo:destroy() end)
    fire(solo.handle, 'click'); eq(solo:isDisposed(), true)
    eq(#PRINTED, 0)
end)

test('on checks the frame, event type and callback before any native', function()
    local ui = Frame.origin(ORIGIN_FRAME_GAME_UI)
    local button = Frame.createByType('BUTTON', ui)
    resetCalls()
    failsAt(function() button:on('click', nil) end, 'Frame.on: expected a callback function')
    failsAt(function() button:on(nil, function() end) end, 'Frame.on: expected a frame event type')
    eq(totalCalls(), 0)
    button:destroy()
    failsAt(function() button:on('click', function() end) end, 'Frame.on: Frame is disposed')
    ui:on('click', function() end)
    eq(callCount('CreateTrigger'), 1)
end)
