local Handle = require('wrappers.internal.handle')

---@class MoonwellWrappers.Player
---@field handle player? Read-only by convention. Use getHandle for a non-null native handle.
local PlayerWrapper = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Player, player>
local registry = Handle.new(PlayerWrapper, 'Player')

---@param raw player?
---@return MoonwellWrappers.Player?
---@overload fun(raw: nil): nil
function PlayerWrapper.fromHandle(raw) return registry.wrap(raw) end

---@param index integer Zero-based, including neutral player slots.
---@return MoonwellWrappers.Player
function PlayerWrapper.fromIndex(index)
    if type(index) ~= 'number' or index % 1 ~= 0 or index < 0 or index >= bj_MAX_PLAYER_SLOTS then
        error('[wrappers] Player.fromIndex: expected an integer player slot', 2)
    end
    return Handle.created(PlayerWrapper.fromHandle(Player(index)), 'Player.fromIndex')
end

---@return player
function PlayerWrapper:getHandle() return registry.require(self, 'Player.getHandle') end
---@return boolean
function PlayerWrapper:isDisposed() return registry.isDisposed(self, 'Player.isDisposed') end
---@return integer
function PlayerWrapper:getId() return GetPlayerId(registry.require(self, 'Player.getId')) end
---@return string
function PlayerWrapper:getName() return GetPlayerName(registry.require(self, 'Player.getName')) end
---@return playercolor
function PlayerWrapper:getColor() return GetPlayerColor(registry.require(self, 'Player.getColor')) end
---@param state playerstate
---@return integer
function PlayerWrapper:getState(state) return GetPlayerState(registry.require(self, 'Player.getState'), state) end
---@param state playerstate
---@param value integer
function PlayerWrapper:setState(state, value) SetPlayerState(registry.require(self, 'Player.setState'), state, value) end

return PlayerWrapper
