local Callback = {}

---@param value unknown
---@param operation string
function Callback.check(value, operation)
    if type(value) ~= 'function' then error('[wrappers] ' .. operation .. ': expected a callback function', 3) end
end

---@param value unknown
---@param operation string
function Callback.nonnegative(value, operation)
    if type(value) ~= 'number' or value ~= value or value < 0 or value == math.huge then
        error('[wrappers] ' .. operation .. ': expected a finite non-negative number', 3)
    end
end

---@generic T
---@param label string
---@param fn fun(value: T): ...
---@param argument T
function Callback.call(label, fn, argument)
    local ok, message = pcall(fn, argument)
    if not ok then
        local printable, text = pcall(tostring, message)
        print('[wrappers] ' .. label .. ' callback failed: ' .. (printable and text or '<unprintable error>'))
    end
end

return Callback
