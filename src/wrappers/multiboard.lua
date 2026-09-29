local Handle = require('wrappers.internal.handle')
local Options = require('wrappers.internal.options')

---Rows and columns count from 1. Cell handles are obtained and released inside each call, so none can leak.
---@class MoonwellWrappers.Multiboard
---@field handle multiboard? Read-only by convention; nil after destruction.
local Multiboard = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Multiboard, multiboard>
local registry = Handle.new(Multiboard, 'Multiboard')

---@class MoonwellWrappers.MultiboardCellOptions
---@field value string? The cell's text.
---@field color integer[]? {r, g, b, a?}, each 0-255, for the text.
---@field icon string? Icon path.
---@field showValue boolean? Show the text; give together with showIcon.
---@field showIcon boolean? Show the icon; give together with showValue.
---@field width number? Width as a fraction of the screen width.

---@type MoonwellWrappers.OptionFields
local cellFields = {
    value = {'string'}, color = {'color'}, icon = {'string'}, showValue = {'boolean'}, showIcon = {'boolean'},
    width = {'nonnegative'},
}

---Level 3 blames the caller of the public method.
---@param options unknown
---@param operation string
---@return table<string, any>
local function cellOptions(options, operation)
    local o = Options.read(options, cellFields, operation)
    if o.value == nil and o.color == nil and o.icon == nil and o.showValue == nil and o.showIcon == nil
        and o.width == nil then
        error('[wrappers] ' .. operation .. ': expected at least one option', 3)
    end
    if (o.showValue == nil) ~= (o.showIcon == nil) then
        error('[wrappers] ' .. operation .. ": options 'showValue' and 'showIcon' go together", 3)
    end
    return o
end

---@param value unknown
---@param what string
---@param operation string
local function checkCount(value, what, operation)
    if type(value) ~= 'number' or value % 1 ~= 0 or value < 0 then
        error('[wrappers] ' .. operation .. ': expected a non-negative integer ' .. what, 3)
    end
end

---@param value unknown
---@param count integer
---@param what string
---@param operation string
local function checkIndex(value, count, what, operation)
    if type(value) ~= 'number' or value % 1 ~= 0 or value < 1 or value > count then
        error('[wrappers] ' .. operation .. ': ' .. what .. ' ' .. tostring(value) .. ' outside 1..' .. count, 3)
    end
end

---Gets one cell (one-based), applies the options in a fixed order and releases the cell handle.
---@param raw multiboard
---@param row integer
---@param column integer
---@param o table<string, any>
local function setCell(raw, row, column, o)
    local item = MultiboardGetItem(raw, row - 1, column - 1)
    if o.value ~= nil then MultiboardSetItemValue(item, o.value) end
    if o.color ~= nil then MultiboardSetItemValueColor(item, o.color[1], o.color[2], o.color[3], o.color[4]) end
    if o.icon ~= nil then MultiboardSetItemIcon(item, o.icon) end
    if o.showValue ~= nil then MultiboardSetItemStyle(item, o.showValue, o.showIcon) end
    if o.width ~= nil then MultiboardSetItemWidth(item, o.width) end
    MultiboardReleaseItem(item)
end

---@param raw multiboard?
---@return MoonwellWrappers.Multiboard?
---@overload fun(raw: nil): nil
function Multiboard.fromHandle(raw) return registry.wrap(raw) end
---@param rows integer
---@param columns integer
---@param title string?
---@return MoonwellWrappers.Multiboard
function Multiboard.create(rows, columns, title)
    checkCount(rows, 'row count', 'Multiboard.create')
    checkCount(columns, 'column count', 'Multiboard.create')
    local raw = CreateMultiboard()
    local board = Handle.created(Multiboard.fromHandle(raw), 'Multiboard.create')
    MultiboardSetColumnCount(raw, columns)
    board:setRowCount(rows)
    if title ~= nil then MultiboardSetTitleText(raw, title) end
    return board
end
---Hides (true) or allows (false) every multiboard, for everyone.
---@param flag boolean
function Multiboard.suppressDisplay(flag) MultiboardSuppressDisplay(flag) end
---@return multiboard
function Multiboard:getHandle() return registry.require(self, 'Multiboard.getHandle') end
---@return boolean
function Multiboard:isDisposed() return registry.isDisposed(self, 'Multiboard.isDisposed') end
---Changes the row count one row at a time, a safeguard: w3ts reports that bigger steps are unsafe (a direct change from
---0 to 5 rows worked in our probe on 3.0.0.24268).
---@param count integer
function Multiboard:setRowCount(count)
    local raw = registry.require(self, 'Multiboard.setRowCount')
    checkCount(count, 'row count', 'Multiboard.setRowCount')
    local current = MultiboardGetRowCount(raw)
    local step = count >= current and 1 or -1
    while current ~= count do
        current = current + step
        MultiboardSetRowCount(raw, current)
    end
end
---@param count integer
function Multiboard:setColumnCount(count)
    local raw = registry.require(self, 'Multiboard.setColumnCount')
    checkCount(count, 'column count', 'Multiboard.setColumnCount')
    MultiboardSetColumnCount(raw, count)
end
---@return integer
function Multiboard:getRowCount() return MultiboardGetRowCount(registry.require(self, 'Multiboard.getRowCount')) end
---@return integer
function Multiboard:getColumnCount()
    return MultiboardGetColumnCount(registry.require(self, 'Multiboard.getColumnCount'))
end
---@param text string
function Multiboard:setTitle(text) MultiboardSetTitleText(registry.require(self, 'Multiboard.setTitle'), text) end
---@return string
function Multiboard:getTitle() return MultiboardGetTitleText(registry.require(self, 'Multiboard.getTitle')) end
---@param r integer 0-255
---@param g integer 0-255
---@param b integer 0-255
---@param a integer 0-255
function Multiboard:setTitleColor(r, g, b, a)
    MultiboardSetTitleTextColor(registry.require(self, 'Multiboard.setTitleColor'), r, g, b, a)
end
---@param row integer From 1.
---@param column integer From 1.
---@param options MoonwellWrappers.MultiboardCellOptions
function Multiboard:setCell(row, column, options)
    local raw = registry.require(self, 'Multiboard.setCell')
    local o = cellOptions(options, 'Multiboard.setCell')
    checkIndex(row, MultiboardGetRowCount(raw), 'row', 'Multiboard.setCell')
    checkIndex(column, MultiboardGetColumnCount(raw), 'column', 'Multiboard.setCell')
    setCell(raw, row, column, o)
end
---@param row integer From 1.
---@param options MoonwellWrappers.MultiboardCellOptions
function Multiboard:setRow(row, options)
    local raw = registry.require(self, 'Multiboard.setRow')
    local o = cellOptions(options, 'Multiboard.setRow')
    checkIndex(row, MultiboardGetRowCount(raw), 'row', 'Multiboard.setRow')
    for column = 1, MultiboardGetColumnCount(raw) do setCell(raw, row, column, o) end
end
---@param column integer From 1.
---@param options MoonwellWrappers.MultiboardCellOptions
function Multiboard:setColumn(column, options)
    local raw = registry.require(self, 'Multiboard.setColumn')
    local o = cellOptions(options, 'Multiboard.setColumn')
    checkIndex(column, MultiboardGetColumnCount(raw), 'column', 'Multiboard.setColumn')
    for row = 1, MultiboardGetRowCount(raw) do setCell(raw, row, column, o) end
end
---Applies the options to every cell with the whole-board natives.
---@param options MoonwellWrappers.MultiboardCellOptions
function Multiboard:setAll(options)
    local raw = registry.require(self, 'Multiboard.setAll')
    local o = cellOptions(options, 'Multiboard.setAll')
    if o.value ~= nil then MultiboardSetItemsValue(raw, o.value) end
    if o.color ~= nil then MultiboardSetItemsValueColor(raw, o.color[1], o.color[2], o.color[3], o.color[4]) end
    if o.icon ~= nil then MultiboardSetItemsIcon(raw, o.icon) end
    if o.showValue ~= nil then MultiboardSetItemsStyle(raw, o.showValue, o.showIcon) end
    if o.width ~= nil then MultiboardSetItemsWidth(raw, o.width) end
end
---@param flag boolean
function Multiboard:show(flag) MultiboardDisplay(registry.require(self, 'Multiboard.show'), flag) end
---Shows the multiboard on that player's machine only. Only local visuals differ.
---@param player MoonwellWrappers.Player
function Multiboard:setVisibleFor(player)
    local raw = registry.require(self, 'Multiboard.setVisibleFor')
    MultiboardDisplay(raw, Handle.unwrap(player, 'Player', 'Multiboard.setVisibleFor') == GetLocalPlayer())
end
---@param flag boolean
function Multiboard:minimize(flag) MultiboardMinimize(registry.require(self, 'Multiboard.minimize'), flag) end
function Multiboard:destroy()
    local raw = registry.dispose(self, 'Multiboard.destroy')
    if raw then DestroyMultiboard(raw) end
end

return Multiboard
