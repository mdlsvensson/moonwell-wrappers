local Handle = require('wrappers.internal.handle')
local Callback = require('wrappers.internal.callback')

---Opaque token returned by Trigger:addAction; pass it to Trigger:removeAction.
---@class MoonwellWrappers.TriggerAction

---Opaque token returned by Trigger:addCondition; pass it to Trigger:removeCondition.
---@class MoonwellWrappers.TriggerCondition

---@class MoonwellWrappers.Trigger
---@field handle trigger? Read-only by convention; nil after destruction.
local Trigger = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Trigger, trigger>
local registry = Handle.new(Trigger, 'Trigger')

---@class MoonwellWrappers.TriggerCell
---@field trigger MoonwellWrappers.Trigger
---@field kind 'TriggerAction'|'TriggerCondition'
---@field native? any
---@field callback (fun(trigger: MoonwellWrappers.Trigger): ...)?
---@field predicate (fun(trigger: MoonwellWrappers.Trigger): any)?
---@field boolexpr conditionfunc?

-- Arrays, not sets: clearing calls natives in order, and pairs order over table keys differs between clients.
---@type table<MoonwellWrappers.Trigger, {actions: MoonwellWrappers.TriggerCell[], conditions: MoonwellWrappers.TriggerCell[]}>
local states = {}
---@type table<table, MoonwellWrappers.TriggerCell>
local cells = setmetatable({}, {__mode = 'k'})

---@param trigger MoonwellWrappers.Trigger
local function stateOf(trigger)
    local state = states[trigger]
    if not state then
        state = {actions = {}, conditions = {}}
        states[trigger] = state
    end
    return state
end

---@param list MoonwellWrappers.TriggerCell[]
---@param cell MoonwellWrappers.TriggerCell
---@return MoonwellWrappers.TriggerCell[]
local function without(list, cell)
    local result = {}
    for _, item in ipairs(list) do
        if item ~= cell then result[#result + 1] = item end
    end
    return result
end

---@param trigger MoonwellWrappers.Trigger
---@param token unknown
---@param kind string
---@param operation string
---@return MoonwellWrappers.TriggerCell
local function ownedCell(trigger, token, kind, operation)
    local cell = cells[token]
    if not cell or cell.kind ~= kind then error('[wrappers] ' .. operation .. ': expected ' .. kind .. ' token', 3) end
    if cell.trigger ~= trigger then error('[wrappers] ' .. operation .. ': token belongs to another trigger', 3) end
    return cell
end

---Makes every condition closure a no-op and returns the boolexprs to destroy, in insertion order.
---@param state {conditions: MoonwellWrappers.TriggerCell[]}
---@return conditionfunc[]
local function releaseConditions(state)
    local boolexprs = {}
    for _, cell in ipairs(state.conditions) do
        cell.predicate = nil
        boolexprs[#boolexprs + 1] = cell.boolexpr
    end
    state.conditions = {}
    return boolexprs
end

---@param raw trigger?
---@return MoonwellWrappers.Trigger?
---@overload fun(raw: nil): nil
function Trigger.fromHandle(raw) return registry.wrap(raw) end
---@return MoonwellWrappers.Trigger
function Trigger.create() return (Handle.created(Trigger.fromHandle(CreateTrigger()), 'Trigger.create')) end
---@return trigger
function Trigger:getHandle() return (registry.require(self, 'Trigger.getHandle')) end
---@return boolean
function Trigger:isDisposed() return (registry.isDisposed(self, 'Trigger.isDisposed')) end
function Trigger:enable() EnableTrigger(registry.require(self, 'Trigger.enable')) end
function Trigger:disable() DisableTrigger(registry.require(self, 'Trigger.disable')) end
---@return boolean
function Trigger:isEnabled() return IsTriggerEnabled(registry.require(self, 'Trigger.isEnabled')) end
---@return boolean
function Trigger:evaluate() return TriggerEvaluate(registry.require(self, 'Trigger.evaluate')) end
function Trigger:execute() TriggerExecute(registry.require(self, 'Trigger.execute')) end

---@param unit MoonwellWrappers.Unit
---@param event unitevent
function Trigger:registerUnitEvent(unit, event)
    local raw = registry.require(self, 'Trigger.registerUnitEvent')
    TriggerRegisterUnitEvent(raw, Handle.unwrap(unit, 'Unit', 'Trigger.registerUnitEvent'), event)
end
---@param player MoonwellWrappers.Player
---@param event playerunitevent
function Trigger:registerPlayerUnitEvent(player, event)
    local raw = registry.require(self, 'Trigger.registerPlayerUnitEvent')
    local rawPlayer = Handle.unwrap(player, 'Player', 'Trigger.registerPlayerUnitEvent')
    -- Warcraft accepts a null filter; the generated JASS signature cannot express that.
    ---@diagnostic disable-next-line: param-type-mismatch
    TriggerRegisterPlayerUnitEvent(raw, rawPlayer, event, nil)
end
---Registers the event for every player slot, like TriggerRegisterAnyUnitEventBJ.
---@param event playerunitevent
function Trigger:registerAnyUnitEvent(event)
    local raw = registry.require(self, 'Trigger.registerAnyUnitEvent')
    for index = 0, bj_MAX_PLAYER_SLOTS - 1 do
        -- Warcraft accepts a null filter; the generated JASS signature cannot express that.
        ---@diagnostic disable-next-line: param-type-mismatch
        TriggerRegisterPlayerUnitEvent(raw, Player(index), event, nil)
    end
end
---@param player MoonwellWrappers.Player
---@param event playerevent
function Trigger:registerPlayerEvent(player, event)
    local raw = registry.require(self, 'Trigger.registerPlayerEvent')
    TriggerRegisterPlayerEvent(raw, Handle.unwrap(player, 'Player', 'Trigger.registerPlayerEvent'), event)
end
---@param player MoonwellWrappers.Player
---@param text string
---@param exactMatch boolean
function Trigger:registerChatEvent(player, text, exactMatch)
    local raw = registry.require(self, 'Trigger.registerChatEvent')
    local rawPlayer = Handle.unwrap(player, 'Player', 'Trigger.registerChatEvent')
    TriggerRegisterPlayerChatEvent(raw, rawPlayer, text, exactMatch)
end
---@param region MoonwellWrappers.Region
function Trigger:registerEnterRegion(region)
    local raw = registry.require(self, 'Trigger.registerEnterRegion')
    local rawRegion = Handle.unwrap(region, 'Region', 'Trigger.registerEnterRegion')
    -- Warcraft accepts a null filter; the generated JASS signature cannot express that.
    ---@diagnostic disable-next-line: param-type-mismatch
    TriggerRegisterEnterRegion(raw, rawRegion, nil)
end
---@param region MoonwellWrappers.Region
function Trigger:registerLeaveRegion(region)
    local raw = registry.require(self, 'Trigger.registerLeaveRegion')
    local rawRegion = Handle.unwrap(region, 'Region', 'Trigger.registerLeaveRegion')
    -- Warcraft accepts a null filter; the generated JASS signature cannot express that.
    ---@diagnostic disable-next-line: param-type-mismatch
    TriggerRegisterLeaveRegion(raw, rawRegion, nil)
end
---@param widget MoonwellWrappers.Widget
function Trigger:registerDeathEvent(widget)
    local raw = registry.require(self, 'Trigger.registerDeathEvent')
    TriggerRegisterDeathEvent(raw, Handle.unwrapWidget(widget, 'Trigger.registerDeathEvent'))
end
---@param unit MoonwellWrappers.Unit
---@param range number
function Trigger:registerUnitInRange(unit, range)
    local raw = registry.require(self, 'Trigger.registerUnitInRange')
    local rawUnit = Handle.unwrap(unit, 'Unit', 'Trigger.registerUnitInRange')
    Callback.nonnegative(range, 'Trigger.registerUnitInRange')
    -- Warcraft accepts a null filter; the generated JASS signature cannot express that.
    ---@diagnostic disable-next-line: param-type-mismatch
    TriggerRegisterUnitInRange(raw, rawUnit, range, nil)
end
---@param unit MoonwellWrappers.Unit
---@param state unitstate
---@param op limitop
---@param value number
function Trigger:registerUnitStateEvent(unit, state, op, value)
    local raw = registry.require(self, 'Trigger.registerUnitStateEvent')
    TriggerRegisterUnitStateEvent(raw, Handle.unwrap(unit, 'Unit', 'Trigger.registerUnitStateEvent'), state, op, value)
end
---@param timeout number
---@param periodic boolean
function Trigger:registerTimerEvent(timeout, periodic)
    local raw = registry.require(self, 'Trigger.registerTimerEvent')
    Callback.nonnegative(timeout, 'Trigger.registerTimerEvent')
    TriggerRegisterTimerEvent(raw, timeout, periodic)
end
---@param event gameevent
function Trigger:registerGameEvent(event)
    TriggerRegisterGameEvent(registry.require(self, 'Trigger.registerGameEvent'), event)
end

---@param callback fun(trigger: MoonwellWrappers.Trigger): ...
---@return MoonwellWrappers.TriggerAction
function Trigger:addAction(callback)
    local raw = registry.require(self, 'Trigger.addAction')
    Callback.check(callback, 'Trigger.addAction')
    ---@type MoonwellWrappers.TriggerCell
    local cell = {trigger = self, kind = 'TriggerAction', callback = callback}
    local state = stateOf(self)
    state.actions[#state.actions + 1] = cell
    cell.native = TriggerAddAction(raw, function()
        local current = cell.callback
        if current then Callback.call('Trigger', current, self) end
    end)
    ---@type MoonwellWrappers.TriggerAction
    local token = {}
    cells[token] = cell
    return token
end
---Removing a token twice, or after clearActions, does nothing.
---@param token MoonwellWrappers.TriggerAction
function Trigger:removeAction(token)
    local raw = registry.require(self, 'Trigger.removeAction')
    local cell = ownedCell(self, token, 'TriggerAction', 'Trigger.removeAction')
    if not cell.callback then return end
    cell.callback = nil
    local state = stateOf(self)
    state.actions = without(state.actions, cell)
    TriggerRemoveAction(raw, cell.native)
end
function Trigger:clearActions()
    local raw = registry.require(self, 'Trigger.clearActions')
    local state = stateOf(self)
    for _, cell in ipairs(state.actions) do cell.callback = nil end
    state.actions = {}
    TriggerClearActions(raw)
end

---The predicate's result counts as truthy or falsy. An error is printed and counts as false.
---@param predicate fun(trigger: MoonwellWrappers.Trigger): any
---@return MoonwellWrappers.TriggerCondition
function Trigger:addCondition(predicate)
    local raw = registry.require(self, 'Trigger.addCondition')
    Callback.check(predicate, 'Trigger.addCondition')
    ---@type MoonwellWrappers.TriggerCell
    local cell = {trigger = self, kind = 'TriggerCondition', predicate = predicate}
    cell.boolexpr = Handle.created(Condition(function()
        local current = cell.predicate
        if not current then return false end
        return Callback.test('Trigger condition', current, self)
    end), 'Trigger.addCondition')
    local state = stateOf(self)
    state.conditions[#state.conditions + 1] = cell
    cell.native = TriggerAddCondition(raw, cell.boolexpr)
    ---@type MoonwellWrappers.TriggerCondition
    local token = {}
    cells[token] = cell
    return token
end
---Removing a token twice, or after clearConditions, does nothing.
---@param token MoonwellWrappers.TriggerCondition
function Trigger:removeCondition(token)
    local raw = registry.require(self, 'Trigger.removeCondition')
    local cell = ownedCell(self, token, 'TriggerCondition', 'Trigger.removeCondition')
    if not cell.predicate then return end
    cell.predicate = nil
    local state = stateOf(self)
    state.conditions = without(state.conditions, cell)
    TriggerRemoveCondition(raw, cell.native)
    DestroyCondition(cell.boolexpr)
end
function Trigger:clearConditions()
    local raw = registry.require(self, 'Trigger.clearConditions')
    local boolexprs = releaseConditions(stateOf(self))
    TriggerClearConditions(raw)
    for _, boolexpr in ipairs(boolexprs) do DestroyCondition(boolexpr) end
end

function Trigger:destroy()
    local raw = registry.dispose(self, 'Trigger.destroy')
    if not raw then return end
    local state = stateOf(self)
    states[self] = nil
    for _, cell in ipairs(state.actions) do cell.callback = nil end
    local boolexprs = releaseConditions(state)
    TriggerClearConditions(raw)
    for _, boolexpr in ipairs(boolexprs) do DestroyCondition(boolexpr) end
    DestroyTrigger(raw)
end

return Trigger
