local Handle = require('wrappers.internal.handle')
local Callback = require('wrappers.internal.callback')
local Options = require('wrappers.internal.options')
local PlayerWrapper = require('wrappers.player')

---@class MoonwellWrappers.Dialog
---@field handle dialog? Read-only by convention; nil after destruction.
local Dialog = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.Dialog, dialog>
local registry = Handle.new(Dialog, 'Dialog')

---A button belongs to the dialog that made it: the dialog's clear() and destroy() dispose it.
---@class MoonwellWrappers.DialogButton
---@field handle button? Read-only by convention; nil once its dialog is cleared or destroyed.
local DialogButton = {}
---@type MoonwellWrappers.Registry<MoonwellWrappers.DialogButton, button>
local buttonRegistry = Handle.new(DialogButton, 'DialogButton')

---@alias MoonwellWrappers.DialogButtonCallback fun(player: MoonwellWrappers.Player): ...

---@class MoonwellWrappers.DialogButtonOptions
---@field hotkey string? One letter or digit that clicks the button.
---@field quit boolean? The button quits the game for the clicking player; default false.
---@field scoreScreen boolean? With quit, show the score screen first; default false.

---@type MoonwellWrappers.OptionFields
local buttonFields = {hotkey = {'string'}, quit = {'boolean', false}, scoreScreen = {'boolean', false}}

---@class MoonwellWrappers.DialogState
---@field buttons MoonwellWrappers.DialogButton[] Live buttons in creation order.
---@field byHandle table<button, MoonwellWrappers.DialogButton> Click lookup only; never iterated.
---@field trigger trigger? Created by the first button with a callback.

-- Keyed by wrapper; only indexed, never iterated.
---@type table<MoonwellWrappers.Dialog, MoonwellWrappers.DialogState>
local states = {}
---@type table<MoonwellWrappers.DialogButton, {dialog: MoonwellWrappers.Dialog, callback: function?}>
local buttonInfo = setmetatable({}, {__mode = 'k'})

---@param dialog MoonwellWrappers.Dialog
---@return MoonwellWrappers.DialogState
local function stateOf(dialog)
    local state = states[dialog]
    if not state then
        state = {buttons = {}, byHandle = {}}
        states[dialog] = state
    end
    return state
end

---Disposes every button first, so no callback can run for a button the game has removed.
---@param state MoonwellWrappers.DialogState
local function disposeButtons(state)
    for _, button in ipairs(state.buttons) do
        buttonInfo[button].callback = nil
        buttonRegistry.dispose(button, 'Dialog.clear')
    end
    state.buttons, state.byHandle = {}, {}
end

---The dialog trigger's action: finds the clicked button among the dialog's live buttons.
---@param dialog MoonwellWrappers.Dialog
local function route(dialog)
    local state = states[dialog]
    if not state then return end
    local button = state.byHandle[GetClickedButton()]
    if not button then return end
    local callback = buttonInfo[button].callback
    if callback then Callback.call('Dialog button', callback, PlayerWrapper.fromHandle(GetTriggerPlayer())) end
end

---@param raw dialog?
---@return MoonwellWrappers.Dialog?
---@overload fun(raw: nil): nil
function Dialog.fromHandle(raw) return registry.wrap(raw) end
---@return MoonwellWrappers.Dialog
function Dialog.create() return (Handle.created(Dialog.fromHandle(DialogCreate()), 'Dialog.create')) end
---@return dialog
function Dialog:getHandle() return (registry.require(self, 'Dialog.getHandle')) end
---@return boolean
function Dialog:isDisposed() return (registry.isDisposed(self, 'Dialog.isDisposed')) end
---@param text string
function Dialog:setMessage(text) DialogSetMessage(registry.require(self, 'Dialog.setMessage'), text) end

---Adds a button: the text, then the callback, then the options, each of the last two optional (a button with options
---and no callback is `addButton(text, nil, options)`). The callback receives the Player who clicked and runs behind
---the callback boundary: an error is printed, later clicks still run.
---@param text string
---@param callback MoonwellWrappers.DialogButtonCallback?
---@param options MoonwellWrappers.DialogButtonOptions?
---@return MoonwellWrappers.DialogButton
function Dialog:addButton(text, callback, options)
    local raw = registry.require(self, 'Dialog.addButton')
    Callback.optional(callback, 'Dialog.addButton')
    local o = Options.read(options, buttonFields, 'Dialog.addButton')
    local hotkey = 0
    if o.hotkey ~= nil then
        if not o.hotkey:match('^[A-Za-z0-9]$') then
            error("[wrappers] Dialog.addButton: 'hotkey' expected one letter or digit", 2)
        end
        hotkey = string.byte(o.hotkey:upper())
    end
    if o.scoreScreen and not o.quit then error("[wrappers] Dialog.addButton: 'scoreScreen' needs 'quit'", 2) end
    local state = stateOf(self)
    if callback and not state.trigger then
        local trigger = Handle.created(CreateTrigger(), 'Dialog.addButton')
        TriggerRegisterDialogEvent(trigger, raw)
        TriggerAddAction(trigger, function() route(self) end)
        state.trigger = trigger
    end
    local buttonRaw
    if o.quit then
        buttonRaw = DialogAddQuitButton(raw, o.scoreScreen, text, hotkey)
    else
        buttonRaw = DialogAddButton(raw, text, hotkey)
    end
    local button = Handle.created(buttonRegistry.wrap(buttonRaw), 'Dialog.addButton')
    buttonInfo[button] = {dialog = self, callback = callback}
    state.buttons[#state.buttons + 1] = button
    state.byHandle[buttonRaw] = button
    return button
end

---Shows the dialog to one player; every machine makes the same call.
---@param player MoonwellWrappers.Player
function Dialog:show(player)
    local raw = registry.require(self, 'Dialog.show')
    DialogDisplay(Handle.unwrap(player, 'Player', 'Dialog.show'), raw, true)
end
---@param player MoonwellWrappers.Player
function Dialog:hide(player)
    local raw = registry.require(self, 'Dialog.hide')
    DialogDisplay(Handle.unwrap(player, 'Player', 'Dialog.hide'), raw, false)
end
---Removes every button and disposes their wrappers. The dialog stays usable.
function Dialog:clear()
    local raw = registry.require(self, 'Dialog.clear')
    local state = states[self]
    if state then disposeButtons(state) end
    DialogClear(raw)
end
function Dialog:destroy()
    local raw = registry.dispose(self, 'Dialog.destroy')
    if not raw then return end
    local state = states[self]
    states[self] = nil
    if state then
        disposeButtons(state)
        if state.trigger then DestroyTrigger(state.trigger) end
    end
    DialogDestroy(raw)
end

---@return button
function DialogButton:getHandle() return (buttonRegistry.require(self, 'DialogButton.getHandle')) end
---@return boolean
function DialogButton:isDisposed() return (buttonRegistry.isDisposed(self, 'DialogButton.isDisposed')) end
---The dialog that made this button; still answers after the button is disposed.
---@return MoonwellWrappers.Dialog
function DialogButton:getDialog()
    buttonRegistry.isDisposed(self, 'DialogButton.getDialog')
    return buttonInfo[self].dialog
end

return Dialog
