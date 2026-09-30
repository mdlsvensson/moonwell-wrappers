local Callback = require('wrappers.internal.callback')
local Listeners = require('wrappers.internal.listeners')
local PlayerWrapper = require('wrappers.player')

---Synced messages between players. Send from the local player only (inside a local-player branch); listeners run on
---every machine, in the same order, some frames after the send. Each prefix has one shared trigger, created by its
---first listener. Nothing is created at import.
local Sync = {}

---@class MoonwellWrappers.SyncListener

---The game cuts longer messages to 255 bytes and still reports success (measured on 3.0.0.24268).
local LIMIT = 255

---@param prefix unknown
---@param operation string
local function checkPrefix(prefix, operation)
    if type(prefix) ~= 'string' or prefix == '' then
        error('[wrappers] ' .. operation .. ': expected a non-empty prefix string', 3)
    end
end

---@param trigger trigger
---@param prefix string
local function register(trigger, prefix)
    for index = 0, bj_MAX_PLAYERS - 1 do BlzTriggerRegisterPlayerSyncEvent(trigger, Player(index), prefix, false) end
end

---@param _ string
---@param cells MoonwellWrappers.ListenerCell[]
local function route(_, cells)
    Listeners.call(cells, 'Sync listener', PlayerWrapper.fromHandle(GetTriggerPlayer()), BlzGetTriggerSyncData())
end

local listeners = Listeners.new('SyncListener', register, route)

---Sends `data` to every player under `prefix`. Call it for the local player only.
---@param prefix string
---@param data string At most 255 bytes.
---@return boolean sent What BlzSendSyncData returned.
function Sync.send(prefix, data)
    checkPrefix(prefix, 'Sync.send')
    if type(data) ~= 'string' then error('[wrappers] Sync.send: expected a string', 2) end
    if #data > LIMIT then
        error('[wrappers] Sync.send: data is ' .. #data .. ' bytes, over the ' .. LIMIT .. '-byte limit', 2)
    end
    return BlzSendSyncData(prefix, data)
end

---Runs `callback` with the sending Player and the data for every message under `prefix`, behind the callback boundary.
---@param prefix string
---@param callback fun(player: MoonwellWrappers.Player, data: string): ...
---@return MoonwellWrappers.SyncListener
function Sync.on(prefix, callback)
    checkPrefix(prefix, 'Sync.on')
    Callback.check(callback, 'Sync.on')
    return (Listeners.add(listeners, prefix, callback, 'Sync.on'))
end

---Removes a listener at once, even during a firing. Removing it twice does nothing.
---@param token MoonwellWrappers.SyncListener
function Sync.off(token)
    Listeners.remove(listeners, token, 'Sync.off')
end

return Sync
