local Handle = require('wrappers.internal.handle')
local Options = require('wrappers.internal.options')
local Callback = require('wrappers.internal.callback')
local Cells = require('wrappers.internal.cells')
local Check = require('wrappers.internal.check')
local PlayerWrapper = require('wrappers.player')

---A Blz frame. Owned frames (made by Frame.create, createSimple or createByType) can be destroyed, which disposes
---their whole subtree. Template parts (findChild, getChild) belong to the owned frame they were found through, also
---when Frame.byName or Frame.fromHandle reached them first. Borrowed frames are the game's and are never destroyed
---through a wrapper.
---@class MoonwellWrappers.Frame
---@field handle framehandle? Read-only by convention; nil after disposal.
local Frame = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Frame, framehandle>
local registry = Handle.new(Frame, 'Frame')

---@class MoonwellWrappers.FrameCreateOptions
---@field priority integer? Default 0.

---@class MoonwellWrappers.FrameByTypeOptions
---@field name string? The frame's name, for Frame.byName and findChild; default "".
---@field inherits string? A template to inherit from; default "".

---@type MoonwellWrappers.OptionFields
local createFields = {priority = {'integer', 0}}
---@type MoonwellWrappers.OptionFields
local byTypeFields = {name = {'string', ''}, inherits = {'string', ''}}

---@class MoonwellWrappers.FrameState
---@field kind 'owned'|'part'|'borrowed'
---@field owner MoonwellWrappers.Frame A part's owned frame; an owned or borrowed frame's owner is itself.
---@field parent MoonwellWrappers.Frame? An owned frame's owned parent; nil for a root.
---@field context integer An owned frame's create context; a part's is its owner's; 0 when borrowed.
---@field children MoonwellWrappers.Frame[] Owned frames under an owned frame, in creation order.
---@field parts MoonwellWrappers.Frame[] Template parts found through an owned frame, in the order found.
---@field origin boolean? True for a frame Frame.origin returned: it is the game's and never becomes a part.
---@field trigger trigger? Created by the first on().
---@field lists MoonwellWrappers.Cells[] One list of callbacks per event type, in the order the types were first used.
---@field byType table<frameeventtype, MoonwellWrappers.Cells> The same lists by event type; lookup only.

-- Keyed by wrapper; only indexed, never iterated.
---@type table<MoonwellWrappers.Frame, MoonwellWrappers.FrameState>
local states = {}
-- Every machine creates frames in the same order, so this counter agrees across machines.
local lastContext = 0

---@return integer
local function nextContext()
    lastContext = lastContext + 1
    return lastContext
end

---@param list any[]
---@param item any
---@return any[]
local function without(list, item)
    local result = {}
    for _, value in ipairs(list) do
        if value ~= item then result[#result + 1] = value end
    end
    return result
end

---@param kind 'owned'|'part'|'borrowed'
---@param owner MoonwellWrappers.Frame
---@param context integer
---@return MoonwellWrappers.FrameState
local function newState(kind, owner, context)
    return {kind = kind, owner = owner, context = context, children = {}, parts = {}, lists = {}, byType = {}}
end

---Wraps a raw handle the game gave us. A new frame becomes a part of `owner`, or borrowed when `owner` is nil; a new
---frame that getParent reaches from a part becomes a part too, of that part's owner. A known frame keeps its wrapper
---and its kind, with one exception that only getChild and findChild ask for (`convert`): a borrowed frame they find
---through an owned frame is a template part that Frame.byName or Frame.fromHandle reached first, so it becomes a part
---of `owner`. That is sound for those two: a direct child is in the owner's subtree, and so is a name found in the
---owner's create context, unless raw code created or moved a frame with that context. getParent never converts,
---because a parent need not be in the subtree (a part may have been moved under a frame of the game's), and a frame
---from Frame.origin is the game's, so no path converts it. An owned frame created under a part while that part was
---still borrowed stays a root: converting the part does not move it under the owner.
---@param raw framehandle
---@param owner MoonwellWrappers.Frame?
---@param convert boolean? True when a known borrowed frame may become a part of `owner`.
---@return MoonwellWrappers.Frame
local function adopt(raw, owner, convert)
    local frame = assert(registry.wrap(raw))
    local state = states[frame]
    if not state then
        if owner then
            states[frame] = newState('part', owner, states[owner].context)
            local parts = states[owner].parts
            parts[#parts + 1] = frame
        else
            states[frame] = newState('borrowed', frame, 0)
        end
    elseif convert and owner and state.kind == 'borrowed' and not state.origin then
        local owned = states[owner]
        state.kind, state.owner, state.context = 'part', owner, owned.context
        owned.parts[#owned.parts + 1] = frame
    end
    return frame
end

---The owned frame whose destruction also destroys a frame parented to `parent`; nil for a borrowed parent.
---@param parent MoonwellWrappers.Frame
---@return MoonwellWrappers.Frame?
local function ownerOf(parent)
    local state = states[parent]
    if state.kind == 'borrowed' then return nil end
    return state.owner
end

---Records a frame a factory just made as owned, under the owned frame that `parent` belongs to.
---@param frame MoonwellWrappers.Frame
---@param parent MoonwellWrappers.Frame
---@param context integer
---@return MoonwellWrappers.Frame
local function own(frame, parent, context)
    local state = newState('owned', frame, context)
    state.parent = ownerOf(parent)
    states[frame] = state
    if state.parent then
        local children = states[state.parent].children
        children[#children + 1] = frame
    end
    return frame
end

---Clears a frame's callbacks, then destroys its internal trigger.
---@param state MoonwellWrappers.FrameState
local function releaseEvents(state)
    local lists = state.lists
    for index = 1, #lists do Cells.clear(lists[index]) end
    if state.trigger then DestroyTrigger(state.trigger) end
end

---Disposes a frame's wrapper and its owned descendants and parts, depth-first. Never calls BlzDestroyFrame.
---@param frame MoonwellWrappers.Frame
local function dispose(frame)
    local state = states[frame]
    states[frame] = nil
    for _, child in ipairs(state.children) do dispose(child) end
    for _, part in ipairs(state.parts) do dispose(part) end
    releaseEvents(state)
    registry.dispose(frame, 'Frame.destroy')
end

---@param raw framehandle?
---@return MoonwellWrappers.Frame?
---@overload fun(raw: nil): nil
function Frame.fromHandle(raw)
    if raw == nil then return nil end
    return adopt(raw, nil)
end
---Creates a frame from a template the game knows (built in, or loaded with Frame.loadTOC). Create frames on every
---machine in the same order, never inside a branch on the local player.
---@param template string
---@param parent MoonwellWrappers.Frame
---@param options MoonwellWrappers.FrameCreateOptions?
---@return MoonwellWrappers.Frame
function Frame.create(template, parent, options)
    local parentRaw = registry.require(parent, 'Frame.create')
    local o = Options.read(options, createFields, 'Frame.create')
    local context = nextContext()
    local raw = BlzCreateFrame(template, parentRaw, o.priority, context)
    local frame = Handle.created(registry.wrap(raw), 'Frame.create')
    return own(frame, parent, context)
end
---@param template string
---@param parent MoonwellWrappers.Frame
---@return MoonwellWrappers.Frame
function Frame.createSimple(template, parent)
    local parentRaw = registry.require(parent, 'Frame.createSimple')
    local context = nextContext()
    local frame = Handle.created(registry.wrap(BlzCreateSimpleFrame(template, parentRaw, context)),
        'Frame.createSimple')
    return own(frame, parent, context)
end
---Creates a frame of a type such as "BACKDROP", "TEXT" or "GLUETEXTBUTTON", optionally inheriting a template.
---@param frameType string
---@param parent MoonwellWrappers.Frame
---@param options MoonwellWrappers.FrameByTypeOptions?
---@return MoonwellWrappers.Frame
function Frame.createByType(frameType, parent, options)
    local parentRaw = registry.require(parent, 'Frame.createByType')
    local o = Options.read(options, byTypeFields, 'Frame.createByType')
    local context = nextContext()
    local raw = BlzCreateFrameByType(frameType, o.name, parentRaw, o.inherits, context)
    local frame = Handle.created(registry.wrap(raw), 'Frame.createByType')
    return own(frame, parent, context)
end
---A game frame such as ORIGIN_FRAME_GAME_UI. Borrowed: never destroyed through the wrapper.
---@param originType originframetype
---@param index integer? Default 0.
---@return MoonwellWrappers.Frame
function Frame.origin(originType, index)
    if index ~= nil then Check.requireInteger(index, 'index', 'Frame.origin') end
    local raw = BlzGetOriginFrame(originType, index or 0)
    if raw == nil then error('[wrappers] Frame.origin: no frame', 2) end
    local frame = adopt(raw, nil)
    local state = states[frame]
    if state.kind == 'borrowed' then state.origin = true end
    return frame
end
---The frame with that name and create context: the existing wrapper, or a borrowed one.
---@param name string
---@param context integer? Default 0.
---@return MoonwellWrappers.Frame
function Frame.byName(name, context)
    if context ~= nil then Check.requireInteger(context, 'context', 'Frame.byName') end
    local raw = BlzGetFrameByName(name, context or 0)
    if raw == nil then error('[wrappers] Frame.byName: no frame named ' .. Check.show(name), 2) end
    return adopt(raw, nil)
end
---Loads a .toc file that lists .fdf files, so their templates can be created.
---@param path string In-map path, for example "war3mapImported\\templates.toc".
function Frame.loadTOC(path)
    if not BlzLoadTOCFile(path) then error('[wrappers] Frame.loadTOC: could not load ' .. Check.show(path), 2) end
end
---Hides (true) or shows (false) the game's own UI, for everyone.
---@param flag boolean
function Frame.setOriginHidden(flag) BlzHideOriginFrames(flag) end
---Turns the game's automatic placing of its own UI on (true) or off (false): BlzEnableUIAutoPosition.
---@param flag boolean
function Frame.setAutoPosition(flag) BlzEnableUIAutoPosition(flag) end

---@return framehandle
function Frame:getHandle() return (registry.require(self, 'Frame.getHandle')) end
---@return boolean
function Frame:isDisposed() return (registry.isDisposed(self, 'Frame.isDisposed')) end
---@return string
function Frame:getName() return BlzFrameGetName(registry.require(self, 'Frame.getName')) end
---@return MoonwellWrappers.Frame?
function Frame:getParent()
    local raw = BlzFrameGetParent(registry.require(self, 'Frame.getParent'))
    if raw == nil then return nil end
    local state = states[self]
    if state.kind == 'part' then return adopt(raw, state.owner) end
    return adopt(raw, nil)
end
---@return integer
function Frame:getChildrenCount() return BlzFrameGetChildrenCount(registry.require(self, 'Frame.getChildrenCount')) end
---The child at a zero-based index. Under an owned frame or part it is a template part (or an owned frame made there).
---@param index integer
---@return MoonwellWrappers.Frame
function Frame:getChild(index)
    local selfRaw = registry.require(self, 'Frame.getChild')
    Check.requireInteger(index, 'index', 'Frame.getChild')
    local raw = BlzFrameGetChild(selfRaw, index)
    if raw == nil then error('[wrappers] Frame.getChild: no child ' .. index, 2) end
    local state = states[self]
    if state.kind == 'borrowed' then return adopt(raw, nil) end
    return adopt(raw, state.owner, true)
end
---Finds a template part by name, with the create context of the owned frame this frame belongs to.
---@param name string
---@return MoonwellWrappers.Frame
function Frame:findChild(name)
    registry.require(self, 'Frame.findChild')
    local state = states[self]
    if state.kind == 'borrowed' then
        error('[wrappers] Frame.findChild: findChild needs a frame made by Frame.create*', 2)
    end
    local raw = BlzGetFrameByName(name, states[state.owner].context)
    if raw == nil then
        error('[wrappers] Frame.findChild: no frame named ' .. Check.show(name) .. ' in this frame', 2)
    end
    return adopt(raw, state.owner, true)
end
---Moves the frame under another frame. An owned frame moves in the tree; a borrowed frame may only move under another
---borrowed frame; a template part cannot move.
---@param parent MoonwellWrappers.Frame
function Frame:setParent(parent)
    local raw = registry.require(self, 'Frame.setParent')
    local parentRaw = registry.require(parent, 'Frame.setParent')
    local state = states[self]
    local up = ownerOf(parent)
    if state.kind == 'part' then error('[wrappers] Frame.setParent: a template part cannot be re-parented', 2) end
    if state.kind == 'borrowed' then
        if up ~= nil then
            error('[wrappers] Frame.setParent: a borrowed frame can only be re-parented to a borrowed frame', 2)
        end
    else
        local walk = up
        while walk ~= nil do
            if walk == self then
                error('[wrappers] Frame.setParent: a frame cannot be re-parented into its own subtree', 2)
            end
            walk = states[walk].parent
        end
        if state.parent then
            local old = states[state.parent]
            old.children = without(old.children, self)
        end
        state.parent = up
        if up then
            local children = states[up].children
            children[#children + 1] = self
        end
    end
    BlzFrameSetParent(raw, parentRaw)
end
---Destroys an owned frame and everything under it: every wrapper in its subtree is disposed and their callbacks never
---run again. Borrowed frames and template parts raise.
function Frame:destroy()
    if registry.isDisposed(self, 'Frame.destroy') then return end
    local raw = registry.require(self, 'Frame.destroy')
    local state = states[self]
    if state.kind ~= 'owned' then
        error('[wrappers] Frame.destroy: only frames made by Frame.create, createSimple or createByType can be destroyed',
            2)
    end
    if state.parent then
        local parent = states[state.parent]
        parent.children = without(parent.children, self)
    end
    dispose(self)
    BlzDestroyFrame(raw)
end

---@param point framepointtype
---@param relative MoonwellWrappers.Frame
---@param relativePoint framepointtype
---@param x number
---@param y number
function Frame:setPoint(point, relative, relativePoint, x, y)
    local raw = registry.require(self, 'Frame.setPoint')
    BlzFrameSetPoint(raw, point, registry.require(relative, 'Frame.setPoint'), relativePoint, x, y)
end
---Places a point of the frame at screen coordinates: 0-0.8 wide, 0-0.6 high, origin bottom left.
---@param point framepointtype
---@param x number
---@param y number
function Frame:setAbsPoint(point, x, y) BlzFrameSetAbsPoint(registry.require(self, 'Frame.setAbsPoint'), point, x, y) end
---@param relative MoonwellWrappers.Frame
function Frame:setAllPoints(relative)
    local raw = registry.require(self, 'Frame.setAllPoints')
    BlzFrameSetAllPoints(raw, registry.require(relative, 'Frame.setAllPoints'))
end
function Frame:clearPoints() BlzFrameClearAllPoints(registry.require(self, 'Frame.clearPoints')) end
---@param width number
---@param height number
function Frame:setSize(width, height) BlzFrameSetSize(registry.require(self, 'Frame.setSize'), width, height) end
---@param scale number
function Frame:setScale(scale) BlzFrameSetScale(registry.require(self, 'Frame.setScale'), scale) end
---@param level integer
function Frame:setLevel(level) BlzFrameSetLevel(registry.require(self, 'Frame.setLevel'), level) end
---@param text string
function Frame:setText(text) BlzFrameSetText(registry.require(self, 'Frame.setText'), text) end
---@param text string
function Frame:addText(text) BlzFrameAddText(registry.require(self, 'Frame.addText'), text) end
---@param r integer 0-255
---@param g integer 0-255
---@param b integer 0-255
---@param a integer 0-255
function Frame:setTextColor(r, g, b, a)
    local raw = registry.require(self, 'Frame.setTextColor')
    BlzFrameSetTextColor(raw, BlzConvertColor(a, r, g, b))
end
---Tints the frame (BlzFrameSetVertexColor).
---@param r integer 0-255
---@param g integer 0-255
---@param b integer 0-255
---@param a integer 0-255
function Frame:setColor(r, g, b, a)
    local raw = registry.require(self, 'Frame.setColor')
    BlzFrameSetVertexColor(raw, BlzConvertColor(a, r, g, b))
end
---@param path string
---@param height number
---@param flags integer? Default 0.
function Frame:setFont(path, height, flags)
    BlzFrameSetFont(registry.require(self, 'Frame.setFont'), path, height, flags or 0)
end
---@param vertical textaligntype
---@param horizontal textaligntype
function Frame:setTextAlignment(vertical, horizontal)
    BlzFrameSetTextAlignment(registry.require(self, 'Frame.setTextAlignment'), vertical, horizontal)
end
---@param size integer
function Frame:setTextSizeLimit(size) BlzFrameSetTextSizeLimit(registry.require(self, 'Frame.setTextSizeLimit'), size) end
---@param path string
---@param flag integer? Default 0.
---@param blend boolean? Default true.
function Frame:setTexture(path, flag, blend)
    local raw = registry.require(self, 'Frame.setTexture')
    if blend == nil then blend = true end
    BlzFrameSetTexture(raw, path, flag or 0, blend)
end
---@param path string
---@param cameraIndex integer? Default 0.
function Frame:setModel(path, cameraIndex)
    BlzFrameSetModel(registry.require(self, 'Frame.setModel'), path, cameraIndex or 0)
end
---@param primaryProp integer
---@param flags integer
function Frame:setSpriteAnimate(primaryProp, flags)
    BlzFrameSetSpriteAnimate(registry.require(self, 'Frame.setSpriteAnimate'), primaryProp, flags)
end
---For text areas.
---@param flag boolean
function Frame:setAutoScroll(flag) BlzTextAreaFrameSetAutoScroll(registry.require(self, 'Frame.setAutoScroll'), flag) end
---@param value number
function Frame:setValue(value) BlzFrameSetValue(registry.require(self, 'Frame.setValue'), value) end
---@param min number
---@param max number
function Frame:setMinMaxValue(min, max) BlzFrameSetMinMaxValue(registry.require(self, 'Frame.setMinMaxValue'), min, max) end
---@param step number
function Frame:setStepSize(step) BlzFrameSetStepSize(registry.require(self, 'Frame.setStepSize'), step) end
---@param alpha integer 0-255
function Frame:setAlpha(alpha) BlzFrameSetAlpha(registry.require(self, 'Frame.setAlpha'), alpha) end
---@param flag boolean
function Frame:setEnabled(flag) BlzFrameSetEnable(registry.require(self, 'Frame.setEnabled'), flag) end
---Shows `tooltip` while the mouse is over this frame.
---@param tooltip MoonwellWrappers.Frame
function Frame:setTooltip(tooltip)
    local raw = registry.require(self, 'Frame.setTooltip')
    BlzFrameSetTooltip(raw, registry.require(tooltip, 'Frame.setTooltip'))
end
---@param flag boolean
function Frame:setVisible(flag) BlzFrameSetVisible(registry.require(self, 'Frame.setVisible'), flag) end
---Shows the frame on that player's machine only. Only local visuals differ.
---@param player MoonwellWrappers.Player
function Frame:setVisibleFor(player)
    local raw = registry.require(self, 'Frame.setVisibleFor')
    BlzFrameSetVisible(raw, Handle.unwrap(player, 'Player', 'Frame.setVisibleFor') == GetLocalPlayer())
end
---On that player's machine only, disables and re-enables the frame, so a clicked button gives keyboard focus back
---(hotkeys work again). Call it from a click callback with the callback's player.
---@param player MoonwellWrappers.Player
function Frame:releaseFocusFor(player)
    local raw = registry.require(self, 'Frame.releaseFocusFor')
    if Handle.unwrap(player, 'Player', 'Frame.releaseFocusFor') == GetLocalPlayer() then
        BlzFrameSetEnable(raw, false)
        BlzFrameSetEnable(raw, true)
    end
end

---The data of one firing. Every callback of that firing gets the same table.
---@class MoonwellWrappers.FrameEvent
---@field type frameeventtype
---@field frame MoonwellWrappers.Frame
---@field text string The event's synced text (edit boxes).
---@field value number The event's synced value (sliders, check boxes, popup menus, the mouse wheel).

---@alias MoonwellWrappers.FrameCallback fun(player: MoonwellWrappers.Player, event: MoonwellWrappers.FrameEvent): ...

---The internal trigger's action: runs the live callbacks for the event type that fired, in the order added. Callbacks
---added during this firing wait for the next one; cancelled or disposed ones are skipped at once.
---@param frame MoonwellWrappers.Frame
local function route(frame)
    local state = states[frame]
    if not state then return end
    local eventType = BlzGetTriggerFrameEvent()
    local list = state.byType[eventType]
    if not list or Cells.count(list) == 0 then return end
    local player = PlayerWrapper.fromHandle(GetTriggerPlayer())
    ---@type MoonwellWrappers.FrameEvent
    local event = {type = eventType, frame = frame, text = BlzGetTriggerFrameText(), value = BlzGetTriggerFrameValue()}
    Cells.call(list, 'Frame event', player, event)
end

---Runs `callback` when the event fires for this frame, behind the callback boundary, until the returned function is
---called. It receives the Player who caused the event and the event's synced data. The returned function removes the
---callback at once, even during a firing; calling it again, or after the frame was destroyed, does nothing.
---@param eventType frameeventtype For example FRAMEEVENT_CONTROL_CLICK.
---@param callback MoonwellWrappers.FrameCallback
---@return MoonwellWrappers.Cancel
function Frame:on(eventType, callback)
    local raw = registry.require(self, 'Frame.on')
    if eventType == nil then error('[wrappers] Frame.on: expected a frame event type', 2) end
    Callback.check(callback, 'Frame.on')
    local state = states[self]
    local trigger = state.trigger
    if not trigger then
        trigger = Handle.created(CreateTrigger(), 'Frame.on')
        TriggerAddAction(trigger, function() route(self) end)
        state.trigger = trigger
    end
    local list = state.byType[eventType]
    if not list then
        list = Cells.new()
        state.byType[eventType] = list
        state.lists[#state.lists + 1] = list
        BlzTriggerRegisterFrameEvent(trigger, raw, eventType)
    end
    local _, cancel = Cells.add(list, callback)
    return cancel
end

return Frame
