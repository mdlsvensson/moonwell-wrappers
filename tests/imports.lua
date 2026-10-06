-- The internal layer first, while nothing else is loaded: what each internal pulls in, and that none of them loads a
-- public module or calls a native.
local function loadedWrappers()
    local names = {}
    for name in pairs(package.loaded) do
        if name:find('^wrappers%.') then names[#names + 1] = name end
    end
    table.sort(names)
    return table.concat(names, ' ')
end
require('wrappers.internal.check')
eq(loadedWrappers(), 'wrappers.internal.check')
require('wrappers.internal.cells')
eq(loadedWrappers(), 'wrappers.internal.callback wrappers.internal.cells wrappers.internal.check')
for _, name in ipairs({'callback', 'handle', 'options', 'listeners'}) do require('wrappers.internal.' .. name) end
for name in loadedWrappers():gmatch('%S+') do
    assert(name:find('^wrappers%.internal%.'), 'an internal module loaded ' .. name)
end
eq(totalCalls(), 0)

for _, name in ipairs({'trigger', 'effect', 'timer', 'destructable', 'rect', 'region', 'texttag', 'sound', 'lightning',
    'image', 'ubersplat', 'fogmodifier', 'multiboard', 'leaderboard', 'quest', 'defeatcondition', 'timerdialog',
    'weathereffect'}) do
    require('wrappers.' .. name)
end
eq(totalCalls(), 0)

test('modules that only take wrapper arguments load no other public module', function()
    for _, name in ipairs({'unit', 'player', 'group', 'item', 'force'}) do eq(package.loaded['wrappers.' .. name], nil) end
end)

test('the dialog module loads the Player module and no other', function()
    require('wrappers.dialog')
    eq(totalCalls(), 0)
    eq(package.loaded['wrappers.player'] ~= nil, true)
    for _, name in ipairs({'unit', 'group', 'item', 'force'}) do eq(package.loaded['wrappers.' .. name], nil) end
end)

test('the frame module loads the Player module and no other', function()
    require('wrappers.frame')
    eq(totalCalls(), 0)
    eq(package.loaded['wrappers.player'] ~= nil, true)
    for _, name in ipairs({'unit', 'group', 'item', 'force'}) do eq(package.loaded['wrappers.' .. name], nil) end
end)

test('the sync module loads the Player module and no other', function()
    require('wrappers.sync')
    eq(totalCalls(), 0)
    eq(package.loaded['wrappers.player'] ~= nil, true)
    for _, name in ipairs({'unit', 'group', 'item', 'force'}) do eq(package.loaded['wrappers.' .. name], nil) end
end)

test('the input module loads the Player module and no other', function()
    require('wrappers.input')
    eq(totalCalls(), 0)
    eq(package.loaded['wrappers.player'] ~= nil, true)
    for _, name in ipairs({'unit', 'group', 'item', 'force'}) do eq(package.loaded['wrappers.' .. name], nil) end
end)

test('the damage module loads Unit and what Unit loads, and nothing else', function()
    require('wrappers.damage')
    eq(totalCalls(), 0)
    eq(package.loaded['wrappers.unit'] ~= nil, true)
    for _, name in ipairs({'group', 'force'}) do eq(package.loaded['wrappers.' .. name], nil) end
end)

test('internal/widget is annotations only: no module loads it', function()
    require('wrappers.unit'); require('wrappers.item'); require('wrappers.destructable')
    eq(package.loaded['wrappers.internal.widget'], nil)
end)

test('the callback module is the boundary only', function()
    local names = {}
    for name in pairs(require('wrappers.internal.callback')) do names[#names + 1] = name end
    table.sort(names)
    eq(table.concat(names, ' '), 'call check optional test')
end)
