local Handle = require('wrappers.internal.handle')
local Callback = require('wrappers.internal.callback')
local Listeners = require('wrappers.internal.listeners')
local Options = require('wrappers.internal.options')
local PlayerWrapper = require('wrappers.player')

---Keyboard and mouse input of one player. The events are synced: listeners run on every machine, in the same order,
---some frames after the input, so they may change game state. Each player and key, and each player and kind of mouse
---event, has one shared trigger, created by its first listener. Nothing is created at import.
local Input = {}

---@class MoonwellWrappers.InputSource
---@field player player
---@field key oskeytype? Set for a key's trigger.
---@field event playerevent? Set for a mouse trigger.
---@field button boolean? True when the mouse event carries a button.

---What each listener key's trigger registers for; filled before the key's first listener is added.
---@type table<string, MoonwellWrappers.InputSource>
local sources = {}
---The keys that are down, by listener key, each with the game time of its last down: a down while one is set, and
---within REPEAT_WINDOW of that time, is a repeat. Changed only inside the synced events and when a key's last listener
---is cancelled, and game time is the same on every machine, so it is the same on every machine.
---@type table<string, number>
local held = {}
---The game drops a key's release when the key is let go while the game takes no keyboard input: another program in
---front, the chat or the menu open (measured on 3.0.0.24268). The next press then arrives with no release before it.
---A repeat follows the previous down by the keyboard's repeat delay at most (0.5 seconds measured; Windows allows up
---to 1 second and macOS up to 1.8), so a down later than this many seconds after the last one is a new press.
local REPEAT_WINDOW = 2
---Game time for that rule: one timer on one long run, started with the first key listener and never destroyed. It
---is set before any key's trigger exists, so the code that reads it needs no check.
---@type timer
local clock

---@class MoonwellWrappers.InputKeyDownOptions
---@field repeats boolean? Also run for the downs the game repeats while the key stays held; default false.

---@type MoonwellWrappers.OptionFields
local keyDownFields = {repeats = {'boolean', false}}

---@param trigger trigger
---@param id string
local function register(trigger, id)
    local source = sources[id]
    local key = source.key
    if key then
        -- The game matches the modifier keys exactly (measured on 3.0.0.24268): a registration for no modifier does
        -- not fire while Shift is held. So every one of the 16 combinations is registered, for down and for up.
        for meta = 0, 15 do
            BlzTriggerRegisterPlayerKeyEvent(trigger, source.player, key, meta, true)
            BlzTriggerRegisterPlayerKeyEvent(trigger, source.player, key, meta, false)
        end
    else
        TriggerRegisterPlayerEvent(trigger, source.player, source.event)
    end
end

---@param id string
---@param list MoonwellWrappers.Cells
local function route(id, list)
    local source = sources[id]
    local player = PlayerWrapper.fromHandle(GetTriggerPlayer())
    if source.key then
        local down, repeated = BlzGetTriggerPlayerIsKeyDown(), false
        if down then
            local at, last = TimerGetElapsed(clock), held[id]
            repeated = last ~= nil and at - last <= REPEAT_WINDOW
            held[id] = at
        else
            held[id] = nil
        end
        Listeners.call(list, 'Input listener', down, player, BlzGetTriggerPlayerMetaKey(), repeated)
    elseif source.button then
        Listeners.call(list, 'Input listener', player, BlzGetTriggerPlayerMouseX(), BlzGetTriggerPlayerMouseY(),
            BlzGetTriggerPlayerMouseButton())
    else
        Listeners.call(list, 'Input listener', player, BlzGetTriggerPlayerMouseX(), BlzGetTriggerPlayerMouseY())
    end
end

---A release that arrives while a key's trigger is disabled is never seen, so the key's state starts over when its
---last listener is cancelled. The key of a mouse listener has no entry, so for it this does nothing.
---@param id string
local function forget(id) held[id] = nil end

local listeners = Listeners.new(register, route, forget)

---@param player player
---@param key oskeytype
---@param operation string
---@return string id The listener key of this player and key.
local function keySource(player, key, operation)
    if not clock then
        clock = Handle.created(CreateTimer(), operation, 1)
        TimerStart(clock, 1000000, false, function() end)
    end
    -- Only a table key: a key constant's handle id is the same on every machine, and nothing else reads it.
    local id = 'k' .. GetPlayerId(player) .. ':' .. GetHandleId(key)
    if not sources[id] then sources[id] = {player = player, key = key} end
    return id
end

---@param kind string
---@param player player
---@param event playerevent
---@param button boolean
---@return string id The listener key of this player and kind of mouse event.
local function mouseSource(kind, player, event, button)
    local id = kind .. GetPlayerId(player)
    if not sources[id] then sources[id] = {player = player, event = event, button = button} end
    return id
end

---Runs `callback` when `player` presses `key`, whatever modifier keys are held; `meta` is the sum of the held
---METAKEY_SHIFT, METAKEY_CTRL, METAKEY_ALT and METAKEY_WINKEYS. It runs once per press: the downs the game repeats
---while the key stays held are skipped, unless the option `repeats` is true; `repeated` is true for those. The returned
---function cancels the listener, at once even during a firing; calling it twice does nothing.
---@param player MoonwellWrappers.Player
---@param key oskeytype
---@param callback fun(player: MoonwellWrappers.Player, meta: integer, repeated: boolean): ...
---@param options MoonwellWrappers.InputKeyDownOptions?
---@return MoonwellWrappers.Cancel
function Input.onKeyDown(player, key, callback, options)
    local rawPlayer = Handle.unwrap(player, 'Player', 'Input.onKeyDown')
    if key == nil then error('[wrappers] Input.onKeyDown: expected a key, such as OSKEY_Q', 2) end
    Callback.check(callback, 'Input.onKeyDown')
    local repeats = Options.read(options, keyDownFields, 'Input.onKeyDown').repeats
    return (Listeners.add(listeners, keySource(rawPlayer, key, 'Input.onKeyDown'), function(down, who, meta, repeated)
        if down and (repeats or not repeated) then callback(who, meta, repeated) end
    end, 'Input.onKeyDown'))
end

---Runs `callback` when `player` lets go of `key`, with the modifier keys held at that moment, until the returned
---function is called.
---@param player MoonwellWrappers.Player
---@param key oskeytype
---@param callback fun(player: MoonwellWrappers.Player, meta: integer): ...
---@return MoonwellWrappers.Cancel
function Input.onKeyUp(player, key, callback)
    local rawPlayer = Handle.unwrap(player, 'Player', 'Input.onKeyUp')
    if key == nil then error('[wrappers] Input.onKeyUp: expected a key, such as OSKEY_Q', 2) end
    Callback.check(callback, 'Input.onKeyUp')
    return (Listeners.add(listeners, keySource(rawPlayer, key, 'Input.onKeyUp'), function(down, who, meta)
        if not down then callback(who, meta) end
    end, 'Input.onKeyUp'))
end

---Runs `callback` when `player` presses a mouse button, with the world point under the cursor, until the returned
---function is called.
---@param player MoonwellWrappers.Player
---@param callback fun(player: MoonwellWrappers.Player, x: number, y: number, button: mousebuttontype): ...
---@return MoonwellWrappers.Cancel
function Input.onMouseDown(player, callback)
    local rawPlayer = Handle.unwrap(player, 'Player', 'Input.onMouseDown')
    Callback.check(callback, 'Input.onMouseDown')
    local id = mouseSource('d', rawPlayer, EVENT_PLAYER_MOUSE_DOWN, true)
    return (Listeners.add(listeners, id, callback, 'Input.onMouseDown'))
end

---Runs `callback` when `player` lets go of a mouse button, with the world point under the cursor, until the returned
---function is called.
---@param player MoonwellWrappers.Player
---@param callback fun(player: MoonwellWrappers.Player, x: number, y: number, button: mousebuttontype): ...
---@return MoonwellWrappers.Cancel
function Input.onMouseUp(player, callback)
    local rawPlayer = Handle.unwrap(player, 'Player', 'Input.onMouseUp')
    Callback.check(callback, 'Input.onMouseUp')
    local id = mouseSource('u', rawPlayer, EVENT_PLAYER_MOUSE_UP, true)
    return (Listeners.add(listeners, id, callback, 'Input.onMouseUp'))
end

---Runs `callback` with the world point under the cursor of `player` whenever the mouse moves: 150 to 190 synced
---events a second while it does (measured on 3.0.0.24268). Call the returned function when the listener is not needed.
---@param player MoonwellWrappers.Player
---@param callback fun(player: MoonwellWrappers.Player, x: number, y: number): ...
---@return MoonwellWrappers.Cancel
function Input.onMouseMove(player, callback)
    local rawPlayer = Handle.unwrap(player, 'Player', 'Input.onMouseMove')
    Callback.check(callback, 'Input.onMouseMove')
    local id = mouseSource('m', rawPlayer, EVENT_PLAYER_MOUSE_MOVE, false)
    return (Listeners.add(listeners, id, callback, 'Input.onMouseMove'))
end

return Input
