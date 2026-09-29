local Handle = require('wrappers.internal.handle')
local Options = require('wrappers.internal.options')

---A Blz frame. Owned frames (made by Frame.create, createSimple or createByType) can be destroyed, which disposes
---their whole subtree. Template parts (findChild, getChild) belong to the owned frame they were found through.
---Borrowed frames are the game's and are never destroyed through a wrapper.
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

---@class MoonwellWrappers.FrameCell
---@field frame MoonwellWrappers.Frame
---@field eventType frameeventtype
---@field callback function? Nil once removed or disposed.

---@class MoonwellWrappers.FrameState
---@field kind 'owned'|'part'|'borrowed'
---@field owner MoonwellWrappers.Frame A part's owned frame; an owned or borrowed frame's owner is itself.
---@field parent MoonwellWrappers.Frame? An owned frame's owned parent; nil for a root.
---@field context integer An owned frame's create context; a part's is its owner's; 0 when borrowed.
---@field children MoonwellWrappers.Frame[] Owned frames under an owned frame, in creation order.
---@field parts MoonwellWrappers.Frame[] Template parts found through an owned frame, in the order found.
---@field trigger trigger? Created by the first on().
---@field cells MoonwellWrappers.FrameCell[] Live event callbacks, in the order added.
---@field byType table<frameeventtype, MoonwellWrappers.FrameCell[]> Callbacks by event type; lookup only.

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
    return {kind = kind, owner = owner, context = context, children = {}, parts = {}, cells = {}, byType = {}}
end

---Wraps a raw handle the game gave us. A known frame keeps its wrapper and kind; a new one becomes a part of `owner`,
---or borrowed when `owner` is nil.
---@param raw framehandle
---@param owner MoonwellWrappers.Frame?
---@return MoonwellWrappers.Frame
local function adopt(raw, owner)
    local frame = assert(registry.wrap(raw))
    if not states[frame] then
        if owner then
            states[frame] = newState('part', owner, states[owner].context)
            local parts = states[owner].parts
            parts[#parts + 1] = frame
        else
            states[frame] = newState('borrowed', frame, 0)
        end
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
    for _, cell in ipairs(state.cells) do cell.callback = nil end
    state.cells, state.byType = {}, {}
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
    local raw = BlzGetOriginFrame(originType, index or 0)
    if raw == nil then error('[wrappers] Frame.origin: no frame', 2) end
    return adopt(raw, nil)
end
---The frame with that name and create context: the existing wrapper, or a borrowed one.
---@param name string
---@param context integer? Default 0.
---@return MoonwellWrappers.Frame
function Frame.byName(name, context)
    local raw = BlzGetFrameByName(name, context or 0)
    if raw == nil then error('[wrappers] Frame.byName: no frame named ' .. tostring(name), 2) end
    return adopt(raw, nil)
end
---Loads a .toc file that lists .fdf files, so their templates can be created.
---@param path string In-map path, for example "war3mapImported\\templates.toc".
function Frame.loadTOC(path)
    if not BlzLoadTOCFile(path) then error('[wrappers] Frame.loadTOC: could not load ' .. tostring(path), 2) end
end
---Hides (true) or shows (false) the game's own UI, for everyone.
---@param flag boolean
function Frame.hideOrigin(flag) BlzHideOriginFrames(flag) end
---@param flag boolean
function Frame.enableAutoPosition(flag) BlzEnableUIAutoPosition(flag) end

---@return framehandle
function Frame:getHandle() return registry.require(self, 'Frame.getHandle') end
---@return boolean
function Frame:isDisposed() return registry.isDisposed(self, 'Frame.isDisposed') end
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
    local raw = BlzFrameGetChild(registry.require(self, 'Frame.getChild'), index)
    if raw == nil then error('[wrappers] Frame.getChild: no child ' .. tostring(index), 2) end
    local state = states[self]
    if state.kind == 'borrowed' then return adopt(raw, nil) end
    return adopt(raw, state.owner)
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
        error('[wrappers] Frame.findChild: no frame named ' .. tostring(name) .. ' in this frame', 2)
    end
    return adopt(raw, state.owner)
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

return Frame
