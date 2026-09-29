for _, name in ipairs({'SetImageRenderAlways', 'ShowImage', 'SetImagePosition', 'SetImageColor',
    'SetImageConstantHeight', 'SetImageAboveWater', 'SetImageType', 'DestroyImage'}) do
    native(name, function() end)
end
native('CreateImage', function() return {} end)
native('GetHandleId', function() return 8 end)
native('GetLocalPlayer', function() return PLAYER_RAW end)
local Image = require('wrappers.image')
local Player = require('wrappers.player')
eq(totalCalls(), 0)

test('images are centered on creation, drawn and shown', function()
    eq(Image.fromHandle(nil), nil)
    local image = Image.create('aoe.blp', 256, 128, 100, 50, 1)
    expectCall('CreateImage', 'aoe.blp', 256, 128, 0, -28, -14, 0, 0, 0, 0, 1)
    expectCall('SetImageRenderAlways', image.handle, true); expectCall('ShowImage', image.handle, true)
    eq(Image.fromHandle(image.handle), image); eq(image:getHandle(), image.handle); eq(image:isDisposed(), false)
    image:setPosition(0, 0); expectCall('SetImagePosition', image.handle, -128, -64, 0)
    image:setPosition(10, 20, 5); expectCall('SetImagePosition', image.handle, -118, -44, 5)
    image:destroy()
end)

test('a wrapped image of unknown size cannot be centered', function()
    local foreign = Image.fromHandle({})
    fails(function() foreign:setPosition(0, 0) end,
        'Image.setPosition: size unknown for a wrapped image; use SetImagePosition')
    eq(callCount('SetImagePosition'), 0)
    foreign:destroy()
end)

test('image settings and local visibility forward exact arguments', function()
    local image = Image.create('aoe.blp', 64, 64, 0, 0, 2)
    checkSetters(image, {{'ShowImage', 'show', false}, {'SetImageColor', 'setColor', 1, 2, 3, 4},
        {'SetImageConstantHeight', 'setConstantHeight', true, 10}, {'SetImageAboveWater', 'setAboveWater', true, false},
        {'SetImageType', 'setType', 3}})
    image:setVisibleFor(Player.fromIndex(0)); expectCall('ShowImage', image.handle, true)
    image:setVisibleFor(Player.fromHandle({})); expectCall('ShowImage', image.handle, false)
    fails(function() image:setVisibleFor(image) end, 'Image.setVisibleFor: expected Player wrapper')
    image:destroy()
end)

test('image destruction is idempotent and guards every method', function()
    local image = Image.create('aoe.blp', 64, 64, 0, 0, 1)
    local raw = image.handle
    image:destroy(); image:destroy()
    expectCall('DestroyImage', raw); eq(callCount('DestroyImage'), 1); eq(image.handle, nil)
    eq(image:isDisposed(), true)
    checkDisposed(image, {'getHandle', 'setPosition', 'show', 'setVisibleFor', 'setColor', 'setConstantHeight',
        'setAboveWater', 'setType'})
    native('CreateImage', function() return nil end)
    fails(function() Image.create('aoe.blp', 64, 64, 0, 0, 1) end, 'Image.create')
    eq(callCount('SetImageRenderAlways'), 1)
    native('CreateImage', function() return {} end)
end)

test('a wrong image path raises and destroys the invalid image', function()
    local invalid = {}
    native('CreateImage', function() return invalid end)
    native('GetHandleId', function(raw) return raw == invalid and -1 or 8 end)
    fails(function() Image.create('missing.blp', 64, 64, 0, 0, 1) end, 'Image.create: invalid image path')
    expectCall('DestroyImage', invalid); eq(callCount('DestroyImage'), 1)
    eq(callCount('SetImageRenderAlways'), 0); eq(callCount('ShowImage'), 0)
    native('CreateImage', function() return {} end)
    native('GetHandleId', function() return 8 end)
end)
