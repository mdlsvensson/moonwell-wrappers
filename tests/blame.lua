-- Every failure of every public function is a `[wrappers]` error at the line that called it (spec 2026-10-06 §6),
-- whatever the rest of its message says. The sweep calls every function of every class with no argument, with a table
-- that is no wrapper, and with a live receiver whose later arguments are missing or are that table.
--
-- No native is ever missing here: a global named like a native (a capital letter, then a lower-case one) that nothing
-- defined answers with a stand-in that returns 0, which serves as a handle, a count and an amount alike. So a function
-- that reaches a native runs on, and every failure counts. The natives named below return a fresh handle per call,
-- where the sweep needs distinct objects.

-- Functions that raise a raw Lua error inside the library today, each with the task of the 0.10.0 plan that fixes it.
-- The sweep fails on a misplaced error that is not listed, and on an entry that misplaces none, so the list cannot go
-- stale.
local KNOWN = {
    ['Image.create'] = true, -- Task 11
    ['Image.setPosition'] = true, -- Task 11
    ['Player.addGold'] = true, -- Task 9
    ['Player.addLumber'] = true, -- Task 9
    ['TextTag.setText'] = true, -- Task 11
}

local function stub() return 0 end
setmetatable(_G, {__index = function(_, name)
    if type(name) == 'string' and name:find('^%u%l') then return stub end
    return nil
end})
for _, name in ipairs({'CreateImage', 'CreateQuest', 'CreateTrigger', 'DialogAddButton', 'DialogCreate',
    'QuestCreateItem'}) do
    native(name, function() return {} end)
end

-- {label, module}: the label is the class name the error messages and KNOWN use.
local CLASSES = {
    {'Damage', 'damage'}, {'DefeatCondition', 'defeatcondition'}, {'Destructable', 'destructable'},
    {'Dialog', 'dialog'}, {'Effect', 'effect'}, {'FogModifier', 'fogmodifier'}, {'Force', 'force'},
    {'Frame', 'frame'}, {'Group', 'group'}, {'Image', 'image'}, {'Input', 'input'}, {'Item', 'item'},
    {'Leaderboard', 'leaderboard'}, {'Lightning', 'lightning'}, {'Multiboard', 'multiboard'}, {'Player', 'player'},
    {'Quest', 'quest'}, {'Rect', 'rect'}, {'Region', 'region'}, {'Sound', 'sound'}, {'Sync', 'sync'},
    {'TextTag', 'texttag'}, {'Timer', 'timer'}, {'TimerDialog', 'timerdialog'}, {'Trigger', 'trigger'},
    {'Ubersplat', 'ubersplat'}, {'Unit', 'unit'}, {'WeatherEffect', 'weathereffect'},
}

-- Wrong as a wrapper, a number, a string, a callback and an options table (its key is no option).
local WRONG = {wrong = true}

---@class BlameResult
---@field raised integer How many of the calls failed.
---@field misplaced string? The first failure that was not a wrappers error at the calling line.

---@param result BlameResult
---@param attempt fun() Calls the function as a statement, so the error's position is this file's line.
local function try(result, attempt)
    local ok, err = pcall(attempt)
    if ok then return end
    result.raised = result.raised + 1
    local message = tostring(err)
    if not result.misplaced and not message:find('^%./tests/blame%.lua:%d+: %[wrappers%] ') then
        result.misplaced = message
    end
end

---Calls every function of `class` in each wrong way and records its failures under '<label>.<key>'.
---@param label string
---@param class table
---@param receiver (fun(): table)? Returns a live instance; nil for a module of plain functions.
---@param results table<string, BlameResult>
local function sweep(label, class, receiver, results)
    for key, fn in pairs(class) do
        if type(fn) == 'function' then
            local name = label .. '.' .. key
            local result = results[name] or {raised = 0}
            results[name] = result
            try(result, function() fn() end)
            try(result, function() fn(WRONG) end)
            try(result, function() fn(WRONG, WRONG, WRONG, WRONG, WRONG, WRONG, WRONG, WRONG, WRONG) end)
            if receiver then
                -- A fresh instance per call: some functions dispose their receiver.
                local instance = receiver()
                try(result, function() fn(instance) end)
                instance = receiver()
                try(result, function() fn(instance, WRONG, WRONG, WRONG, WRONG, WRONG, WRONG, WRONG, WRONG) end)
            end
        end
    end
end

test('every failure of every public function is a wrappers error at its caller', function()
    ---@type table<string, BlameResult>
    local results = {}
    local labels = {}
    for index, entry in ipairs(CLASSES) do
        local label, class = entry[1], require('wrappers.' .. entry[2])
        labels[index] = label
        local receiver
        if label == 'Image' then
            -- setPosition needs the size that only Image.create records.
            receiver = function() return class.create('path', 2, 2, 0, 0, 1) end
        elseif class.fromHandle then
            receiver = function() return class.fromHandle({}) end
        end
        sweep(label, class, receiver, results)
    end

    -- The classes no module table exposes are reached through an instance's metatable.
    local Dialog, Quest, Damage = require('wrappers.dialog'), require('wrappers.quest'), require('wrappers.damage')
    local function button() return Dialog.create():addButton('text') end
    sweep('DialogButton', getmetatable(button()), button, results)
    local function item() return Quest.create():addItem('text') end
    sweep('QuestItem', getmetatable(item()), item, results)
    -- A damage event exists only while its trigger's action runs: sweep it there, while its setters work, and again
    -- afterwards, when they refuse an event that is over.
    local actions, events = {}, {}
    native('TriggerAddAction', function(_, action) actions[#actions + 1] = action end)
    local function listener(label)
        return function(event)
            events[#events + 1] = {label, event}
            sweep(label, getmetatable(event), function() return event end, results)
        end
    end
    Damage.onDamaging(listener('DamagingEvent'))
    Damage.onDamaged(listener('DamagedEvent'))
    for _, action in ipairs(actions) do action() end
    eq(#events, 2)
    for _, entry in ipairs(events) do
        sweep(entry[1], getmetatable(entry[2]), function() return entry[2] end, results)
    end
    for _, label in ipairs({'DialogButton', 'QuestItem', 'DamagingEvent', 'DamagedEvent'}) do
        labels[#labels + 1] = label
    end

    local raised, wrong, stale = {}, {}, {}
    for name, result in pairs(results) do
        local label = name:match('^[^.]+')
        raised[label] = (raised[label] or 0) + result.raised
        if result.misplaced and not KNOWN[name] then wrong[#wrong + 1] = name .. ' -> ' .. result.misplaced end
    end
    for name in pairs(KNOWN) do
        if not (results[name] and results[name].misplaced) then stale[#stale + 1] = name end
    end
    for _, label in ipairs(labels) do assert((raised[label] or 0) > 0, label .. ': no function raised') end
    table.sort(wrong)
    table.sort(stale)
    assert(#wrong == 0, #wrong .. ' functions misplace an error and are not in KNOWN:\n' .. table.concat(wrong, '\n'))
    assert(#stale == 0, 'KNOWN names functions that misplace no error: ' .. table.concat(stale, ', '))
end)

test('every function of damage, sync and input refuses a table as its first argument', function()
    for _, name in ipairs({'damage', 'sync', 'input'}) do
        for key, fn in pairs(require('wrappers.' .. name)) do
            if type(fn) == 'function' then
                local ok = pcall(function() fn({}) end)
                assert(not ok, name .. '.' .. key .. ' accepted a table')
            end
        end
    end
end)
