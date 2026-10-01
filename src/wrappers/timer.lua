local Handle = require('wrappers.internal.handle')
local Callback = require('wrappers.internal.callback')

---@class MoonwellWrappers.Timer
---@field handle timer? Read-only by convention; nil after destruction.
local Timer = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Timer, timer>
local registry = Handle.new(Timer, 'Timer')
---@type table<MoonwellWrappers.Timer, {generation: table?, callback: (fun(timer: MoonwellWrappers.Timer): ...)?}>
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

---One-shot delivery releases its callback but keeps the timer for restart or explicit destruction.
---@param timeout number
---@param periodic boolean
---@param callback fun(timer: MoonwellWrappers.Timer): ...
function Timer:start(timeout, periodic, callback)
    local raw = registry.require(self, 'Timer.start')
    Callback.nonnegative(timeout, 'Timer.start')
    Callback.check(callback, 'Timer.start')
    local state = states[self] or {}
    local generation = {}
    state.generation = generation
    state.callback = callback
    states[self] = state
    TimerStart(raw, timeout, periodic, function()
        local current = state.callback
        if state.generation ~= generation or not current then return end
        if not periodic then state.callback = nil end
        Callback.call('Timer', current, self)
    end)
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
    if state then state.callback = nil; state.generation = nil end
    states[self] = nil
    PauseTimer(raw)
    DestroyTimer(raw)
end

return Timer
