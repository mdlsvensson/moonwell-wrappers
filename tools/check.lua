-- Lua 5.3.6 syntax of every file under src/, tests/ and tools/: yue -e tools/check.lua.
-- The game runs Lua 5.3 and the YueScript compiler's Lua is 5.4, so passing suites do not prove the syntax.
package.path = './tools/?.lua;' .. package.path
local Lib = require('lib')

local luac = Lib.quote(Lib.native(os.getenv('MOONWELL_LUAC') or 'luac'))
local version = Lib.must(luac .. ' -v')
if not version:find('Lua 5.3.6', 1, true) then error('Lua 5.3.6 luac is required, found: ' .. version, 0) end

local count = 0
for _, dir in ipairs({'src', 'tests', 'tools'}) do
    for _, file in ipairs(Lib.files(dir, '.lua')) do
        Lib.must(luac .. ' -p ' .. Lib.quote(Lib.native(file)))
        count = count + 1
    end
end

-- Prove the selected parser refuses a construct that only Lua 5.4 has.
Lib.mkdir('.test-work')
Lib.write('.test-work/lua54-syntax.lua', 'local x <const> = 1\nreturn x\n')
if Lib.run(luac .. ' -p ' .. Lib.quote(Lib.native('.test-work/lua54-syntax.lua'))) == 0 then
    error('Lua 5.4 syntax was accepted', 0)
end
print('Lua 5.3.6 syntax: ' .. count .. ' files passed; Lua 5.4-only syntax rejected')
