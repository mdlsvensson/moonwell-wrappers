local Handle = require('wrappers.internal.handle')

---@class MoonwellWrappers.Image
---@field handle image? Read-only by convention; nil after destruction.
local Image = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Image, image>
local registry = Handle.new(Image, 'Image')
---Sizes of images made by Image.create, for centering. Only indexed, never iterated.
---@type table<MoonwellWrappers.Image, number[]>
local sizes = setmetatable({}, {__mode = 'k'})

---@param raw image?
---@return MoonwellWrappers.Image?
---@overload fun(raw: nil): nil
function Image.fromHandle(raw) return registry.wrap(raw) end
---Creates a visible image centered on x, y.
---@param path string
---@param width number
---@param height number
---@param x number
---@param y number
---@param imageType integer 1 selection, 2 indicator, 3 occlusion mask, 4 ubersplat.
---@return MoonwellWrappers.Image
function Image.create(path, width, height, x, y, imageType)
    local raw = CreateImage(path, width, height, 0, x - width / 2, y - height / 2, 0, 0, 0, 0, imageType)
    local image = Handle.created(Image.fromHandle(raw), 'Image.create')
    sizes[image] = {width, height}
    SetImageRenderAlways(raw, true)
    ShowImage(raw, true)
    return image
end
---@return image
function Image:getHandle() return registry.require(self, 'Image.getHandle') end
---@return boolean
function Image:isDisposed() return registry.isDisposed(self, 'Image.isDisposed') end
---Centers the image on x, y. Fails for an image wrapped with fromHandle, whose size is unknown.
---@param x number
---@param y number
---@param z number? Default 0.
function Image:setPosition(x, y, z)
    local raw = registry.require(self, 'Image.setPosition')
    local size = sizes[self]
    if size == nil then
        error('[wrappers] Image.setPosition: size unknown for a wrapped image; use SetImagePosition', 2)
    end
    SetImagePosition(raw, x - size[1] / 2, y - size[2] / 2, z or 0)
end
---@param flag boolean
function Image:show(flag) ShowImage(registry.require(self, 'Image.show'), flag) end
---Shows the image on that player's machine only. Only local visuals differ.
---@param player MoonwellWrappers.Player
function Image:setVisibleFor(player)
    local raw = registry.require(self, 'Image.setVisibleFor')
    ShowImage(raw, Handle.unwrap(player, 'Player', 'Image.setVisibleFor') == GetLocalPlayer())
end
---@param r integer 0-255
---@param g integer 0-255
---@param b integer 0-255
---@param a integer 0-255
function Image:setColor(r, g, b, a) SetImageColor(registry.require(self, 'Image.setColor'), r, g, b, a) end
---@param flag boolean
---@param height number
function Image:setConstantHeight(flag, height)
    SetImageConstantHeight(registry.require(self, 'Image.setConstantHeight'), flag, height)
end
---@param flag boolean
---@param useWaterAlpha boolean
function Image:setAboveWater(flag, useWaterAlpha)
    SetImageAboveWater(registry.require(self, 'Image.setAboveWater'), flag, useWaterAlpha)
end
---@param imageType integer 1 selection, 2 indicator, 3 occlusion mask, 4 ubersplat.
function Image:setType(imageType) SetImageType(registry.require(self, 'Image.setType'), imageType) end
function Image:destroy()
    local raw = registry.dispose(self, 'Image.destroy')
    sizes[self] = nil
    if raw then DestroyImage(raw) end
end

return Image
