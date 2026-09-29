local Handle = require('wrappers.internal.handle')
local Options = require('wrappers.internal.options')

---Items are keyed by player: each player has at most one item.
---@class MoonwellWrappers.Leaderboard
---@field handle leaderboard? Read-only by convention; nil after destruction.
local Leaderboard = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Leaderboard, leaderboard>
local registry = Handle.new(Leaderboard, 'Leaderboard')

---@class MoonwellWrappers.LeaderboardStyleOptions
---@field label boolean? Show the leaderboard's label; default true.
---@field names boolean? Show the item labels; default true.
---@field values boolean? Show the values; default true.
---@field icons boolean? Show the icons; default true.

---@class MoonwellWrappers.LeaderboardItemStyleOptions
---@field label boolean? Show this item's label; default true.
---@field value boolean? Show this item's value; default true.
---@field icon boolean? Show this item's icon; default true.

---@type MoonwellWrappers.OptionFields
local styleFields = {label = {'boolean', true}, names = {'boolean', true}, values = {'boolean', true},
    icons = {'boolean', true}}
---@type MoonwellWrappers.OptionFields
local itemStyleFields = {label = {'boolean', true}, value = {'boolean', true}, icon = {'boolean', true}}

---A leaderboard starts with no rows and does not grow by itself (LeaderboardResizeBJ does the same).
---@param raw leaderboard
local function resize(raw) LeaderboardSetSizeByItemCount(raw, LeaderboardGetItemCount(raw)) end

---Returns the leaderboard handle, the player's zero-based item index and the player handle. Level 3 blames the caller
---of the public method.
---@param board MoonwellWrappers.Leaderboard
---@param player MoonwellWrappers.Player
---@param operation string
---@return leaderboard, integer, player
local function itemOf(board, player, operation)
    local raw = registry.require(board, operation)
    local p = Handle.unwrap(player, 'Player', operation)
    if not LeaderboardHasPlayerItem(raw, p) then error('[wrappers] ' .. operation .. ': player has no item', 3) end
    return raw, LeaderboardGetPlayerIndex(raw, p), p
end

---@param raw leaderboard?
---@return MoonwellWrappers.Leaderboard?
---@overload fun(raw: nil): nil
function Leaderboard.fromHandle(raw) return registry.wrap(raw) end
---@param label string?
---@return MoonwellWrappers.Leaderboard
function Leaderboard.create(label)
    local raw = CreateLeaderboard()
    local board = Handle.created(Leaderboard.fromHandle(raw), 'Leaderboard.create')
    if label ~= nil then LeaderboardSetLabel(raw, label) end
    return board
end
---@return leaderboard
function Leaderboard:getHandle() return registry.require(self, 'Leaderboard.getHandle') end
---@return boolean
function Leaderboard:isDisposed() return registry.isDisposed(self, 'Leaderboard.isDisposed') end
---@param text string
function Leaderboard:setLabel(text) LeaderboardSetLabel(registry.require(self, 'Leaderboard.setLabel'), text) end
---@param r integer 0-255
---@param g integer 0-255
---@param b integer 0-255
---@param a integer 0-255
function Leaderboard:setLabelColor(r, g, b, a)
    LeaderboardSetLabelColor(registry.require(self, 'Leaderboard.setLabelColor'), r, g, b, a)
end
---@param r integer 0-255
---@param g integer 0-255
---@param b integer 0-255
---@param a integer 0-255
function Leaderboard:setValueColor(r, g, b, a)
    LeaderboardSetValueColor(registry.require(self, 'Leaderboard.setValueColor'), r, g, b, a)
end
---@param options MoonwellWrappers.LeaderboardStyleOptions?
function Leaderboard:setStyle(options)
    local raw = registry.require(self, 'Leaderboard.setStyle')
    local o = Options.read(options, styleFields, 'Leaderboard.setStyle')
    LeaderboardSetStyle(raw, o.label, o.names, o.values, o.icons)
end
---Adds the player's item and resizes the board. A player has at most one item.
---@param player MoonwellWrappers.Player
---@param label string
---@param value integer
function Leaderboard:addItem(player, label, value)
    local raw = registry.require(self, 'Leaderboard.addItem')
    local p = Handle.unwrap(player, 'Player', 'Leaderboard.addItem')
    if LeaderboardHasPlayerItem(raw, p) then error('[wrappers] Leaderboard.addItem: player already has an item', 2) end
    LeaderboardAddItem(raw, label, value, p)
    resize(raw)
end
---Removes the player's item and resizes the board.
---@param player MoonwellWrappers.Player
function Leaderboard:removeItem(player)
    local raw, _, p = itemOf(self, player, 'Leaderboard.removeItem')
    LeaderboardRemovePlayerItem(raw, p)
    resize(raw)
end
---@param player MoonwellWrappers.Player
---@param value integer
function Leaderboard:setItemValue(player, value)
    local raw, index = itemOf(self, player, 'Leaderboard.setItemValue')
    LeaderboardSetItemValue(raw, index, value)
end
---@param player MoonwellWrappers.Player
---@param label string
function Leaderboard:setItemLabel(player, label)
    local raw, index = itemOf(self, player, 'Leaderboard.setItemLabel')
    LeaderboardSetItemLabel(raw, index, label)
end
---@param player MoonwellWrappers.Player
---@param r integer 0-255
---@param g integer 0-255
---@param b integer 0-255
---@param a integer 0-255
function Leaderboard:setItemLabelColor(player, r, g, b, a)
    local raw, index = itemOf(self, player, 'Leaderboard.setItemLabelColor')
    LeaderboardSetItemLabelColor(raw, index, r, g, b, a)
end
---@param player MoonwellWrappers.Player
---@param r integer 0-255
---@param g integer 0-255
---@param b integer 0-255
---@param a integer 0-255
function Leaderboard:setItemValueColor(player, r, g, b, a)
    local raw, index = itemOf(self, player, 'Leaderboard.setItemValueColor')
    LeaderboardSetItemValueColor(raw, index, r, g, b, a)
end
---@param player MoonwellWrappers.Player
---@param options MoonwellWrappers.LeaderboardItemStyleOptions?
function Leaderboard:setItemStyle(player, options)
    local raw, index = itemOf(self, player, 'Leaderboard.setItemStyle')
    local o = Options.read(options, itemStyleFields, 'Leaderboard.setItemStyle')
    LeaderboardSetItemStyle(raw, index, o.label, o.value, o.icon)
end
---@param player MoonwellWrappers.Player
---@return boolean
function Leaderboard:hasItem(player)
    local raw = registry.require(self, 'Leaderboard.hasItem')
    return LeaderboardHasPlayerItem(raw, Handle.unwrap(player, 'Player', 'Leaderboard.hasItem'))
end
---@return integer
function Leaderboard:getItemCount() return LeaderboardGetItemCount(registry.require(self, 'Leaderboard.getItemCount')) end
---@param ascending boolean
function Leaderboard:sortByValue(ascending)
    LeaderboardSortItemsByValue(registry.require(self, 'Leaderboard.sortByValue'), ascending)
end
---@param ascending boolean
function Leaderboard:sortByLabel(ascending)
    LeaderboardSortItemsByLabel(registry.require(self, 'Leaderboard.sortByLabel'), ascending)
end
---@param ascending boolean
function Leaderboard:sortByPlayer(ascending)
    LeaderboardSortItemsByPlayer(registry.require(self, 'Leaderboard.sortByPlayer'), ascending)
end
---Makes this the leaderboard that player sees. Assign, then show.
---@param player MoonwellWrappers.Player
function Leaderboard:assign(player)
    local raw = registry.require(self, 'Leaderboard.assign')
    PlayerSetLeaderboard(Handle.unwrap(player, 'Player', 'Leaderboard.assign'), raw)
end
---@param flag boolean
function Leaderboard:show(flag) LeaderboardDisplay(registry.require(self, 'Leaderboard.show'), flag) end
function Leaderboard:destroy()
    local raw = registry.dispose(self, 'Leaderboard.destroy')
    if raw then DestroyLeaderboard(raw) end
end

return Leaderboard
