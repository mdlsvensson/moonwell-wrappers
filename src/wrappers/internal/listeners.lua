local Handle = require('wrappers.internal.handle')
local Cells = require('wrappers.internal.cells')

---One shared trigger per key, under wrappers.damage (a phase), wrappers.sync (a prefix) and wrappers.input (a player
---and a key, or a player and a kind of mouse event). A key's trigger is created by its first listener, disabled while
---the key has no listeners and enabled again by the next one; it is never destroyed, so a listener that cancels itself
---never destroys the trigger running it.
local Listeners = {}

---@class MoonwellWrappers.ListenerSet
---@field register fun(trigger: trigger, key: any) Registers a new key's trigger for its events.
---@field route fun(key: any, list: MoonwellWrappers.Cells) The trigger's action.
---@field emptied (fun(key: any))? Runs after the key's last listener is cancelled. It must not raise, and it may run
---during a firing.
---@field lists table<any, MoonwellWrappers.Cells> The listeners of each key; only indexed, never iterated.
---@field triggers table<any, trigger> The internal trigger of each key; only indexed, never iterated.

---@param register fun(trigger: trigger, key: any)
---@param route fun(key: any, list: MoonwellWrappers.Cells)
---@param emptied (fun(key: any))?
---@return MoonwellWrappers.ListenerSet
function Listeners.new(register, route, emptied)
    return {register = register, route = route, emptied = emptied, lists = {}, triggers = {}}
end

---Adds a listener for `key` and returns the function that cancels it. The public function must call this as
---`return (Listeners.add(...))`: a failed CreateTrigger raises at the public function's caller.
---@param set MoonwellWrappers.ListenerSet
---@param key any
---@param callback function
---@param operation string
---@return MoonwellWrappers.Cancel
function Listeners.add(set, key, callback, operation)
    local list = set.lists[key]
    if not list then
        local trigger = Handle.created(CreateTrigger(), operation, 1)
        local created = Cells.new()
        created.cancelled = function()
            if Cells.count(created) > 0 then return end
            DisableTrigger(trigger)
            local emptied = set.emptied
            if emptied then emptied(key) end
        end
        set.register(trigger, key)
        TriggerAddAction(trigger, function() set.route(key, created) end)
        set.triggers[key] = trigger
        set.lists[key] = created
        list = created
    elseif Cells.count(list) == 0 then
        EnableTrigger(set.triggers[key])
    end
    local _, cancel = Cells.add(list, callback)
    return cancel
end

---Runs the live listeners of one firing behind the callback boundary: Cells.call. Listeners added during the firing
---wait for the next one; cancelled ones are skipped at once.
Listeners.call = Cells.call

return Listeners
