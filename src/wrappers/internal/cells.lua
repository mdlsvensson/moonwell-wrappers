local Callback = require('wrappers.internal.callback')

---The list of cancellable callbacks under Trigger, Frame and the shared listeners. A firing reads the list once: a
---callback added during it waits for the next firing, and a cancelled one is skipped at once. Internal: the caller
---checks its arguments.
local Cells = {}

---What a registration returns: removes the callback. Calling it again, or after the owner is gone, does nothing.
---@alias MoonwellWrappers.Cancel fun()

---One registered callback. A module may keep fields of its own on a cell.
---@class MoonwellWrappers.Cell
---@field callback function? Nil once cancelled or cleared.
---@field [string] any

---@class MoonwellWrappers.Cells
---@field items MoonwellWrappers.Cell[] Live cells in the order added: appended in place, copied on a cancel.
---@field cancelled (fun(cell: MoonwellWrappers.Cell))? Runs once after a cell is cancelled singly; not on clear.

---@param cancelled (fun(cell: MoonwellWrappers.Cell))? Runs after a cell is cancelled by its cancel function. An error
---it raises propagates to whoever called the cancel function, after the list is already updated, and is not retried:
---a hook must not raise.
---@return MoonwellWrappers.Cells
function Cells.new(cancelled) return {items = {}, cancelled = cancelled} end

---Appends a callback and returns its cell and its cancel function. The cancel function drops the callback, takes the
---cell out of the list (in a copy, so a firing that is running keeps its own array), then tells `list.cancelled`.
---@param list MoonwellWrappers.Cells
---@param callback function
---@return MoonwellWrappers.Cell cell
---@return MoonwellWrappers.Cancel cancel
function Cells.add(list, callback)
    ---@type MoonwellWrappers.Cell
    local cell = {callback = callback}
    local items = list.items
    items[#items + 1] = cell
    return cell, function()
        if cell.callback == nil then return end
        cell.callback = nil
        local kept = {}
        for _, other in ipairs(list.items) do
            if other ~= cell then kept[#kept + 1] = other end
        end
        list.items = kept
        local cancelled = list.cancelled
        if cancelled then cancelled(cell) end
    end
end

---The number of live cells.
---@param list MoonwellWrappers.Cells
---@return integer
function Cells.count(list) return #list.items end

---Drops every callback and empties the list, for an owner that is going away: a cancel function called afterwards
---does nothing. `list.cancelled` does not run.
---@param list MoonwellWrappers.Cells
function Cells.clear(list)
    local items = list.items
    if #items == 0 then return end
    for index = 1, #items do items[index].callback = nil end
    list.items = {}
end

---Runs the live callbacks of one firing, in the order added, behind the callback boundary: an error is printed with
---`label` and the next callback still runs. A caller that needs the callbacks' results walks `list.items` itself and
---skips the cells whose `callback` is nil, in a numeric `for` whose bound is read once (an `ipairs` walk would run a
---callback added during the firing, because `Cells.add` appends in place).
---@param list MoonwellWrappers.Cells
---@param label string
---@param ... any Passed to every callback.
function Cells.call(list, label, ...)
    local items = list.items
    for index = 1, #items do
        local callback = items[index].callback
        if callback then Callback.call(label, callback, ...) end
    end
end

return Cells
