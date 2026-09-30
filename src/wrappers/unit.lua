local Handle = require('wrappers.internal.handle')
local Widget = require('wrappers.internal.widget')
local PlayerWrapper = require('wrappers.player')
local Item = require('wrappers.item')

---@class MoonwellWrappers.Unit: MoonwellWrappers.Widget
---@field handle unit? Read-only by convention; nil after removal.
local Unit = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Unit, unit>
local registry = Handle.new(Unit, 'Unit', {weak = true, widget = true})

---@param raw unit?
---@return MoonwellWrappers.Unit?
---@overload fun(raw: nil): nil
function Unit.fromHandle(raw) return registry.wrap(raw) end

---@param owner MoonwellWrappers.Player
---@param typeId integer
---@param x number
---@param y number
---@param facing number
---@return MoonwellWrappers.Unit
function Unit.create(owner, typeId, x, y, facing)
    local rawOwner = Handle.unwrap(owner, 'Player', 'Unit.create')
    return (Handle.created(Unit.fromHandle(CreateUnit(rawOwner, typeId, x, y, facing)), 'Unit.create'))
end
---@return unit
function Unit:getHandle() return (registry.require(self, 'Unit.getHandle')) end
---@return boolean
function Unit:isDisposed() return (registry.isDisposed(self, 'Unit.isDisposed')) end
---@return integer
function Unit:getTypeId() return GetUnitTypeId(registry.require(self, 'Unit.getTypeId')) end
---@return MoonwellWrappers.Player
function Unit:getOwner()
    return (Handle.created(PlayerWrapper.fromHandle(GetOwningPlayer(registry.require(self, 'Unit.getOwner'))), 'Unit.getOwner'))
end
---@param owner MoonwellWrappers.Player
---@param changeColor boolean
function Unit:setOwner(owner, changeColor)
    local raw = registry.require(self, 'Unit.setOwner')
    SetUnitOwner(raw, Handle.unwrap(owner, 'Player', 'Unit.setOwner'), changeColor)
end
---@return number
function Unit:getX() return GetUnitX(registry.require(self, 'Unit.getX')) end
---@return number
function Unit:getY() return GetUnitY(registry.require(self, 'Unit.getY')) end
---Uses SetUnitPosition, which respects pathing.
---@param x number
---@param y number
function Unit:setPosition(x, y) SetUnitPosition(registry.require(self, 'Unit.setPosition'), x, y) end
---Uses SetUnitX, which ignores pathing.
---@param x number
function Unit:setX(x) SetUnitX(registry.require(self, 'Unit.setX'), x) end
---Uses SetUnitY, which ignores pathing.
---@param y number
function Unit:setY(y) SetUnitY(registry.require(self, 'Unit.setY'), y) end
---@return number
function Unit:getFacing() return GetUnitFacing(registry.require(self, 'Unit.getFacing')) end
---@param facing number
function Unit:setFacing(facing) SetUnitFacing(registry.require(self, 'Unit.setFacing'), facing) end
---@return number
function Unit:getLife() return GetWidgetLife(registry.require(self, 'Unit.getLife')) end
---@param value number
function Unit:setLife(value) SetWidgetLife(registry.require(self, 'Unit.setLife'), value) end
---@return integer
function Unit:getMaxLife() return BlzGetUnitMaxHP(registry.require(self, 'Unit.getMaxLife')) end
---@param value integer
function Unit:setMaxLife(value) BlzSetUnitMaxHP(registry.require(self, 'Unit.setMaxLife'), value) end
---@return number
function Unit:getMana() return GetUnitState(registry.require(self, 'Unit.getMana'), UNIT_STATE_MANA) end
---@param value number
function Unit:setMana(value) SetUnitState(registry.require(self, 'Unit.setMana'), UNIT_STATE_MANA, value) end
---@return integer
function Unit:getMaxMana() return BlzGetUnitMaxMana(registry.require(self, 'Unit.getMaxMana')) end
---@param value integer
function Unit:setMaxMana(value) BlzSetUnitMaxMana(registry.require(self, 'Unit.setMaxMana'), value) end
---@return number
function Unit:getMoveSpeed() return GetUnitMoveSpeed(registry.require(self, 'Unit.getMoveSpeed')) end
---@param speed number
function Unit:setMoveSpeed(speed) SetUnitMoveSpeed(registry.require(self, 'Unit.setMoveSpeed'), speed) end
---@param color playercolor
function Unit:setColor(color) SetUnitColor(registry.require(self, 'Unit.setColor'), color) end
---@param scale number Uniform scale.
function Unit:setScale(scale) SetUnitScale(registry.require(self, 'Unit.setScale'), scale, scale, scale) end
---@param red integer 0-255
---@param green integer 0-255
---@param blue integer 0-255
---@param alpha integer 0-255
function Unit:setVertexColor(red, green, blue, alpha)
    SetUnitVertexColor(registry.require(self, 'Unit.setVertexColor'), red, green, blue, alpha)
end
---@param animation string
function Unit:setAnimation(animation) SetUnitAnimation(registry.require(self, 'Unit.setAnimation'), animation) end
---@param flag boolean
function Unit:pause(flag) PauseUnit(registry.require(self, 'Unit.pause'), flag) end
---@return boolean
function Unit:isPaused() return IsUnitPaused(registry.require(self, 'Unit.isPaused')) end
---@param flag boolean
function Unit:setInvulnerable(flag) SetUnitInvulnerable(registry.require(self, 'Unit.setInvulnerable'), flag) end
---@return boolean
function Unit:isInvulnerable() return BlzIsUnitInvulnerable(registry.require(self, 'Unit.isInvulnerable')) end
---@param visible boolean
function Unit:show(visible) ShowUnit(registry.require(self, 'Unit.show'), visible) end
---@return boolean
function Unit:isHidden() return IsUnitHidden(registry.require(self, 'Unit.isHidden')) end
---@param kind unittype
---@return boolean
function Unit:isType(kind) return IsUnitType(registry.require(self, 'Unit.isType'), kind) end
---@param player MoonwellWrappers.Player
---@return boolean
function Unit:isAlly(player)
    local raw = registry.require(self, 'Unit.isAlly')
    return IsUnitAlly(raw, Handle.unwrap(player, 'Player', 'Unit.isAlly'))
end
---@param player MoonwellWrappers.Player
---@return boolean
function Unit:isEnemy(player)
    local raw = registry.require(self, 'Unit.isEnemy')
    return IsUnitEnemy(raw, Handle.unwrap(player, 'Player', 'Unit.isEnemy'))
end
---@return string
function Unit:getName() return GetUnitName(registry.require(self, 'Unit.getName')) end
---@return integer
function Unit:getCurrentOrder() return GetUnitCurrentOrder(registry.require(self, 'Unit.getCurrentOrder')) end
---Not dead and not removed, by the UnitAlive native (known to Moonwell since 0.5.1).
---@return boolean
function Unit:isAlive() return UnitAlive(registry.require(self, 'Unit.isAlive')) end
---True while the game still has the unit, dead or alive; false once the game has removed it (decay, or removal by code
---that bypassed this wrapper). A disposed wrapper raises, like every method.
---@return boolean
function Unit:exists() return GetUnitTypeId(registry.require(self, 'Unit.exists')) ~= 0 end
function Unit:kill() KillUnit(registry.require(self, 'Unit.kill')) end
function Unit:remove()
    local raw = registry.dispose(self, 'Unit.remove')
    if raw then RemoveUnit(raw) end
end
---@param buffId integer
---@param duration number
function Unit:applyTimedLife(buffId, duration)
    UnitApplyTimedLife(registry.require(self, 'Unit.applyTimedLife'), buffId, duration)
end
---@param target MoonwellWrappers.Widget
---@param amount number
---@param attack boolean
---@param ranged boolean
---@param attackType attacktype
---@param damageType damagetype
---@param weaponType weapontype
---@return boolean
function Unit:damageTarget(target, amount, attack, ranged, attackType, damageType, weaponType)
    local raw = registry.require(self, 'Unit.damageTarget')
    local rawTarget = Handle.unwrapWidget(target, 'Unit.damageTarget')
    return UnitDamageTarget(raw, rawTarget, amount, attack, ranged, attackType, damageType, weaponType)
end

-- Hero. Warcraft's own behavior applies to non-heroes.

---@return boolean
function Unit:isHero() return IsUnitType(registry.require(self, 'Unit.isHero'), UNIT_TYPE_HERO) end
---@return string
function Unit:getHeroName() return GetHeroProperName(registry.require(self, 'Unit.getHeroName')) end
---@return integer
function Unit:getLevel() return GetHeroLevel(registry.require(self, 'Unit.getLevel')) end
---@param level integer
---@param showEffect boolean
function Unit:setLevel(level, showEffect) SetHeroLevel(registry.require(self, 'Unit.setLevel'), level, showEffect) end
---@return integer
function Unit:getXP() return GetHeroXP(registry.require(self, 'Unit.getXP')) end
---@param xp integer
---@param showEffect boolean
function Unit:setXP(xp, showEffect) SetHeroXP(registry.require(self, 'Unit.setXP'), xp, showEffect) end
---@param xp integer
---@param showEffect boolean
function Unit:addXP(xp, showEffect) AddHeroXP(registry.require(self, 'Unit.addXP'), xp, showEffect) end
---@param includeBonuses boolean
---@return integer
function Unit:getStr(includeBonuses) return GetHeroStr(registry.require(self, 'Unit.getStr'), includeBonuses) end
---@param value integer
---@param permanent boolean
function Unit:setStr(value, permanent) SetHeroStr(registry.require(self, 'Unit.setStr'), value, permanent) end
---@param includeBonuses boolean
---@return integer
function Unit:getAgi(includeBonuses) return GetHeroAgi(registry.require(self, 'Unit.getAgi'), includeBonuses) end
---@param value integer
---@param permanent boolean
function Unit:setAgi(value, permanent) SetHeroAgi(registry.require(self, 'Unit.setAgi'), value, permanent) end
---@param includeBonuses boolean
---@return integer
function Unit:getInt(includeBonuses) return GetHeroInt(registry.require(self, 'Unit.getInt'), includeBonuses) end
---@param value integer
---@param permanent boolean
function Unit:setInt(value, permanent) SetHeroInt(registry.require(self, 'Unit.setInt'), value, permanent) end
---@return integer
function Unit:getSkillPoints() return GetHeroSkillPoints(registry.require(self, 'Unit.getSkillPoints')) end
---@param delta integer
---@return boolean
function Unit:modifySkillPoints(delta)
    return UnitModifySkillPoints(registry.require(self, 'Unit.modifySkillPoints'), delta)
end
---@param abilityId integer
function Unit:selectSkill(abilityId) SelectHeroSkill(registry.require(self, 'Unit.selectSkill'), abilityId) end
---@param x number
---@param y number
---@param showEffect boolean
---@return boolean
function Unit:revive(x, y, showEffect) return ReviveHero(registry.require(self, 'Unit.revive'), x, y, showEffect) end

-- Abilities (integer ids).

---@param abilityId integer
---@return boolean
function Unit:addAbility(abilityId) return UnitAddAbility(registry.require(self, 'Unit.addAbility'), abilityId) end
---@param abilityId integer
---@return boolean
function Unit:removeAbility(abilityId)
    return UnitRemoveAbility(registry.require(self, 'Unit.removeAbility'), abilityId)
end
---@param abilityId integer
---@return integer
function Unit:getAbilityLevel(abilityId)
    return GetUnitAbilityLevel(registry.require(self, 'Unit.getAbilityLevel'), abilityId)
end
---@param abilityId integer
---@param level integer
---@return integer
function Unit:setAbilityLevel(abilityId, level)
    return SetUnitAbilityLevel(registry.require(self, 'Unit.setAbilityLevel'), abilityId, level)
end
---@param abilityId integer
---@param permanent boolean
---@return boolean
function Unit:makeAbilityPermanent(abilityId, permanent)
    return UnitMakeAbilityPermanent(registry.require(self, 'Unit.makeAbilityPermanent'), permanent, abilityId)
end
---@param abilityId integer
---@param hidden boolean
function Unit:hideAbility(abilityId, hidden)
    BlzUnitHideAbility(registry.require(self, 'Unit.hideAbility'), abilityId, hidden)
end
---@param abilityId integer
---@param disabled boolean
---@param hideUI boolean
function Unit:disableAbility(abilityId, disabled, hideUI)
    BlzUnitDisableAbility(registry.require(self, 'Unit.disableAbility'), abilityId, disabled, hideUI)
end
---@param abilityId integer
---@param seconds number
function Unit:startCooldown(abilityId, seconds)
    BlzStartUnitAbilityCooldown(registry.require(self, 'Unit.startCooldown'), abilityId, seconds)
end
---@param abilityId integer
function Unit:endCooldown(abilityId) BlzEndUnitAbilityCooldown(registry.require(self, 'Unit.endCooldown'), abilityId) end
---@param abilityId integer
---@return number
function Unit:getCooldownRemaining(abilityId)
    return BlzGetUnitAbilityCooldownRemaining(registry.require(self, 'Unit.getCooldownRemaining'), abilityId)
end

-- Inventory. Slots are zero-based.

---@param raw unit
---@param slot unknown
---@param operation string
local function checkSlot(raw, slot, operation)
    if type(slot) ~= 'number' or slot % 1 ~= 0 or slot < 0 or slot >= UnitInventorySize(raw) then
        error('[wrappers] ' .. operation .. ': expected an inventory slot index', 3)
    end
end
---@return integer
function Unit:getInventorySize() return UnitInventorySize(registry.require(self, 'Unit.getInventorySize')) end
---@param slot integer
---@return MoonwellWrappers.Item?
function Unit:getItemInSlot(slot)
    local raw = registry.require(self, 'Unit.getItemInSlot')
    checkSlot(raw, slot, 'Unit.getItemInSlot')
    return Item.fromHandle(UnitItemInSlot(raw, slot))
end
---@param item MoonwellWrappers.Item
---@return boolean
function Unit:addItem(item)
    local raw = registry.require(self, 'Unit.addItem')
    return UnitAddItem(raw, Handle.unwrap(item, 'Item', 'Unit.addItem'))
end
---@param typeId integer
---@return MoonwellWrappers.Item?
function Unit:addItemById(typeId)
    return Item.fromHandle(UnitAddItemById(registry.require(self, 'Unit.addItemById'), typeId))
end
---@param item MoonwellWrappers.Item
function Unit:removeItem(item)
    local raw = registry.require(self, 'Unit.removeItem')
    UnitRemoveItem(raw, Handle.unwrap(item, 'Item', 'Unit.removeItem'))
end
---@param slot integer
---@return MoonwellWrappers.Item?
function Unit:removeItemFromSlot(slot)
    local raw = registry.require(self, 'Unit.removeItemFromSlot')
    checkSlot(raw, slot, 'Unit.removeItemFromSlot')
    return Item.fromHandle(UnitRemoveItemFromSlot(raw, slot))
end
---@param item MoonwellWrappers.Item
---@return boolean
function Unit:hasItem(item)
    local raw = registry.require(self, 'Unit.hasItem')
    return UnitHasItem(raw, Handle.unwrap(item, 'Item', 'Unit.hasItem'))
end
---@param item MoonwellWrappers.Item
---@param x number
---@param y number
---@return boolean
function Unit:dropItemAt(item, x, y)
    local raw = registry.require(self, 'Unit.dropItemAt')
    return UnitDropItemPoint(raw, Handle.unwrap(item, 'Item', 'Unit.dropItemAt'), x, y)
end
---@param item MoonwellWrappers.Item
---@param slot integer
---@return boolean
function Unit:dropItemToSlot(item, slot)
    local raw = registry.require(self, 'Unit.dropItemToSlot')
    local rawItem = Handle.unwrap(item, 'Item', 'Unit.dropItemToSlot')
    checkSlot(raw, slot, 'Unit.dropItemToSlot')
    return UnitDropItemSlot(raw, rawItem, slot)
end
---@param item MoonwellWrappers.Item
---@return boolean
function Unit:useItem(item)
    local raw = registry.require(self, 'Unit.useItem')
    return UnitUseItem(raw, Handle.unwrap(item, 'Item', 'Unit.useItem'))
end

-- Orders.

---@param order string
---@return boolean
function Unit:issueOrder(order) return IssueImmediateOrder(registry.require(self, 'Unit.issueOrder'), order) end
---@param order string
---@param x number
---@param y number
---@return boolean
function Unit:issuePointOrder(order, x, y)
    return IssuePointOrder(registry.require(self, 'Unit.issuePointOrder'), order, x, y)
end
---@param order string
---@param target MoonwellWrappers.Widget
---@return boolean
function Unit:issueTargetOrder(order, target)
    local raw = registry.require(self, 'Unit.issueTargetOrder')
    return IssueTargetOrder(raw, order, Handle.unwrapWidget(target, 'Unit.issueTargetOrder'))
end
---@param orderId integer
---@return boolean
function Unit:issueOrderById(orderId)
    return IssueImmediateOrderById(registry.require(self, 'Unit.issueOrderById'), orderId)
end
---@param orderId integer
---@param x number
---@param y number
---@return boolean
function Unit:issuePointOrderById(orderId, x, y)
    return IssuePointOrderById(registry.require(self, 'Unit.issuePointOrderById'), orderId, x, y)
end
---@param orderId integer
---@param target MoonwellWrappers.Widget
---@return boolean
function Unit:issueTargetOrderById(orderId, target)
    local raw = registry.require(self, 'Unit.issueTargetOrderById')
    return IssueTargetOrderById(raw, orderId, Handle.unwrapWidget(target, 'Unit.issueTargetOrderById'))
end

-- Unit defines all four shared methods itself (GetUnitX/GetUnitY keep v0.1.0's mapping); install is a no-op here.
Widget.install(Unit, registry)
return Unit
