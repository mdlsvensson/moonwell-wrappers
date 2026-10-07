local Callback = require('wrappers.internal.callback')
local Check = require('wrappers.internal.check')
local Listeners = require('wrappers.internal.listeners')
local PlayerWrapper = require('wrappers.player')

---Synced messages between players. Send from the local player only (inside a local-player branch); listeners run on
---every machine, in the same order, some frames after the send. Each prefix has one shared trigger, created by its
---first listener and never destroyed. Nothing is created at import.
---@class MoonwellWrappers.Sync
local Sync = {}

---The game cuts longer messages to 255 bytes and still reports success (measured on 3.0.0.24268).
local LIMIT = 255

---@param trigger trigger
---@param prefix string
local function register(trigger, prefix)
    for index = 0, bj_MAX_PLAYERS - 1 do BlzTriggerRegisterPlayerSyncEvent(trigger, Player(index), prefix, false) end
end

---@param _ string
---@param list MoonwellWrappers.Cells
local function route(_, list)
    Listeners.call(list, 'Sync listener', PlayerWrapper.fromHandle(GetTriggerPlayer()), BlzGetTriggerSyncData())
end

local listeners = Listeners.new(register, route)

---Sends `data` to every player under `prefix`. Call it for the local player only.
---@param prefix string Not empty.
---@param data string At most 255 bytes.
---@return boolean sent What BlzSendSyncData returned.
function Sync.send(prefix, data)
    if Check.requireText(prefix, 'a non-empty prefix string', 'Sync.send') == '' then
        error('[wrappers] Sync.send: expected a non-empty prefix string', 2)
    end
    Check.requireText(data, 'a data string', 'Sync.send')
    if #data > LIMIT then
        error('[wrappers] Sync.send: data is ' .. #data .. ' bytes, over the ' .. LIMIT .. '-byte limit', 2)
    end
    return BlzSendSyncData(prefix, data)
end

---Runs `callback` with the sending Player and the data for every message under `prefix`, behind the callback boundary,
---until the returned function is called. Cancelling takes effect at once, even during a firing; cancelling twice does
---nothing.
---@param prefix string Not empty.
---@param callback fun(player: MoonwellWrappers.Player, data: string): ...
---@return MoonwellWrappers.Cancel
function Sync.on(prefix, callback)
    if Check.requireText(prefix, 'a non-empty prefix string', 'Sync.on') == '' then
        error('[wrappers] Sync.on: expected a non-empty prefix string', 2)
    end
    Callback.check(callback, 'Sync.on')
    return (Listeners.add(listeners, prefix, callback, 'Sync.on'))
end

return Sync
