local Callback = {}

---@param value unknown
---@param operation string
function Callback.check(value, operation)
    if type(value) ~= 'function' then error('[wrappers] ' .. operation .. ': expected a callback function', 3) end
end

---Accepts nil or a function; used for optional filters.
---@param value unknown
---@param operation string
function Callback.optional(value, operation)
    if value ~= nil and type(value) ~= 'function' then
        error('[wrappers] ' .. operation .. ': expected a callback function', 3)
    end
end

---@param value unknown
---@param operation string
function Callback.nonnegative(value, operation)
    if type(value) ~= 'number' or value ~= value or value < 0 or value == math.huge then
        error('[wrappers] ' .. operation .. ': expected a finite non-negative number', 3)
    end
end

---@param label string
---@param message unknown
local function report(label, message)
    local printable, text = pcall(tostring, message)
    print('[wrappers] ' .. label .. ' failed: ' .. (printable and text or '<unprintable error>'))
end

---@generic T
---@param label string
---@param fn fun(value: T): ...
---@param argument T
function Callback.call(label, fn, argument)
    local ok, message = pcall(fn, argument)
    if not ok then report(label .. ' callback', message) end
end

---Runs a predicate behind the callback boundary: an error is printed and counts as false.
---@generic T
---@param label string
---@param fn fun(value: T): any
---@param argument T
---@return boolean
function Callback.test(label, fn, argument)
    local ok, result = pcall(fn, argument)
    if not ok then
        report(label, result)
        return false
    end
    return not not result
end

return Callback
