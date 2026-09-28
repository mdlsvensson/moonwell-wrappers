---@class MoonwellWrappers.Registry<T, H>
---@field name string
---@field wrap fun(raw: H?): T?
---@field require fun(value: unknown, operation: string): H
---@field dispose fun(value: unknown, operation: string): H?
---@field isDisposed fun(value: unknown, operation: string): boolean
---@field member fun(value: unknown): H|false|nil

---@class MoonwellWrappers.RegistryOptions
---@field weak boolean? Weak-valued cache: an unreferenced wrapper may be collected and recreated later.
---@field widget boolean? Join the widget family that Handle.unwrapWidget consults.

local Handle = {}
---@type table<string, MoonwellWrappers.Registry>
local loaded = {}
---@type MoonwellWrappers.Registry[]
local widgets = {}

---Private membership, rather than fields or metatables, authenticates instances.
---@param class table
---@param name string
---@param options MoonwellWrappers.RegistryOptions?
---@return MoonwellWrappers.Registry
function Handle.new(class, name, options)
    if loaded[name] then error('[wrappers] duplicate registry: ' .. name, 2) end
    options = options or {}
    local byHandle = options.weak and setmetatable({}, {__mode = 'v'}) or {}
    local members = setmetatable({}, {__mode = 'k'})
    local registry = {name = name}
    class.__index = class
    local function member(value, operation)
        local raw = members[value]
        if raw == nil then error('[wrappers] ' .. operation .. ': expected ' .. name .. ' wrapper', 3) end
        return raw
    end
    function registry.member(value) return members[value] end
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
    loaded[name] = registry
    if options.widget then widgets[#widgets + 1] = registry end
    return registry
end

---Converts a wrapper argument without importing its module: a caller holding one has loaded it.
---@param value unknown
---@param name string
---@param operation string
---@return any
function Handle.unwrap(value, name, operation)
    local registry = loaded[name]
    if registry == nil then error('[wrappers] ' .. operation .. ': expected ' .. name .. ' wrapper', 2) end
    return registry.require(value, operation)
end

---Converts a Unit, Item or Destructable argument.
---@param value unknown
---@param operation string
---@return widget
function Handle.unwrapWidget(value, operation)
    for _, registry in ipairs(widgets) do
        local raw = registry.member(value)
        if raw == false then error('[wrappers] ' .. operation .. ': ' .. registry.name .. ' is disposed', 2) end
        if raw ~= nil then return raw end
    end
    error('[wrappers] ' .. operation .. ': expected Widget wrapper', 2)
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
