---Annotation-only base of Unit, Item and Destructable. There is no Widget module class and no
---Widget.fromHandle: Warcraft has no reliable handle-type check to pick the wrapper class for a raw widget.
---@class MoonwellWrappers.Widget
---@field getHandle fun(self: MoonwellWrappers.Widget): widget
---@field isDisposed fun(self: MoonwellWrappers.Widget): boolean
---@field getLife fun(self: MoonwellWrappers.Widget): number
---@field setLife fun(self: MoonwellWrappers.Widget, value: number)
---@field getX fun(self: MoonwellWrappers.Widget): number
---@field getY fun(self: MoonwellWrappers.Widget): number

local Widget = {}

---Copies the shared widget methods onto a class, keeping any method the class defines itself.
---@param class table
---@param registry MoonwellWrappers.Registry
function Widget.install(class, registry)
    local name = registry.name
    local shared = {
        {'getLife', function(self) return GetWidgetLife(registry.require(self, name .. '.getLife')) end},
        {'setLife', function(self, value) SetWidgetLife(registry.require(self, name .. '.setLife'), value) end},
        {'getX', function(self) return GetWidgetX(registry.require(self, name .. '.getX')) end},
        {'getY', function(self) return GetWidgetY(registry.require(self, name .. '.getY')) end},
    }
    for _, entry in ipairs(shared) do
        if rawget(class, entry[1]) == nil then class[entry[1]] = entry[2] end
    end
end

return Widget
