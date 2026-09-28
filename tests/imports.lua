for _, name in ipairs({'trigger', 'effect', 'timer'}) do require('wrappers.' .. name) end
eq(totalCalls(), 0)

test('modules that only take wrapper arguments load no other public module', function()
    for _, name in ipairs({'unit', 'player', 'group'}) do eq(package.loaded['wrappers.' .. name], nil) end
end)
