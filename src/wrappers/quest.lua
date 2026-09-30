local Handle = require('wrappers.internal.handle')
local Options = require('wrappers.internal.options')

---@class MoonwellWrappers.Quest
---@field handle quest? Read-only by convention; nil after destruction.
local Quest = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Quest, quest>
local registry = Handle.new(Quest, 'Quest')

---An item belongs to the quest that made it: the quest's destroy() disposes it.
---@class MoonwellWrappers.QuestItem
---@field handle questitem? Read-only by convention; nil once its quest is destroyed.
local QuestItem = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.QuestItem, questitem>
local itemRegistry = Handle.new(QuestItem, 'QuestItem')

---@class MoonwellWrappers.QuestOptions
---@field title string?
---@field description string?
---@field icon string? Icon path.
---@field required boolean? Required (true) or optional (false); default true.
---@field discovered boolean? Shown in the quest log; default true.

---@type MoonwellWrappers.OptionFields
local questFields = {
    title = {'string'}, description = {'string'}, icon = {'string'}, required = {'boolean', true},
    discovered = {'boolean', true},
}

-- Keyed by wrapper; only indexed, never iterated. Each list is in creation order.
---@type table<MoonwellWrappers.Quest, MoonwellWrappers.QuestItem[]>
local itemsOf = {}
---@type table<MoonwellWrappers.QuestItem, MoonwellWrappers.Quest>
local questOf = setmetatable({}, {__mode = 'k'})

---@param raw quest?
---@return MoonwellWrappers.Quest?
---@overload fun(raw: nil): nil
function Quest.fromHandle(raw) return registry.wrap(raw) end
---@param options MoonwellWrappers.QuestOptions?
---@return MoonwellWrappers.Quest
function Quest.create(options)
    local o = Options.read(options, questFields, 'Quest.create')
    local raw = CreateQuest()
    local quest = Handle.created(Quest.fromHandle(raw), 'Quest.create')
    if o.title ~= nil then QuestSetTitle(raw, o.title) end
    if o.description ~= nil then QuestSetDescription(raw, o.description) end
    if o.icon ~= nil then QuestSetIconPath(raw, o.icon) end
    QuestSetRequired(raw, o.required)
    QuestSetDiscovered(raw, o.discovered)
    return quest
end
---Flashes the quest button, for everyone.
function Quest.flashButton() FlashQuestDialogButton() end
---Updates an open quest log.
function Quest.refresh() ForceQuestDialogUpdate() end
---@return quest
function Quest:getHandle() return (registry.require(self, 'Quest.getHandle')) end
---@return boolean
function Quest:isDisposed() return (registry.isDisposed(self, 'Quest.isDisposed')) end
---@param text string
function Quest:setTitle(text) QuestSetTitle(registry.require(self, 'Quest.setTitle'), text) end
---@param text string
function Quest:setDescription(text) QuestSetDescription(registry.require(self, 'Quest.setDescription'), text) end
---@param path string
function Quest:setIcon(path) QuestSetIconPath(registry.require(self, 'Quest.setIcon'), path) end
---@param flag boolean
function Quest:setRequired(flag) QuestSetRequired(registry.require(self, 'Quest.setRequired'), flag) end
---@return boolean
function Quest:isRequired() return IsQuestRequired(registry.require(self, 'Quest.isRequired')) end
---@param flag boolean
function Quest:setCompleted(flag) QuestSetCompleted(registry.require(self, 'Quest.setCompleted'), flag) end
---@return boolean
function Quest:isCompleted() return IsQuestCompleted(registry.require(self, 'Quest.isCompleted')) end
---@param flag boolean
function Quest:setFailed(flag) QuestSetFailed(registry.require(self, 'Quest.setFailed'), flag) end
---@return boolean
function Quest:isFailed() return IsQuestFailed(registry.require(self, 'Quest.isFailed')) end
---@param flag boolean
function Quest:setDiscovered(flag) QuestSetDiscovered(registry.require(self, 'Quest.setDiscovered'), flag) end
---@return boolean
function Quest:isDiscovered() return IsQuestDiscovered(registry.require(self, 'Quest.isDiscovered')) end
---@param flag boolean
function Quest:setEnabled(flag) QuestSetEnabled(registry.require(self, 'Quest.setEnabled'), flag) end
---@return boolean
function Quest:isEnabled() return IsQuestEnabled(registry.require(self, 'Quest.isEnabled')) end
---@param description string
---@return MoonwellWrappers.QuestItem
function Quest:addItem(description)
    local raw = registry.require(self, 'Quest.addItem')
    local itemRaw = QuestCreateItem(raw)
    local item = Handle.created(itemRegistry.wrap(itemRaw), 'Quest.addItem')
    QuestItemSetDescription(itemRaw, description)
    local list = itemsOf[self] or {}
    itemsOf[self] = list
    list[#list + 1] = item
    questOf[item] = self
    return item
end
---Disposes every item of the quest, then destroys it.
function Quest:destroy()
    local raw = registry.dispose(self, 'Quest.destroy')
    if not raw then return end
    for _, item in ipairs(itemsOf[self] or {}) do itemRegistry.dispose(item, 'Quest.destroy') end
    itemsOf[self] = nil
    DestroyQuest(raw)
end

---@return questitem
function QuestItem:getHandle() return (itemRegistry.require(self, 'QuestItem.getHandle')) end
---@return boolean
function QuestItem:isDisposed() return (itemRegistry.isDisposed(self, 'QuestItem.isDisposed')) end
---@param text string
function QuestItem:setDescription(text)
    QuestItemSetDescription(itemRegistry.require(self, 'QuestItem.setDescription'), text)
end
---@param flag boolean
function QuestItem:setCompleted(flag)
    QuestItemSetCompleted(itemRegistry.require(self, 'QuestItem.setCompleted'), flag)
end
---@return boolean
function QuestItem:isCompleted() return IsQuestItemCompleted(itemRegistry.require(self, 'QuestItem.isCompleted')) end
---The quest that made this item; still answers after the item is disposed.
---@return MoonwellWrappers.Quest
function QuestItem:getQuest()
    itemRegistry.isDisposed(self, 'QuestItem.getQuest')
    return questOf[self]
end

return Quest
