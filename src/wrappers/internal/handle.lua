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
---Each registry's membership table by class name: a wrapper to its handle, or to false once disposed. Handle.unwrap
---indexes it directly.
---@type table<string, table<table, any>>
local membersOf = {}
---The membership tables of the widget classes, for Handle.unwrapWidget, and their class names at the same indices.
---Unit comes first whatever the load order: most widget arguments are units.
---@type table<table, any>[]
local widgetMembers = {}
---@type string[]
local widgetNames = {}

---Private membership, rather than fields or metatables, authenticates instances.
---@param class table
---@param name string
---@param options MoonwellWrappers.RegistryOptions?
---@return MoonwellWrappers.Registry
function Handle.new(class, name, options)
    if membersOf[name] then error('[wrappers] duplicate registry: ' .. name, 2) end
    options = options or {}
    local byHandle = options.weak and setmetatable({}, {__mode = 'v'}) or {}
    local members = setmetatable({}, {__mode = 'k'})
    local registry = {name = name}
    class.__index = class
    local function expected(operation) return '[wrappers] ' .. operation .. ': expected ' .. name .. ' wrapper' end
    local function disposed(operation) return '[wrappers] ' .. operation .. ': ' .. name .. ' is disposed' end
    ---The one place a wrapper is disposed: it stays a member, without a handle, and leaves the cache.
    local function release(value, raw)
        members[value] = false
        byHandle[raw] = nil
        value.handle = nil
    end
    function registry.member(value) return members[value] end
    ---One cache lookup for a handle that already has its wrapper.
    function registry.wrap(raw)
        if raw == nil then return nil end
        local value = byHandle[raw]
        if value then return value end
        value = setmetatable({handle = raw}, class)
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
        release(value, raw)
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
            if gone(raw) then release(value, raw) end
        end
    end
    membersOf[name] = members
    if options.widget then
        local at = name == 'Unit' and 1 or #widgetMembers + 1
        table.insert(widgetMembers, at, members)
        table.insert(widgetNames, at, name)
    end
    return registry
end

---Converts a wrapper argument without importing its module: a caller holding one has loaded it. Errors point at the
---caller of the public function (level 3), plus `depth` for helper frames in between. Each overload gives the handle
---type of one class name, so a native call is checked against what was unwrapped; a name without one gives `any`.
---@param value unknown
---@param name string
---@param operation string
---@param depth integer?
---@return any
---@overload fun(value: unknown, name: 'Player', operation: string, depth: integer?): player
---@overload fun(value: unknown, name: 'Unit', operation: string, depth: integer?): unit
---@overload fun(value: unknown, name: 'Item', operation: string, depth: integer?): item
---@overload fun(value: unknown, name: 'Rect', operation: string, depth: integer?): rect
---@overload fun(value: unknown, name: 'Region', operation: string, depth: integer?): region
---@overload fun(value: unknown, name: 'Timer', operation: string, depth: integer?): timer
function Handle.unwrap(value, name, operation, depth)
    local members = membersOf[name]
    local raw = members and members[value]
    if raw then return raw end
    local level = 3 + (depth or 0)
    if raw == false then error('[wrappers] ' .. operation .. ': ' .. name .. ' is disposed', level) end
    error('[wrappers] ' .. operation .. ': expected ' .. name .. ' wrapper', level)
end

---Converts a Unit, Item or Destructable argument. Errors point at the caller of the public function (level 3).
---@param value unknown
---@param operation string
---@return widget
function Handle.unwrapWidget(value, operation)
    for index = 1, #widgetMembers do
        local raw = widgetMembers[index][value]
        if raw then return raw end
        if raw == false then error('[wrappers] ' .. operation .. ': ' .. widgetNames[index] .. ' is disposed', 3) end
    end
    error('[wrappers] ' .. operation .. ': expected Widget wrapper', 3)
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

---Keeps the wrappers a filter accepts, in their order: the one filtering pass of Item.enumInRect and
---Destructable.enumInRect. Without a filter the array itself comes back; with one, a new array. The filter runs as
---ordinary Lua, after every wrapper was made, and its error propagates.
---@generic T
---@param wrappers T[]
---@param filter (fun(wrapper: T): any)?
---@return T[]
function Handle.keep(wrappers, filter)
    if filter == nil then return wrappers end
    local kept, count = {}, 0
    for index = 1, #wrappers do
        local wrapper = wrappers[index]
        if filter(wrapper) then
            count = count + 1
            kept[count] = wrapper
        end
    end
    return kept
end

---True for the invalid handle Warcraft returns in place of nil when CreateImage is given a path it cannot load or
---AddWeatherEffect an id it does not know: its handle id is -1. The id is only compared with -1, which every machine
---gets for the same bad argument; no other handle id is read.
---@param raw handle?
---@return boolean
function Handle.invalid(raw) return raw ~= nil and GetHandleId(raw) == -1 end

return Handle
