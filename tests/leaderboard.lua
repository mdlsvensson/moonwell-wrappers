local function position(raw, p)
    for index, q in ipairs(raw.items) do if q == p then return index end end
end
native('CreateLeaderboard', function() return {items = {}} end)
native('LeaderboardHasPlayerItem', function(raw, p) return position(raw, p) ~= nil end)
native('LeaderboardGetPlayerIndex', function(raw, p) return (position(raw, p) or 0) - 1 end)
native('LeaderboardAddItem', function(raw, _, _, p) raw.items[#raw.items + 1] = p end)
native('LeaderboardRemovePlayerItem', function(raw, p) table.remove(raw.items, position(raw, p)) end)
native('LeaderboardGetItemCount', function(raw) return #raw.items end)
for _, name in ipairs({'LeaderboardSetLabel', 'LeaderboardSetLabelColor', 'LeaderboardSetValueColor',
    'LeaderboardSetStyle', 'LeaderboardSetSizeByItemCount', 'LeaderboardSetItemValue', 'LeaderboardSetItemLabel',
    'LeaderboardSetItemLabelColor', 'LeaderboardSetItemValueColor', 'LeaderboardSetItemStyle',
    'LeaderboardSortItemsByValue', 'LeaderboardSortItemsByLabel', 'LeaderboardSortItemsByPlayer',
    'PlayerSetLeaderboard', 'LeaderboardDisplay', 'DestroyLeaderboard'}) do
    native(name, function() end)
end
local Leaderboard = require('wrappers.leaderboard')
local Player = require('wrappers.player')
eq(totalCalls(), 0)

local mutating = {'LeaderboardAddItem', 'LeaderboardRemovePlayerItem', 'LeaderboardSetSizeByItemCount',
    'LeaderboardSetItemValue', 'LeaderboardSetItemLabel', 'LeaderboardSetItemLabelColor',
    'LeaderboardSetItemValueColor', 'LeaderboardSetItemStyle', 'LeaderboardSetStyle'}

test('create sets the optional label and keeps identity', function()
    local board = Leaderboard.create('Kills')
    expectCall('LeaderboardSetLabel', board.handle, 'Kills')
    eq(Leaderboard.fromHandle(board.handle), board); eq(Leaderboard.fromHandle(nil), nil)
    eq(board:getHandle(), board.handle); eq(board:isDisposed(), false)
    local plain = Leaderboard.create()
    eq(callCount('LeaderboardSetLabel'), 1)
    board:destroy(); plain:destroy()
end)

test('items are keyed by player and resize the board', function()
    local board = Leaderboard.create()
    local red, blue = Player.fromIndex(0), Player.fromHandle({})
    board:addItem(red, 'Red', 3)
    expectCall('LeaderboardAddItem', board.handle, 'Red', 3, red.handle)
    expectCall('LeaderboardSetSizeByItemCount', board.handle, 1)
    board:addItem(blue, 'Blue', 5)
    expectCall('LeaderboardSetSizeByItemCount', board.handle, 2)
    eq(board:getItemCount(), 2); eq(board:hasItem(blue), true)
    board:setItemValue(blue, 9); expectCall('LeaderboardSetItemValue', board.handle, 1, 9)
    board:setItemLabel(red, 'R'); expectCall('LeaderboardSetItemLabel', board.handle, 0, 'R')
    board:setItemLabelColor(blue, 1, 2, 3, 4); expectCall('LeaderboardSetItemLabelColor', board.handle, 1, 1, 2, 3, 4)
    board:setItemValueColor(red, 5, 6, 7, 8); expectCall('LeaderboardSetItemValueColor', board.handle, 0, 5, 6, 7, 8)
    board:setItemStyle(blue, {icon = false}); expectCall('LeaderboardSetItemStyle', board.handle, 1, true, true, false)
    board:setItemStyle(red); expectCall('LeaderboardSetItemStyle', board.handle, 0, true, true, true)
    board:removeItem(red)
    expectCall('LeaderboardRemovePlayerItem', board.handle, red.handle)
    expectCall('LeaderboardSetSizeByItemCount', board.handle, 1)
    eq(board:hasItem(red), false)
    board:setItemValue(blue, 1); expectCall('LeaderboardSetItemValue', board.handle, 0, 1)
    board:destroy()
end)

test('one item per player: misuse fails before any change', function()
    local board = Leaderboard.create()
    local red, blue = Player.fromIndex(0), Player.fromHandle({})
    board:addItem(red, 'Red', 3)
    resetCalls()
    fails(function() board:addItem(red, 'Again', 1) end, 'Leaderboard.addItem: player already has an item')
    fails(function() board:removeItem(blue) end, 'Leaderboard.removeItem: player has no item')
    fails(function() board:setItemValue(blue, 1) end, 'Leaderboard.setItemValue: player has no item')
    fails(function() board:setItemLabel(blue, 'x') end, 'Leaderboard.setItemLabel: player has no item')
    fails(function() board:setItemLabelColor(blue, 1, 2, 3, 4) end, 'Leaderboard.setItemLabelColor: player has no item')
    fails(function() board:setItemValueColor(blue, 1, 2, 3, 4) end, 'Leaderboard.setItemValueColor: player has no item')
    fails(function() board:setItemStyle(blue) end, 'Leaderboard.setItemStyle: player has no item')
    fails(function() board:addItem(board, 'x', 1) end, 'Leaderboard.addItem: expected Player wrapper')
    fails(function() board:setItemValue(board, 1) end, 'Leaderboard.setItemValue: expected Player wrapper')
    fails(function() board:hasItem(board) end, 'Leaderboard.hasItem: expected Player wrapper')
    fails(function() board:setItemStyle(red, {icons = false}) end, "Leaderboard.setItemStyle: unknown option 'icons'")
    fails(function() board:setStyle({labels = true}) end, "Leaderboard.setStyle: unknown option 'labels'")
    failsAt(function() board:setStyle({names = 1}) end, "Leaderboard.setStyle: 'names' expected a boolean")
    for _, name in ipairs(mutating) do eq(callCount(name), 0) end
    board:destroy()
end)

test('style, colors, sorting, assignment and display forward exact arguments', function()
    local board = Leaderboard.create()
    checkSetters(board, {{'LeaderboardSetLabel', 'setLabel', 'Gold'},
        {'LeaderboardSetLabelColor', 'setLabelColor', 1, 2, 3, 4}, {'LeaderboardSetValueColor', 'setValueColor', 5, 6, 7, 8},
        {'LeaderboardSortItemsByValue', 'sortByValue', true}, {'LeaderboardSortItemsByLabel', 'sortByLabel', false},
        {'LeaderboardSortItemsByPlayer', 'sortByPlayer', true}, {'LeaderboardDisplay', 'show', true}})
    board:setStyle({names = false}); expectCall('LeaderboardSetStyle', board.handle, true, false, true, true)
    board:setStyle(); expectCall('LeaderboardSetStyle', board.handle, true, true, true, true)
    local red = Player.fromIndex(0)
    board:assign(red); expectCall('PlayerSetLeaderboard', red.handle, board.handle)
    fails(function() board:assign(board) end, 'Leaderboard.assign: expected Player wrapper')
    eq(board.isDisplayed, nil)
    board:destroy()
end)

test('destroy is idempotent and guards every method', function()
    local board = Leaderboard.create()
    local raw = board.handle
    board:destroy(); board:destroy()
    expectCall('DestroyLeaderboard', raw); eq(callCount('DestroyLeaderboard'), 1)
    eq(board.handle, nil); eq(board:isDisposed(), true)
    checkDisposed(board, {'getHandle', 'setLabel', 'setLabelColor', 'setValueColor', 'setStyle', 'addItem',
        'removeItem', 'setItemValue', 'setItemLabel', 'setItemLabelColor', 'setItemValueColor', 'setItemStyle',
        'hasItem', 'getItemCount', 'sortByValue', 'sortByLabel', 'sortByPlayer', 'assign', 'show'})
end)

test('create fails clearly when the native returns nil', function()
    native('CreateLeaderboard', function() return nil end)
    fails(function() Leaderboard.create('x') end, 'Leaderboard.create: native returned nil')
    eq(callCount('LeaderboardSetLabel'), 0)
    native('CreateLeaderboard', function() return {items = {}} end)
end)

test('item errors point at the caller', function()
    local board = Leaderboard.create()
    failsAt(function() board:setItemValue(Player.fromIndex(1), 5) end, 'Leaderboard.setItemValue: player has no item')
    failsAt(function() board:setItemValue({}, 5) end, 'Leaderboard.setItemValue: expected Player wrapper')
end)
