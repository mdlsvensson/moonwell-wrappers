local Handle = require('wrappers.internal.handle')
local PlayerWrapper = require('wrappers.player')

---@class MoonwellWrappers.Force
---@field handle force? Read-only by convention; nil after destruction.
local Force = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Force, force>
local registry = Handle.new(Force, 'Force')

---@param raw force?
---@return MoonwellWrappers.Force?
---@overload fun(raw: nil): nil
function Force.fromHandle(raw) return registry.wrap(raw) end
---@return MoonwellWrappers.Force
function Force.create() return Handle.created(Force.fromHandle(CreateForce()), 'Force.create') end
---@return force
function Force:getHandle() return registry.require(self, 'Force.getHandle') end
---@return boolean
function Force:isDisposed() return registry.isDisposed(self, 'Force.isDisposed') end
---@param player MoonwellWrappers.Player
function Force:add(player)
    local raw = registry.require(self, 'Force.add')
    ForceAddPlayer(raw, Handle.unwrap(player, 'Player', 'Force.add'))
end
---@param player MoonwellWrappers.Player
function Force:remove(player)
    local raw = registry.require(self, 'Force.remove')
    ForceRemovePlayer(raw, Handle.unwrap(player, 'Player', 'Force.remove'))
end
---@param player MoonwellWrappers.Player
---@return boolean
function Force:contains(player)
    local raw = registry.require(self, 'Force.contains')
    return IsPlayerInForce(Handle.unwrap(player, 'Player', 'Force.contains'), raw)
end
function Force:clear() ForceClear(registry.require(self, 'Force.clear')) end
---Clears the force, then adds every player.
function Force:enumPlayers()
    local raw = registry.require(self, 'Force.enumPlayers')
    ForceClear(raw)
    -- Warcraft accepts a null filter; the generated JASS signature cannot express that.
    ---@diagnostic disable-next-line: param-type-mismatch
    ForceEnumPlayers(raw, nil)
end
---Clears the force, then adds the allies of a player.
---@param player MoonwellWrappers.Player
function Force:enumAllies(player)
    local raw = registry.require(self, 'Force.enumAllies')
    local rawPlayer = Handle.unwrap(player, 'Player', 'Force.enumAllies')
    ForceClear(raw)
    -- Warcraft accepts a null filter; the generated JASS signature cannot express that.
    ---@diagnostic disable-next-line: param-type-mismatch
    ForceEnumAllies(raw, rawPlayer, nil)
end
---Clears the force, then adds the enemies of a player.
---@param player MoonwellWrappers.Player
function Force:enumEnemies(player)
    local raw = registry.require(self, 'Force.enumEnemies')
    local rawPlayer = Handle.unwrap(player, 'Player', 'Force.enumEnemies')
    ForceClear(raw)
    -- Warcraft accepts a null filter; the generated JASS signature cannot express that.
    ---@diagnostic disable-next-line: param-type-mismatch
    ForceEnumEnemies(raw, rawPlayer, nil)
end
---A new dense snapshot; later force changes do not alter it.
---@return MoonwellWrappers.Player[]
function Force:getPlayers()
    local raw = registry.require(self, 'Force.getPlayers')
    local result = {}
    ForForce(raw, function()
        local player = PlayerWrapper.fromHandle(GetEnumPlayer())
        if player then result[#result + 1] = player end
    end)
    return result
end
function Force:destroy()
    local raw = registry.dispose(self, 'Force.destroy')
    if raw then DestroyForce(raw) end
end

return Force
