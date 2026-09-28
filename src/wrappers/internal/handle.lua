---@class MoonwellWrappers.Registry<T, H>
---@field wrap fun(raw: H?): T?
---@field require fun(value: unknown, operation: string): H
---@field dispose fun(value: unknown, operation: string): H?
---@field isDisposed fun(value: unknown, operation: string): boolean

local Handle = {}

---Private membership, rather than fields or metatables, authenticates instances.
---@param class table
---@param name string
---@return MoonwellWrappers.Registry
function Handle.new(class, name)
    local byHandle = {}
    local members = setmetatable({}, {__mode = 'k'})
    local registry = {}
    class.__index = class
    local function member(value, operation)
        local raw = members[value]
        if raw == nil then error('[wrappers] ' .. operation .. ': expected ' .. name .. ' wrapper', 3) end
        return raw
    end
    function registry.wrap(raw)
        if raw == nil then return nil end
        if byHandle[raw] then return byHandle[raw] end
        local value = setmetatable({handle = raw}, class)
        byHandle[raw] = value
        members[value] = raw
        return value
    end
    function registry.require(value, operation)
        local raw = member(value, operation)
        if raw == false then error('[wrappers] ' .. operation .. ': ' .. name .. ' is disposed', 3) end
        return raw
    end
    function registry.dispose(value, operation)
        local raw = member(value, operation)
        if raw == false then return nil end
        members[value] = false
        byHandle[raw] = nil
        value.handle = nil
        return raw
    end
    function registry.isDisposed(value, operation)
        return member(value, operation) == false
    end
    return registry
end

---@generic H
---@param raw H?
---@param operation string
---@return H
function Handle.created(raw, operation)
    if raw == nil then error('[wrappers] ' .. operation .. ': native returned nil', 3) end
    return raw
end

return Handle
