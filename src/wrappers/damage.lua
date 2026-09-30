local Callback = require('wrappers.internal.callback')
local Listeners = require('wrappers.internal.listeners')
local Unit = require('wrappers.unit')

---Damage events for every unit: listeners before armor (DAMAGING) and after armor (DAMAGED). Each phase has one shared
---trigger, created by its first listener. Nothing is created at import.
local Damage = {}

---@class MoonwellWrappers.DamageListener

---The hit's data, read once when the firing starts. Every listener of one firing gets the same table, so a setter's
---change is visible to the listeners after it.
---@class MoonwellWrappers.DamageEvent
---@field source MoonwellWrappers.Unit? Nil when the game gives no source.
---@field target MoonwellWrappers.Unit
---@field amount number
---@field isAttack boolean
---@field attackType attacktype
---@field damageType damagetype
---@field weaponType weapontype

---Before armor: the amount and the attack, damage and weapon types can still change.
---@class MoonwellWrappers.DamagingEvent: MoonwellWrappers.DamageEvent
local DamagingEvent = {}
DamagingEvent.__index = DamagingEvent

---After armor: only the amount can still change.
---@class MoonwellWrappers.DamagedEvent: MoonwellWrappers.DamageEvent
local DamagedEvent = {}
DamagedEvent.__index = DamagedEvent

---Events whose firing is still running; setters raise for any other.
---@type table<table, true>
local live = setmetatable({}, {__mode = 'k'})

---@param event table
---@param amount unknown
---@param operation string
local function setAmount(event, amount, operation)
    if not live[event] then error('[wrappers] ' .. operation .. ': the damage event is over', 3) end
    if type(amount) ~= 'number' or amount ~= amount or amount == math.huge or amount == -math.huge then
        error('[wrappers] ' .. operation .. ': expected a finite number', 3)
    end
    BlzSetEventDamage(amount)
    event.amount = amount
end

---@param event table
---@param value unknown
---@param operation string
---@param what string For the error, e.g. 'an attack type'.
local function checkType(event, value, operation, what)
    if not live[event] then error('[wrappers] ' .. operation .. ': the damage event is over', 3) end
    if value == nil then error('[wrappers] ' .. operation .. ': expected ' .. what, 3) end
end

---Sets the hit's amount (BlzSetEventDamage). Negative amounts are passed to the native unchanged.
---@param amount number
function DamagingEvent:setAmount(amount) setAmount(self, amount, 'DamagingEvent.setAmount') end
---Sets the attack type, which picks the armor table (BlzSetEventAttackType).
---@param attackType attacktype
function DamagingEvent:setAttackType(attackType)
    checkType(self, attackType, 'DamagingEvent.setAttackType', 'an attack type')
    BlzSetEventAttackType(attackType)
    self.attackType = attackType
end
---Sets the damage type, which decides immunity and spell reduction (BlzSetEventDamageType).
---@param damageType damagetype
function DamagingEvent:setDamageType(damageType)
    checkType(self, damageType, 'DamagingEvent.setDamageType', 'a damage type')
    BlzSetEventDamageType(damageType)
    self.damageType = damageType
end
---Sets the weapon type, which decides the impact sound (BlzSetEventWeaponType).
---@param weaponType weapontype
function DamagingEvent:setWeaponType(weaponType)
    checkType(self, weaponType, 'DamagingEvent.setWeaponType', 'a weapon type')
    BlzSetEventWeaponType(weaponType)
    self.weaponType = weaponType
end
---Sets the hit's amount after armor (BlzSetEventDamage). Negative amounts are passed to the native unchanged.
---@param amount number
function DamagedEvent:setAmount(amount) setAmount(self, amount, 'DamagedEvent.setAmount') end

---@param trigger trigger
---@param class table DamagingEvent or DamagedEvent.
local function register(trigger, class)
    local event = class == DamagingEvent and EVENT_PLAYER_UNIT_DAMAGING or EVENT_PLAYER_UNIT_DAMAGED
    for index = 0, bj_MAX_PLAYER_SLOTS - 1 do
        -- Warcraft accepts a null filter; the generated JASS signature cannot express that.
        ---@diagnostic disable-next-line: param-type-mismatch
        TriggerRegisterPlayerUnitEvent(trigger, Player(index), event, nil)
    end
end

---@param class table DamagingEvent or DamagedEvent.
---@param cells MoonwellWrappers.ListenerCell[]
local function route(class, cells)
    local event = setmetatable({
        source = Unit.fromHandle(GetEventDamageSource()),
        target = Unit.fromHandle(BlzGetEventDamageTarget()),
        amount = GetEventDamage(),
        isAttack = BlzGetEventIsAttack(),
        attackType = BlzGetEventAttackType(),
        damageType = BlzGetEventDamageType(),
        weaponType = BlzGetEventWeaponType(),
    }, class)
    live[event] = true
    Listeners.call(cells, 'Damage listener', event)
    live[event] = nil
end

local listeners = Listeners.new('DamageListener', register, route)

---Runs `callback` for every hit before armor, behind the callback boundary.
---@param callback fun(event: MoonwellWrappers.DamagingEvent): ...
---@return MoonwellWrappers.DamageListener
function Damage.onDamaging(callback)
    Callback.check(callback, 'Damage.onDamaging')
    return (Listeners.add(listeners, DamagingEvent, callback, 'Damage.onDamaging'))
end

---Runs `callback` for every hit after armor, behind the callback boundary.
---@param callback fun(event: MoonwellWrappers.DamagedEvent): ...
---@return MoonwellWrappers.DamageListener
function Damage.onDamaged(callback)
    Callback.check(callback, 'Damage.onDamaged')
    return (Listeners.add(listeners, DamagedEvent, callback, 'Damage.onDamaged'))
end

---Removes a listener at once, even during a firing. Removing it twice does nothing.
---@param token MoonwellWrappers.DamageListener
function Damage.off(token)
    Listeners.remove(listeners, token, 'Damage.off')
end

return Damage
