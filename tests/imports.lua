for _, name in ipairs({'trigger', 'effect', 'timer', 'destructable', 'rect', 'region', 'texttag', 'sound', 'lightning',
    'image', 'ubersplat', 'fogmodifier', 'multiboard', 'leaderboard', 'quest', 'defeatcondition', 'timerdialog'}) do
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

test('the damage module loads Unit and what Unit loads, and nothing else', function()
    require('wrappers.damage')
    eq(totalCalls(), 0)
    eq(package.loaded['wrappers.unit'] ~= nil, true)
    for _, name in ipairs({'group', 'force'}) do eq(package.loaded['wrappers.' .. name], nil) end
end)
