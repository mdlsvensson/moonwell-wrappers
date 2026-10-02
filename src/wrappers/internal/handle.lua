---@class MoonwellWrappers.Registry<T, H>
---@field name string
---@field wrap fun(raw: H?): T?
---@field require fun(value: unknown, operation: string, depth: integer?): H
---@field dispose fun(value: unknown, operation: string): H?
---@field isDisposed fun(value: unknown, operation: string): boolean
---@field live fun(value: unknown, operation: string): H?
---@field sweep fun(gone: fun(raw: H): boolean)
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
    local function expected(operation) return '[wrappers] ' .. operation .. ': expected ' .. name .. ' wrapper' end
    local function disposed(operation) return '[wrappers] ' .. operation .. ': ' .. name .. ' is disposed' end
    function registry.member(value) return members[value] end
    function registry.wrap(raw)
        if raw == nil then return nil end
        if byHandle[raw] then return byHandle[raw] end
        local value = setmetatable({handle = raw}, class)
        byHandle[raw] = value
        members[value] = raw
        return value
    end
    ---One lookup on the happy path. Errors point at the caller of the public function that called this (level 3),
    ---plus `depth` for helper frames in between.
    function registry.require(value, operation, depth)
        local raw = members[value]
        if raw then return raw end
        local level = 3 + (depth or 0)
        if raw == false then error(disposed(operation), level) end
        error(expected(operation), level)
    end
    function registry.dispose(value, operation)
        local raw = members[value]
        if raw == false then return nil end
        if raw == nil then error(expected(operation), 3) end
        members[value] = false
        byHandle[raw] = nil
        value.handle = nil
        return raw
    end
    function registry.isDisposed(value, operation)
        local raw = members[value]
        if raw == nil then error(expected(operation), 3) end
        return raw == false
    end
    ---Like require, but a disposed wrapper gives nil instead of raising.
    function registry.live(value, operation)
        local raw = members[value]
        if raw then return raw end
        if raw == nil then error(expected(operation), 3) end
        return nil
    end
    ---Disposes every cached wrapper whose handle `gone` names, without a native call of its own. The cache is walked
    ---in no fixed order, so `gone` must only read.
    function registry.sweep(gone)
        for raw, value in pairs(byHandle) do
            if gone(raw) then
                members[value] = false
                byHandle[raw] = nil
                value.handle = nil
            end
        end
    end
    loaded[name] = registry
    if options.widget then widgets[#widgets + 1] = registry end
    return registry
end

---Converts a wrapper argument without importing its module: a caller holding one has loaded it. Errors point at the
---caller of the public function (level 3), plus `depth` for helper frames in between.
---@param value unknown
---@param name string
---@param operation string
---@param depth integer?
---@return any
function Handle.unwrap(value, name, operation, depth)
    local registry = loaded[name]
    local raw = registry and registry.member(value)
    if raw then return raw end
    local level = 3 + (depth or 0)
    if raw == false then error('[wrappers] ' .. operation .. ': ' .. name .. ' is disposed', level) end
    error('[wrappers] ' .. operation .. ': expected ' .. name .. ' wrapper', level)
end

---Converts a Unit, Item or Destructable argument.
---@param value unknown
---@param operation string
---@param depth integer?
---@return widget
function Handle.unwrapWidget(value, operation, depth)
    local level = 3 + (depth or 0)
    for _, registry in ipairs(widgets) do
        local raw = registry.member(value)
        if raw == false then error('[wrappers] ' .. operation .. ': ' .. registry.name .. ' is disposed', level) end
        if raw ~= nil then return raw end
    end
    error('[wrappers] ' .. operation .. ': expected Widget wrapper', level)
end

---@generic H
---@param raw H?
---@param operation string
---@param depth integer?
---@return H
function Handle.created(raw, operation, depth)
    if raw == nil then error('[wrappers] ' .. operation .. ': native returned nil', 3 + (depth or 0)) end
    return raw
end

return Handle
