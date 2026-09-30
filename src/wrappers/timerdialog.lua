local Handle = require('wrappers.internal.handle')

---Shows a Timer's countdown. It does not own the timer: destroy the timer dialog first.
---@class MoonwellWrappers.TimerDialog
---@field handle timerdialog? Read-only by convention; nil after destruction.
local TimerDialog = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.TimerDialog, timerdialog>
local registry = Handle.new(TimerDialog, 'TimerDialog')
---The Timer each dialog made by create shows. Only indexed, never iterated.
---@type table<MoonwellWrappers.TimerDialog, MoonwellWrappers.Timer>
local timers = setmetatable({}, {__mode = 'k'})

---Returns the dialog's handle after checking the dialog and, when known, its Timer.
---@param dialog MoonwellWrappers.TimerDialog
---@param operation string
---@return timerdialog
local function live(dialog, operation)
    local raw = registry.require(dialog, operation, 1)
    local timer = timers[dialog]
    if timer ~= nil then Handle.unwrap(timer, 'Timer', operation, 1) end
    return raw
end

---@param raw timerdialog?
---@return MoonwellWrappers.TimerDialog?
---@overload fun(raw: nil): nil
function TimerDialog.fromHandle(raw) return registry.wrap(raw) end
---Creates a hidden timer dialog for the timer; call show(true) to display it.
---@param timer MoonwellWrappers.Timer
---@param title string?
---@return MoonwellWrappers.TimerDialog
function TimerDialog.create(timer, title)
    local raw = CreateTimerDialog(Handle.unwrap(timer, 'Timer', 'TimerDialog.create'))
    local dialog = Handle.created(TimerDialog.fromHandle(raw), 'TimerDialog.create')
    timers[dialog] = timer
    if title ~= nil then TimerDialogSetTitle(raw, title) end
    return dialog
end
---@return timerdialog
function TimerDialog:getHandle() return (live(self, 'TimerDialog.getHandle')) end
---@return boolean
function TimerDialog:isDisposed() return (registry.isDisposed(self, 'TimerDialog.isDisposed')) end
---@param text string
function TimerDialog:setTitle(text) TimerDialogSetTitle(live(self, 'TimerDialog.setTitle'), text) end
---@param r integer 0-255
---@param g integer 0-255
---@param b integer 0-255
---@param a integer 0-255
function TimerDialog:setTitleColor(r, g, b, a)
    TimerDialogSetTitleColor(live(self, 'TimerDialog.setTitleColor'), r, g, b, a)
end
---@param r integer 0-255
---@param g integer 0-255
---@param b integer 0-255
---@param a integer 0-255
function TimerDialog:setTimeColor(r, g, b, a)
    TimerDialogSetTimeColor(live(self, 'TimerDialog.setTimeColor'), r, g, b, a)
end
---@param factor number
function TimerDialog:setSpeed(factor) TimerDialogSetSpeed(live(self, 'TimerDialog.setSpeed'), factor) end
---@param seconds number
function TimerDialog:setRealTimeRemaining(seconds)
    TimerDialogSetRealTimeRemaining(live(self, 'TimerDialog.setRealTimeRemaining'), seconds)
end
---@param flag boolean
function TimerDialog:show(flag) TimerDialogDisplay(live(self, 'TimerDialog.show'), flag) end
---Shows the timer dialog on that player's machine only. Only local visuals differ.
---@param player MoonwellWrappers.Player
function TimerDialog:setVisibleFor(player)
    local raw = live(self, 'TimerDialog.setVisibleFor')
    TimerDialogDisplay(raw, Handle.unwrap(player, 'Player', 'TimerDialog.setVisibleFor') == GetLocalPlayer())
end
---Destroys the timer dialog, never its timer. Works after the timer is destroyed.
function TimerDialog:destroy()
    local raw = registry.dispose(self, 'TimerDialog.destroy')
    if not raw then return end
    timers[self] = nil
    DestroyTimerDialog(raw)
end

return TimerDialog
