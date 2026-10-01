local Handle = require('wrappers.internal.handle')
local Callback = require('wrappers.internal.callback')
local Listeners = require('wrappers.internal.listeners')
local Options = require('wrappers.internal.options')
local PlayerWrapper = require('wrappers.player')

---Keyboard and mouse input of one player. The events are synced: listeners run on every machine, in the same order,
---some frames after the input, so they may change game state. Each player and key, and each player and kind of mouse
---event, has one shared trigger, created by its first listener. Nothing is created at import.
local Input = {}

---@class MoonwellWrappers.InputListener

---@class MoonwellWrappers.InputSource
---@field player player
---@field key oskeytype? Set for a key's trigger.
---@field event playerevent? Set for a mouse trigger.
---@field button boolean? True when the mouse event carries a button.

---What each listener key's trigger registers for; filled before the key's first listener is added.
---@type table<string, MoonwellWrappers.InputSource>
local sources = {}
---The keys that are down, by listener key: a down while one is set is a repeat. Changed only inside the synced
---events and when a key's last listener is removed, so it is the same on every machine.
---@type table<string, boolean>
local held = {}
local KEY_DOWN_OPTIONS = {repeats = {'boolean', false}}

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
---@param cells MoonwellWrappers.ListenerCell[]
local function route(id, cells)
    local source = sources[id]
    local player = PlayerWrapper.fromHandle(GetTriggerPlayer())
    if source.key then
        local down, repeated = BlzGetTriggerPlayerIsKeyDown(), false
        if down then
            repeated = held[id] == true
            held[id] = true
        else
            held[id] = nil
        end
        Listeners.call(cells, 'Input listener', down, player, BlzGetTriggerPlayerMetaKey(), repeated)
    elseif source.button then
        Listeners.call(cells, 'Input listener', player, BlzGetTriggerPlayerMouseX(), BlzGetTriggerPlayerMouseY(),
            BlzGetTriggerPlayerMouseButton())
    else
        Listeners.call(cells, 'Input listener', player, BlzGetTriggerPlayerMouseX(), BlzGetTriggerPlayerMouseY())
    end
end

local listeners = Listeners.new('InputListener', register, route)

---@param player player
---@param key oskeytype
---@return string id The listener key of this player and key.
local function keySource(player, key)
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
---while the key stays held are skipped, unless the option `repeats` is true; `repeated` is true for those.
---@param player MoonwellWrappers.Player
---@param key oskeytype
---@param callback fun(player: MoonwellWrappers.Player, meta: integer, repeated: boolean): ...
---@param options? {repeats: boolean?}
---@return MoonwellWrappers.InputListener
function Input.onKeyDown(player, key, callback, options)
    local rawPlayer = Handle.unwrap(player, 'Player', 'Input.onKeyDown')
    if key == nil then error('[wrappers] Input.onKeyDown: expected a key, such as OSKEY_Q', 2) end
    Callback.check(callback, 'Input.onKeyDown')
    local repeats = Options.read(options, KEY_DOWN_OPTIONS, 'Input.onKeyDown').repeats
    return (Listeners.add(listeners, keySource(rawPlayer, key), function(down, who, meta, repeated)
        if down and (repeats or not repeated) then callback(who, meta, repeated) end
    end, 'Input.onKeyDown'))
end

---Runs `callback` when `player` lets go of `key`, with the modifier keys held at that moment.
---@param player MoonwellWrappers.Player
---@param key oskeytype
---@param callback fun(player: MoonwellWrappers.Player, meta: integer): ...
---@return MoonwellWrappers.InputListener
function Input.onKeyUp(player, key, callback)
    local rawPlayer = Handle.unwrap(player, 'Player', 'Input.onKeyUp')
    if key == nil then error('[wrappers] Input.onKeyUp: expected a key, such as OSKEY_Q', 2) end
    Callback.check(callback, 'Input.onKeyUp')
    return (Listeners.add(listeners, keySource(rawPlayer, key), function(down, who, meta)
        if not down then callback(who, meta) end
    end, 'Input.onKeyUp'))
end

---Runs `callback` when `player` presses a mouse button, with the world point under the cursor.
---@param player MoonwellWrappers.Player
---@param callback fun(player: MoonwellWrappers.Player, x: number, y: number, button: mousebuttontype): ...
---@return MoonwellWrappers.InputListener
function Input.onMouseDown(player, callback)
    local rawPlayer = Handle.unwrap(player, 'Player', 'Input.onMouseDown')
    Callback.check(callback, 'Input.onMouseDown')
    local id = mouseSource('d', rawPlayer, EVENT_PLAYER_MOUSE_DOWN, true)
    return (Listeners.add(listeners, id, callback, 'Input.onMouseDown'))
end

---Runs `callback` when `player` lets go of a mouse button, with the world point under the cursor.
---@param player MoonwellWrappers.Player
---@param callback fun(player: MoonwellWrappers.Player, x: number, y: number, button: mousebuttontype): ...
---@return MoonwellWrappers.InputListener
function Input.onMouseUp(player, callback)
    local rawPlayer = Handle.unwrap(player, 'Player', 'Input.onMouseUp')
    Callback.check(callback, 'Input.onMouseUp')
    local id = mouseSource('u', rawPlayer, EVENT_PLAYER_MOUSE_UP, true)
    return (Listeners.add(listeners, id, callback, 'Input.onMouseUp'))
end

---Runs `callback` with the world point under the cursor of `player` whenever the mouse moves: 150 to 190 synced
---events a second while it does (measured on 3.0.0.24268). Remove the listener when it is not needed.
---@param player MoonwellWrappers.Player
---@param callback fun(player: MoonwellWrappers.Player, x: number, y: number): ...
---@return MoonwellWrappers.InputListener
function Input.onMouseMove(player, callback)
    local rawPlayer = Handle.unwrap(player, 'Player', 'Input.onMouseMove')
    Callback.check(callback, 'Input.onMouseMove')
    local id = mouseSource('m', rawPlayer, EVENT_PLAYER_MOUSE_MOVE, false)
    return (Listeners.add(listeners, id, callback, 'Input.onMouseMove'))
end

---Removes a listener at once, even during a firing. Removing it twice does nothing.
---@param token MoonwellWrappers.InputListener
function Input.off(token)
    Listeners.remove(listeners, token, 'Input.off')
    local id = listeners.cells[token].key
    -- A release that arrives while the key's trigger is disabled is never seen, so the state starts over.
    if #listeners.lists[id] == 0 then held[id] = nil end
end

return Input
