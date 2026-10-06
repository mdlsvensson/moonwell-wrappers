---Argument checks shared by every wrapper module. A predicate returns a boolean. A raising form returns its value, or
---raises `[wrappers] <operation>: expected ...` at the line that called the public function: level 3 when the public
---function calls it directly, plus `depth` for each helper frame in between. Never tail-call a raising form: a tail
---call drops the position.
---In Warcraft's Lua NaN compares equal to itself, so no check here can tell NaN from a number in game. Everywhere else,
---the suites included, `finite` and the checks built on it refuse NaN.
local Check = {}

---The game's integers are 32-bit.
local LOWEST, HIGHEST = -2147483648, 2147483647

---A number that is not NaN and not infinite.
---@param value unknown
---@return boolean
function Check.finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

---A finite number greater than 0.
---@param value unknown
---@return boolean
function Check.positive(value)
    return type(value) == 'number' and value == value and value > 0 and value ~= math.huge
end

---A finite number of at least 0.
---@param value unknown
---@return boolean
function Check.nonNegative(value)
    return type(value) == 'number' and value == value and value >= 0 and value ~= math.huge
end

---A number without a fraction that a game integer can hold. A float that holds a whole number (5.0) counts; a whole
---number outside the 32-bit range does not.
---@param value unknown
---@return boolean
function Check.integer(value)
    return type(value) == 'number' and value >= LOWEST and value <= HIGHEST and value % 1 == 0
end

---@param value unknown
---@return boolean
function Check.text(value) return type(value) == 'string' end

---A value as text for a message. A table, function, userdata, thread or nil has no text that is the same on every
---machine (tostring gives an address), so it is shown by its type: `<table>`.
---@param value unknown
---@return string
function Check.show(value)
    local kind = type(value)
    if kind == 'string' or kind == 'number' or kind == 'boolean' then return tostring(value) end
    return '<' .. kind .. '>'
end

---@param operation string
---@param description string What was expected, after "expected ".
---@param level integer The level of the public function's caller, counted from the raising form.
local function fail(operation, description, level)
    -- One more level for this frame.
    error('[wrappers] ' .. operation .. ': expected ' .. description, level + 1)
end

---@param value unknown
---@param name string The argument's name, for example 'amount'.
---@param operation string
---@param depth integer? Helper frames between the public function and this call.
---@return number
function Check.requireFinite(value, name, operation, depth)
    if not Check.finite(value) then fail(operation, 'a finite ' .. name, 3 + (depth or 0)) end
    return value
end

---@param value unknown
---@param name string
---@param operation string
---@param depth integer?
---@return number
function Check.requirePositive(value, name, operation, depth)
    if not Check.positive(value) then fail(operation, 'a finite positive ' .. name, 3 + (depth or 0)) end
    return value
end

---@param value unknown
---@param name string
---@param operation string
---@param depth integer?
---@return number
function Check.requireNonNegative(value, name, operation, depth)
    if not Check.nonNegative(value) then fail(operation, 'a finite non-negative ' .. name, 3 + (depth or 0)) end
    return value
end

---An integer inside the 32-bit range and, when given, inside `min` to `max`.
---@param value unknown
---@param name string
---@param operation string
---@param depth integer?
---@param min integer?
---@param max integer?
---@return integer
function Check.requireInteger(value, name, operation, depth, min, max)
    if not Check.integer(value) or (min ~= nil and value < min) or (max ~= nil and value > max) then
        local description = 'an integer ' .. name
        if min ~= nil and max ~= nil then
            description = description .. ' from ' .. min .. ' to ' .. max
        elseif min ~= nil then
            description = description .. ' of at least ' .. min
        elseif max ~= nil then
            description = description .. ' of at most ' .. max
        end
        fail(operation, description, 3 + (depth or 0))
    end
    return value
end

---@param value unknown
---@param phrase string What the string is, with its article: 'a model path'.
---@param operation string
---@param depth integer?
---@return string
function Check.requireText(value, phrase, operation, depth)
    if type(value) ~= 'string' then fail(operation, phrase, 3 + (depth or 0)) end
    return value
end

return Check
