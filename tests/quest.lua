native('CreateQuest', function() return {} end)
native('QuestCreateItem', function() return {} end)
for _, name in ipairs({'QuestSetTitle', 'QuestSetDescription', 'QuestSetIconPath', 'QuestSetRequired',
    'QuestSetCompleted', 'QuestSetFailed', 'QuestSetDiscovered', 'QuestSetEnabled', 'QuestItemSetDescription',
    'QuestItemSetCompleted', 'DestroyQuest', 'FlashQuestDialogButton', 'ForceQuestDialogUpdate'}) do
    native(name, function() end)
end
local Quest = require('wrappers.quest')
eq(totalCalls(), 0)

test('create applies options and always sets required and discovered', function()
    local quest = Quest.create({title = 'Rescue', description = 'Find the prince', icon = 'q.blp', required = false})
    expectCall('QuestSetTitle', quest.handle, 'Rescue')
    expectCall('QuestSetDescription', quest.handle, 'Find the prince')
    expectCall('QuestSetIconPath', quest.handle, 'q.blp')
    expectCall('QuestSetRequired', quest.handle, false)
    expectCall('QuestSetDiscovered', quest.handle, true)
    eq(Quest.fromHandle(quest.handle), quest); eq(Quest.fromHandle(nil), nil)
    eq(quest:getHandle(), quest.handle); eq(quest:isDisposed(), false)
    local plain = Quest.create()
    eq(callCount('QuestSetTitle'), 1)
    expectCall('QuestSetRequired', plain.handle, true); expectCall('QuestSetDiscovered', plain.handle, true)
    quest:destroy(); plain:destroy()
end)

test('bad options fail before CreateQuest', function()
    failsAt(function() Quest.create({titel = 'x'}) end, "Quest.create: unknown option 'titel'")
    failsAt(function() Quest.create({required = 'yes'}) end, "Quest.create: 'required' expected a boolean")
    failsAt(function() Quest.create('Rescue') end, 'Quest.create: expected an options table')
    eq(totalCalls(), 0)
end)

test('setters, getters and statics forward exact arguments', function()
    local quest = Quest.create()
    checkSetters(quest, {{'QuestSetTitle', 'setTitle', 'T'}, {'QuestSetDescription', 'setDescription', 'D'},
        {'QuestSetIconPath', 'setIcon', 'i.blp'}, {'QuestSetRequired', 'setRequired', false},
        {'QuestSetCompleted', 'setCompleted', true}, {'QuestSetFailed', 'setFailed', true},
        {'QuestSetDiscovered', 'setDiscovered', false}, {'QuestSetEnabled', 'setEnabled', false}})
    checkGetters(quest, {{'IsQuestRequired', 'isRequired', true}, {'IsQuestCompleted', 'isCompleted', false},
        {'IsQuestFailed', 'isFailed', true}, {'IsQuestDiscovered', 'isDiscovered', false},
        {'IsQuestEnabled', 'isEnabled', true}})
    Quest.flashButton(); expectCall('FlashQuestDialogButton')
    Quest.refresh(); expectCall('ForceQuestDialogUpdate')
    quest:destroy()
end)

test('quest items belong to their quest', function()
    local quest = Quest.create()
    local first = quest:addItem('Kill the ogre')
    expectCall('QuestCreateItem', quest.handle)
    expectCall('QuestItemSetDescription', first.handle, 'Kill the ogre')
    local second = quest:addItem('Return')
    eq(first:getQuest(), quest); eq(first:getHandle(), first.handle); eq(first:isDisposed(), false)
    checkSetters(first, {{'QuestItemSetDescription', 'setDescription', 'Changed'},
        {'QuestItemSetCompleted', 'setCompleted', true}})
    checkGetters(first, {{'IsQuestItemCompleted', 'isCompleted', true}})
    eq(first.destroy, nil); eq(first.fromHandle, nil)
    failsAt(function() first.getQuest(quest) end, 'QuestItem.getQuest: expected QuestItem wrapper')
    local raw = quest.handle
    quest:destroy(); quest:destroy()
    expectCall('DestroyQuest', raw); eq(callCount('DestroyQuest'), 1)
    eq(first:isDisposed(), true); eq(second:isDisposed(), true); eq(first.handle, nil)
    eq(first:getQuest(), quest)
    checkDisposed(first, {'getHandle', 'setDescription', 'setCompleted', 'isCompleted'})
    checkDisposed(quest, {'getHandle', 'setTitle', 'setDescription', 'setIcon', 'setRequired', 'setCompleted',
        'setFailed', 'setDiscovered', 'setEnabled', 'isRequired', 'isCompleted', 'isFailed', 'isDiscovered',
        'isEnabled', 'addItem'})
end)

test('create and addItem fail clearly when the native returns nil', function()
    native('CreateQuest', function() return nil end)
    failsAt(function() Quest.create() end, 'Quest.create: native returned nil')
    eq(callCount('QuestSetRequired'), 0)
    native('CreateQuest', function() return {} end)
    local quest = Quest.create()
    native('QuestCreateItem', function() return nil end)
    failsAt(function() quest:addItem('x') end, 'Quest.addItem: native returned nil')
    eq(callCount('QuestItemSetDescription'), 0)
    native('QuestCreateItem', function() return {} end)
    quest:destroy()
end)
