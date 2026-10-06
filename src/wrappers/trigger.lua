local Handle = require('wrappers.internal.handle')
local Callback = require('wrappers.internal.callback')
local Cells = require('wrappers.internal.cells')
local Check = require('wrappers.internal.check')

---@class MoonwellWrappers.Trigger
---@field handle trigger? Read-only by convention; nil after destruction.
local Trigger = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Trigger, trigger>
local registry = Handle.new(Trigger, 'Trigger')

---What Trigger keeps on the cells of its lists, beside the callback. The class is declared in internal/cells.lua, which
---lets a module keep fields of its own on a cell; this block names and types the three of Trigger.
---@class MoonwellWrappers.Cell
---@field triggerAction triggeraction? An action's native handle.
---@field triggerCondition triggercondition? A condition's native handle.
---@field conditionFunc conditionfunc? A condition's boolexpr, which the trigger owns and destroys.

---@class MoonwellWrappers.TriggerState
---@field actions MoonwellWrappers.Cells In the order added.
---@field conditions MoonwellWrappers.Cells In the order added: clearing destroys their boolexprs in that order.

-- Keyed by wrapper; only indexed, never iterated. A trigger gets its state with its first action or condition.
---@type table<MoonwellWrappers.Trigger, MoonwellWrappers.TriggerState>
local states = {}

---The state of a live trigger. Its two `cancelled` functions run when one cell is cancelled, and that only happens
---while the trigger is live: clearing a list and destroying the trigger empty the lists first.
---@param trigger MoonwellWrappers.Trigger
---@param raw trigger
---@return MoonwellWrappers.TriggerState
local function stateOf(trigger, raw)
    local state = states[trigger]
    if not state then
        state = {
            actions = Cells.new(function(cell)
                local action = cell.triggerAction
                if action then TriggerRemoveAction(raw, action) end
            end),
            conditions = Cells.new(function(cell)
                local condition, boolexpr = cell.triggerCondition, cell.conditionFunc
                if condition then TriggerRemoveCondition(raw, condition) end
                if boolexpr then DestroyCondition(boolexpr) end
            end),
        }
        states[trigger] = state
    end
    return state
end

---Empties the list of conditions, so that none runs again and no cancel function does anything, and returns the
---boolexprs to destroy, in the order added.
---@param state MoonwellWrappers.TriggerState
---@return conditionfunc[]
local function releaseConditions(state)
    local boolexprs, count = {}, 0
    local items = state.conditions.items
    for index = 1, #items do
        local boolexpr = items[index].conditionFunc
        if boolexpr then
            count = count + 1
            boolexprs[count] = boolexpr
        end
    end
    Cells.clear(state.conditions)
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
---Enables (true) or disables (false) the trigger: EnableTrigger or DisableTrigger.
---@param flag boolean
function Trigger:setEnabled(flag)
    local raw = registry.require(self, 'Trigger.setEnabled')
    if flag then EnableTrigger(raw) else DisableTrigger(raw) end
end
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
    Check.requireNonNegative(range, 'range', 'Trigger.registerUnitInRange')
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
    local rawUnit = Handle.unwrap(unit, 'Unit', 'Trigger.registerUnitStateEvent')
    Check.requireFinite(value, 'value', 'Trigger.registerUnitStateEvent')
    TriggerRegisterUnitStateEvent(raw, rawUnit, state, op, value)
end
---@param timeout number
---@param periodic boolean
function Trigger:registerTimerEvent(timeout, periodic)
    local raw = registry.require(self, 'Trigger.registerTimerEvent')
    Check.requireNonNegative(timeout, 'timeout', 'Trigger.registerTimerEvent')
    TriggerRegisterTimerEvent(raw, timeout, periodic)
end
---@param event gameevent
function Trigger:registerGameEvent(event)
    TriggerRegisterGameEvent(registry.require(self, 'Trigger.registerGameEvent'), event)
end
---Fires inside SetPlayerState, at every change to a value that satisfies the comparison (measured on 3.0.0.24268).
---@param player MoonwellWrappers.Player
---@param state playerstate
---@param op limitop
---@param value number
function Trigger:registerPlayerStateEvent(player, state, op, value)
    local raw = registry.require(self, 'Trigger.registerPlayerStateEvent')
    local rawPlayer = Handle.unwrap(player, 'Player', 'Trigger.registerPlayerStateEvent')
    Check.requireFinite(value, 'value', 'Trigger.registerPlayerStateEvent')
    TriggerRegisterPlayerStateEvent(raw, rawPlayer, state, op, value)
end
---Fires inside SetPlayerAlliance when this player's setting of this kind toward any player really changes. The event
---names no player: GetTriggerPlayer() is nil (measured on 3.0.0.24268).
---@param player MoonwellWrappers.Player
---@param alliance alliancetype
function Trigger:registerPlayerAllianceChange(player, alliance)
    local raw = registry.require(self, 'Trigger.registerPlayerAllianceChange')
    local rawPlayer = Handle.unwrap(player, 'Player', 'Trigger.registerPlayerAllianceChange')
    TriggerRegisterPlayerAllianceChange(raw, rawPlayer, alliance)
end
---Fires when the comparison becomes true, by a set or by the game's clock (measured for GAME_STATE_TIME_OF_DAY on
---3.0.0.24268).
---@param state gamestate
---@param op limitop
---@param value number
function Trigger:registerGameStateEvent(state, op, value)
    local raw = registry.require(self, 'Trigger.registerGameStateEvent')
    Check.requireFinite(value, 'value', 'Trigger.registerGameStateEvent')
    TriggerRegisterGameStateEvent(raw, state, op, value)
end
---Fires at every expiry of the timer, before the timer's own callback (measured on 3.0.0.24268). The trigger does not
---own the timer.
---@param timer MoonwellWrappers.Timer
function Trigger:registerTimerExpireEvent(timer)
    local raw = registry.require(self, 'Trigger.registerTimerExpireEvent')
    TriggerRegisterTimerExpireEvent(raw, Handle.unwrap(timer, 'Timer', 'Trigger.registerTimerExpireEvent'))
end

---Runs `callback` with the trigger when it fires, behind the callback boundary, until the returned function is called.
---That function removes the action at once, even during a firing; calling it again, after clearActions or after
---destroy does nothing.
---@param callback fun(trigger: MoonwellWrappers.Trigger): ...
---@return MoonwellWrappers.Cancel
function Trigger:addAction(callback)
    local raw = registry.require(self, 'Trigger.addAction')
    Callback.check(callback, 'Trigger.addAction')
    local cell, cancel = Cells.add(stateOf(self, raw).actions, callback)
    cell.triggerAction = TriggerAddAction(raw, function()
        local current = cell.callback
        if current then Callback.call('Trigger', current, self) end
    end)
    return cancel
end
function Trigger:clearActions()
    local raw = registry.require(self, 'Trigger.clearActions')
    local state = states[self]
    if state then Cells.clear(state.actions) end
    TriggerClearActions(raw)
end

---The predicate's result counts as truthy or falsy. An error is printed and counts as false. The returned function
---removes the condition at once and destroys its boolexpr; calling it again, after clearConditions or after destroy
---does nothing.
---@param predicate fun(trigger: MoonwellWrappers.Trigger): any
---@return MoonwellWrappers.Cancel
function Trigger:addCondition(predicate)
    local raw = registry.require(self, 'Trigger.addCondition')
    Callback.check(predicate, 'Trigger.addCondition')
    -- Set below, before the game can evaluate the condition; the cell joins the list only once its boolexpr exists.
    ---@type MoonwellWrappers.Cell
    local cell
    local boolexpr = Handle.created(Condition(function()
        local current = cell.callback
        if not current then return false end
        return Callback.test('Trigger condition', current, self)
    end), 'Trigger.addCondition')
    local cancel
    cell, cancel = Cells.add(stateOf(self, raw).conditions, predicate)
    cell.conditionFunc = boolexpr
    cell.triggerCondition = TriggerAddCondition(raw, boolexpr)
    return cancel
end
function Trigger:clearConditions()
    local raw = registry.require(self, 'Trigger.clearConditions')
    local state = states[self]
    local boolexprs = state and releaseConditions(state)
    TriggerClearConditions(raw)
    if boolexprs then
        for _, boolexpr in ipairs(boolexprs) do DestroyCondition(boolexpr) end
    end
end

---Clears both lists first, so that no callback runs again and no cancel function calls a native. Conditions are then
---cleared natively and their boolexprs destroyed; the native actions are left to DestroyTrigger.
function Trigger:destroy()
    local raw = registry.dispose(self, 'Trigger.destroy')
    if not raw then return end
    local state = states[self]
    states[self] = nil
    ---@type conditionfunc[]?
    local boolexprs
    if state then
        Cells.clear(state.actions)
        boolexprs = releaseConditions(state)
    end
    TriggerClearConditions(raw)
    if boolexprs then
        for _, boolexpr in ipairs(boolexprs) do DestroyCondition(boolexpr) end
    end
    DestroyTrigger(raw)
end

return Trigger
