-- Planted native-call mistakes. Integration checks src/wrappers with LuaLS and Moonwell's native declarations; these
-- lines prove that the check reports each kind of mistake. Every other file in that check must be clean.
local model = 'model.mdx'
AddSpecialEfectTarget(model, nil, 'origin') -- EXPECT undefined-global
local effect = AddSpecialEffect(model, 0) -- EXPECT missing-parameter
DestroyEffect(effect, true) -- EXPECT redundant-parameter
SetUnitX(Player(0), 0) -- EXPECT param-type-mismatch
local function position() return 0, 0 end
SetUnitPosition(CreateUnit(Player(0), 1751543663, 0, 0, 0), position())
-- Handle.unwrap gives the handle type of the class it is asked for, so a wrong class name is a type error.
local Handle = require('wrappers.internal.handle')
SetUnitX(Handle.unwrap(nil, 'Unit', 'Test.op'), 0)
SetUnitX(Handle.unwrap(nil, 'Item', 'Test.op'), 0) -- EXPECT param-type-mismatch
return true
