local Handle = require('wrappers.internal.handle')
local Options = require('wrappers.internal.options')

---@class MoonwellWrappers.Sound
---@field handle sound? Read-only by convention; nil after destruction.
local Sound = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Sound, sound>
local registry = Handle.new(Sound, 'Sound')

---@class MoonwellWrappers.SoundOptions
---@field looping boolean? Default false.
---@field is3D boolean? Default false.
---@field stopWhenOutOfRange boolean? Default false.
---@field fadeIn integer? Default 10.
---@field fadeOut integer? Default 10.
---@field eax string? Default "DefaultEAXON".

---@class MoonwellWrappers.SoundPlayOnceOptions
---@field volume integer? 0-127; default 127.
---@field x number? With y, makes the sound 3D at that point.
---@field y number? With x, makes the sound 3D at that point.
---@field z number? Default 0.
---@field player MoonwellWrappers.Player? Hear the sound on this player's machine only; default everyone.

---@type MoonwellWrappers.OptionFields
local createFields = {
    looping = {'boolean', false}, is3D = {'boolean', false}, stopWhenOutOfRange = {'boolean', false},
    fadeIn = {'integer', 10}, fadeOut = {'integer', 10}, eax = {'string', 'DefaultEAXON'},
}
---@type MoonwellWrappers.OptionFields
local playOnceFields = {
    volume = {'integer', 127}, x = {'number'}, y = {'number'}, z = {'number', 0}, player = {'Player'},
}

---@param raw sound?
---@return MoonwellWrappers.Sound?
---@overload fun(raw: nil): nil
function Sound.fromHandle(raw) return registry.wrap(raw) end
---Creates an owned sound. It is never released when done: destroy() is its only cleanup.
---@param path string
---@param options MoonwellWrappers.SoundOptions?
---@return MoonwellWrappers.Sound
function Sound.create(path, options)
    local o = Options.read(options, createFields, 'Sound.create')
    local raw = CreateSound(path, o.looping, o.is3D, o.stopWhenOutOfRange, o.fadeIn, o.fadeOut, o.eax)
    return Handle.created(Sound.fromHandle(raw), 'Sound.create')
end
---Plays a sound once and releases it when done. Returns nothing, so no wrapper can go stale. With `player`, the other
---machines play it at volume 0, so every machine starts and releases the sound identically.
---@param path string
---@param options MoonwellWrappers.SoundPlayOnceOptions?
function Sound.playOnce(path, options)
    local o = Options.read(options, playOnceFields, 'Sound.playOnce')
    if (o.x == nil) ~= (o.y == nil) then error('[wrappers] Sound.playOnce: options x and y must be given together', 2) end
    local is3D = o.x ~= nil
    local raw = Handle.created(CreateSound(path, false, is3D, false, 10, 10, 'DefaultEAXON'), 'Sound.playOnce')
    SetSoundVolume(raw, (o.player == nil or o.player == GetLocalPlayer()) and o.volume or 0)
    if is3D then SetSoundPosition(raw, o.x, o.y, o.z) end
    StartSound(raw)
    KillSoundWhenDone(raw)
end
---@return sound
function Sound:getHandle() return registry.require(self, 'Sound.getHandle') end
---@return boolean
function Sound:isDisposed() return registry.isDisposed(self, 'Sound.isDisposed') end
function Sound:play() StartSound(registry.require(self, 'Sound.play')) end
---Starts the sound on that player's machine only. The sound itself exists on every machine.
---@param player MoonwellWrappers.Player
function Sound:playFor(player)
    local raw = registry.require(self, 'Sound.playFor')
    if Handle.unwrap(player, 'Player', 'Sound.playFor') == GetLocalPlayer() then StartSound(raw) end
end
---@param fadeOut boolean?
function Sound:stop(fadeOut) StopSound(registry.require(self, 'Sound.stop'), false, fadeOut or false) end
---@param volume integer 0-127
function Sound:setVolume(volume) SetSoundVolume(registry.require(self, 'Sound.setVolume'), volume) end
---@param pitch number
function Sound:setPitch(pitch) SetSoundPitch(registry.require(self, 'Sound.setPitch'), pitch) end
---@param channel integer
function Sound:setChannel(channel) SetSoundChannel(registry.require(self, 'Sound.setChannel'), channel) end
---@param x number
---@param y number
---@param z number
function Sound:setPosition(x, y, z) SetSoundPosition(registry.require(self, 'Sound.setPosition'), x, y, z) end
---@param unit MoonwellWrappers.Unit
function Sound:attachToUnit(unit)
    local raw = registry.require(self, 'Sound.attachToUnit')
    AttachSoundToUnit(raw, Handle.unwrap(unit, 'Unit', 'Sound.attachToUnit'))
end
---@param min number
---@param max number
function Sound:setDistances(min, max) SetSoundDistances(registry.require(self, 'Sound.setDistances'), min, max) end
---@param cutoff number
function Sound:setDistanceCutoff(cutoff)
    SetSoundDistanceCutoff(registry.require(self, 'Sound.setDistanceCutoff'), cutoff)
end
---@return integer milliseconds
function Sound:getDuration() return GetSoundDuration(registry.require(self, 'Sound.getDuration')) end
function Sound:destroy()
    local raw = registry.dispose(self, 'Sound.destroy')
    if raw then StopSound(raw, true, false) end
end

return Sound
