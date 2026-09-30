-- Every wrapper error points at the line that called the public function (spec 2026-09-30 §2). The sweep calls every
-- function of every class with an empty table as its first argument: each "expected <Class> wrapper" error must point
-- at this file. No natives are defined here, so functions that reach a native fail differently and are skipped.
local modules = {
    'defeatcondition', 'destructable', 'dialog', 'effect', 'fogmodifier', 'force', 'frame', 'group', 'image', 'item',
    'leaderboard', 'lightning', 'multiboard', 'player', 'quest', 'rect', 'region', 'sound', 'texttag', 'timer',
    'timerdialog', 'trigger', 'ubersplat', 'unit',
}

test('every function given a wrong wrapper points at its caller', function()
    local wrong = {}
    for _, name in ipairs(modules) do
        local class = require('wrappers.' .. name)
        local checked = 0
        for key, fn in pairs(class) do
            if type(fn) == 'function' then
                local ok, err = pcall(function() fn({}) end)
                local message = tostring(err)
                if not ok and message:find('expected %w+ wrapper') then
                    checked = checked + 1
                    if not message:find('^%./tests/blame%.lua:%d+: ') then
                        wrong[#wrong + 1] = name .. '.' .. tostring(key) .. ' -> ' .. message
                    end
                end
            end
        end
        assert(checked > 0, name .. ': no function was checked')
    end
    table.sort(wrong)
    assert(#wrong == 0, #wrong .. ' misplaced errors:\n' .. table.concat(wrong, '\n'))
end)

test('damage and sync functions given wrong arguments point at their caller', function()
    local wrong, checked = {}, 0
    for _, name in ipairs({'damage', 'sync'}) do
        for key, fn in pairs(require('wrappers.' .. name)) do
            if type(fn) == 'function' then
                local ok, err = pcall(function() fn({}) end)
                assert(not ok, name .. '.' .. key .. ' accepted a table')
                checked = checked + 1
                if not tostring(err):find('^%./tests/blame%.lua:%d+: ') then
                    wrong[#wrong + 1] = name .. '.' .. key .. ' -> ' .. tostring(err)
                end
            end
        end
    end
    eq(checked, 6)
    table.sort(wrong)
    assert(#wrong == 0, #wrong .. ' misplaced errors:\n' .. table.concat(wrong, '\n'))
end)
