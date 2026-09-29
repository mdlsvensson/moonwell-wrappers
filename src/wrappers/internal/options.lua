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

---Level 4 blames the caller of the public function that called Options.read.
---@param operation string
---@param message string
local function fail(operation, message) error('[wrappers] ' .. operation .. ': ' .. message, 4) end

---@param value unknown
---@param name string
---@param operation string
---@return integer[]
local function color(value, name, operation)
    if type(value) ~= 'table' or (#value ~= 3 and #value ~= 4) then
        fail(operation, "option '" .. name .. "' expected {r, g, b, a?} integers")
    end
    for index = 1, #value do
        if not isInteger(value[index]) then fail(operation, "option '" .. name .. "' expected {r, g, b, a?} integers") end
    end
    return {value[1], value[2], value[3], value[4] or 255}
end

---Validates an options table and returns a fresh table with every declared field, defaults filled in. Never modifies
---`options`. Colors come back as fresh {r, g, b, a}; Player options come back as raw player handles.
---@param options unknown
---@param fields MoonwellWrappers.OptionFields
---@param operation string
---@return table<string, any>
function Options.read(options, fields, operation)
    if options ~= nil and type(options) ~= 'table' then fail(operation, 'expected an options table') end
    local given = options or {}
    for key in pairs(given) do
        if fields[key] == nil then fail(operation, "unknown option '" .. tostring(key) .. "'") end
    end
    local result = {}
    for name, field in pairs(fields) do
        local kind, value = field[1], given[name]
        if value == nil then value = field[2] end
        if value ~= nil then
            if kind == 'color' then
                value = color(value, name, operation)
            elseif kind == 'Player' then
                value = Handle.unwrap(value, 'Player', operation)
            elseif not checks[kind](value) then
                fail(operation, "option '" .. name .. "' expected " .. expected[kind])
            end
        end
        result[name] = value
    end
    return result
end

return Options
