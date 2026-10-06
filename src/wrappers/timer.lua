local Handle = require('wrappers.internal.handle')
local Callback = require('wrappers.internal.callback')
local Check = require('wrappers.internal.check')

---@class MoonwellWrappers.Timer
---@field handle timer? Read-only by convention; nil after destruction.
local Timer = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Timer, timer>
local registry = Handle.new(Timer, 'Timer')

---@class MoonwellWrappers.TimerState
---@field callback (fun(timer: MoonwellWrappers.Timer): ...)? Nil after a one-shot expiry and after destroy.
---@field periodic boolean What the last start asked for.
---@field tick fun() The one function this Timer gives to TimerStart, made by its first start.

-- Keyed by wrapper; only indexed, never iterated. A timer gets its state with its first start.
---@type table<MoonwellWrappers.Timer, MoonwellWrappers.TimerState>
local states = {}

---@param raw timer?
---@return MoonwellWrappers.Timer?
---@overload fun(raw: nil): nil
function Timer.fromHandle(raw) return registry.wrap(raw) end
---The timer whose expiry is running (GetExpiredTimer), or nil outside one.
---@return MoonwellWrappers.Timer?
function Timer.fromEvent() return registry.wrap(GetExpiredTimer()) end
---@return MoonwellWrappers.Timer
function Timer.create() return (Handle.created(Timer.fromHandle(CreateTimer()), 'Timer.create')) end
---@return timer
function Timer:getHandle() return (registry.require(self, 'Timer.getHandle')) end
---@return boolean
function Timer:isDisposed() return (registry.isDisposed(self, 'Timer.isDisposed')) end

---One-shot delivery releases its callback but keeps the timer for restart or explicit destruction. A start replaces
---the schedule and the callback of the one before it. Every start of a Timer gives the game the same function, which
---reads the callback and `periodic` of the latest start: a timer that is started again and again makes no new closure.
---@param timeout number
---@param periodic boolean
---@param callback fun(timer: MoonwellWrappers.Timer): ...
function Timer:start(timeout, periodic, callback)
    local raw = registry.require(self, 'Timer.start')
    Check.requireNonNegative(timeout, 'timeout', 'Timer.start')
    Callback.check(callback, 'Timer.start')
    local state = states[self]
    if state then
        state.callback, state.periodic = callback, periodic
    else
        -- Set below, before the game can run the function that reads it.
        ---@type MoonwellWrappers.TimerState
        local created
        created = {callback = callback, periodic = periodic, tick = function()
            local current = created.callback
            if not current then return end
            if not created.periodic then created.callback = nil end
            Callback.call('Timer', current, self)
        end}
        states[self] = created
        state = created
    end
    TimerStart(raw, timeout, periodic, state.tick)
end

function Timer:pause() PauseTimer(registry.require(self, 'Timer.pause')) end
function Timer:resume() ResumeTimer(registry.require(self, 'Timer.resume')) end
---@return number
function Timer:getElapsed() return TimerGetElapsed(registry.require(self, 'Timer.getElapsed')) end
---@return number
function Timer:getRemaining() return TimerGetRemaining(registry.require(self, 'Timer.getRemaining')) end
---@return number
function Timer:getTimeout() return TimerGetTimeout(registry.require(self, 'Timer.getTimeout')) end

function Timer:destroy()
    local raw = registry.dispose(self, 'Timer.destroy')
    if not raw then return end
    local state = states[self]
    if state then state.callback = nil end
    states[self] = nil
    PauseTimer(raw)
    DestroyTimer(raw)
end

return Timer
