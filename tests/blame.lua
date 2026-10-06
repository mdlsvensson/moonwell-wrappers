-- Every failure the sweep provokes is a `[wrappers]` error at the line that called the public function (spec
-- 2026-10-06 §6), whatever the rest of its message says. The sweep calls every function of every class with each
-- argument list of `shapesOf`, bare and behind a live receiver: no argument, a table that is no wrapper, and one to
-- four fillers of one kind (a number, a string, a boolean, a function or a Player wrapper) followed by nothing, by
-- that table or, after up to three, by a filler of another kind. A filler stands for a valid argument, so the check
-- behind it is reached, and for a wrong one that is no table.
--
-- No native is ever missing here: a global named like a native (a capital letter, then a lower-case one) that nothing
-- defined answers with a stand-in that returns 0, which serves as a handle, a count and an amount alike. So a function
-- that reaches a native runs on, and every failure counts. The natives named below return a fresh handle per call,
-- where the sweep needs distinct objects. The stand-in also answers for a name that is no native: a misspelt native
-- in `src` passes this suite, and only a suite that defines its natives one by one (or the integration) catches it.
--
-- What the sweep does not reach, so a green run proves nothing about it:
-- - a check behind an argument that no filler satisfies: a wrapper of another class than Player, or a mix of kinds
--   that no shape builds (three different kinds in a row);
-- - a check on the value of an argument of the right kind, where it has an error of its own: an empty prefix, a
--   string over a limit, an index outside a count (the fillers are 1, 'text', true);
-- - an error that depends on what a native answers ("native returned nil", "no frame named ..."): the stand-in
--   always answers 0;
-- - code inside a callback that a native would call (an enumeration, a filter, a timer or a trigger action);
-- - a receiver in a state the suite does not build: a disposed wrapper, a frame the library created, an image
--   wrapped with fromHandle, a multiboard with rows;
-- - a function that fails for none of the shapes (every fromHandle and fromEvent, a create without a checked
--   argument).
-- A check that only one of those reaches is pinned with `failsAt` in its own suite.

-- Arithmetic on an argument that nothing checked: a raw Lua error at a library line. Lua words it one way for a nil,
-- a boolean, a function or a table ("attempt to perform arithmetic on a nil value") and another for a string that is
-- no number ("attempt to div a 'string' with a 'number'").
local ARITHMETIC = {'attempt to perform arithmetic on a', "' with a '"}

-- Functions that misplace an error today, each with the fragments of that error's message and the task of the 0.10.0
-- plan that fixes it. An entry shields only failures that hold one of its fragments: the sweep fails on any other
-- misplaced error, listed or not, and on an entry whose error no longer occurs, so the list cannot go stale.
---@type table<string, string[]>
local KNOWN = {
    ['Image.create'] = ARITHMETIC, -- Task 11
    ['Image.setPosition'] = ARITHMETIC, -- Task 11
    ['TextTag.setText'] = ARITHMETIC, -- Task 11
}

-- A constant, so the stand-in does not answer for it: Sync.on reads it once a shape gives it a prefix and a callback.
bj_MAX_PLAYERS = 24

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
-- More arguments than any function takes.
local PAD = 9

---The argument lists every function is called with. Each list has no hole, so its length is its argument count.
---@param fillers any[] One value of each kind; none is a table without a metatable.
---@return any[][]
local function shapesOf(fillers)
    local padded = {}
    for index = 1, PAD do padded[index] = WRONG end
    local lists = {{}, {WRONG}, padded}
    for _, filler in ipairs(fillers) do
        for count = 1, 4 do
            -- The fillers alone (the next argument is missing), and followed by the table.
            local alone, before = {}, {}
            for index = 1, count do alone[index], before[index] = filler, filler end
            for index = count + 1, PAD do before[index] = WRONG end
            lists[#lists + 1] = alone
            lists[#lists + 1] = before
            -- Followed by one filler of another kind: wrong where the table is right (an options table), and valid
            -- where the function takes two kinds (a prefix and a callback).
            if count < 4 then
                for _, other in ipairs(fillers) do
                    if other ~= filler then
                        local mixed = {}
                        for index = 1, count do mixed[index] = filler end
                        mixed[count + 1] = other
                        lists[#lists + 1] = mixed
                    end
                end
            end
        end
    end
    return lists
end

---@class BlameResult
---@field raised integer How many of the calls failed.
---@field known string[]? The function's fragments in KNOWN.
---@field shielded boolean? A failure was misplaced and held one of those fragments.
---@field unexpected string? The first misplaced failure that held none of them.

---@param result BlameResult
---@param attempt fun() Calls the function as a statement on the line that defines `attempt`, so the error's position
---is that line: a level two or more too high names another line of this file, and one too high names none.
local function try(result, attempt)
    local ok, err = pcall(attempt)
    if ok then return end
    result.raised = result.raised + 1
    local message = tostring(err)
    local line = debug.getinfo(attempt, 'S').linedefined
    if message:find('^%./tests/blame%.lua:' .. line .. ': %[wrappers%] ') then return end
    for _, fragment in ipairs(result.known or {}) do
        if message:find(fragment, 1, true) then
            result.shielded = true
            return
        end
    end
    if not result.unexpected then result.unexpected = message end
end

---Calls every function of `class` with every shape and records its failures under '<label>.<key>'.
---@param label string
---@param class table
---@param receiver (fun(): table)? Returns a live instance; nil for a module of plain functions.
---@param results table<string, BlameResult>
---@param shapes any[][]
local function sweep(label, class, receiver, results, shapes)
    for key, fn in pairs(class) do
        if type(fn) == 'function' then
            local name = label .. '.' .. key
            local result = results[name]
            if not result then
                result = {raised = 0, known = KNOWN[name]}
                results[name] = result
            end
            for index = 1, #shapes do
                local list = shapes[index]
                local count = #list
                try(result, function() fn(table.unpack(list, 1, count)) end)
                if receiver then
                    -- A fresh instance per call: some functions dispose their receiver.
                    local instance = receiver()
                    try(result, function() fn(instance, table.unpack(list, 1, count)) end)
                end
            end
        end
    end
end

test('every failure the sweep provokes is a wrappers error at the line that called the function', function()
    ---@type table<string, BlameResult>
    local results = {}
    local shapes = shapesOf({1, 'text', true, function() end, require('wrappers.player').fromHandle({})})

    -- A damage event exists only while its trigger's action runs: sweep it there, while its setters work, and again
    -- afterwards, when they refuse an event that is over. This comes before the main sweep, whose function fillers
    -- register listeners of their own: the two actions caught here are the damage triggers' and nothing else's.
    local Damage = require('wrappers.damage')
    local actions, events = {}, {}
    native('TriggerAddAction', function(_, action)
        actions[#actions + 1] = action
        return 0
    end)
    local function listener(label)
        return function(event)
            events[#events + 1] = {label, event}
            sweep(label, getmetatable(event), function() return event end, results, shapes)
        end
    end
    Damage.onDamaging(listener('DamagingEvent'))
    Damage.onDamaged(listener('DamagedEvent'))
    native('TriggerAddAction', stub)
    eq(#actions, 2)
    for _, action in ipairs(actions) do action() end
    eq(#events, 2)
    -- A listener runs behind the callback boundary: an error inside the sweep itself would only be printed.
    assert(#PRINTED == 0, 'the sweep inside a damage listener failed: ' .. tostring(PRINTED[1]))
    for _, entry in ipairs(events) do
        sweep(entry[1], getmetatable(entry[2]), function() return entry[2] end, results, shapes)
    end

    local labels = {'DamagingEvent', 'DamagedEvent', 'DialogButton', 'QuestItem'}
    for _, entry in ipairs(CLASSES) do
        local label, class = entry[1], require('wrappers.' .. entry[2])
        labels[#labels + 1] = label
        local receiver
        if label == 'Image' then
            -- setPosition needs the size that only Image.create records.
            receiver = function() return class.create('path', 2, 2, 0, 0, 1) end
        elseif class.fromHandle then
            receiver = function() return class.fromHandle({}) end
        end
        sweep(label, class, receiver, results, shapes)
    end

    -- The classes no module table exposes are reached through an instance's metatable.
    local Dialog, Quest = require('wrappers.dialog'), require('wrappers.quest')
    local function button() return Dialog.create():addButton('text') end
    sweep('DialogButton', getmetatable(button()), button, results, shapes)
    local function item() return Quest.create():addItem('text') end
    sweep('QuestItem', getmetatable(item()), item, results, shapes)

    local raised, wrong, stale = {}, {}, {}
    for name, result in pairs(results) do
        local label = name:match('^[^.]+')
        raised[label] = (raised[label] or 0) + result.raised
        if result.unexpected then wrong[#wrong + 1] = name .. ' -> ' .. result.unexpected end
    end
    for name in pairs(KNOWN) do
        if not (results[name] and results[name].shielded) then stale[#stale + 1] = name end
    end
    for _, label in ipairs(labels) do assert((raised[label] or 0) > 0, label .. ': no function raised') end
    table.sort(wrong)
    table.sort(stale)
    -- Both lists in one failure: a change that fixes one known function and breaks another shows both at once.
    local report = {}
    if #wrong > 0 then
        report[#report + 1] = #wrong .. ' functions misplace an error that KNOWN does not name:\n'
            .. table.concat(wrong, '\n')
    end
    if #stale > 0 then
        report[#report + 1] = 'KNOWN names errors that no longer occur: ' .. table.concat(stale, ', ')
    end
    assert(#report == 0, table.concat(report, '\n'))
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
