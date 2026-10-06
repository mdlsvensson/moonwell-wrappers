local Callback = {}

---Errors point at the caller of the public function (level 3), plus `depth` for helper frames in between.
---@param value unknown
---@param operation string
---@param depth integer?
function Callback.check(value, operation, depth)
    if type(value) ~= 'function' then
        error('[wrappers] ' .. operation .. ': expected a callback function', 3 + (depth or 0))
    end
end

---Accepts nil or a function; used for optional filters. Errors point as those of Callback.check do.
---@param value unknown
---@param operation string
---@param depth integer?
function Callback.optional(value, operation, depth)
    if value ~= nil and type(value) ~= 'function' then
        error('[wrappers] ' .. operation .. ': expected a callback function', 3 + (depth or 0))
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

---Runs a callback behind the callback boundary: an error is printed and does not propagate.
---@param label string
---@param fn function
---@param ... any Passed to fn.
function Callback.call(label, fn, ...)
    local ok, message = pcall(fn, ...)
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
