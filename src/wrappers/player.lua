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
---The player the running event is about (GetTriggerPlayer), or nil when it has none.
---@return MoonwellWrappers.Player?
function PlayerWrapper.fromEvent() return registry.wrap(GetTriggerPlayer()) end

---@param index integer Zero-based, including neutral player slots.
---@return MoonwellWrappers.Player
function PlayerWrapper.fromIndex(index)
    if type(index) ~= 'number' or index % 1 ~= 0 or index < 0 or index >= bj_MAX_PLAYER_SLOTS then
        error('[wrappers] Player.fromIndex: expected an integer player slot', 2)
    end
    return (Handle.created(PlayerWrapper.fromHandle(Player(index)), 'Player.fromIndex'))
end

---@return player
function PlayerWrapper:getHandle() return (registry.require(self, 'Player.getHandle')) end
---@return boolean
function PlayerWrapper:isDisposed() return (registry.isDisposed(self, 'Player.isDisposed')) end
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
---@return integer
function PlayerWrapper:getGold()
    return GetPlayerState(registry.require(self, 'Player.getGold'), PLAYER_STATE_RESOURCE_GOLD)
end
---@param value integer
function PlayerWrapper:setGold(value)
    SetPlayerState(registry.require(self, 'Player.setGold'), PLAYER_STATE_RESOURCE_GOLD, value)
end
---Reads the current gold, then sets it.
---@param amount integer
function PlayerWrapper:addGold(amount)
    local raw = registry.require(self, 'Player.addGold')
    SetPlayerState(raw, PLAYER_STATE_RESOURCE_GOLD, GetPlayerState(raw, PLAYER_STATE_RESOURCE_GOLD) + amount)
end
---@return integer
function PlayerWrapper:getLumber()
    return GetPlayerState(registry.require(self, 'Player.getLumber'), PLAYER_STATE_RESOURCE_LUMBER)
end
---@param value integer
function PlayerWrapper:setLumber(value)
    SetPlayerState(registry.require(self, 'Player.setLumber'), PLAYER_STATE_RESOURCE_LUMBER, value)
end
---Reads the current lumber, then sets it.
---@param amount integer
function PlayerWrapper:addLumber(amount)
    local raw = registry.require(self, 'Player.addLumber')
    SetPlayerState(raw, PLAYER_STATE_RESOURCE_LUMBER, GetPlayerState(raw, PLAYER_STATE_RESOURCE_LUMBER) + amount)
end
---@param other MoonwellWrappers.Player
---@param setting alliancetype
---@return boolean
function PlayerWrapper:getAlliance(other, setting)
    local raw = registry.require(self, 'Player.getAlliance')
    return GetPlayerAlliance(raw, registry.require(other, 'Player.getAlliance'), setting)
end
---@param other MoonwellWrappers.Player
---@param setting alliancetype
---@param value boolean
function PlayerWrapper:setAlliance(other, setting, value)
    local raw = registry.require(self, 'Player.setAlliance')
    SetPlayerAlliance(raw, registry.require(other, 'Player.setAlliance'), setting, value)
end
---@param other MoonwellWrappers.Player
---@return boolean
function PlayerWrapper:isAlly(other)
    local raw = registry.require(self, 'Player.isAlly')
    return IsPlayerAlly(raw, registry.require(other, 'Player.isAlly'))
end
---@param other MoonwellWrappers.Player
---@return boolean
function PlayerWrapper:isEnemy(other)
    local raw = registry.require(self, 'Player.isEnemy')
    return IsPlayerEnemy(raw, registry.require(other, 'Player.isEnemy'))
end
---@param techId integer
---@param specificOnly boolean
---@return integer
function PlayerWrapper:getTechCount(techId, specificOnly)
    return GetPlayerTechCount(registry.require(self, 'Player.getTechCount'), techId, specificOnly)
end
---@param techId integer
---@param level integer
function PlayerWrapper:setTechResearched(techId, level)
    SetPlayerTechResearched(registry.require(self, 'Player.setTechResearched'), techId, level)
end
---@param techId integer
---@param levels integer
function PlayerWrapper:addTechResearched(techId, levels)
    AddPlayerTechResearched(registry.require(self, 'Player.addTechResearched'), techId, levels)
end
---@param techId integer
---@param maximum integer
function PlayerWrapper:setTechMaxAllowed(techId, maximum)
    SetPlayerTechMaxAllowed(registry.require(self, 'Player.setTechMaxAllowed'), techId, maximum)
end
---@param abilityId integer
---@param available boolean
function PlayerWrapper:setAbilityAvailable(abilityId, available)
    SetPlayerAbilityAvailable(registry.require(self, 'Player.setAbilityAvailable'), abilityId, available)
end
---@return mapcontrol
function PlayerWrapper:getController() return GetPlayerController(registry.require(self, 'Player.getController')) end
---@return playerslotstate
function PlayerWrapper:getSlotState() return GetPlayerSlotState(registry.require(self, 'Player.getSlotState')) end
---@return race
function PlayerWrapper:getRace() return GetPlayerRace(registry.require(self, 'Player.getRace')) end
---@return integer
function PlayerWrapper:getTeam() return GetPlayerTeam(registry.require(self, 'Player.getTeam')) end
---@return number
function PlayerWrapper:getStartX() return GetPlayerStartLocationX(registry.require(self, 'Player.getStartX')) end
---@return number
function PlayerWrapper:getStartY() return GetPlayerStartLocationY(registry.require(self, 'Player.getStartY')) end
---True only on the machine of this player. Branching on it must not change synchronized game state.
---@return boolean
function PlayerWrapper:isLocal() return registry.require(self, 'Player.isLocal') == GetLocalPlayer() end

return PlayerWrapper
