local Handle = require('wrappers.internal.handle')

---@alias MoonwellWrappers.OptionFields table<string, table> Option name to {kind, default?}.

local Options = {}

---@param value unknown
---@return boolean
local function isInteger(value) return type(value) == 'number' and value % 1 == 0 end

local checks = {
    boolean = function(value) return type(value) == 'boolean' end,
    string = function(value) return type(value) == 'string' end,
    number = function(value) return type(value) == 'number' end,
    integer = isInteger,
    nonnegative = function(value)
        return type(value) == 'number' and value == value and value >= 0 and value ~= math.huge
    end,
}
local expected = {
    boolean = 'a boolean', string = 'a string', number = 'a number', integer = 'an integer',
    nonnegative = 'a finite non-negative number',
}

---@param operation string
---@param message string
---@param level integer Counted from fail.
local function fail(operation, message, level) error('[wrappers] ' .. operation .. ': ' .. message, level) end

---@param value unknown
---@param name string
---@param operation string
---@param level integer The level that points at the caller from Options.read; this frame adds one.
---@return integer[]
local function color(value, name, operation, level)
    local message = "option '" .. name .. "' expected {r, g, b, a?} integers"
    if type(value) ~= 'table' or (#value ~= 3 and #value ~= 4) then fail(operation, message, level + 1) end
    for index = 1, #value do
        if not isInteger(value[index]) then fail(operation, message, level + 1) end
    end
    return {value[1], value[2], value[3], value[4] or 255}
end

---Field names in sorted order, once per field table, so every machine reports the same first error.
local orders = setmetatable({}, {__mode = 'k'})
---@param fields MoonwellWrappers.OptionFields
---@return string[]
local function namesOf(fields)
    local names = orders[fields]
    if names == nil then
        names = {}
        for name in pairs(fields) do names[#names + 1] = name end
        table.sort(names)
        orders[fields] = names
    end
    return names
end

---Validates an options table and returns a fresh table with every declared field, defaults filled in. Never modifies
---`options`. Colors come back as fresh {r, g, b, a}; Player options come back as raw player handles. Errors point at
---the caller of the public function (plus `depth` for helper frames in between), and several errors report the first
---in sorted order.
---@param options unknown
---@param fields MoonwellWrappers.OptionFields
---@param operation string
---@param depth integer?
---@return table<string, any>
function Options.read(options, fields, operation, depth)
    depth = depth or 0
    local level = 4 + depth
    if options ~= nil and type(options) ~= 'table' then fail(operation, 'expected an options table', level) end
    local given = options or {}
    local unknown = {}
    for key in pairs(given) do
        if fields[key] == nil then unknown[#unknown + 1] = tostring(key) end
    end
    if #unknown > 0 then
        table.sort(unknown)
        fail(operation, "unknown option '" .. unknown[1] .. "'", level)
    end
    local result = {}
    for _, name in ipairs(namesOf(fields)) do
        local field = fields[name]
        local kind, value = field[1], given[name]
        if value == nil then value = field[2] end
        if value ~= nil then
            if kind == 'color' then
                value = color(value, name, operation, level)
            elseif kind == 'Player' then
                value = Handle.unwrap(value, 'Player', operation, depth + 1)
            elseif not checks[kind](value) then
                fail(operation, "option '" .. name .. "' expected " .. expected[kind], level)
            end
        end
        result[name] = value
    end
    return result
end

return Options
