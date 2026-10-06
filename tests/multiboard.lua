local rows, columns, steps, items, released = {}, {}, {}, {}, {}
local function newBoard() local raw = {}; rows[raw], columns[raw] = 0, 0; return raw end
native('CreateMultiboard', newBoard)
native('MultiboardSetRowCount', function(raw, count) rows[raw] = count; steps[#steps + 1] = count end)
native('MultiboardSetColumnCount', function(raw, count) columns[raw] = count end)
native('MultiboardGetRowCount', function(raw) return rows[raw] end)
native('MultiboardGetColumnCount', function(raw) return columns[raw] end)
native('MultiboardGetItem', function(_, row, column)
    local item = {row = row, column = column}
    items[#items + 1] = item
    return item
end)
native('MultiboardReleaseItem', function(item) released[#released + 1] = item end)
for _, name in ipairs({'MultiboardSetTitleText', 'MultiboardSetTitleTextColor', 'MultiboardSetItemValue',
    'MultiboardSetItemValueColor', 'MultiboardSetItemIcon', 'MultiboardSetItemStyle', 'MultiboardSetItemWidth',
    'MultiboardSetItemsValue', 'MultiboardSetItemsValueColor', 'MultiboardSetItemsIcon', 'MultiboardSetItemsStyle',
    'MultiboardSetItemsWidth', 'MultiboardDisplay', 'MultiboardMinimize', 'MultiboardSuppressDisplay',
    'DestroyMultiboard'}) do
    native(name, function() end)
end
native('MultiboardGetTitleText', function() return '' end)
native('GetLocalPlayer', function() return PLAYER_RAW end)
local Multiboard = require('wrappers.multiboard')
local Player = require('wrappers.player')
eq(totalCalls(), 0)

local function names()
    local list = {}
    for index = 1, totalCalls() do list[#list + 1] = callName(index) end
    return table.concat(list, ' ')
end

test('create sets columns, steps rows one at a time and sets the title', function()
    steps = {}
    local board = Multiboard.create(3, 2, 'Scores')
    expectCall('MultiboardSetColumnCount', board.handle, 2)
    eq(table.concat(steps, ','), '1,2,3')
    expectCall('MultiboardSetTitleText', board.handle, 'Scores')
    eq(board:getRowCount(), 3); eq(board:getColumnCount(), 2)
    eq(Multiboard.fromHandle(board.handle), board); eq(Multiboard.fromHandle(nil), nil)
    eq(board:getHandle(), board.handle); eq(board:isDisposed(), false)
    local untitled = Multiboard.create(0, 0)
    eq(callCount('MultiboardSetTitleText'), 1)
    board:destroy(); untitled:destroy()
end)

test('setRowCount steps one row at a time, up and down', function()
    local board = Multiboard.create(3, 1)
    steps = {}
    board:setRowCount(6); eq(table.concat(steps, ','), '4,5,6')
    steps = {}
    board:setRowCount(2); eq(table.concat(steps, ','), '5,4,3,2')
    steps = {}
    board:setRowCount(2); eq(#steps, 0)
    board:setColumnCount(4); expectCall('MultiboardSetColumnCount', board.handle, 4)
    board:destroy()
end)

test('counts must be non-negative integers', function()
    fails(function() Multiboard.create(-1, 2) end, 'Multiboard.create: expected a non-negative integer row count')
    fails(function() Multiboard.create(1, 1.5) end, 'Multiboard.create: expected a non-negative integer column count')
    fails(function() Multiboard.create('3', 1) end, 'Multiboard.create: expected a non-negative integer row count')
    eq(totalCalls(), 0)
    local board = Multiboard.create(1, 1)
    resetCalls()
    fails(function() board:setRowCount('3') end, 'Multiboard.setRowCount: expected a non-negative integer row count')
    fails(function() board:setRowCount(math.huge) end, 'expected a non-negative integer row count')
    fails(function() board:setColumnCount(-2) end,
        'Multiboard.setColumnCount: expected a non-negative integer column count')
    eq(callCount('MultiboardSetRowCount'), 0); eq(callCount('MultiboardSetColumnCount'), 0)
    board:destroy()
end)

test('setCell converts to zero-based, applies options in order and releases the item', function()
    local board = Multiboard.create(2, 3)
    items, released = {}, {}
    resetCalls()
    board:setCell(2, 3, {value = 'Arthas', color = {255, 204, 0}, icon = 'arthas.blp', showValue = true,
        showIcon = false, width = 0.1})
    eq(#items, 1); eq(items[1].row, 1); eq(items[1].column, 2)
    local item = items[1]
    expectCall('MultiboardSetItemValue', item, 'Arthas')
    expectCall('MultiboardSetItemValueColor', item, 255, 204, 0, 255)
    expectCall('MultiboardSetItemIcon', item, 'arthas.blp')
    expectCall('MultiboardSetItemStyle', item, true, false)
    expectCall('MultiboardSetItemWidth', item, 0.1)
    eq(#released, 1); eq(released[1], item)
    eq(names(), 'MultiboardGetRowCount MultiboardGetColumnCount MultiboardGetItem MultiboardSetItemValue ' ..
        'MultiboardSetItemValueColor MultiboardSetItemIcon MultiboardSetItemStyle MultiboardSetItemWidth ' ..
        'MultiboardReleaseItem')
    resetCalls()
    board:setCell(1, 1, {value = 'x'})
    eq(names(), 'MultiboardGetRowCount MultiboardGetColumnCount MultiboardGetItem MultiboardSetItemValue ' ..
        'MultiboardReleaseItem')
    board:setCell(1, 1, {showValue = false, showIcon = true})
    expectCall('MultiboardSetItemStyle', items[#items], false, true)
    board:destroy()
end)

test('bad cells fail before any item is obtained', function()
    local board = Multiboard.create(4, 2)
    resetCalls()
    fails(function() board:setCell(5, 1, {value = 'x'}) end, 'Multiboard.setCell: row 5 outside 1..4')
    fails(function() board:setCell(0, 1, {value = 'x'}) end, 'Multiboard.setCell: row 0 outside 1..4')
    fails(function() board:setCell(1, 3, {value = 'x'}) end, 'Multiboard.setCell: column 3 outside 1..2')
    fails(function() board:setCell(1.5, 1, {value = 'x'}) end, 'Multiboard.setCell: row 1.5 outside 1..4')
    fails(function() board:setCell('1', 1, {value = 'x'}) end, 'Multiboard.setCell: row 1 outside 1..4')
    fails(function() board:setRow(9, {value = 'x'}) end, 'Multiboard.setRow: row 9 outside 1..4')
    fails(function() board:setColumn(3, {value = 'x'}) end, 'Multiboard.setColumn: column 3 outside 1..2')
    eq(callCount('MultiboardGetItem'), 0)
    resetCalls()
    fails(function() board:setCell(1, 1, {}) end, 'Multiboard.setCell: expected at least one option')
    fails(function() board:setCell(1, 1) end, 'Multiboard.setCell: expected at least one option')
    fails(function() board:setAll({showValue = true}) end,
        "Multiboard.setAll: options 'showValue' and 'showIcon' go together")
    fails(function() board:setRow(1, {showIcon = false}) end, "options 'showValue' and 'showIcon' go together")
    fails(function() board:setCell(1, 1, {colour = {1, 2, 3}}) end, "unknown option 'colour'")
    failsAt(function() board:setCell(1, 1, {width = -1}) end,
        "Multiboard.setCell: 'width' expected a finite non-negative number")
    eq(totalCalls(), 0)
    board:destroy()
end)

test('setRow and setColumn set each cell in ascending order and release each item', function()
    local board = Multiboard.create(2, 3)
    items, released = {}, {}
    board:setRow(2, {value = 'r'})
    eq(#items, 3); eq(#released, 3)
    for index, item in ipairs(items) do eq(item.row, 1); eq(item.column, index - 1); eq(released[index], item) end
    items, released = {}, {}
    board:setColumn(3, {icon = 'i.blp'})
    eq(#items, 2); eq(#released, 2)
    for index, item in ipairs(items) do eq(item.row, index - 1); eq(item.column, 2); eq(released[index], item) end
    board:destroy()
end)

test('setAll uses the whole-board natives', function()
    local board = Multiboard.create(2, 2)
    resetCalls()
    board:setAll({value = '-', color = {1, 2, 3, 4}, icon = 'x.blp', showValue = true, showIcon = false, width = 0.05})
    expectCall('MultiboardSetItemsValue', board.handle, '-')
    expectCall('MultiboardSetItemsValueColor', board.handle, 1, 2, 3, 4)
    expectCall('MultiboardSetItemsIcon', board.handle, 'x.blp')
    expectCall('MultiboardSetItemsStyle', board.handle, true, false)
    expectCall('MultiboardSetItemsWidth', board.handle, 0.05)
    eq(callCount('MultiboardGetItem'), 0); eq(totalCalls(), 5)
    board:destroy()
end)

test('title, display and minimize forward exact arguments', function()
    local board = Multiboard.create(1, 1)
    checkSetters(board, {{'MultiboardSetTitleText', 'setTitle', 'Kills'},
        {'MultiboardSetTitleTextColor', 'setTitleColor', 1, 2, 3, 4}, {'MultiboardDisplay', 'show', true},
        {'MultiboardMinimize', 'minimize', false}})
    checkGetters(board, {{'MultiboardGetTitleText', 'getTitle', 'Kills'}})
    Multiboard.suppressDisplay(true); expectCall('MultiboardSuppressDisplay', true)
    Multiboard.suppressDisplay(false); expectCall('MultiboardSuppressDisplay', false)
    board:setVisibleFor(Player.fromIndex(0)); expectCall('MultiboardDisplay', board.handle, true)
    board:setVisibleFor(Player.fromHandle({})); expectCall('MultiboardDisplay', board.handle, false)
    fails(function() board:setVisibleFor(board) end, 'Multiboard.setVisibleFor: expected Player wrapper')
    eq(board.isMinimized, nil); eq(board.isDisplayed, nil)
    board:destroy()
end)

test('destroy is idempotent and guards every method', function()
    local board = Multiboard.create(1, 1)
    local raw = board.handle
    board:destroy(); board:destroy()
    expectCall('DestroyMultiboard', raw); eq(callCount('DestroyMultiboard'), 1)
    eq(board.handle, nil); eq(board:isDisposed(), true)
    checkDisposed(board, {'getHandle', 'setRowCount', 'setColumnCount', 'getRowCount', 'getColumnCount', 'setTitle',
        'getTitle', 'setTitleColor', 'setCell', 'setRow', 'setColumn', 'setAll', 'show', 'setVisibleFor', 'minimize'})
end)

test('create fails clearly when the native returns nil', function()
    native('CreateMultiboard', function() return nil end)
    fails(function() Multiboard.create(1, 1) end, 'Multiboard.create: native returned nil')
    eq(callCount('MultiboardSetColumnCount'), 0)
    native('CreateMultiboard', newBoard)
end)

test('cell option errors point at the caller', function()
    local board = Multiboard.create(1, 1)
    failsAt(function() board:setCell(1, 1, {bogus = 1}) end, "Multiboard.setCell: unknown option 'bogus'")
    failsAt(function() board:setCell(1, 1, {}) end, 'Multiboard.setCell: expected at least one option')
    failsAt(function() board:setCell(9, 1, {value = 'x'}) end, 'outside 1..1')
end)
