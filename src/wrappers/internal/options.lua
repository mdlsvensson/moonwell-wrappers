local Handle = require('wrappers.internal.handle')
local Check = require('wrappers.internal.check')

---@alias MoonwellWrappers.OptionFields table<string, table> Option name to {kind, default?}.

local Options = {}

---What each plain kind accepts. The kinds `color` and `Player` convert their value and are handled in `convert`.
---@type table<string, fun(value: unknown): boolean>
local checks = {
    boolean = function(value) return type(value) == 'boolean' end,
    string = Check.text,
    number = function(value) return type(value) == 'number' end,
    integer = Check.integer,
    nonnegative = Check.nonNegative,
}
---How a message describes each kind, after "'<name>' expected ".
---@type table<string, string>
local expected = {
    boolean = 'a boolean', string = 'a string', number = 'a number', integer = 'an integer',
    nonnegative = 'a finite non-negative number', color = '{r, g, b, a?} integers',
}

---A fresh {r, g, b, a} from a color option, or nil when it is not a table of three or four integers.
---@param value unknown
---@return integer[]?
local function color(value)
    if type(value) ~= 'table' then return nil end
    local count = #value
    if count ~= 3 and count ~= 4 then return nil end
    for index = 1, count do
        if not Check.integer(value[index]) then return nil end
    end
    return {value[1], value[2], value[3], value[4] or 255}
end

---Checks one value of one field and returns what the result holds for it: the value, a fresh color, or a raw player
---handle. Its errors point at the caller of the public function when Options.read calls it directly; `depth` counts
---any further frames in between.
---@param kind string
---@param value unknown
---@param name string
---@param operation string
---@param depth integer
---@return any
local function convert(kind, value, name, operation, depth)
    if kind == 'color' then
        local copy = color(value)
        if copy then return copy end
    elseif kind == 'Player' then
        return (Handle.unwrap(value, 'Player', operation, depth + 2))
    elseif checks[kind](value) then
        return value
    end
    error('[wrappers] ' .. operation .. ": '" .. name .. "' expected " .. expected[kind], depth + 4)
end

---What Options.read needs of a field table, worked out at its first read.
---@class MoonwellWrappers.OptionPlan
---@field names string[] Every field name, sorted, so several errors report the same first one on every machine.
---@field defaults table<string, any> The declared defaults, checked and converted once.
---@field plain string[] The names whose default is copied as it is.
---@field colors string[] The names whose default is a color: each read gets a fresh copy.

---@type table<MoonwellWrappers.OptionFields, MoonwellWrappers.OptionPlan>
local plans = setmetatable({}, {__mode = 'k'})

---@param fields MoonwellWrappers.OptionFields
---@param operation string
---@param depth integer Frames between the public function and Options.read.
---@return MoonwellWrappers.OptionPlan
local function planOf(fields, operation, depth)
    local plan = plans[fields]
    if plan then return plan end
    plan = {names = {}, defaults = {}, plain = {}, colors = {}}
    for name in pairs(fields) do plan.names[#plan.names + 1] = name end
    table.sort(plan.names)
    for _, name in ipairs(plan.names) do
        local kind, default = fields[name][1], fields[name][2]
        if default ~= nil then
            plan.defaults[name] = convert(kind, default, name, operation, depth + 1)
            local list = kind == 'color' and plan.colors or plan.plain
            list[#list + 1] = name
        end
    end
    plans[fields] = plan
    return plan
end

---Validates an options table and returns a fresh table with every declared field, defaults filled in. Never modifies
---`options`. Colors come back as fresh {r, g, b, a}; Player options come back as raw player handles. A table with a
---metatable (a wrapper passed by mistake) is not an options table. Errors point at the caller of the public function
---(plus `depth` for helper frames in between): an unknown key first, the smallest by its text, then the first wrong
---value by field name. A field table is read once, at its first use: do not change it afterwards.
---@param options unknown
---@param fields MoonwellWrappers.OptionFields
---@param operation string
---@param depth integer?
---@return table<string, any>
function Options.read(options, fields, operation, depth)
    depth = depth or 0
    local plan = planOf(fields, operation, depth)
    local defaults = plan.defaults
    local result = {}
    if options == nil then
        -- The usual call: nothing to check, the defaults are copied.
        local plain, colors = plan.plain, plan.colors
        for index = 1, #plain do
            local name = plain[index]
            result[name] = defaults[name]
        end
        for index = 1, #colors do
            local name = colors[index]
            local default = defaults[name]
            result[name] = {default[1], default[2], default[3], default[4]}
        end
        return result
    end
    if type(options) ~= 'table' or getmetatable(options) ~= nil then
        error('[wrappers] ' .. operation .. ': expected an options table', depth + 3)
    end
    local unknown
    for key in pairs(options) do
        if fields[key] == nil then
            local shown = Check.show(key)
            if unknown == nil or shown < unknown then unknown = shown end
        end
    end
    if unknown then error('[wrappers] ' .. operation .. ": unknown option '" .. unknown .. "'", depth + 3) end
    local names = plan.names
    for index = 1, #names do
        local name = names[index]
        local kind, value = fields[name][1], options[name]
        if value ~= nil then
            result[name] = convert(kind, value, name, operation, depth)
        elseif kind == 'color' then
            local default = defaults[name]
            if default then result[name] = {default[1], default[2], default[3], default[4]} end
        else
            result[name] = defaults[name]
        end
    end
    return result
end

return Options
