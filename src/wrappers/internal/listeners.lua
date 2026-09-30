local Handle = require('wrappers.internal.handle')
local Callback = require('wrappers.internal.callback')

---Listener lists shared by wrappers.damage and wrappers.sync. Each key (a damage phase, a sync prefix) has at most one
---trigger, created by its first listener. The trigger is disabled while the key has no listeners and enabled again by
---the next one; it is never destroyed, so a listener that removes itself never destroys the trigger running it.
local Listeners = {}

---@class MoonwellWrappers.ListenerCell
---@field key any
---@field callback function? Nil once removed.

---@class MoonwellWrappers.ListenerSet
---@field kind string The token's class name, for errors.
---@field register fun(trigger: trigger, key: any) Registers a new key's trigger for its events.
---@field route fun(key: any, cells: MoonwellWrappers.ListenerCell[]) The trigger's action.
---@field lists table<any, MoonwellWrappers.ListenerCell[]> Live listeners per key, in the order added.
---@field triggers table<any, trigger>
---@field cells table<table, MoonwellWrappers.ListenerCell> Token to cell.

---@param list MoonwellWrappers.ListenerCell[]
---@param cell MoonwellWrappers.ListenerCell
---@return MoonwellWrappers.ListenerCell[]
local function without(list, cell)
    local result = {}
    for _, value in ipairs(list) do
        if value ~= cell then result[#result + 1] = value end
    end
    return result
end

---@param kind string
---@param register fun(trigger: trigger, key: any)
---@param route fun(key: any, cells: MoonwellWrappers.ListenerCell[])
---@return MoonwellWrappers.ListenerSet
function Listeners.new(kind, register, route)
    return {kind = kind, register = register, route = route, lists = {}, triggers = {},
        cells = setmetatable({}, {__mode = 'k'})}
end

---Adds a listener for `key` and returns its token. The public function must call this as `return (Listeners.add(...))`:
---a failed CreateTrigger raises at the public function's caller.
---@param set MoonwellWrappers.ListenerSet
---@param key any
---@param callback function
---@param operation string
---@return table
function Listeners.add(set, key, callback, operation)
    local trigger, list = set.triggers[key], set.lists[key]
    if not trigger then
        trigger = Handle.created(CreateTrigger(), operation, 1)
        set.register(trigger, key)
        TriggerAddAction(trigger, function() set.route(key, set.lists[key]) end)
        set.triggers[key] = trigger
        list = {}
        set.lists[key] = list
    elseif #list == 0 then
        EnableTrigger(trigger)
    end
    ---@type MoonwellWrappers.ListenerCell
    local cell = {key = key, callback = callback}
    list[#list + 1] = cell
    local token = {}
    set.cells[token] = cell
    return token
end

---Removes a listener at once, even during a firing. Removing it twice does nothing. Call it as a statement from the
---public function: a wrong token raises at that function's caller.
---@param set MoonwellWrappers.ListenerSet
---@param token table
---@param operation string
function Listeners.remove(set, token, operation)
    local cell = token ~= nil and set.cells[token] or nil
    if not cell then error('[wrappers] ' .. operation .. ': expected ' .. set.kind .. ' token', 3) end
    if not cell.callback then return end
    cell.callback = nil
    local list = without(set.lists[cell.key], cell)
    set.lists[cell.key] = list
    if #list == 0 then DisableTrigger(set.triggers[cell.key]) end
end

---Runs the live listeners of one firing behind the callback boundary. Listeners added during the firing wait for the
---next one (the loop bound is read once); removed ones are skipped at once.
---@param cells MoonwellWrappers.ListenerCell[]
---@param label string
---@param ... any Passed to every listener.
function Listeners.call(cells, label, ...)
    for index = 1, #cells do
        local callback = cells[index].callback
        if callback then Callback.call(label, callback, ...) end
    end
end

return Listeners
