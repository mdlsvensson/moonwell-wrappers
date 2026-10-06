ORIGIN_FRAME_GAME_UI = {}
local ORIGIN = {}
native('BlzGetOriginFrame', function() return ORIGIN end)
native('BlzCreateFrameByType', function() return {} end)
native('BlzConvertColor', function(a, r, g, b) return ((a * 256 + r) * 256 + g) * 256 + b end)
native('GetLocalPlayer', function() return PLAYER_RAW end)
for _, name in ipairs({'BlzDestroyFrame', 'DestroyTrigger'}) do native(name, function() end) end
local Frame = require('wrappers.frame')
local Player = require('wrappers.player')
eq(totalCalls(), 0)

local setters = {{'BlzFrameSetAbsPoint', 'setAbsPoint', 'center', 0.4, 0.3}, {'BlzFrameClearAllPoints', 'clearPoints'},
    {'BlzFrameSetSize', 'setSize', 0.1, 0.05}, {'BlzFrameSetScale', 'setScale', 1.5}, {'BlzFrameSetLevel', 'setLevel', 2},
    {'BlzFrameSetText', 'setText', 'Hi'}, {'BlzFrameAddText', 'addText', 'more'},
    {'BlzFrameSetTextAlignment', 'setTextAlignment', 'top', 'left'},
    {'BlzFrameSetTextSizeLimit', 'setTextSizeLimit', 12}, {'BlzFrameSetSpriteAnimate', 'setSpriteAnimate', 1, 0},
    {'BlzTextAreaFrameSetAutoScroll', 'setAutoScroll', true}, {'BlzFrameSetValue', 'setValue', 3},
    {'BlzFrameSetMinMaxValue', 'setMinMaxValue', 0, 10}, {'BlzFrameSetStepSize', 'setStepSize', 1},
    {'BlzFrameSetAlpha', 'setAlpha', 128}, {'BlzFrameSetEnable', 'setEnabled', false},
    {'BlzFrameSetVisible', 'setVisible', true}}

test('setters forward exact arguments on owned and borrowed frames', function()
    local ui = Frame.origin(ORIGIN_FRAME_GAME_UI)
    local frame = Frame.createByType('TEXT', ui)
    checkSetters(frame, setters)
    checkSetters(ui, {{'BlzFrameSetVisible', 'setVisible', false}, {'BlzFrameSetAlpha', 'setAlpha', 200}})
    eq(frame.show, nil); eq(frame.setVertexColor, nil)
    frame:destroy()
end)

test('colors convert with BlzConvertColor and defaults fill optional arguments', function()
    local frame = Frame.createByType('TEXT', Frame.origin(ORIGIN_FRAME_GAME_UI))
    for _, name in ipairs({'BlzFrameSetTextColor', 'BlzFrameSetVertexColor', 'BlzFrameSetFont', 'BlzFrameSetTexture',
        'BlzFrameSetModel'}) do
        native(name, function() end)
    end
    frame:setTextColor(255, 204, 0, 128)
    expectCall('BlzConvertColor', 128, 255, 204, 0)
    expectCall('BlzFrameSetTextColor', frame.handle, ((128 * 256 + 255) * 256 + 204) * 256 + 0)
    frame:setColor(1, 2, 3, 4)
    expectCall('BlzConvertColor', 4, 1, 2, 3)
    expectCall('BlzFrameSetVertexColor', frame.handle, ((4 * 256 + 1) * 256 + 2) * 256 + 3)
    frame:setFont('font.ttf', 0.012); expectCall('BlzFrameSetFont', frame.handle, 'font.ttf', 0.012, 0)
    frame:setFont('font.ttf', 0.012, 1); expectCall('BlzFrameSetFont', frame.handle, 'font.ttf', 0.012, 1)
    frame:setTexture('icon.blp'); expectCall('BlzFrameSetTexture', frame.handle, 'icon.blp', 0, true)
    frame:setTexture('icon.blp', 1, false); expectCall('BlzFrameSetTexture', frame.handle, 'icon.blp', 1, false)
    frame:setModel('model.mdx'); expectCall('BlzFrameSetModel', frame.handle, 'model.mdx', 0)
    frame:setModel('model.mdx', 2); expectCall('BlzFrameSetModel', frame.handle, 'model.mdx', 2)
    frame:destroy()
end)

test('frame arguments are unwrapped and checked first', function()
    local ui = Frame.origin(ORIGIN_FRAME_GAME_UI)
    local frame, tip = Frame.createByType('TEXT', ui), Frame.createByType('TEXT', ui)
    for _, name in ipairs({'BlzFrameSetPoint', 'BlzFrameSetAllPoints', 'BlzFrameSetTooltip'}) do
        native(name, function() end)
    end
    frame:setPoint('top', ui, 'bottom', 0, -0.01)
    expectCall('BlzFrameSetPoint', frame.handle, 'top', ui.handle, 'bottom', 0, -0.01)
    frame:setAllPoints(ui); expectCall('BlzFrameSetAllPoints', frame.handle, ui.handle)
    frame:setTooltip(tip); expectCall('BlzFrameSetTooltip', frame.handle, tip.handle)
    resetCalls()
    fails(function() frame:setPoint('top', {}, 'bottom', 0, 0) end, 'Frame.setPoint: expected Frame wrapper')
    fails(function() frame:setAllPoints(nil) end, 'Frame.setAllPoints: expected Frame wrapper')
    fails(function() frame:setTooltip(Player.fromIndex(0)) end, 'Frame.setTooltip: expected Frame wrapper')
    tip:destroy()
    fails(function() frame:setTooltip(tip) end, 'Frame.setTooltip: Frame is disposed')
    eq(callCount('BlzFrameSetPoint') + callCount('BlzFrameSetAllPoints') + callCount('BlzFrameSetTooltip'), 0)
    frame:destroy()
end)

test('setVisibleFor and releaseFocusFor act on that player machine only', function()
    local frame = Frame.createByType('BUTTON', Frame.origin(ORIGIN_FRAME_GAME_UI))
    local enabled = {}
    native('BlzFrameSetVisible', function() end)
    native('BlzFrameSetEnable', function(_, flag) enabled[#enabled + 1] = tostring(flag) end)
    frame:setVisibleFor(Player.fromIndex(0)); expectCall('BlzFrameSetVisible', frame.handle, true)
    frame:setVisibleFor(Player.fromHandle({})); expectCall('BlzFrameSetVisible', frame.handle, false)
    frame:releaseFocusFor(Player.fromHandle({})); eq(#enabled, 0)
    frame:releaseFocusFor(Player.fromIndex(0)); eq(table.concat(enabled, ','), 'false,true')
    expectCall('BlzFrameSetEnable', frame.handle, true)
    fails(function() frame:setVisibleFor(frame) end, 'Frame.setVisibleFor: expected Player wrapper')
    fails(function() frame:releaseFocusFor(nil) end, 'Frame.releaseFocusFor: expected Player wrapper')
    frame:destroy()
end)

test('disposed frames guard every setter', function()
    local frame = Frame.createByType('TEXT', Frame.origin(ORIGIN_FRAME_GAME_UI))
    frame:destroy()
    checkDisposed(frame, {'setPoint', 'setAbsPoint', 'setAllPoints', 'clearPoints', 'setSize', 'setScale', 'setLevel',
        'setText', 'addText', 'setTextColor', 'setColor', 'setFont', 'setTextAlignment', 'setTextSizeLimit',
        'setTexture', 'setModel', 'setSpriteAnimate', 'setAutoScroll', 'setValue', 'setMinMaxValue', 'setStepSize',
        'setAlpha', 'setEnabled', 'setTooltip', 'setVisible', 'setVisibleFor', 'releaseFocusFor'})
end)
